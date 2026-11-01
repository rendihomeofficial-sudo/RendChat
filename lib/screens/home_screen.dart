import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../models/status_model.dart';
import '../models/call_model.dart';
import '../services/app_update_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../services/lock_chat_passcode_manager.dart';
import '../theme/whatsapp_theme.dart';
import '../widgets/user_avatar.dart';
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

  final List<String> _filters = ['All', 'Unread', 'Favorites', 'Groups'];

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
    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final storageService = context.read<StorageService>();
    final user = auth.appUser;
    if (user == null) return;

    try {
      XFile? picked;
      if (isVideo) {
        picked = await _picker.pickVideo(
          source: fromCamera ? ImageSource.camera : ImageSource.gallery,
          maxDuration: const Duration(seconds: 30),
        );
      } else {
        picked = await _picker.pickImage(
          source: fromCamera ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 75,
        );
      }
      if (picked == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isVideo ? 'Mengunggah video status...' : 'Mengunggah foto status...')),
      );

      final bytes = await picked.readAsBytes();
      final url = await storageService.uploadStatusMedia(
        userId: user.uid,
        filePath: picked.path,
        fileBytes: bytes,
        fileName: picked.name,
      );

      if (url != null) {
        await chatService.postStatus(
          userId: user.uid,
          userName: user.displayName,
          userAvatar: user.photoURL,
          text: isVideo ? '📹 Video Status' : '',
          mediaUrl: url,
          backgroundColor: 0xFF000000,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isVideo ? 'Status video berhasil dipublikasikan!' : 'Status foto berhasil dipublikasikan!')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading media status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat status: $e')),
        );
      }
    }
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
        _showIncomingCallDialog(incoming);
      }
    });
  }

  void _showIncomingCallDialog(CallModel call) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2C34),
        title: Text(
          call.isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
          style: const TextStyle(color: WhatsAppTheme.primaryTeal, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
              name: call.callerName,
              photoUrl: call.callerAvatar,
              radius: 36,
            ),
            const SizedBox(height: 12),
            Text(
              call.callerName,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'RenChat Call...',
              style: TextStyle(color: WhatsAppTheme.darkTextSecondary),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            icon: const Icon(Icons.call_end_rounded),
            label: const Text('Decline'),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ChatService>().updateCallStatus(call.id, 'rejected');
              _showingCallId = null;
            },
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
            icon: Icon(call.isVideo ? Icons.videocam_rounded : Icons.call_rounded),
            label: const Text('Accept'),
            onPressed: () {
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
    );
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

    return Scaffold(
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
                _buildCommunitiesTab(context),
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
              label: 'Chats',
            ),
            NavigationDestination(
              icon: Icon(Icons.update_rounded, color: WhatsAppTheme.darkTextSecondary),
              selectedIcon: Icon(Icons.update_rounded, color: WhatsAppTheme.primaryTeal),
              label: 'Updates',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined, color: WhatsAppTheme.darkTextSecondary),
              selectedIcon: Icon(Icons.groups_rounded, color: WhatsAppTheme.primaryTeal),
              label: 'Communities',
            ),
            NavigationDestination(
              icon: Icon(Icons.call_outlined, color: WhatsAppTheme.darkTextSecondary),
              selectedIcon: Icon(Icons.call_rounded, color: WhatsAppTheme.primaryTeal),
              label: 'Calls',
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(context),
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

    final titles = ['RenChat', 'Updates', 'Communities', 'Calls'];
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
          tooltip: 'Camera',
          onPressed: () => _captureAndPostMediaStatus(fromCamera: true),
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
                MaterialPageRoute(builder: (_) => const ContactsScreen()),
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
              onPressed: () => _captureAndPostMediaStatus(fromCamera: true),
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
                  showModalBottomSheet(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Wrap(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.camera_alt_rounded, color: WhatsAppTheme.primaryTeal),
                            title: const Text('Ambil Foto Kamera'),
                            onTap: () {
                              Navigator.pop(ctx);
                              _captureAndPostMediaStatus(fromCamera: true);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.photo_library_rounded, color: WhatsAppTheme.primaryTeal),
                            title: const Text('Pilih Foto dari Galeri'),
                            onTap: () {
                              Navigator.pop(ctx);
                              _captureAndPostMediaStatus(fromCamera: false);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.videocam_rounded, color: WhatsAppTheme.primaryTeal),
                            title: const Text('Pilih Video Status'),
                            subtitle: const Text('Unggah video status hingga 30 detik', style: TextStyle(fontSize: 11, color: WhatsAppTheme.darkTextSecondary)),
                            onTap: () {
                              Navigator.pop(ctx);
                              _captureAndPostMediaStatus(fromCamera: false, isVideo: true);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.edit_rounded, color: WhatsAppTheme.primaryTeal),
                            title: const Text('Buat Status Teks & Lagu'),
                            subtitle: const Text('Status warna teks dan pilihan musik latar WhatsApp', style: TextStyle(fontSize: 11, color: WhatsAppTheme.darkTextSecondary)),
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
                  );
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Channels',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Explore >',
                    style: TextStyle(color: WhatsAppTheme.primaryTeal, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF008069),
                child: Icon(Icons.campaign_rounded, color: Colors.white),
              ),
              title: const Text('RenChat Official', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Welcome to RenChat Channels! Get updates on new features.'),
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
                label: Text(_isFollowingOfficialChannel ? 'Following' : 'Follow'),
              ),
            ),
          ],
        );
      },
    );
  }

  // 3. COMMUNITIES TAB
  Widget _buildCommunitiesTab(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
            const SizedBox(height: 24),
            const Text(
              'Stay connected with a community',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Communities bring members together in topic-based groups, and make it easy to get admin announcements.',
              textAlign: TextAlign.center,
              style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: WhatsAppTheme.primaryTeal,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Start your community'),
              onPressed: () {
                _showNewCommunityDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 4. CALLS TAB
  Widget _buildCallsTab(BuildContext context, AppUser currentUser) {
    final chatService = context.read<ChatService>();

    return StreamBuilder<List<CallModel>>(
      stream: chatService.streamUserCalls(currentUser.uid),
      builder: (context, snapshot) {
        final calls = snapshot.data ?? [];

        return ListView(
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
                    'No call history yet. Start a voice or video call from any chat!',
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Point your phone camera to scan RenChat Web QR Code')),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.groups_rounded, color: WhatsAppTheme.primaryTeal),
            SizedBox(width: 8),
            Text('New Community'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bring members together in topic-based groups, and easily send admin announcements.',
              style: TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Community Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
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
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(chat: newCommunity),
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Komunitas "$name" berhasil dibuat!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal membuat komunitas: $e')),
                      );
                    }
                  }
                }
              }
            },
            child: const Text('Create'),
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

    String timeStr = '';
    if (chat.lastMessageAt != null) {
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
                title: Text(isPinned ? 'Unpin chat' : 'Pin chat'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final pinned = await chatService.togglePinChat(
                      chatId: chat.id,
                      userId: currentUserId,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(pinned ? 'Chat pinned' : 'Chat unpinned')),
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
                title: const Text('Archive chat'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await chatService.toggleArchiveChat(
                    chatId: chat.id,
                    userId: currentUserId,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat archived')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline_rounded),
                title: const Text('Lock chat'),
                subtitle: const Text('Hide and lock this chat with passcode'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await chatService.toggleLockChat(
                    chatId: chat.id,
                    userId: currentUserId,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat moved to Locked Chats')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.mark_chat_unread_outlined),
                title: const Text('Mark as unread'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Marked as unread')),
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
                chat.lastMessage ?? 'Say hello!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: unreadCount > 0 ? WhatsAppTheme.darkTextPrimary : WhatsAppTheme.darkTextSecondary,
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
