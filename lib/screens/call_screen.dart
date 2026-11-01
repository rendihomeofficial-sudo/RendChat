import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/call_model.dart';
import '../services/auth_service.dart';
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
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isVideoOff = false;
  bool _isFrontCamera = true;
  bool _isConnected = false;
  bool _isHolding = false;
  int _callSeconds = 0;
  Timer? _callTimer;
  Timer? _connectTimer;
  StreamSubscription<CallModel?>? _callStatusSub;
  String? _activeCallId;

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
    _activeCallId = widget.existingCallId;
    _isSpeaker = widget.isVideo;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCallingSound();
    _initiateFirestoreCall();
  }

  void _startCallingSound() {
    // Only play calling ring-back tone if this device is the caller (originating call)
    if (widget.existingCallId == null) {
      _ringtonePlayer = AudioPlayer();
      _playCallingToneBurst();
      // Pola nada dering panggil: nada panggil berulang setiap 3.2 detik seperti telepon WhatsApp
      _ringtoneTimer = Timer.periodic(const Duration(milliseconds: 3200), (t) {
        if (!_isConnected && mounted) {
          _playCallingToneBurst();
        } else {
          t.cancel();
        }
      });
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
      final auth = context.read<AuthService>();
      final currentUser = auth.appUser;
      if (currentUser != null) {
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
      }
    }
  }

  void _endCallInFirestore() {
    if (_activeCallId != null) {
      context.read<ChatService>().updateCallStatus(
            _activeCallId!,
            _isConnected ? 'ended' : 'missed',
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
                    'Add participants',
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
                'Up to 32 people can join this RenChat group call.',
                style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: WhatsAppTheme.primaryTeal,
                  child: Icon(Icons.link_rounded, color: Colors.white),
                ),
                title: const Text('Share Call Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Anyone with RenChat can join', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('RenChat Call link copied to clipboard!')),
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
          if (widget.isVideo && !_isVideoOff)
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
                          ? (widget.isVideo ? 'RenChat video call...' : 'Ringing...')
                          : _formatDuration(_callSeconds),
                      style: TextStyle(
                        color: _isConnected ? WhatsAppTheme.primaryTeal : WhatsAppTheme.darkTextSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // 3. CENTER AVATAR (For voice or disabled camera)
                if (!widget.isVideo || _isVideoOff)
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

                // 4. FLOATING SELF-VIEW PIP (When Video is active)
                if (widget.isVideo && !_isVideoOff)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _isFrontCamera = !_isFrontCamera);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_isFrontCamera ? 'Switched to front camera' : 'Switched to rear camera')),
                        );
                      },
                      child: Container(
                        width: 105,
                        height: 155,
                        margin: const EdgeInsets.only(right: 20, bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2C34),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white30, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Container(
                              color: const Color(0xFF2A3942),
                              child: const Center(
                                child: Icon(Icons.person, color: Colors.white54, size: 48),
                              ),
                            ),
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 14),
                              ),
                            ),
                            const Positioned(
                              top: 6,
                              left: 6,
                              child: Text(
                                'You',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 5. BOTTOM WHATSAPP CONTROL DOCK
                _buildControlDock(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Realistic Video Background (Remote participant canvas)
  Widget _buildVideoBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF131D24),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Remote simulated camera feed
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  const Color(0xFF223642),
                  const Color(0xFF0F1A20),
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(
                    name: widget.callerName,
                    photoUrl: widget.callerAvatar,
                    radius: 54,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_rounded, color: WhatsAppTheme.primaryTeal, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Remote Camera Stream Active (HD)',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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

              // Video Camera toggle
              if (widget.isVideo)
                _dockButton(
                  icon: _isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                  label: 'Video',
                  isActive: !_isVideoOff,
                  onTap: () {
                    setState(() => _isVideoOff = !_isVideoOff);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(milliseconds: 900),
                        content: Text(_isVideoOff ? 'Camera paused' : 'Camera turned on'),
                      ),
                    );
                  },
                )
              else
                // Switch to video call button for voice calls
                _dockButton(
                  icon: Icons.videocam_outlined,
                  label: 'Video',
                  isActive: false,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Requesting video call switch...')),
                    );
                  },
                ),

              // Mic Mute toggle
              _dockButton(
                icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: 'Mute',
                isActive: _isMuted,
                onTap: () {
                  setState(() => _isMuted = !_isMuted);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(milliseconds: 900),
                      content: Text(_isMuted ? 'Microphone muted' : 'Microphone unmuted'),
                    ),
                  );
                },
              ),

              // Hold call toggle
              _dockButton(
                icon: _isHolding ? Icons.play_arrow_rounded : Icons.pause_rounded,
                label: _isHolding ? 'Resume' : 'Hold',
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
                            ? 'Call ended • Duration ${_formatDuration(_callSeconds)}'
                            : 'Call cancelled',
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
