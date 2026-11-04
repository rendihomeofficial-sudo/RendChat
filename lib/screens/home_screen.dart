import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../models/status_model.dart';
import '../models/message_model.dart';
import '../models/call_model.dart';
import '../services/app_update_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../services/ringtone_service.dart';
import '../services/call_history_manager.dart';
import '../services/lock_chat_passcode_manager.dart';
import '../theme/whatsapp_theme.dart';
import '../widgets/user_avatar.dart';
import '../widgets/chat_feedback_widgets.dart';
import 'camera_qr_scanner_screen.dart';
import 'media_status_composer_screen.dart';
import 'chat_screen.dart';
import 'contacts_screen.dart';
import 'new_group_screen.dart';
import 'profile_screen.dart';
import 'starred_messages_screen.dart';
import 'call_screen.dart';
import 'status_viewer_screen.dart';
import 'text_status_composer_screen.dart';
import 'archived_chats_screen.dart';
import 'locked_chats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  String _selectedFilter = 'All';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<CallModel?>? _incomingCallSub;
  String? _showingCallId;

  final List<String> _filters = ['Semua', 'Belum Dibaca', 'Favorit', 'Grup'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.instance.checkUpdateOnStartup();
      _listenIncomingCalls();
    });
  }

  bool _isFollowingOfficialChannel = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _captureAndPostMediaStatus({bool fromCamera = true, bool isVideo = false}) async {
    try {
      XFile? picked;
      if (isVideo) {
        picked = await _picker.pickVideo(
          source: fromCamera ? ImageSource.camera : ImageSource.gallery,
          maxDuration: const Duration(seconds: 45),
        );
      } else {
        picked = await _picker.pickImage(
          source: fromCamera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1440,
          maxHeight: 1440,
          imageQuality: 82, // Dioptimalkan untuk kejernihan visual & ukuran efisien
        );
      }
      if (picked == null) return;

      if (!mounted) return;
      // Buka editor/composer media status untuk menambahkan Caption & Emotion
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MediaStatusComposerScreen(
            file: picked!,
            isVideo: isVideo,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error selecting media status: $e');
      if (mounted) {
        showPremiumNotificationToast(
          context,
          title: 'Terjadi Kesalahan',
          message: 'Gagal memilih media: $e',
          icon: Icons.error_outline_rounded,
          accentColor: const Color(0xFFEF4444),
        );
      }
    }
  }

  void _showStatusCreationOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Buat Status Baru',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: WhatsAppTheme.primaryTeal, size: 24),
                ),
                title: const Text('Ambil Foto Kamera (HD)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Potret langsung dengan kamera beresolusi tinggi', style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _captureAndPostMediaStatus(fromCamera: true, isVideo: false);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFAC44CF).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFFAC44CF), size: 24),
                ),
                title: const Text('Pilih Foto dari Galeri (HD)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Unggah gambar berkualitas jernih tanpa pecah', style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _captureAndPostMediaStatus(fromCamera: false, isVideo: false);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE542A3).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam_rounded, color: Color(0xFFE542A3), size: 24),
                ),
                title: const Text('Pilih Video Status (HD)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Rekam atau pilih video hingga 45 detik', style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _captureAndPostMediaStatus(fromCamera: false, isVideo: true);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF009DE2).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: Color(0xFF009DE2), size: 24),
                ),
                title: const Text('Buat Status Teks & Musik', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Status warna teks dan pilihan musik latar WhatsApp', style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TextStatusComposerScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _listenIncomingCalls() {
    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final uid = auth.currentUid;
    if (uid == null) return;

    _incomingCallSub?.cancel();
    _incomingCallSub = chatService.streamIncomingCall(uid).listen((incoming) {
      if (incoming != null && incoming.id != _showingCallId && mounted) {
        _showingCallId = incoming.id;
        RingtoneService.instance.startIncomingRingtone();
        _showIncomingCallDialog(incoming);
      } else if (incoming == null && _showingCallId != null) {
        // Panggilan dibatalkan oleh pemanggil sebelum diangkat
        RingtoneService.instance.stopRingtone();
        _showingCallId = null;
      }
    });
  }

  void _showIncomingCallDialog(CallModel call) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2C34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              call.isVideo ? Icons.videocam_rounded : Icons.phone_in_talk_rounded,
              color: WhatsAppTheme.primaryTeal,
            ),
            const SizedBox(width: 8),
            Text(
              call.isVideo ? 'Panggilan Video Masuk' : 'Panggilan Suara Masuk',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: WhatsAppTheme.primaryTeal, width: 2.5),
              ),
              child: UserAvatar(
                name: call.callerName,
                photoUrl: call.callerAvatar,
                radius: 40,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              call.callerName,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Memanggil Anda di RenChat...',
              style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.call_end_rounded),
            label: const Text('Tolak'),
            onPressed: () {
              RingtoneService.instance.stopRingtone();
              Navigator.pop(ctx);
              context.read<ChatService>().updateCallStatus(call.id, 'rejected');
              _showingCallId = null;
            },
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: WhatsAppTheme.primaryTeal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: Icon(call.isVideo ? Icons.videocam_rounded : Icons.call_rounded),
            label: const Text('Terima', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              RingtoneService.instance.stopRingtone();
              Navigator.pop(ctx);
              _showingCallId = null;
              context.read<ChatService>().updateCallStatus(call.id, 'connected');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    callerName: call.callerName,
                    callerAvatar: call.callerAvatar,
                    isVideo: call.isVideo,
                    existingCallId: call.id,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ).then((_) {
      RingtoneService.instance.stopRingtone();
    });
  }

  @override
  void dispose() {
    _incomingCallSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final currentUser = auth.appUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: _currentTabIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Jika sedang di tab lain selain Chats (tab 0), kembali ke tab Chats alih-alih keluar aplikasi
        setState(() {
          _currentTabIndex = 0;
        });
      },
      child: Scaffold(
        appBar: _buildAppBar(context, currentUser),
        body: Column(
        children: [
          // Banner popup otomatis saat versi baru tersedia di GitHub.
          const UpdateBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                _buildChatsTab(context, currentUser),
                _buildUpdatesTab(context, currentUser),
                _buildCommunitiesTab(context, currentUser),
                _buildCallsTab(context, currentUser),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: WhatsAppTheme.darkSurface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentTabIndex,
          onDestinationSelected: (index) {
            HapticFeedback.selectionClick();
            setState(() => _currentTabIndex = index);
          },
          backgroundColor: Colors.transparent,
          indicatorColor: WhatsAppTheme.primaryTeal.withValues(alpha: 0.22),
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded, color: WhatsAppTheme.darkTextSecondary),
              selectedIcon: Icon(Icons.chat_bubble_rounded, color: WhatsAppTheme.primaryTeal),
              label: 'Obrolan',
            ),
            NavigationDestination(
              icon: Icon(Icons.update_rounded, color: WhatsAppTheme.darkTextSecondary),
              selectedIcon: Icon(Icons.update_rounded, color: WhatsAppTheme.primaryTeal),
              label: 'Pembaruan',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined, color: WhatsAppTheme.darkTextSecondary),
              selectedIcon: Icon(Icons.groups_rounded, color: WhatsAppTheme.primaryTeal),
              label: 'Komunitas',
            ),
            NavigationDestination(
              icon: Icon(Icons.call_outlined, color: WhatsAppTheme.darkTextSecondary),
              selectedIcon: Icon(Icons.call_rounded, color: WhatsAppTheme.primaryTeal),
              label: 'Panggilan',
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(context),
    ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AppUser currentUser) {
    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchController.clear();
            });
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 17),
          decoration: const InputDecoration(
            hintText: 'Search or enter secret code...',
            hintStyle: TextStyle(color: WhatsAppTheme.darkTextSecondary),
            border: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() {});
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                });
              },
            ),
        ],
      );
    }

    final titles = ['RenChat', 'Pembaruan', 'Komunitas', 'Panggilan'];
    return AppBar(
      title: Text(
        titles[_currentTabIndex],
        style: TextStyle(
          color: _currentTabIndex == 0 ? WhatsAppTheme.primaryTeal : null,
          fontWeight: FontWeight.bold,
          fontSize: 22,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.camera_alt_outlined),
          tooltip: 'Status Media',
          onPressed: () => _showStatusCreationOptionsSheet(context),
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Search',
          onPressed: () {
            setState(() {
              _isSearching = true;
            });
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) {
            if (value == 'new_group') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewGroupScreen()),
              );
            } else if (value == 'new_broadcast') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewGroupScreen(isBroadcast: true)),
              );
            } else if (value == 'linked_devices') {
              _showLinkedDevicesDialog(context);
            } else if (value == 'starred') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StarredMessagesScreen()),
              );
            } else if (value == 'profile' || value == 'settings') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'new_group',
              child: Text('New group'),
            ),
            const PopupMenuItem(
              value: 'new_broadcast',
              child: Text('New broadcast'),
            ),
            const PopupMenuItem(
              value: 'linked_devices',
              child: Text('Linked devices'),
            ),
            const PopupMenuItem(
              value: 'starred',
              child: Text('Starred messages'),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Text('Settings'),
            ),
          ],
        ),
      ],
    );
  }

  Widget? _buildFab(BuildContext context) {
    switch (_currentTabIndex) {
      case 0: // Chats
        return FloatingActionButton(
          tooltip: 'New Chat',
          child: const Icon(Icons.message_rounded),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactsScreen()),
            );
          },
        );
      case 1: // Updates/Status
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 40,
              width: 40,
              child: FloatingActionButton.small(
                backgroundColor: WhatsAppTheme.darkPill,
                foregroundColor: Colors.white,
                child: const Icon(Icons.edit_rounded, size: 20),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TextStatusComposerScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              tooltip: 'Add Status',
              child: const Icon(Icons.camera_alt_rounded),
              onPressed: () => _showStatusCreationOptionsSheet(context),
            ),
          ],
        );
      case 3: // Calls
        return FloatingActionButton(
          tooltip: 'New Call',
          child: const Icon(Icons.add_call),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactsScreen()),
            );
          },
        );
      default:
        return null;
    }
  }

  // 1. CHATS TAB
  Widget _buildChatsTab(BuildContext context, AppUser currentUser) {
    final chatService = context.read<ChatService>();
    return Column(
      children: [
        // Filter Pills Row (WhatsApp Modern: All, Unread, Favorites, Groups)
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final f = _filters[idx];
              final isSelected = _selectedFilter == f;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedFilter = f);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? WhatsAppTheme.primaryTeal.withValues(alpha: 0.2)
                        : WhatsAppTheme.darkPill,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? WhatsAppTheme.primaryTeal : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? WhatsAppTheme.primaryTeal : WhatsAppTheme.darkTextSecondary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // WhatsApp Locked Chats Folder (Secret PIN/Biometric Chats)
        ValueListenableBuilder<bool>(
          valueListenable: LockChatPasscodeManager().hideLockedChatsNotifier,
          builder: (context, isHidden, _) {
            final query = _searchController.text.trim();
            final secretPasscode = LockChatPasscodeManager().currentPasscode;
            final isSecretCodeEntered = query == secretPasscode;

            return StreamBuilder<List<Chat>>(
              stream: chatService.streamUserChats(currentUser.uid),
              builder: (context, snap) {
                final allChats = snap.data ?? [];
                final lockedCount = allChats.where((c) => c.isLockedBy(currentUser.uid)).length;
                final archivedCount = allChats.where((c) => c.isArchivedBy(currentUser.uid)).length;

                // If hidden, only show when secret code is typed into search bar
                final shouldShowLocked = lockedCount > 0 && (!isHidden || isSecretCodeEntered);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (shouldShowLocked)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.lock_rounded, size: 20, color: WhatsAppTheme.primaryTeal),
                        title: Row(
                          children: [
                            const Text('Locked chats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            if (isHidden && isSecretCodeEntered) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Secret Code Match',
                                  style: TextStyle(color: WhatsAppTheme.primaryTeal, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Text(
                          '$lockedCount',
                          style: const TextStyle(color: WhatsAppTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LockedChatsScreen()),
                          );
                        },
                      ),
                    // WhatsApp Archived Chats Folder
                    if (!_isSearching)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.archive_outlined, size: 20, color: WhatsAppTheme.darkTextSecondary),
                        title: const Text('Archived', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        trailing: Text(
                          '$archivedCount',
                          style: TextStyle(
                            color: archivedCount > 0 ? WhatsAppTheme.primaryTeal : WhatsAppTheme.darkTextSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ArchivedChatsScreen()),
                          );
                        },
                      ),
                    const Divider(height: 1),
                  ],
                );
              },
            );
          },
        ),
        // Chat List Stream
        Expanded(
          child: StreamBuilder<List<Chat>>(
            stream: chatService.streamUserChats(currentUser.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var chats = snapshot.data ?? [];

              // Exclude archived and locked chats from the main chat list (matching WhatsApp APK)
              chats = chats.where((c) => !c.isArchivedBy(currentUser.uid) && !c.isLockedBy(currentUser.uid)).toList();

              // Sort pinned chats to the top, then by lastMessageAt desc
              chats.sort((a, b) {
                final aPinned = a.isPinnedBy(currentUser.uid);
                final bPinned = b.isPinnedBy(currentUser.uid);
                if (aPinned && !bPinned) return -1;
                if (!aPinned && bPinned) return 1;
                final aDate = a.lastMessageAt ?? a.createdAt;
                final bDate = b.lastMessageAt ?? b.createdAt;
                return bDate.compareTo(aDate);
              });

              // Filter logic
              if (_selectedFilter == 'Unread') {
                chats = chats.where((c) => (c.unread[currentUser.uid] ?? 0) > 0).toList();
              } else if (_selectedFilter == 'Groups') {
                chats = chats.where((c) => c.isGroup).toList();
              }

              // Search query filter
              final q = _searchController.text.trim().toLowerCase();
              if (q.isNotEmpty && q != LockChatPasscodeManager().currentPasscode) {
                chats = chats.where((c) {
                  final title = c.getDisplayTitle(currentUser.uid).toLowerCase();
                  final last = (c.lastMessage ?? '').toLowerCase();
                  return title.contains(q) || last.contains(q);
                }).toList();
              }

              if (chats.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 72,
                          color: WhatsAppTheme.darkTextSecondary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No chats yet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap the green button below to start messaging friends on RenChat.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: WhatsAppTheme.darkTextSecondary),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: WhatsAppTheme.primaryTeal,
                          ),
                          icon: const Icon(Icons.chat_rounded),
                          label: const Text('Start Chat'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ContactsScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                cacheExtent: 500,
                itemCount: chats.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  indent: 74,
                  endIndent: 16,
                  color: Color(0xFF1E282E),
                ),
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  // Swipe untuk mengarsipkan chat, seperti di WhatsApp.
                  return Dismissible(
                    key: ValueKey('chat_tile_${chat.id}'),
                    direction: DismissDirection.startToEnd,
                    background: Container(
                      color: WhatsAppTheme.darkSurface,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 24),
                      child: const Row(
                        children: [
                          Icon(Icons.archive_rounded, color: WhatsAppTheme.primaryTeal),
                          SizedBox(width: 8),
                          Text(
                            'Archive',
                            style: TextStyle(
                              color: WhatsAppTheme.primaryTeal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    confirmDismiss: (_) async {
                      HapticFeedback.mediumImpact();
                      final archived = await chatService.toggleArchiveChat(
                        chatId: chat.id,
                        userId: currentUser.uid,
                      );
                      if (!context.mounted) return false;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            archived ? 'Chat archived' : 'Chat unarchived',
                          ),
                        ),
                      );
                      return false; // daftar di-stream ulang oleh Firestore
                    },
                    child: _WhatsAppChatTile(
                      chat: chat,
                      currentUserId: currentUser.uid,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // 2. UPDATES / STATUS TAB
  Widget _buildUpdatesTab(BuildContext context, AppUser currentUser) {
    final chatService = context.read<ChatService>();

    return StreamBuilder<List<StatusModel>>(
      stream: chatService.streamActiveStatuses(),
      builder: (context, snapshot) {
        final allStatuses = snapshot.data ?? [];
        final myStatuses = allStatuses.where((s) => s.userId == currentUser.uid).toList();
        final otherStatuses = allStatuses.where((s) => s.userId != currentUser.uid).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: myStatuses.isNotEmpty
                          ? Border.all(color: WhatsAppTheme.primaryTeal, width: 2.2)
                          : null,
                    ),
                    child: UserAvatar(
                      name: currentUser.displayName,
                      photoUrl: currentUser.photoURL,
                      radius: 24,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: WhatsAppTheme.primaryTeal,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
              title: const Text('My status', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                myStatuses.isNotEmpty
                    ? 'Published ${DateFormat('h:mm a').format(myStatuses.first.createdAt)} • ${myStatuses.length} update'
                    : 'Tap to add status update',
                style: const TextStyle(color: WhatsAppTheme.darkTextSecondary),
              ),
              trailing: myStatuses.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.more_vert, color: WhatsAppTheme.darkTextSecondary),
                      onPressed: () {
                        final latest = myStatuses.first;
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: const Color(0xFF1F2C34),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (bCtx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.visibility_outlined, color: WhatsAppTheme.primaryTeal),
                                  title: const Text('Lihat Status', style: TextStyle(color: Colors.white)),
                                  onTap: () {
                                    Navigator.pop(bCtx);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StatusViewerScreen(
                                          statusId: latest.id,
                                          userId: currentUser.uid,
                                          userName: 'My Status',
                                          userAvatar: currentUser.photoURL,
                                          statusText: latest.text,
                                          mediaUrl: latest.mediaUrl,
                                          musicUrl: latest.musicUrl,
                                          musicTitle: latest.musicTitle,
                                          backgroundColor: Color(latest.backgroundColor),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                  title: const Text(
                                    'Hapus Status',
                                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                  ),
                                  onTap: () {
                                    Navigator.pop(bCtx);
                                    showDialog(
                                      context: context,
                                      builder: (dCtx) => AlertDialog(
                                        backgroundColor: const Color(0xFF1F2C34),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                        title: const Text('Hapus status?'),
                                        content: const Text(
                                          'Update status ini akan dihapus permanen untuk semua orang.',
                                          style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dCtx),
                                            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                                            onPressed: () async {
                                              Navigator.pop(dCtx);
                                              try {
                                                await chatService.deleteStatus(
                                                  statusId: latest.id,
                                                  userId: currentUser.uid,
                                                );
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Status berhasil dihapus!'),
                                                      backgroundColor: WhatsAppTheme.primaryTeal,
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Gagal menghapus status: $e')),
                                                  );
                                                }
                                              }
                                            },
                                            child: const Text('Hapus'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : null,
              onTap: () {
                if (myStatuses.isNotEmpty) {
                  final latest = myStatuses.first;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StatusViewerScreen(
                        statusId: latest.id,
                        userId: currentUser.uid,
                        userName: 'My Status',
                        userAvatar: currentUser.photoURL,
                        statusText: latest.text,
                        mediaUrl: latest.mediaUrl,
                        musicUrl: latest.musicUrl,
                        musicTitle: latest.musicTitle,
                        backgroundColor: Color(latest.backgroundColor),
                      ),
                    ),
                  );
                } else {
                  _showStatusCreationOptionsSheet(context);
                }
              },
            ),
            const Divider(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Recent updates',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: WhatsAppTheme.darkTextSecondary,
                ),
              ),
            ),
            if (otherStatuses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Text(
                  'No recent status updates from your contacts.',
                  style: TextStyle(color: WhatsAppTheme.darkTextSecondary),
                ),
              )
            else
              ...otherStatuses.map((st) {
                final isViewed = st.isViewedBy(currentUser.uid);
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(2.8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isViewed
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF00A884), Color(0xFF25D366), Color(0xFF128C7E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      border: isViewed
                          ? Border.all(color: Colors.white24, width: 2.0)
                          : null,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                        color: WhatsAppTheme.darkBg,
                        shape: BoxShape.circle,
                      ),
                      child: UserAvatar(
                        name: st.userName,
                        photoUrl: st.userAvatar,
                        radius: 21,
                      ),
                    ),
                  ),
                  title: Text(st.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    DateFormat('h:mm a').format(st.createdAt),
                    style: const TextStyle(color: WhatsAppTheme.darkTextSecondary),
                  ),
                  onTap: () {
                    chatService.markStatusViewed(
                      statusId: st.id,
                      viewerId: currentUser.uid,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StatusViewerScreen(
                          statusId: st.id,
                          userId: st.userId,
                          userName: st.userName,
                          userAvatar: st.userAvatar,
                          statusText: st.text,
                          mediaUrl: st.mediaUrl,
                          musicUrl: st.musicUrl,
                          musicTitle: st.musicTitle,
                          backgroundColor: Color(st.backgroundColor),
                        ),
                      ),
                    );
                  },
                );
              }),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Saluran Resmi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  InkWell(
                    onTap: () async {
                      final url = Uri.parse('https://github.com/rendihomeofficial-sudo/RendChat/releases');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Rilis GitHub >',
                        style: TextStyle(color: WhatsAppTheme.primaryTeal, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // RenChat Official Channel Card with Live Release Info
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1B272C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF008069),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_rounded, color: Colors.white, size: 22),
                    ),
                    title: const Row(
                      children: [
                        Text('RenChat Official', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(width: 6),
                        Icon(Icons.check_circle_rounded, color: WhatsAppTheme.primaryTeal, size: 16),
                      ],
                    ),
                    subtitle: const Text('Saluran Informasi Pembaruan & Fitur Resmi', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
                    trailing: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _isFollowingOfficialChannel ? Colors.white : WhatsAppTheme.primaryTeal,
                        backgroundColor: _isFollowingOfficialChannel ? WhatsAppTheme.primaryTeal : null,
                        side: const BorderSide(color: WhatsAppTheme.primaryTeal),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: Icon(
                        _isFollowingOfficialChannel ? Icons.check_rounded : Icons.add_rounded,
                        size: 16,
                      ),
                      onPressed: () {
                        setState(() => _isFollowingOfficialChannel = !_isFollowingOfficialChannel);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isFollowingOfficialChannel
                                  ? 'Berhasil mengikuti Saluran Resmi RenChat!'
                                  : 'Berhenti mengikuti Saluran Resmi RenChat',
                            ),
                          ),
                        );
                      },
                      label: Text(_isFollowingOfficialChannel ? 'Mengikuti' : 'Ikuti'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Consumer<AppUpdateService>(
                          builder: (context, updateService, _) {
                            final liveInfo = updateService.latestReleaseInfo ?? updateService.updateInfo;
                            final versionLabel = liveInfo != null
                                ? 'v${liveInfo.version} Live'
                                : 'v1.3.14 Live';
                            final releaseNotes = liveInfo?.releaseNotes != null && liveInfo!.releaseNotes.isNotEmpty
                                ? liveInfo.releaseNotes
                                : '📢 Catatan Rilis Resmi RenChat:\n'
                                  '• Bisukan Notifikasi Nyata (Mute): Opsi menu dan pengaturan kontak kini menyimpan status durasi bisu (8 Jam, 1 Minggu, atau Selalu) langsung ke Cloud Firestore.\n'
                                  '• Pesan Sementara Interaktif (Disappearing Messages): Pilihan durasi hapus otomatis (24 Jam, 7 Hari, 90 Hari, atau Mati) tersimpan dan tersinkronisasi di obrolan.\n'
                                  '• Pembersihan Obrolan Model WhatsApp: clearedAt per-user menjaga pesan tetap bersih di perangkat Anda tanpa menghapus riwayat obrolan lawan bicara.\n'
                                  '• Kamera Fisik Nyata Video Call PIP: CameraController mengontrol sensor optik kamera depan secara nyata.';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: WhatsAppTheme.darkChatBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'VERSI TERBARU',
                                          style: TextStyle(color: WhatsAppTheme.primaryTeal, fontSize: 10.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(versionLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    releaseNotes,
                                    style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.open_in_new_rounded, size: 16, color: WhatsAppTheme.primaryTeal),
                              label: const Text('Buka Rilis GitHub', style: TextStyle(color: WhatsAppTheme.primaryTeal, fontWeight: FontWeight.bold, fontSize: 12.5)),
                              onPressed: () async {
                                final url = Uri.parse('https://github.com/rendihomeofficial-sudo/RendChat/releases');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: WhatsAppTheme.primaryTeal,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              icon: const Icon(Icons.system_update_rounded, size: 16),
                              label: const Text('Periksa Update', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                showUpdateDialog(context);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // 3. COMMUNITIES TAB
  Widget _buildCommunitiesTab(BuildContext context, AppUser currentUser) {
    final chatService = context.read<ChatService>();

    return StreamBuilder<List<Chat>>(
      stream: chatService.streamUserChats(currentUser.uid),
      builder: (context, snapshot) {
        final allChats = snapshot.data ?? [];
        final communityChats = allChats
            .where((c) => c.isGroup && (c.title?.startsWith('🌐') == true || c.title?.toLowerCase().contains('komunitas') == true || c.title?.toLowerCase().contains('community') == true))
            .toList();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            // Tombol Buat Komunitas Baru
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_add_rounded, color: WhatsAppTheme.primaryTeal, size: 26),
              ),
              title: const Text('Buat Komunitas Baru', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Satukan grup bertopik dan bagikan pengumuman resmi', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
              onTap: () => _showNewCommunityDialog(context),
            ),
            const Divider(height: 24, indent: 72),
            if (communityChats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: WhatsAppTheme.darkPill,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        size: 80,
                        color: WhatsAppTheme.primaryTeal,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Tetap Terhubung dengan Komunitas',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Komunitas menyatukan anggota dalam beberapa grup topik dan mempermudah pengiriman pengumuman admin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13.5),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WhatsAppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Mulai Komunitas Anda', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _showNewCommunityDialog(context),
                    ),
                  ],
                ),
              )
            else ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Komunitas Anda',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: WhatsAppTheme.darkTextSecondary),
                ),
              ),
              ...communityChats.map((c) => _WhatsAppChatTile(chat: c, currentUserId: currentUser.uid)),
            ],
          ],
        );
      },
    );
  }

  // 4. CALLS TAB
  Widget _buildCallsTab(BuildContext context, AppUser currentUser) {
    final chatService = context.read<ChatService>();

    return StreamBuilder<List<CallModel>>(
      stream: chatService.streamUserCalls(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          CallHistoryManager.instance.syncRemoteCalls(snapshot.data!);
        }

        return ValueListenableBuilder<List<CallModel>>(
          valueListenable: CallHistoryManager.instance.callsNotifier,
          builder: (context, calls, _) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: WhatsAppTheme.primaryTeal,
                    child: Icon(Icons.link_rounded, color: Colors.white),
                  ),
                  title: const Text('Create call link', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Share a link for your RenChat call',
                      style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
                  onTap: () {
                    _showCallLinkDialog(context);
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'Recent',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15, color: WhatsAppTheme.darkTextSecondary),
                  ),
                ),
                if (calls.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Center(
                      child: Text(
                        'Belum ada riwayat panggilan. Mulai panggilan suara atau video dari chat Anda!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: WhatsAppTheme.darkTextSecondary),
                      ),
                    ),
                  )
                else
                  ...calls.map((c) {
                    final isCaller = c.callerId == currentUser.uid;
                    final displayName = isCaller ? c.receiverName : c.callerName;
                    final displayAvatar = isCaller ? c.receiverAvatar : c.callerAvatar;
                    final isMissed = c.status == 'missed' || c.status == 'rejected';

                    return ListTile(
                      leading: UserAvatar(
                        name: displayName,
                        photoUrl: displayAvatar,
                        radius: 22,
                      ),
                      title: Text(
                        displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isMissed && !isCaller ? Colors.redAccent : null,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Icon(
                            isCaller ? Icons.call_made_rounded : Icons.call_received_rounded,
                            size: 16,
                            color: isMissed ? Colors.redAccent : Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${DateFormat('MMM d, h:mm a').format(c.createdAt)}${c.durationSeconds > 0 ? ' • ${c.durationSeconds}s' : ''}',
                            style: const TextStyle(color: WhatsAppTheme.darkTextSecondary),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          c.isVideo ? Icons.videocam_outlined : Icons.call_outlined,
                          color: WhatsAppTheme.primaryTeal,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CallScreen(
                                callerName: displayName,
                                callerAvatar: displayAvatar,
                                isVideo: c.isVideo,
                                receiverId: isCaller ? c.receiverId : c.callerId,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }

  void _showLinkedDevicesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.devices_rounded, color: WhatsAppTheme.primaryTeal),
            SizedBox(width: 8),
            Text('Linked Devices'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(Icons.laptop_mac_rounded, size: 64, color: WhatsAppTheme.primaryTeal),
            ),
            const SizedBox(height: 16),
            const Text(
              'Use RenChat on Web, Desktop, and other devices without keeping your phone online.',
              style: TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Link a device'),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CameraQrScannerScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCallLinkDialog(BuildContext context) {
    final link = 'https://call.whatsapp.com/v1/${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.link_rounded, color: WhatsAppTheme.primaryTeal),
            SizedBox(width: 8),
            Text('RenChat Call Link'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Anyone with RenChat can use this link to join this call. Only share it with people you trust.',
              style: TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WhatsAppTheme.darkSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(color: WhatsAppTheme.primaryTeal, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy link'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Call link copied to clipboard!')),
              );
            },
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNewCommunityDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B272C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.groups_rounded, color: WhatsAppTheme.primaryTeal, size: 28),
            SizedBox(width: 10),
            Text('Komunitas Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Satukan grup-grup bertopik dan bagikan pengumuman resmi kepada seluruh anggota.',
                style: TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary, height: 1.3),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Komunitas',
                  hintText: 'Misal: Warga RT 05 / Alumni 2020',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.group_rounded, color: WhatsAppTheme.primaryTeal),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Deskripsi Komunitas (Opsional)',
                  hintText: 'Jelaskan tujuan komunitas ini...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.description_rounded, color: WhatsAppTheme.primaryTeal),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: WhatsAppTheme.primaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              Navigator.pop(ctx);
              if (name.isNotEmpty) {
                final auth = context.read<AuthService>();
                final chatService = context.read<ChatService>();
                final user = auth.appUser;
                if (user != null) {
                  try {
                    final newCommunity = await chatService.createGroupChat(
                      title: '🌐 $name',
                      creator: user,
                      members: const [],
                    );

                    // Kirim pesan sambutan pengumuman admin pertama
                    final desc = descCtrl.text.trim();
                    await chatService.sendMessage(
                      chatId: newCommunity.id,
                      senderId: user.uid,
                      senderName: user.displayName,
                      text: '📢 Selamat datang di Komunitas $name! ${desc.isNotEmpty ? "\n\n$desc" : ""}',
                      type: MessageType.text,
                    );

                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(chat: newCommunity),
                        ),
                      );
                      showPremiumNotificationToast(
                        context,
                        title: 'Komunitas Dibuat!',
                        message: 'Komunitas "$name" berhasil dibuat dan siap mengundang anggota.',
                        icon: Icons.groups_rounded,
                        accentColor: WhatsAppTheme.primaryTeal,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showPremiumNotificationToast(
                        context,
                        title: 'Gagal Membuat',
                        message: 'Terjadi kesalahan: $e',
                        icon: Icons.error_outline_rounded,
                        accentColor: const Color(0xFFEF4444),
                      );
                    }
                  }
                }
              }
            },
            child: const Text('Buat Komunitas', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppChatTile extends StatelessWidget {
  final Chat chat;
  final String currentUserId;

  const _WhatsAppChatTile({required this.chat, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final title = chat.getDisplayTitle(currentUserId);
    final avatar = chat.getDisplayAvatar(currentUserId);
    final unreadCount = chat.unread[currentUserId] ?? 0;
    final otherUid = chat.getOtherUserId(currentUserId);
    final chatService = context.read<ChatService>();

    final clearedTime = chat.getClearedAt(currentUserId);
    final isClearedForMe = clearedTime != null &&
        chat.lastMessageAt != null &&
        !chat.lastMessageAt!.isAfter(clearedTime);

    String timeStr = '';
    if (chat.lastMessageAt != null && !isClearedForMe) {
      final now = DateTime.now();
      final msgDate = chat.lastMessageAt!;
      if (now.difference(msgDate).inDays == 0) {
        timeStr = DateFormat.jm().format(msgDate);
      } else if (now.difference(msgDate).inDays == 1) {
        timeStr = 'Yesterday';
      } else {
        timeStr = DateFormat('dd/MM/yy').format(msgDate);
      }
    }

    final isPinned = chat.isPinnedBy(currentUserId);

    void showChatActions(BuildContext context) {
      HapticFeedback.mediumImpact();
      showModalBottomSheet(
        context: context,
        backgroundColor: WhatsAppTheme.darkSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(
                  isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  color: isPinned ? WhatsAppTheme.primaryTeal : null,
                ),
                title: Text(isPinned ? 'Lepas sematan' : 'Sematkan obrolan'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final pinned = await chatService.togglePinChat(
                      chatId: chat.id,
                      userId: currentUserId,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(pinned ? 'Obrolan disematkan' : 'Sematan obrolan dilepas')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Arsipkan obrolan'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await chatService.toggleArchiveChat(
                    chatId: chat.id,
                    userId: currentUserId,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Obrolan diarsipkan')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline_rounded),
                title: const Text('Kunci obrolan'),
                subtitle: const Text('Sembunyikan dan amankan obrolan dengan sandi'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await chatService.toggleLockChat(
                    chatId: chat.id,
                    userId: currentUserId,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Obrolan dipindahkan ke Obrolan Terkunci')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.mark_chat_unread_outlined),
                title: const Text('Tandai belum dibaca'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await chatService.markChatAsUnread(chat.id, currentUserId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ditandai belum dibaca')),
                    );
                  }
                },
              ),
              // Opsi Hapus Komunitas / Grup Obrolan
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                title: Text(
                  chat.isGroup ? 'Hapus Komunitas / Grup' : 'Hapus Obrolan',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  chat.isGroup
                      ? 'Hapus komunitas ini beserta seluruh pesannya'
                      : 'Hapus seluruh riwayat obrolan ini',
                  style: const TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: WhatsAppTheme.darkSurface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                          const SizedBox(width: 8),
                          Text(chat.isGroup ? 'Hapus Komunitas?' : 'Hapus Obrolan?'),
                        ],
                      ),
                      content: Text(
                        chat.isGroup
                            ? 'Apakah Anda yakin ingin menghapus komunitas "${chat.title ?? 'ini'}"? Tindakan ini akan menghapus semua pesan dan grup tidak dapat dipulihkan.'
                            : 'Apakah Anda yakin ingin menghapus seluruh riwayat obrolan ini secara permanen?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('Batal', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                          onPressed: () async {
                            Navigator.pop(dCtx);
                            try {
                              await chatService.deleteChat(chat.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      chat.isGroup
                                          ? 'Komunitas berhasil dihapus'
                                          : 'Obrolan berhasil dihapus',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Gagal menghapus: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('Hapus Permanen'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onLongPress: () => showChatActions(context),
      leading: chat.isGroup
          ? const CircleAvatar(
              radius: 26,
              backgroundColor: Color(0xFF233138),
              child: Icon(Icons.group_rounded, color: Colors.white70, size: 28),
            )
          : otherUid != null
              ? StreamBuilder<AppUser?>(
                  stream: chatService.streamUserProfile(otherUid),
                  builder: (context, snap) {
                    return UserAvatar(
                      name: title,
                      photoUrl: snap.data?.photoURL ?? avatar,
                      radius: 26,
                      showOnlineBadge: true,
                      isOnline: snap.data?.online ?? false,
                    );
                  },
                )
              : UserAvatar(
                  name: title,
                  photoUrl: avatar,
                  radius: 26,
                ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          if (isPinned)
            const Padding(
              padding: EdgeInsets.only(left: 6, right: 4),
              child: Icon(Icons.push_pin_rounded, size: 16, color: WhatsAppTheme.darkTextSecondary),
            ),
          if (timeStr.isNotEmpty)
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 12,
                color: unreadCount > 0 ? WhatsAppTheme.primaryTeal : WhatsAppTheme.darkTextSecondary,
                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isClearedForMe
                    ? 'Obrolan telah dibersihkan'
                    : (chat.lastMessage ?? 'Say hello!'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: isClearedForMe ? FontStyle.italic : FontStyle.normal,
                  color: isClearedForMe
                      ? WhatsAppTheme.darkTextSecondary.withValues(alpha: 0.6)
                      : (unreadCount > 0 ? WhatsAppTheme.darkTextPrimary : WhatsAppTheme.darkTextSecondary),
                  fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: const BoxDecoration(
                  color: WhatsAppTheme.primaryTeal,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)),
        );
      },
    );
  }
}
