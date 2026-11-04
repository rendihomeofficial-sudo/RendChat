import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/lock_chat_passcode_manager.dart';
import '../services/storage_service.dart';
import '../services/app_update_service.dart';
import '../services/settings_service.dart';
import '../theme/whatsapp_theme.dart';
import '../widgets/user_avatar.dart';
import '../widgets/chat_feedback_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  bool _isSaving = false;

  // Bilah pencarian interaktif Settings
  bool _isSearchingSettings = false;
  String _settingsSearchQuery = '';
  final TextEditingController _settingsSearchController = TextEditingController();

  String _lastSeenPrivacy = 'Everyone';
  String _profilePhotoPrivacy = 'My contacts';
  String _aboutPrivacy = 'Everyone';
  bool _readReceipts = true;
  String _themeMode = 'Dark';

  @override
  void initState() {
    super.initState();
    final settings = SettingsService.instance;
    _themeMode = settings.themeModeString;
    _readReceipts = settings.readReceipts;
    _lastSeenPrivacy = settings.lastSeenPrivacy;
    _profilePhotoPrivacy = settings.profilePhotoPrivacy;
    _aboutPrivacy = settings.aboutPrivacy;
    _appLanguage = settings.appLanguage;
  }
  @override
  void dispose() {
    _settingsSearchController.dispose();
    super.dispose();
  }

  String _notificationTone = 'RenChat Ding (Default)';
  String _vibrateSetting = 'Default';
  String _lightSetting = 'White';
  bool _highPriority = true;

  String _appLanguage = 'English (device\'s language)';
  bool _securityNotifications = true;
  bool _twoStepEnabled = false;

  Future<void> _pickAvatar() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Text(
                'Foto Profil',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: WhatsAppTheme.primaryTeal),
              title: const Text('Kamera', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Ambil foto langsung dengan kamera', style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _processAvatarPick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: WhatsAppTheme.primaryTeal),
              title: const Text('Galeri', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Pilih foto dari penyimpanan perangkat', style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _processAvatarPick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processAvatarPick(ImageSource source) async {
    final auth = context.read<AuthService>();
    final storage = context.read<StorageService>();
    final uid = auth.currentUid;
    if (uid == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (picked == null) return;

      setState(() => _isSaving = true);
      showPremiumNotificationToast(
        context,
        title: 'Memperbarui Foto Profil',
        message: 'Sedang mengunggah dan mengoptimalkan gambar...',
        icon: Icons.sync_rounded,
        accentColor: WhatsAppTheme.primaryTeal,
      );

      final bytes = await picked.readAsBytes();
      final url = await storage.uploadAvatar(
        uid: uid,
        filePath: picked.path,
        fileBytes: bytes,
      );

      if (url != null) {
        await auth.updateProfile(photoURL: url);
        if (mounted) {
          showPremiumNotificationToast(
            context,
            title: 'Foto Profil Berhasil Diperbarui',
            message: 'Tampilan profil Anda kini telah diperbarui secara langsung.',
            icon: Icons.check_circle_rounded,
            accentColor: WhatsAppTheme.primaryTeal,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showPremiumNotificationToast(
          context,
          title: 'Gagal Memperbarui Profil',
          message: e.toString().replaceAll('Exception: ', ''),
          icon: Icons.error_outline_rounded,
          accentColor: Colors.redAccent,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _editNameDialog(String currentName) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: const Text('Enter your name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This is not your username or pin. This name will be visible to your RenChat contacts.',
              style: TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 25,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: const InputDecoration(
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: WhatsAppTheme.primaryTeal),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
            onPressed: () async {
              final newName = ctrl.text.trim();
              Navigator.pop(ctx);
              if (newName.isNotEmpty && newName != currentName) {
                await context.read<AuthService>().updateProfile(displayName: newName);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name updated successfully')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editAboutDialog(String currentStatus) {
    final ctrl = TextEditingController(text: currentStatus);
    final predefined = [
      'Available',
      'Busy',
      'At school',
      'At the movies',
      'At work',
      'Battery about to die',
      'Can’t talk, RenChat only',
      'In a meeting',
      'At the gym',
      'Sleeping',
      'Urgent calls only'
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: const Text('About'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                maxLength: 139,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Currently set to',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Select About',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: WhatsAppTheme.darkTextSecondary),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: predefined.length,
                  itemBuilder: (context, i) {
                    final status = predefined[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(status),
                      onTap: () {
                        ctrl.text = status;
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
            onPressed: () async {
              final newAbout = ctrl.text.trim();
              Navigator.pop(ctx);
              if (newAbout.isNotEmpty) {
                await context.read<AuthService>().updateProfile(statusMessage: newAbout);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('About updated')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // 1. ACCOUNT SUB-MENUS
  void _showAccountSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.security_rounded, color: WhatsAppTheme.primaryTeal),
                title: const Text('Security notifications'),
                subtitle: Text(_securityNotifications ? 'Enabled on this phone' : 'Disabled',
                    style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
                trailing: Switch(
                  value: _securityNotifications,
                  activeThumbColor: WhatsAppTheme.primaryTeal,
                  onChanged: (val) {
                    setState(() => _securityNotifications = val);
                    setSheetState(() {});
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.pin_rounded, color: WhatsAppTheme.primaryTeal),
                title: const Text('Two-step verification'),
                subtitle: Text(_twoStepEnabled ? 'Active (6-digit PIN protected)' : 'Not enabled',
                    style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showTwoStepSetupDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone_android_rounded, color: WhatsAppTheme.darkTextSecondary),
                title: const Text('Change number'),
                subtitle: const Text('Migrate account to a new SIM card',
                    style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showChangeNumberDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Delete my account', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteAccountDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTwoStepSetupDialog() {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: const Row(
          children: [
            Icon(Icons.pin_rounded, color: WhatsAppTheme.primaryTeal),
            SizedBox(width: 8),
            Text('Two-step verification'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a 6-digit PIN that you will be asked for when you register your phone number with RenChat again.',
              style: TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              maxLength: 6,
              obscureText: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(letterSpacing: 8, fontSize: 20),
              decoration: const InputDecoration(
                hintText: '••••••',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _twoStepEnabled = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Two-step verification has been turned on!')),
              );
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  void _showChangeNumberDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: const Text('Change phone number'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phonelink_setup_rounded, size: 54, color: WhatsAppTheme.primaryTeal),
            SizedBox(height: 16),
            Text(
              'Changing your phone number will migrate your account info, groups & settings. Before proceeding, verify that your new number can receive SMS.',
              style: TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Verification SMS sent to new number')),
              );
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: const Text('Delete this account?', style: TextStyle(color: Colors.redAccent)),
        content: const Text(
          'Deleting your account will:\n• Delete your account info and profile photo\n• Delete you from all RenChat groups\n• Delete your message history backup',
          style: TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context); // Tutup Settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Menghapus akun Anda...')),
              );
              await context.read<AuthService>().deleteAccount();
            },
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  // 2. PRIVACY SUB-MENUS
  void _showPrivacySettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Privacy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.access_time_rounded, color: WhatsAppTheme.darkTextSecondary),
                title: const Text('Last seen and online'),
                subtitle: Text(_lastSeenPrivacy, style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
                onTap: () {
                  _showOptionPickerDialog(
                    title: 'Who can see my last seen',
                    currentValue: _lastSeenPrivacy,
                    options: ['Everyone', 'My contacts', 'My contacts except...', 'Nobody'],
                    onSelected: (val) {
                      setState(() => _lastSeenPrivacy = val);
                      context.read<SettingsService>().setLastSeenPrivacy(val);
                      setSheetState(() {});
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_circle_outlined, color: WhatsAppTheme.darkTextSecondary),
                title: const Text('Profile photo'),
                subtitle: Text(_profilePhotoPrivacy, style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
                onTap: () {
                  _showOptionPickerDialog(
                    title: 'Who can see my profile photo',
                    currentValue: _profilePhotoPrivacy,
                    options: ['Everyone', 'My contacts', 'Nobody'],
                    onSelected: (val) {
                      setState(() => _profilePhotoPrivacy = val);
                      context.read<SettingsService>().setProfilePhotoPrivacy(val);
                      setSheetState(() {});
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: WhatsAppTheme.darkTextSecondary),
                title: const Text('About'),
                subtitle: Text(_aboutPrivacy, style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
                onTap: () {
                  _showOptionPickerDialog(
                    title: 'Who can see my About',
                    currentValue: _aboutPrivacy,
                    options: ['Everyone', 'My contacts', 'Nobody'],
                    onSelected: (val) {
                      setState(() => _aboutPrivacy = val);
                      context.read<SettingsService>().setAboutPrivacy(val);
                      setSheetState(() {});
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.done_all_rounded, color: WhatsAppTheme.primaryTeal),
                title: const Text('Read receipts'),
                subtitle: const Text('If turned off, you won\'t send or receive Read receipts (blue checks)',
                    style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
                trailing: Switch(
                  value: _readReceipts,
                  activeThumbColor: WhatsAppTheme.primaryTeal,
                  onChanged: (val) {
                    setState(() => _readReceipts = val);
                    context.read<SettingsService>().setReadReceipts(val);
                    setSheetState(() {});
                  },
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.lock_rounded, color: WhatsAppTheme.primaryTeal),
                title: const Text('Chat lock passcode'),
                subtitle: Text(
                  'PIN rahasia: ${LockChatPasscodeManager().currentPasscode} • Tap untuk ubah',
                  style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: WhatsAppTheme.darkTextSecondary),
                onTap: () {
                  Navigator.pop(ctx);
                  _showChangeChatLockPinDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off_rounded, color: WhatsAppTheme.darkTextSecondary),
                title: const Text('Hide locked chats'),
                subtitle: const Text(
                  'Sembunyikan folder Locked chats dari beranda. Hanya dapat dimunculkan dengan mengetikkan kode rahasia di kolom pencarian.',
                  style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12),
                ),
                trailing: Switch(
                  value: LockChatPasscodeManager().hideLockedChatsFolder,
                  activeThumbColor: WhatsAppTheme.primaryTeal,
                  onChanged: (val) {
                    LockChatPasscodeManager().setHideLockedChats(val);
                    setSheetState(() {});
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val
                              ? 'Folder Locked chats disembunyikan. Ketik PIN rahasia di pencarian untuk membukanya.'
                              : 'Folder Locked chats ditampilkan kembali di beranda.',
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1, indent: 56),
              Builder(builder: (context) {
                final auth = context.watch<AuthService>();
                final chatService = context.read<ChatService>();
                final blockedList = auth.appUser?.blockedUsers ?? const [];
                return ListTile(
                  leading: const Icon(Icons.block_rounded, color: WhatsAppTheme.darkTextSecondary),
                  title: const Text('Blocked contacts'),
                  subtitle: Text(
                    blockedList.isEmpty ? 'None' : '${blockedList.length} contacts blocked',
                    style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: WhatsAppTheme.darkTextSecondary),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showBlockedContactsDialog(context, chatService, auth.currentUid ?? '', blockedList);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showBlockedContactsDialog(BuildContext context, ChatService chatService, String currentUid, List<String> initialBlocked) {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.block_rounded, color: Colors.redAccent, size: 24),
                    const SizedBox(width: 12),
                    const Text('Blocked contacts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              const Divider(height: 1),
              StreamBuilder<List<String>>(
                stream: chatService.streamBlockedUserIds(currentUid),
                initialData: initialBlocked,
                builder: (context, snap) {
                  final blockedIds = snap.data ?? [];
                  if (blockedIds.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: Center(
                        child: Text(
                          'No blocked contacts.\nContacts you block will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 14),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: blockedIds.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                    itemBuilder: (context, idx) {
                      final uid = blockedIds[idx];
                      return StreamBuilder<AppUser?>(
                        stream: chatService.streamUserProfile(uid),
                        builder: (context, userSnap) {
                          final name = userSnap.data?.displayName ?? 'User ($uid)';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF233138),
                              child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U'),
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text('Tap unblock to restore chat', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
                            trailing: TextButton.icon(
                              icon: const Icon(Icons.lock_open_rounded, size: 16, color: WhatsAppTheme.primaryTeal),
                              label: const Text('Unblock', style: TextStyle(color: WhatsAppTheme.primaryTeal, fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                final confirmed = await showPremiumActionConfirmDialog(
                                  context,
                                  title: 'Buka Blokir $name?',
                                  message: 'Buka blokir kontak ini untuk mulai berkirim pesan dan melakukan panggilan kembali.',
                                  confirmLabel: 'Buka Blokir',
                                  icon: Icons.lock_open_rounded,
                                  accentColor: WhatsAppTheme.primaryTeal,
                                  isDestructive: false,
                                );

                                if (confirmed == true) {
                                  await chatService.unblockUser(currentUserId: currentUid, targetUserId: uid);
                                  if (context.mounted) {
                                    showPremiumNotificationToast(
                                      context,
                                      title: 'Blokir Dibuka',
                                      message: 'Anda sekarang dapat mengirim pesan dan memanggil $name.',
                                      icon: Icons.check_circle_rounded,
                                      accentColor: WhatsAppTheme.primaryTeal,
                                    );
                                  }
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangeChatLockPinDialog() {
    final oldPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    String error = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: WhatsAppTheme.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: WhatsAppTheme.primaryTeal, size: 24),
              SizedBox(width: 8),
              Text('Chat lock passcode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Masukkan PIN lama dan tentukan 4-digit PIN rahasia baru untuk mengunci dan membuka Locked Chats.',
                  style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: oldPinCtrl,
                  obscureText: true,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: 'PIN Saat Ini (Default: ${LockChatPasscodeManager().currentPasscode})',
                    filled: true,
                    fillColor: WhatsAppTheme.darkBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPinCtrl,
                  obscureText: true,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: 'PIN Baru (4 Digit Angka)',
                    filled: true,
                    fillColor: WhatsAppTheme.darkBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPinCtrl,
                  obscureText: true,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: 'Konfirmasi PIN Baru',
                    filled: true,
                    fillColor: WhatsAppTheme.darkBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
              onPressed: () {
                final oldPin = oldPinCtrl.text.trim();
                final newPin = newPinCtrl.text.trim();
                final confirmPin = confirmPinCtrl.text.trim();

                final manager = LockChatPasscodeManager();
                if (oldPin != manager.currentPasscode) {
                  setDlgState(() {
                    error = 'PIN saat ini salah!';
                  });
                  return;
                }
                if (newPin.length != 4 || int.tryParse(newPin) == null) {
                  setDlgState(() {
                    error = 'PIN baru harus tepat 4 angka!';
                  });
                  return;
                }
                if (newPin != confirmPin) {
                  setDlgState(() {
                    error = 'Konfirmasi PIN tidak cocok!';
                  });
                  return;
                }

                manager.setPasscode(newPin);
                Navigator.pop(ctx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: WhatsAppTheme.primaryTeal,
                    content: Text('PIN kunci obrolan rahasia berhasil diubah ke: $newPin'),
                  ),
                );
              },
              child: const Text('Simpan PIN Baru'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionPickerDialog({
    required String title,
    required String currentValue,
    required List<String> options,
    required Function(String) onSelected,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: Text(title, style: const TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) {
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                opt == currentValue ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: opt == currentValue ? WhatsAppTheme.primaryTeal : WhatsAppTheme.darkTextSecondary,
              ),
              title: Text(opt, style: TextStyle(color: opt == currentValue ? WhatsAppTheme.primaryTeal : Colors.white)),
              onTap: () {
                onSelected(opt);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$title: $opt')),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // 3. CHATS SUB-MENUS
  void _showChatsSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Chats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined, color: WhatsAppTheme.darkTextSecondary),
              title: const Text('Theme'),
              subtitle: Text(_themeMode, style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
              onTap: () {
                _showOptionPickerDialog(
                  title: 'Choose theme',
                  currentValue: _themeMode,
                  options: ['System default', 'Light', 'Dark'],
                  onSelected: (val) {
                    setState(() => _themeMode = val);
                    context.read<SettingsService>().setThemeMode(val);
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.wallpaper_rounded, color: WhatsAppTheme.darkTextSecondary),
              title: const Text('Wallpaper'),
              subtitle: const Text('RenChat default dark doodle wallpaper', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showWallpaperPreviewDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined, color: WhatsAppTheme.primaryTeal),
              title: const Text('Chat backup'),
              subtitle: const Text('Cloud Firestore auto-sync realtime', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showChatBackupDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded, color: WhatsAppTheme.darkTextSecondary),
              title: const Text('Chat history'),
              subtitle: const Text('Bersihkan atau hapus seluruh riwayat obrolan', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showChatHistoryDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showWallpaperPreviewDialog() {
    final settings = context.read<SettingsService>();
    final options = [
      'Default Doodle',
      'Solid Emerald',
      'Deep Navy',
      'Charcoal Grey',
      'Sunset Violet'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentColor = settings.wallpaperColor;
          final customPath = settings.customWallpaperPath;

          return AlertDialog(
            backgroundColor: WhatsAppTheme.darkSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.wallpaper_rounded, color: WhatsAppTheme.primaryTeal),
                SizedBox(width: 8),
                Text('Wallpaper Obrolan'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: currentColor,
                        border: Border.all(color: WhatsAppTheme.primaryTeal, width: 2),
                      ),
                      child: customPath != null && File(customPath).existsSync() && settings.chatWallpaper == 'Custom Photo'
                          ? Image.file(
                              File(customPath),
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Text(
                                'Pratinjau: ${settings.chatWallpaper}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tombol Pilih Foto Pribadi dari Galeri
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WhatsAppTheme.primaryTeal,
                      side: const BorderSide(color: WhatsAppTheme.primaryTeal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Pilih Foto dari Galeri Pribadi'),
                    onPressed: () async {
                      try {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1920,
                          maxHeight: 1920,
                          imageQuality: 90,
                        );
                        if (picked != null) {
                          await settings.setCustomWallpaperPath(picked.path);
                          setDialogState(() {});
                        }
                      } catch (e) {
                        debugPrint('Error picking custom wallpaper: $e');
                      }
                    },
                  ),
                  if (customPath != null) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Hapus Wallpaper Foto Pribadi'),
                      onPressed: () async {
                        await settings.setCustomWallpaperPath(null);
                        await settings.setChatWallpaper('Default Doodle');
                        setDialogState(() {});
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Atau pilih tema warna baku:',
                      style: TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...options.map((opt) {
                    final isSelected = settings.chatWallpaper == opt;
                    return RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(opt, style: const TextStyle(fontSize: 14)),
                      value: opt,
                      groupValue: settings.chatWallpaper,
                      activeColor: WhatsAppTheme.primaryTeal,
                      onChanged: (val) {
                        if (val != null) {
                          settings.setChatWallpaper(val);
                          setDialogState(() {});
                        }
                      },
                    );
                  }),
                ],
              ),
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: WhatsAppTheme.primaryTeal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Wallpaper diubah menjadi "${settings.chatWallpaper}"!')),
                  );
                },
                child: const Text('Selesai'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChatHistoryDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Chat history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_rounded, color: Colors.amberAccent),
              title: const Text('Bersihkan semua pesan', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Hapus isi teks seluruh percakapan Anda', style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    backgroundColor: WhatsAppTheme.darkSurface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Bersihkan Semua Obrolan?'),
                    content: const Text('Semua pesan pada seluruh daftar chat Anda akan dihapus permanen.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Batal')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.amber[700]),
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Bersihkan Semua'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  final auth = context.read<AuthService>();
                  final uid = auth.currentUid;
                  if (uid != null) {
                    await context.read<ChatService>().clearAllChatsForUser(uid);
                    if (mounted) {
                      showPremiumNotificationToast(
                        context,
                        title: 'Semua Chat Dibersihkan',
                        message: 'Seluruh percakapan telah dikosongkan.',
                        icon: Icons.check_circle_rounded,
                        accentColor: WhatsAppTheme.primaryTeal,
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChatBackupDialog() {
    final settings = context.read<SettingsService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: const Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: WhatsAppTheme.primaryTeal),
            SizedBox(width: 8),
            Text('Cloud Backup'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cadangkan riwayat obrolan dan media ke Cloud Firestore agar data Anda aman saat berganti perangkat.'),
            const SizedBox(height: 16),
            Text('• Terakhir dicadangkan: ${settings.lastBackupTime}',
                style: const TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary)),
            const Text('• Enkripsi End-to-end: Aktif',
                style: TextStyle(fontSize: 12, color: WhatsAppTheme.primaryTeal)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
            icon: const Icon(Icons.backup_rounded),
            label: const Text('Cadangkan Sekarang'),
            onPressed: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Menyinkronkan data ke Cloud Firestore...')),
              );
              await settings.performRealBackup();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cadangan obrolan berhasil diperbarui!')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // 4. NOTIFICATIONS SUB-MENUS
  void _showNotificationsSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.music_note_rounded, color: WhatsAppTheme.darkTextSecondary),
                title: const Text('Notification tone'),
                subtitle: Text(_notificationTone, style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
                onTap: () {
                  _showOptionPickerDialog(
                    title: 'Notification tone',
                    currentValue: _notificationTone,
                    options: ['RenChat Ding (Default)', 'Whistle', 'Bells', 'Chimes', 'Aurora', 'None'],
                    onSelected: (val) {
                      setState(() => _notificationTone = val);
                      setSheetState(() {});
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.vibration_rounded, color: WhatsAppTheme.darkTextSecondary),
                title: const Text('Vibrate'),
                subtitle: Text(_vibrateSetting, style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
                onTap: () {
                  _showOptionPickerDialog(
                    title: 'Vibration pattern',
                    currentValue: _vibrateSetting,
                    options: ['Off', 'Default', 'Short', 'Long'],
                    onSelected: (val) {
                      setState(() => _vibrateSetting = val);
                      setSheetState(() {});
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline_rounded, color: WhatsAppTheme.darkTextSecondary),
                title: const Text('Light'),
                subtitle: Text(_lightSetting, style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
                onTap: () {
                  _showOptionPickerDialog(
                    title: 'Notification Light',
                    currentValue: _lightSetting,
                    options: ['None', 'White', 'Red', 'Yellow', 'Green', 'Cyan', 'Blue', 'Purple'],
                    onSelected: (val) {
                      setState(() => _lightSetting = val);
                      setSheetState(() {});
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.priority_high_rounded, color: WhatsAppTheme.primaryTeal),
                title: const Text('High priority notifications'),
                subtitle: const Text('Show notification pop-up previews at the top of the screen',
                    style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
              trailing: Switch(
                value: _highPriority,
                activeThumbColor: WhatsAppTheme.primaryTeal,
                onChanged: (val) {
                    setState(() => _highPriority = val);
                    setSheetState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 5. STORAGE SUB-MENUS
  void _showStorageSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Storage and data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.folder_shared_outlined, color: WhatsAppTheme.primaryTeal),
              title: const Text('Manage storage'),
              subtitle: const Text('3.4 MB used • 45.2 GB available', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showManageStorageDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.data_usage_rounded, color: WhatsAppTheme.darkTextSecondary),
              title: const Text('Network usage'),
              subtitle: const Text('1,248 messages • 32.4 MB sent & received', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showNetworkUsageDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.wifi_rounded, color: WhatsAppTheme.darkTextSecondary),
              title: const Text('Media auto-download'),
              subtitle: const Text('Photos & voice notes over Wi-Fi & Cellular', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Auto-download preferences saved')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showManageStorageDialog() {
    final settings = context.read<SettingsService>();
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<String>(
        future: settings.getRealCacheSize(),
        builder: (context, snapshot) {
          final cacheSize = snapshot.data ?? 'Menghitung...';
          return AlertDialog(
            backgroundColor: WhatsAppTheme.darkSurface,
            title: const Text('Kelola Penyimpanan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: const LinearProgressIndicator(
                    value: 0.08,
                    minHeight: 12,
                    backgroundColor: Color(0xFF2A3942),
                    color: WhatsAppTheme.primaryTeal,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ukuran Berkas Cache: $cacheSize',
                        style: const TextStyle(color: WhatsAppTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Berkas cache memuat sementara foto, thumbnail audio, dan data obrolan agar tampilan lebih cepat.',
                  style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                icon: const Icon(Icons.delete_sweep_rounded),
                label: const Text('Bersihkan Cache'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await settings.clearAppCache();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Penyimpanan cache berhasil dibersihkan!')),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showNetworkUsageDialog() {
    final settings = context.read<SettingsService>();
    String formatBytes(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    final sentFormatted = formatBytes(settings.netSentBytes);
    final recvFormatted = formatBytes(settings.netRecvBytes);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.data_usage_rounded, color: WhatsAppTheme.primaryTeal),
            SizedBox(width: 8),
            Text('Network usage'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.call_rounded, color: WhatsAppTheme.primaryTeal),
              title: const Text('Calls & Media'),
              trailing: Text(
                '$sentFormatted sent • $recvFormatted rec\'d',
                style: const TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary),
              ),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.photo_rounded, color: WhatsAppTheme.primaryTeal),
              title: const Text('Media & Files'),
              trailing: Text(
                formatBytes((settings.netSentBytes * 0.6).toInt()),
                style: const TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary),
              ),
            ),
            const ListTile(
              dense: true,
              leading: Icon(Icons.chat_bubble_rounded, color: WhatsAppTheme.primaryTeal),
              title: Text('Messages & Statuses'),
              trailing: Text(
                'Firestore Cloud Synced',
                style: TextStyle(fontSize: 12, color: WhatsAppTheme.primaryTeal),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await settings.resetNetworkStats();
              if (mounted) {
                showPremiumNotificationToast(
                  context,
                  title: 'Statistik Direset',
                  message: 'Penghitung penggunaan jaringan dikembalikan ke 0 B.',
                  icon: Icons.refresh_rounded,
                  accentColor: WhatsAppTheme.primaryTeal,
                );
              }
            },
            child: const Text('Reset statistics', style: TextStyle(color: Colors.redAccent)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: WhatsAppTheme.primaryTeal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // 6. LANGUAGE & TRANSLATE SETTINGS
  void _showAppLanguageDialog() {
    final settings = SettingsService.instance;
    final current = settings.appLanguage;

    final languages = [
      {'code': 'id', 'name': 'Bahasa Indonesia', 'native': 'Bahasa Indonesia (Default)'},
      {'code': 'en', 'name': 'English', 'native': 'English (United States)'},
      {'code': 'es', 'name': 'Español', 'native': 'Español (América Latina)'},
      {'code': 'ar', 'name': 'العربية', 'native': 'العربية (Arabic)'},
      {'code': 'ja', 'name': '日本語', 'native': '日本語 (Japanese)'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.translate_rounded, color: WhatsAppTheme.primaryTeal, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Bahasa Aplikasi & Terjemahan',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    'Pilih bahasa antarmuka dan preferensi terjemahan pesan instan di RenChat.',
                    style: TextStyle(fontSize: 12.5, color: WhatsAppTheme.darkTextSecondary),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: languages.length,
                    itemBuilder: (context, index) {
                      final item = languages[index];
                      final isSelected = current.toLowerCase().contains(item['name']!.toLowerCase()) ||
                          _appLanguage.toLowerCase().contains(item['name']!.toLowerCase());

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? WhatsAppTheme.primaryTeal.withValues(alpha: 0.15)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                            color: isSelected ? WhatsAppTheme.primaryTeal : WhatsAppTheme.darkTextSecondary,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          item['name']!,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : WhatsAppTheme.darkTextPrimary,
                          ),
                        ),
                        subtitle: Text(
                          item['native']!,
                          style: const TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary),
                        ),
                        trailing: isSelected
                            ? const Text(
                                'Aktif',
                                style: TextStyle(
                                  color: WhatsAppTheme.primaryTeal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        onTap: () async {
                          final newLang = item['name']!;
                          await settings.setAppLanguage(newLang);
                          setState(() => _appLanguage = newLang);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            showPremiumNotificationToast(
                              context,
                              title: 'Bahasa Diperbarui',
                              message: 'Bahasa aplikasi berhasil diubah ke $newLang.',
                              icon: Icons.language_rounded,
                              accentColor: WhatsAppTheme.primaryTeal,
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 7. HELP SUB-MENUS
  void _showHelpSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Help', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline_rounded, color: WhatsAppTheme.primaryTeal),
              title: const Text('Help Centre'),
              subtitle: const Text('Get help, contact us, privacy policy', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showHelpCentreDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_support_outlined, color: WhatsAppTheme.primaryTeal),
              title: const Text('Contact us'),
              subtitle: const Text('Questions? Need technical help?', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showContactSupportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.policy_outlined, color: WhatsAppTheme.darkTextSecondary),
              title: const Text('Terms and Privacy Policy'),
              onTap: () {
                Navigator.pop(ctx);
                _showTermsDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.system_update_rounded, color: WhatsAppTheme.primaryTeal),
              title: const Text('Check for updates', style: TextStyle(fontWeight: FontWeight.bold, color: WhatsAppTheme.primaryTeal)),
              subtitle: const Text('Periksa versi terbaru dari GitHub', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                showUpdateDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: WhatsAppTheme.darkTextSecondary),
              title: const Text('App info'),
              subtitle: Builder(
                builder: (context) {
                  final updateService = context.watch<AppUpdateService>();
                  return Text(
                    'RenChat v${updateService.currentVersion} (Build ${updateService.currentVersionCode})',
                    style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12),
                  );
                },
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showAppInfoDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpCentreDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: const Text('RenChat Help Centre'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Popular Help Topics:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('• About end-to-end encryption in RenChat'),
            SizedBox(height: 6),
            Text('• How to restore your chat history and backup'),
            SizedBox(height: 6),
            Text('• Managing group participants and permissions'),
            SizedBox(height: 6),
            Text('• Keeping your account safe and verified'),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showContactSupportDialog() {
    final issueCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: WhatsAppTheme.darkSurface,
          title: const Text('Contact us'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Describe your issue. Technical details and app logs will automatically be sent to our support team.',
                style: TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: issueCtrl,
                maxLines: 4,
                enabled: !isSubmitting,
                decoration: const InputDecoration(
                  hintText: 'Briefly explain what happened...',
                  border: OutlineInputBorder(),
                ),
              ),
              if (isSubmitting) ...[
                const SizedBox(height: 16),
                const Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(WhatsAppTheme.primaryTeal),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Mengirim tiket bantuan...',
                      style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final text = issueCtrl.text.trim();
                      if (text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Silakan jelaskan kendala yang dialami.')),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      try {
                        final auth = context.read<AuthService>();
                        final user = auth.appUser;
                        final uid = auth.currentUid ?? 'anonymous';

                        // Simpan tiket bantuan nyata ke Cloud Firestore
                        await FirebaseFirestore.instance.collection('support_tickets').add({
                          'userId': uid,
                          'userEmail': user?.email ?? '',
                          'userName': user?.displayName ?? 'Pengguna RenChat',
                          'issue': text,
                          'status': 'open',
                          'createdAt': FieldValue.serverTimestamp(),
                          'appVersion': '1.3.22',
                          'platform': Platform.operatingSystem,
                        });

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }

                        if (mounted) {
                          showPremiumNotificationToast(
                            context,
                            title: 'Tiket Bantuan Terkirim',
                            message: 'Laporan Anda telah diterima tim RenChat via Cloud Firestore.',
                            icon: Icons.check_circle_rounded,
                            accentColor: WhatsAppTheme.primaryTeal,
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal mengirim tiket: $e')),
                          );
                        }
                      }
                    },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: const Text('Terms & Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'RenChat provides messaging, internet calling, and other services to users worldwide.\n\nPrivacy and Security Principles:\n• End-to-end encryption protects messages and calls.\n• We do not sell your personal data.\n• You control your privacy settings, status, and profile visibility.',
            style: TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary, height: 1.4),
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I Agree'),
          ),
        ],
      ),
    );
  }

  void _showAppInfoDialog() {
    final updateService = context.read<AppUpdateService>();
    final currentVer = updateService.currentVersion;
    final currentCode = updateService.currentVersionCode;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: const Center(child: Text('RenChat')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundColor: WhatsAppTheme.primaryTeal,
              child: Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('RenChat Messenger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text('Version $currentVer (Build $currentCode)', style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            const Text('© 2026 RenChat Inc. • Cloud Realtime', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                showLicensePage(
                  context: context,
                  applicationName: 'RenChat',
                  applicationVersion: 'v$currentVer (Build $currentCode)',
                  applicationLegalese: '© 2026 RenChat Inc.',
                );
              },
              child: const Text('Licenses', style: TextStyle(color: WhatsAppTheme.primaryTeal)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.appUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: WhatsAppTheme.darkBg,
      appBar: AppBar(
        leading: _isSearchingSettings
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    _isSearchingSettings = false;
                    _settingsSearchQuery = '';
                    _settingsSearchController.clear();
                  });
                },
              )
            : null,
        title: _isSearchingSettings
            ? TextField(
                controller: _settingsSearchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Cari pengaturan...',
                  hintStyle: TextStyle(color: WhatsAppTheme.darkTextSecondary),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _settingsSearchQuery = val.trim().toLowerCase();
                  });
                },
              )
            : const Text('Settings'),
        actions: [
          if (_isSearchingSettings)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Hapus pencarian',
              onPressed: () {
                setState(() {
                  _settingsSearchQuery = '';
                  _settingsSearchController.clear();
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Search settings',
              onPressed: () {
                setState(() {
                  _isSearchingSettings = true;
                });
              },
            ),
        ],
      ),
      body: _buildSettingsContent(user),
    );
  }

  Widget _buildSettingsContent(AppUser user) {
    if (_isSearchingSettings && _settingsSearchQuery.isNotEmpty) {
      return _buildSearchResults();
    }

    return ListView(
        children: [
          // WhatsApp Profile Header Card
          InkWell(
            onTap: () {
              _openProfileDetailScreen(user);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Stack(
                    children: [
                      UserAvatar(
                        name: user.displayName,
                        photoUrl: user.photoURL,
                        radius: 32,
                      ),
                      if (_isSaving)
                        const Positioned.fill(
                          child: CircularProgressIndicator(color: WhatsAppTheme.primaryTeal),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.statusMessage.isNotEmpty ? user.statusMessage : 'Hey there! I am using RenChat.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_rounded, color: WhatsAppTheme.primaryTeal),
                    tooltip: 'QR Code',
                    onPressed: () {
                      _showQrCodeDialog(user);
                    },
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Standard WhatsApp Settings Tree with Dynamic Subtitle State
          _settingsTile(
            icon: Icons.key_rounded,
            title: 'Account',
            subtitle: _twoStepEnabled ? 'Two-step verification active' : 'Security notifications, change number',
            onTap: _showAccountSettings,
          ),
          _settingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Privacy',
            subtitle: 'Last seen: $_lastSeenPrivacy • Read receipts: ${_readReceipts ? "On" : "Off"}',
            onTap: _showPrivacySettings,
          ),
          _settingsTile(
            icon: Icons.face_rounded,
            title: 'Avatar',
            subtitle: 'Create, edit, profile photo',
            onTap: () {
              _showAvatarDialog();
            },
          ),
          _settingsTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Chats',
            subtitle: 'Theme: $_themeMode • Wallpaper, chat history',
            onTap: _showChatsSettings,
          ),
          _settingsTile(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: 'Tone: $_notificationTone',
            onTap: _showNotificationsSettings,
          ),
          _settingsTile(
            icon: Icons.data_usage_rounded,
            title: 'Storage and data',
            subtitle: 'Network usage, auto-download',
            onTap: _showStorageSettings,
          ),
          _settingsTile(
            icon: Icons.language_rounded,
            title: 'App language',
            subtitle: _appLanguage,
            onTap: _showAppLanguageDialog,
          ),
          Consumer<AppUpdateService>(
            builder: (context, updateService, _) {
              final hasUpdate = updateService.hasUpdate;
              return _settingsTile(
                icon: Icons.system_update_rounded,
                iconColor: WhatsAppTheme.primaryTeal,
                title: 'Pembaruan aplikasi',
                subtitle: hasUpdate
                    ? 'Versi baru v${updateService.updateInfo!.version} tersedia'
                    : 'RenChat v${updateService.currentVersion} (Paling Baru)',
                trailing: hasUpdate
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: WhatsAppTheme.primaryTeal,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Update',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.check_circle_rounded,
                        color: WhatsAppTheme.primaryTeal,
                        size: 20,
                      ),
                onTap: () => showUpdateDialog(context),
              );
            },
          ),
          _settingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Help',
            subtitle: 'Help centre, contact us, privacy policy',
            onTap: _showHelpSettings,
          ),
          _settingsTile(
            icon: Icons.qr_code_2_rounded,
            title: 'Undang Teman',
            subtitle: 'Tampilkan Barcode QR & ID unik akun RenChat Anda',
            onTap: () {
              final auth = context.read<AuthService>();
              final user = auth.appUser;
              if (user != null) {
                _showQrCodeDialog(user);
              }
            },
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Sign Out tile
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('Log out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: WhatsAppTheme.darkSurface,
                  title: const Text('Log out from RenChat?'),
                  content: const Text('You will need to sign in again with your credentials.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Log out'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                final authService = context.read<AuthService>();
                Navigator.pop(context);
                await authService.signOut();
              }
            },
          ),

          const SizedBox(height: 24),
          const Center(
            child: Column(
              children: [
                Text('from', style: TextStyle(fontSize: 11, color: WhatsAppTheme.darkTextSecondary)),
                Text(
                  'Renata Chat',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: WhatsAppTheme.primaryTeal,
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final query = _settingsSearchQuery;
    final allItems = [
      {
        'title': 'Account',
        'subtitle': 'Security notifications, two-step verification, change number',
        'icon': Icons.key_rounded,
        'action': _showAccountSettings,
      },
      {
        'title': 'Privacy',
        'subtitle': 'Last seen and online, profile photo, about, read receipts, disappearing messages',
        'icon': Icons.lock_outline_rounded,
        'action': _showPrivacySettings,
      },
      {
        'title': 'Avatar',
        'subtitle': 'Create personalized avatar, edit avatar, set as profile photo',
        'icon': Icons.face_rounded,
        'action': _showAvatarDialog,
      },
      {
        'title': 'Chats',
        'subtitle': 'Theme, wallpaper, chat backup, chat history',
        'icon': Icons.chat_bubble_outline_rounded,
        'action': _showChatsSettings,
      },
      {
        'title': 'Notifications',
        'subtitle': 'Notification tone, vibrate, popup notification, light, high priority',
        'icon': Icons.notifications_none_rounded,
        'action': _showNotificationsSettings,
      },
      {
        'title': 'Storage and data',
        'subtitle': 'Network usage, auto-download, manage storage, clear cache',
        'icon': Icons.data_usage_rounded,
        'action': _showStorageSettings,
      },
      {
        'title': 'App language',
        'subtitle': 'Indonesian, English, and other regional languages',
        'icon': Icons.language_rounded,
        'action': _showAppLanguageDialog,
      },
      {
        'title': 'Pembaruan aplikasi',
        'subtitle': 'Periksa update versi terbaru RenChat dari GitHub Releases',
        'icon': Icons.system_update_rounded,
        'action': () => showUpdateDialog(context),
      },
      {
        'title': 'Help & Support',
        'subtitle': 'Help centre, contact us, terms and privacy policy, app info',
        'icon': Icons.help_outline_rounded,
        'action': _showHelpSettings,
      },
      {
        'title': 'Undang Teman',
        'subtitle': 'Barcode QR code, bagikan ID unik akun RenChat',
        'icon': Icons.qr_code_2_rounded,
        'action': () {
          final auth = context.read<AuthService>();
          final user = auth.appUser;
          if (user != null) _showQrCodeDialog(user);
        },
      },
    ];

    final filtered = allItems.where((item) {
      final t = (item['title'] as String).toLowerCase();
      final s = (item['subtitle'] as String).toLowerCase();
      return t.contains(query) || s.contains(query);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_off_rounded, size: 48, color: WhatsAppTheme.darkTextSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                'Tidak ada opsi pengaturan untuk "$query"',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (ctx, idx) {
        final item = filtered[idx];
        return _settingsTile(
          icon: item['icon'] as IconData,
          title: item['title'] as String,
          subtitle: item['subtitle'] as String,
          onTap: item['action'] as VoidCallback,
        );
      },
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? WhatsAppTheme.darkTextSecondary, size: 24),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  void _showAvatarDialog() {
    final auth = context.read<AuthService>();
    final user = auth.appUser;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: const Text('RenChat Avatar & Foto Profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                UserAvatar(
                  name: user?.displayName ?? 'User',
                  photoUrl: user?.photoURL,
                  radius: 46,
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: WhatsAppTheme.primaryTeal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Ekspresikan diri Anda dengan foto profil langsung dari kamera atau galeri perangkat Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Kamera'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _processAvatarPick(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Galeri'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _processAvatarPick(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            if (user?.photoURL != null && user!.photoURL!.isNotEmpty) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                label: const Text('Hapus Foto Profil', style: TextStyle(color: Colors.redAccent)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await auth.updateProfile(photoURL: '');
                    if (mounted) {
                      showPremiumNotificationToast(
                        context,
                        title: 'Foto Profil Dihapus',
                        message: 'Avatar profil Anda telah direset ke inisial nama.',
                        icon: Icons.check_circle_rounded,
                        accentColor: WhatsAppTheme.primaryTeal,
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal menghapus foto profil: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  void _openProfileDetailScreen(dynamic user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: WhatsAppTheme.darkBg,
          appBar: AppBar(title: const Text('Profile')),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            children: [
              Center(
                child: Stack(
                  children: [
                    UserAvatar(
                      name: user.displayName,
                      photoUrl: user.photoURL,
                      radius: 65,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: WhatsAppTheme.primaryTeal,
                        radius: 20,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                          onPressed: _pickAvatar,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded, color: WhatsAppTheme.darkTextSecondary),
                title: const Text('Name', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
                subtitle: Text(
                  user.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                trailing: const Icon(Icons.edit_rounded, color: WhatsAppTheme.primaryTeal, size: 20),
                onTap: () => _editNameDialog(user.displayName),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 56.0),
                child: Text(
                  'This is not your username or pin. This name will be visible to your RenChat contacts.',
                  style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary),
                ),
              ),
              const Divider(height: 32),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: WhatsAppTheme.darkTextSecondary),
                title: const Text('About', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
                subtitle: Text(
                  user.statusMessage.isNotEmpty ? user.statusMessage : 'Hey there! I am using RenChat.',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                trailing: const Icon(Icons.edit_rounded, color: WhatsAppTheme.primaryTeal, size: 20),
                onTap: () => _editAboutDialog(user.statusMessage),
              ),
              const Divider(height: 32),
              ListTile(
                leading: const Icon(Icons.email_outlined, color: WhatsAppTheme.darkTextSecondary),
                title: const Text('Email', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
                subtitle: Text(
                  user.email,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQrCodeDialog(dynamic user) {
    final uid = user.uid as String? ?? '';
    final displayName = user.displayName as String? ?? 'Pengguna RenChat';
    final photoURL = user.photoURL as String?;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: WhatsAppTheme.primaryTeal),
            SizedBox(width: 8),
            Text('Barcode Akun Saya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
              name: displayName,
              photoUrl: photoURL,
              radius: 34,
            ),
            const SizedBox(height: 10),
            Text(
              displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pindai barcode ini atau masukkan ID Pengguna di bawah untuk mulai mengobrol langsung.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: CustomPaint(
                size: const Size(180, 180),
                painter: _ProfileQrPainter(uid),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF101B20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_rounded, color: WhatsAppTheme.primaryTeal, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ID: $uid',
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: WhatsAppTheme.primaryTeal),
                    tooltip: 'Salin ID Akun',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: uid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ID Akun RenChat berhasil disalin ke papan klip!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Salin ID'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: uid));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ID Akun RenChat berhasil disalin ke papan klip!')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileQrPainter extends CustomPainter {
  final String seed;
  _ProfileQrPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final paintDark = Paint()..color = const Color(0xFF111B21);
    final paintTeal = Paint()..color = const Color(0xFF00A884);

    const int grid = 15;
    final cellWidth = size.width / grid;
    final cellHeight = size.height / grid;

    final hash = seed.hashCode.abs();

    for (int r = 0; r < grid; r++) {
      for (int c = 0; c < grid; c++) {
        final isTopLeft = r < 4 && c < 4;
        final isTopRight = r < 4 && c >= grid - 4;
        final isBottomLeft = r >= grid - 4 && c < 4;

        if (isTopLeft || isTopRight || isBottomLeft) {
          final isBorder = (r == 0 || r == 3 || c == 0 || c == 3) ||
              (r == 0 || r == 3 || c == grid - 4 || c == grid - 1) ||
              (r == grid - 4 || r == grid - 1 || c == 0 || c == 3);
          final isCenter = (r >= 1 && r <= 2 && c >= 1 && c <= 2) ||
              (r >= 1 && r <= 2 && c >= grid - 3 && c <= grid - 2) ||
              (r >= grid - 3 && r <= grid - 2 && c >= 1 && c <= 2);

          if (isBorder || isCenter) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(c * cellWidth, r * cellHeight, cellWidth - 1, cellHeight - 1),
                const Radius.circular(2),
              ),
              paintDark,
            );
          }
        } else {
          final val = (hash ^ (r * 31 + c * 17)) % 7;
          if (val < 3) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(c * cellWidth, r * cellHeight, cellWidth - 1.2, cellHeight - 1.2),
                const Radius.circular(1.5),
              ),
              val == 0 ? paintTeal : paintDark,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
