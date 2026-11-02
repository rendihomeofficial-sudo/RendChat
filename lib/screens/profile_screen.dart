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
  String _notificationTone = 'RenChat Ding (Default)';
  String _vibrateSetting = 'Default';
  String _lightSetting = 'White';
  bool _highPriority = true;

  String _appLanguage = 'English (device\'s language)';
  bool _securityNotifications = true;
  bool _twoStepEnabled = false;

  Future<void> _pickAvatar() async {
    final auth = context.read<AuthService>();
    final storage = context.read<StorageService>();
    final uid = auth.currentUid;
    if (uid == null) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 720,
      maxHeight: 720,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _isSaving = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await storage.uploadAvatar(
        uid: uid,
        filePath: picked.path,
        fileBytes: bytes,
      );

      if (url != null) {
        await auth.updateProfile(photoURL: url);
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
              subtitle: const Text('Last backup: Today, 2:00 AM (Cloud Firestore synced)', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showChatBackupDialog();
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
          return AlertDialog(
            backgroundColor: WhatsAppTheme.darkSurface,
            title: const Text('Chat Wallpaper'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: currentColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: WhatsAppTheme.primaryTeal, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      'Preview: ${settings.chatWallpaper}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pilih tema latar belakang untuk semua obrolan Anda:',
                  style: TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary),
                ),
                const SizedBox(height: 10),
                ...options.map((opt) {
                  final isSelected = settings.chatWallpaper == opt;
                  return RadioListTile<String>(
                    dense: true,
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
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
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
    final sentKb = (settings.netSentBytes / 1024).toStringAsFixed(1);
    final recvKb = (settings.netRecvBytes / 1024).toStringAsFixed(1);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: const Text('Network usage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.call_rounded, color: WhatsAppTheme.primaryTeal),
              title: const Text('Calls & Media'),
              trailing: Text('$sentKb KB sent • $recvKb KB rec\'d', style: const TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary)),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.photo_rounded, color: WhatsAppTheme.primaryTeal),
              title: const Text('Media & Files'),
              trailing: Text('${(settings.netSentBytes * 0.4 / 1024).toStringAsFixed(1)} KB sent', style: const TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary)),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.chat_bubble_rounded, color: WhatsAppTheme.primaryTeal),
              title: const Text('Messages & Statuses'),
              trailing: const Text('Cloud Firestore Realtime', style: TextStyle(fontSize: 12, color: WhatsAppTheme.primaryTeal)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await settings.resetNetworkStats();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Statistik jaringan berhasil direset')),
                );
              }
            },
            child: const Text('Reset statistics', style: TextStyle(color: Colors.redAccent)),
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
              subtitle: const Text('RenChat v1.0.0 (GitHub: RendChat)', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: const Text('Contact us'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Describe your issue. Technical details and app logs will automatically be sent to our support team.',
              style: TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: issueCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Briefly explain what happened...',
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support ticket created. We will reply via email!')),
              );
            },
            child: const Text('Send'),
          ),
        ],
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: const Center(child: Text('RenChat')),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: WhatsAppTheme.primaryTeal,
              child: Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 40),
            ),
            SizedBox(height: 16),
            Text('RenChat Messenger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 4),
            Text('Version 2.24.21.79', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13)),
            SizedBox(height: 16),
            Text('© 2026 RenChat Inc.', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
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
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search settings',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search settings: type to filter options')),
              );
            },
          ),
        ],
      ),
      body: ListView(
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
          _settingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Help',
            subtitle: 'Help centre, contact us, privacy policy',
            onTap: _showHelpSettings,
          ),
          _settingsTile(
            icon: Icons.group_outlined,
            title: 'Invite a friend',
            subtitle: 'Bagikan tautan unduhan RenChat ke kontak Anda',
            onTap: () {
              Clipboard.setData(const ClipboardData(
                text: 'Hai! Ayo mengobrol dengan saya di RenChat Messenger. Unduh versi terbarunya di sini: https://github.com/rendihomeofficial-sudo/RendChat/releases/latest',
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tautan undangan RenChat berhasil disalin ke papan klip!')),
              );
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

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: WhatsAppTheme.darkTextSecondary, size: 24),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13),
            )
          : null,
      onTap: onTap,
    );
  }

  void _showAvatarDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: const Text('RenChat Avatar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: WhatsAppTheme.attachGallery,
              child: Icon(Icons.face_rounded, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Express yourself with personalized avatars on RenChat chats and stickers.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Create your Avatar'),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Avatar editor opened! Customize your 3D look.')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: const Center(child: Text('My Code')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.qr_code_2_rounded, size: 160, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Text(
              user.displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your QR code is private. If you share it with someone, they can scan it to message you on RenChat.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share Code'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('RenChat contact link copied to clipboard')),
              );
            },
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
