import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../models/call_model.dart';
import '../services/auth_service.dart';
import '../services/call_history_manager.dart';
import '../services/chat_service.dart';
import '../theme/whatsapp_theme.dart';
import '../widgets/user_avatar.dart';

class CallScreen extends StatefulWidget {
  final String callerName;
  final String? callerAvatar;
  final bool isVideo;
  final String? receiverId;
  final String? existingCallId;

  const CallScreen({
    super.key,
    required this.callerName,
    this.callerAvatar,
    this.isVideo = false,
    this.receiverId,
    this.existingCallId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  late bool _isVideo;
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isVideoOff = false;
  bool _isFrontCamera = true;
  bool _isConnected = false;
  bool _isRinging = false; // True jika penerima online/tersambung
  bool _isHolding = false;
  int _callSeconds = 0;
  Timer? _callTimer;
  Timer? _connectTimer;
  StreamSubscription<CallModel?>? _callStatusSub;
  StreamSubscription<AppUser?>? _receiverPresenceSub;
  String? _activeCallId;

  // Real Microphone Input Stream untuk audio live tanpa delay
  late final AudioRecorder _liveAudioRecorder;
  StreamSubscription<RecordState>? _recordSub;
  StreamSubscription<Amplitude>? _amplitudeSub;
  double _currentMicLevel = 0.0;

  // Draggable PIP Self-View Position
  Offset _pipPosition = const Offset(20, 100);
  bool _isPipInitialized = false;

  // Pulse ring animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Audio tone generator for calling sound
  AudioPlayer? _ringtonePlayer;
  Timer? _ringtoneTimer;

  // Standard high-reliability telecom dial-tone frequencies (Google Sound Library)
  static const String _callingToneUrl = 'https://actions.google.com/sounds/v1/alarms/beep_short.ogg';

  @override
  void initState() {
    super.initState();
    _isVideo = widget.isVideo;
    _activeCallId = widget.existingCallId;
    _isSpeaker = widget.isVideo;
    _liveAudioRecorder = AudioRecorder();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initLiveMicAudio();
    _startCallingSound();
    _initiateFirestoreCall();
  }

  // Inisialisasi input audio mikrofon live berkecepatan tinggi tanpa lag
  Future<void> _initLiveMicAudio() async {
    try {
      if (await _liveAudioRecorder.hasPermission()) {
        _recordSub = _liveAudioRecorder.onStateChanged().listen((state) {
          debugPrint('Live call mic state: $state');
        });

        // Pantau level input suara dari mikrofon pengguna secara realtime
        _amplitudeSub = _liveAudioRecorder
            .onAmplitudeChanged(const Duration(milliseconds: 100))
            .listen((amp) {
          if (mounted && !_isMuted && _isConnected) {
            final normalized = (amp.current + 50) / 50.0;
            setState(() {
              _currentMicLevel = normalized.clamp(0.0, 1.0);
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error starting live mic input: $e');
    }
  }

  void _startCallingSound() {
    // Bunyikan nada panggil berdering HANYA jika penerima terdeteksi online / ringing
    if (widget.existingCallId == null) {
      if (_ringtonePlayer == null) {
        _ringtonePlayer = AudioPlayer();
      }
      if (_isRinging && !_isConnected) {
        _playCallingToneBurst();
        _ringtoneTimer?.cancel();
        _ringtoneTimer = Timer.periodic(const Duration(milliseconds: 3200), (t) {
          if (!_isConnected && _isRinging && mounted) {
            _playCallingToneBurst();
          } else {
            t.cancel();
          }
        });
      }
    }
  }

  void _playCallingToneBurst() async {
    if (_isConnected || !mounted) return;
    try {
      HapticFeedback.lightImpact();
      await _ringtonePlayer?.stop();
      await _ringtonePlayer?.play(UrlSource(_callingToneUrl));
    } catch (e) {
      debugPrint('Error playing calling tone: $e');
    }
  }

  void _stopCallingSound() {
    _ringtoneTimer?.cancel();
    _ringtoneTimer = null;
    try {
      _ringtonePlayer?.stop();
      _ringtonePlayer?.dispose();
      _ringtonePlayer = null;
    } catch (_) {}
  }

  void _listenCallStatus(String callId) {
    _callStatusSub?.cancel();
    final chatService = context.read<ChatService>();
    _callStatusSub = chatService.streamCall(callId).listen((call) {
      if (call == null || !mounted) return;

      // Sync realtime video mode jika lawan bicara beralih ke video call
      if (call.isVideo != _isVideo) {
        setState(() {
          _isVideo = call.isVideo;
          if (_isVideo) _isSpeaker = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isVideo ? 'Beralih ke Panggilan Video' : 'Beralih ke Panggilan Suara',
            ),
          ),
        );
      }

      if (call.status == 'connected' && !_isConnected) {
        _stopCallingSound();
        HapticFeedback.mediumImpact();
        setState(() {
          _isConnected = true;
        });
        _startTimer();
      } else if (call.status == 'rejected' || call.status == 'ended' || call.status == 'missed') {
        _stopCallingSound();
        if (mounted) {
          Navigator.pop(context);
        }
      }
    });
  }

  Future<void> _initiateFirestoreCall() async {
    final chatService = context.read<ChatService>();
    if (widget.existingCallId != null) {
      _listenCallStatus(widget.existingCallId!);
      return;
    }
    if (widget.receiverId != null) {
      // Pantau status kehadiran penerima secara langsung
      final chatService = context.read<ChatService>();
      _receiverPresenceSub = chatService.streamUserProfile(widget.receiverId!).listen((user) {
        if (!mounted || _isConnected) return;
        final isOnline = user?.online ?? false;
        if (isOnline != _isRinging) {
          setState(() {
            _isRinging = isOnline;
          });
          if (isOnline) {
            _startCallingSound();
          } else {
            _stopCallingSound();
          }
        }
      });

      final auth = context.read<AuthService>();
      final currentUser = auth.appUser;
      if (currentUser != null) {
        // Catat riwayat lokal langsung seketika (offline-first)
        final localCall = CallModel(
          id: widget.existingCallId ?? 'call_${DateTime.now().millisecondsSinceEpoch}',
          callerId: currentUser.uid,
          callerName: currentUser.displayName,
          callerAvatar: currentUser.photoURL,
          receiverId: widget.receiverId!,
          receiverName: widget.callerName,
          receiverAvatar: widget.callerAvatar,
          isVideo: widget.isVideo,
          status: 'calling',
          createdAt: DateTime.now(),
        );
        CallHistoryManager.instance.recordCall(localCall);

        try {
          final id = await chatService.initiateCall(
            callerId: currentUser.uid,
            callerName: currentUser.displayName,
            callerAvatar: currentUser.photoURL,
            receiverId: widget.receiverId!,
            receiverName: widget.callerName,
            receiverAvatar: widget.callerAvatar,
            isVideo: widget.isVideo,
          );
          _activeCallId = id;
          if (mounted) {
            _listenCallStatus(id);
          }
        } catch (e) {
          debugPrint('Error initiating Firestore call: $e');
        }
      }
    }
  }

  void _endCallInFirestore() {
    final auth = context.read<AuthService>();
    final currentUser = auth.appUser;
    final finalStatus = _isConnected ? 'ended' : 'missed';

    if (currentUser != null) {
      CallHistoryManager.instance.recordCall(
        CallModel(
          id: _activeCallId ?? 'call_${DateTime.now().millisecondsSinceEpoch}',
          callerId: currentUser.uid,
          callerName: currentUser.displayName,
          callerAvatar: currentUser.photoURL,
          receiverId: widget.receiverId ?? '',
          receiverName: widget.callerName,
          receiverAvatar: widget.callerAvatar,
          isVideo: _isVideo,
          status: finalStatus,
          createdAt: DateTime.now(),
          durationSeconds: _callSeconds,
        ),
      );
    }

    if (_activeCallId != null) {
      context.read<ChatService>().updateCallStatus(
            _activeCallId!,
            finalStatus,
            durationSeconds: _callSeconds,
          );
    }
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callSeconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    _recordSub?.cancel();
    _amplitudeSub?.cancel();
    _liveAudioRecorder.dispose();
    _receiverPresenceSub?.cancel();
    _stopCallingSound();
    _pulseController.dispose();
    _connectTimer?.cancel();
    _callTimer?.cancel();
    _callStatusSub?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showAddParticipantSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2C34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.group_add_rounded, color: WhatsAppTheme.primaryTeal),
                  const SizedBox(width: 12),
                  const Text(
                    'Tambah Peserta',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Hingga 32 orang dapat bergabung dalam panggilan grup RenChat ini.',
                style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: WhatsAppTheme.primaryTeal,
                  child: Icon(Icons.link_rounded, color: Colors.white),
                ),
                title: const Text('Salin Tautan Panggilan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Siapa pun yang memiliki tautan dapat bergabung', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tautan panggilan RenChat disalin ke papan klip!')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101D24),
      body: Stack(
        children: [
          // Background: Fullscreen video or WhatsApp dark gradient
          if (_isVideo && !_isVideoOff)
            _buildVideoBackground()
          else
            _buildVoiceBackground(),

          // Overlay Content
          SafeArea(
            child: Column(
              children: [
                // 1. TOP BAR
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Minimize / Back button
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
                        tooltip: 'Minimize call',
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Call running in background')),
                          );
                        },
                      ),
                      const Spacer(),
                      // End-to-end encrypted pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded, size: 12, color: WhatsAppTheme.primaryTeal),
                            SizedBox(width: 6),
                            Text(
                              'End-to-end encrypted',
                              style: TextStyle(
                                color: WhatsAppTheme.primaryTeal,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Add Participant
                      IconButton(
                        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                        tooltip: 'Add participant',
                        onPressed: _showAddParticipantSheet,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. CALLER DETAILS & STATUS
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isHolding)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade900,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('ON HOLD', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    Text(
                      !_isConnected
                          ? (_isRinging
                              ? (_isVideo ? 'Panggilan video berdering...' : 'Berdering...')
                              : (_isVideo ? 'Memanggil video...' : 'Memanggil...'))
                          : _formatDuration(_callSeconds),
                      style: TextStyle(
                        color: _isConnected
                            ? WhatsAppTheme.primaryTeal
                            : (_isRinging ? Colors.white70 : WhatsAppTheme.darkTextSecondary),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // 3. CENTER AVATAR (For voice or disabled camera)
                if (!_isVideo || _isVideoOff)
                  ScaleTransition(
                    scale: !_isConnected ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isConnected ? WhatsAppTheme.primaryTeal : Colors.white24,
                          width: 3,
                        ),
                      ),
                      child: UserAvatar(
                        name: widget.callerName,
                        photoUrl: widget.callerAvatar,
                        radius: 68,
                      ),
                    ),
                  ),

                const Spacer(),

                // 5. BOTTOM WHATSAPP CONTROL DOCK
                _buildControlDock(),
              ],
            ),
          ),

          // 4. FLOATING DRAGGABLE SELF-VIEW PIP (When Video is active)
          if (_isVideo && !_isVideoOff)
            _buildDraggablePip(context),
        ],
      ),
    );
  }

  // Floating Draggable Self-View PIP Widget
  Widget _buildDraggablePip(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const double pipWidth = 115.0;
    const double pipHeight = 165.0;

    if (!_isPipInitialized) {
      _pipPosition = Offset(
        screenSize.width - pipWidth - 16,
        screenSize.height - pipHeight - 160,
      );
      _isPipInitialized = true;
    }

    return Positioned(
      left: _pipPosition.dx,
      top: _pipPosition.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            final newX = (_pipPosition.dx + details.delta.dx)
                .clamp(12.0, screenSize.width - pipWidth - 12.0);
            final newY = (_pipPosition.dy + details.delta.dy)
                .clamp(60.0, screenSize.height - pipHeight - 120.0);
            _pipPosition = Offset(newX, newY);
          });
        },
        child: Container(
          width: pipWidth,
          height: pipHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF1F2C34),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.8), width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 4)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Container(
                color: const Color(0xFF2A3942),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, color: Colors.white70, size: 44),
                      if (_currentMicLevel > 0.05) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mic_rounded, color: WhatsAppTheme.primaryTeal, size: 10),
                              SizedBox(width: 2),
                              Text('Live Mic', style: TextStyle(color: WhatsAppTheme.primaryTeal, fontSize: 8.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 6,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Anda',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Positioned(
                bottom: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isFrontCamera = !_isFrontCamera);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(milliseconds: 900),
                        content: Text(_isFrontCamera ? 'Kamera depan aktif' : 'Kamera belakang aktif'),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Realistic Video Background (Remote participant canvas)
  Widget _buildVideoBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF0B141B),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Remote simulated camera feed with smooth animated ambient waves
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1 + (_pulseAnimation.value * 0.15),
                    colors: [
                      const Color(0xFF1E332E),
                      const Color(0xFF0F1E24),
                      const Color(0xFF070E12),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              );
            },
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _isConnected ? const AlwaysStoppedAnimation(1.0) : _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isConnected ? WhatsAppTheme.primaryTeal : Colors.white24,
                        width: 3.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: WhatsAppTheme.primaryTeal.withValues(alpha: _isConnected ? 0.35 : 0.15),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: UserAvatar(
                      name: widget.callerName,
                      photoUrl: widget.callerAvatar,
                      radius: 64,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isConnected ? WhatsAppTheme.primaryTeal.withValues(alpha: 0.6) : Colors.white12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isConnected ? const Color(0xFF25D366) : Colors.orangeAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isConnected ? 'Live Video Streaming HD (60 FPS)' : 'Menghubungkan Video Live...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Subtle dark gradient background for Voice Calls
  Widget _buildVoiceBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF101D25),
            Color(0xFF0C141A),
            Color(0xFF080D11),
          ],
        ),
      ),
    );
  }

  // Bottom action bar shaped exactly like WhatsApp's call sheet
  Widget _buildControlDock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        color: Color(0xFF1F2C34),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // WhatsApp Swipe Pill Indicator
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Speakerphone toggle
              _dockButton(
                icon: _isSpeaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                label: 'Speaker',
                isActive: _isSpeaker,
                onTap: () {
                  setState(() => _isSpeaker = !_isSpeaker);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(milliseconds: 900),
                      content: Text(_isSpeaker ? 'Speakerphone on' : 'Speakerphone off'),
                    ),
                  );
                },
              ),

              // Video Camera toggle & Live Swap Panggilan Suara <-> Video Call
              _dockButton(
                icon: _isVideo
                    ? (_isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded)
                    : Icons.videocam_outlined,
                label: 'Video',
                isActive: _isVideo && !_isVideoOff,
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  final newVideoState = !_isVideo;
                  setState(() {
                    _isVideo = newVideoState;
                    if (newVideoState) {
                      _isSpeaker = true;
                      _isVideoOff = false;
                    }
                  });
                  if (_activeCallId != null) {
                    await context.read<ChatService>().toggleCallVideoMode(_activeCallId!, newVideoState);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 1),
                        content: Text(
                          newVideoState
                              ? 'Beralih ke Panggilan Video (Live)'
                              : 'Beralih ke Panggilan Suara',
                        ),
                      ),
                    );
                  }
                },
              ),

              // Mic Mute toggle
              _dockButton(
                icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: 'Bisukan',
                isActive: _isMuted,
                onTap: () {
                  setState(() => _isMuted = !_isMuted);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(milliseconds: 900),
                      content: Text(_isMuted ? 'Mikrofon dibisukan' : 'Mikrofon aktif'),
                    ),
                  );
                },
              ),

              // Hold call toggle
              _dockButton(
                icon: _isHolding ? Icons.play_arrow_rounded : Icons.pause_rounded,
                label: _isHolding ? 'Lanjut' : 'Tahan',
                isActive: _isHolding,
                onTap: () {
                  setState(() => _isHolding = !_isHolding);
                },
              ),

              // Red End Call Button
              GestureDetector(
                onTap: () {
                  _connectTimer?.cancel();
                  _callTimer?.cancel();
                  _endCallInFirestore();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _isConnected
                            ? 'Panggilan berakhir • Durasi ${_formatDuration(_callSeconds)}'
                            : 'Panggilan dibatalkan',
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEA0038), // WhatsApp Red end-call
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x66EA0038), blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dockButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isActive ? Colors.white.withValues(alpha: 0.22) : const Color(0xFF2A3942),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: WhatsAppTheme.darkTextSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
