import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final String statusMessage;
  final bool online;
  final DateTime lastSeen;
  final List<String> fcmTokens;
  final List<String> blockedUsers;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    this.statusMessage = 'Hey there! I am using Messenger.',
    this.online = false,
    required this.lastSeen,
    this.fcmTokens = const [],
    this.blockedUsers = const [],
    required this.createdAt,
  });

  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data() ?? {};
    return AppUser(
      uid: snapshot.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'User',
      photoURL: data['photoURL'] as String?,
      statusMessage: data['statusMessage'] as String? ?? 'Hey there! I am using Messenger.',
      online: data['online'] as bool? ?? false,
      lastSeen: _parseDateTime(data['lastSeen']),
      fcmTokens: (data['fcmTokens'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      blockedUsers: (data['blockedUsers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'statusMessage': statusMessage,
      'online': online,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'fcmTokens': fcmTokens,
      'blockedUsers': blockedUsers,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AppUser copyWith({
    String? displayName,
    String? photoURL,
    String? statusMessage,
    bool? online,
    DateTime? lastSeen,
    List<String>? fcmTokens,
    List<String>? blockedUsers,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      statusMessage: statusMessage ?? this.statusMessage,
      online: online ?? this.online,
      lastSeen: lastSeen ?? this.lastSeen,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      createdAt: createdAt,
    );
  }

  bool isBlocked(String targetUid) => blockedUsers.contains(targetUid);

  static DateTime _parseDateTime(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) {
      final parsed = DateTime.tryParse(val);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }
}
