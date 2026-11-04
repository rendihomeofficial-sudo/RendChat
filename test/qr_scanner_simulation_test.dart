import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_app/models/user_model.dart';
import 'package:messenger_app/widgets/professional_qr_card.dart';

void main() {
  group('CameraQrScanner & ProfessionalQrCard Format Simulation Tests', () {
    const currentUserId = 'user_my_account_123';
    const targetUserId = 'renchat_user_target_456';
    const targetDisplayName = 'Budi Santoso';
    const targetEmail = 'budi.santoso@example.com';

    final targetUser = AppUser(
      uid: targetUserId,
      displayName: targetDisplayName,
      email: targetEmail,
      statusMessage: 'Hey there! I am using RenChat.',
      online: true,
      lastSeen: DateTime.now(),
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );

    test('ProfessionalQrCard instantiates cleanly with target UID and displayName', () {
      final card = ProfessionalQrCard(
        uid: targetUserId,
        displayName: targetDisplayName,
        photoUrl: null,
      );

      expect(card.uid, equals(targetUserId));
      expect(card.displayName, equals(targetDisplayName));
      expect(card.photoUrl, isNull);
    });

    test('Scanner parser extracts clean UID from raw text format', () {
      const rawInput = 'renchat_user_target_456';
      
      String targetQuery = rawInput.trim();
      if (rawInput.startsWith('RENCHAT:')) {
        final parts = rawInput.split(':');
        if (parts.length >= 2) targetQuery = parts[1];
      }

      expect(targetQuery, equals(targetUserId));
    });

    test('Scanner parser extracts clean UID from prefixed RENCHAT: format', () {
      const rawInput = 'RENCHAT:renchat_user_target_456';
      
      String targetQuery = rawInput.trim();
      if (rawInput.startsWith('RENCHAT:')) {
        final parts = rawInput.split(':');
        if (parts.length >= 2) targetQuery = parts[1];
      }

      expect(targetQuery, equals(targetUserId));
    });

    test('Search match simulation verifies target user match by exact UID and self-isolation', () {
      final usersDirectory = [
        AppUser(
          uid: currentUserId,
          displayName: 'Current User',
          email: 'me@example.com',
          lastSeen: DateTime.now(),
          createdAt: DateTime.now(),
        ),
        targetUser,
      ];

      const query = targetUserId;
      final matched = usersDirectory.where((u) {
        return u.uid != currentUserId &&
            (u.uid.toLowerCase() == query.toLowerCase() ||
                u.displayName.toLowerCase().contains(query.toLowerCase()) ||
                u.email.toLowerCase().contains(query.toLowerCase()));
      }).toList();

      expect(matched.length, equals(1));
      expect(matched.first.uid, equals(targetUserId));
      expect(matched.first.displayName, equals('Budi Santoso'));
    });

    test('Self-scan rejection simulation prevents chatting with own QR code', () {
      final usersDirectory = [
        AppUser(
          uid: currentUserId,
          displayName: 'Current User',
          email: 'me@example.com',
          lastSeen: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      ];

      const scannedOwnUid = currentUserId;
      final matched = usersDirectory.where((u) => u.uid != currentUserId && u.uid == scannedOwnUid).toList();

      expect(matched, isEmpty);
    });
  });
}
