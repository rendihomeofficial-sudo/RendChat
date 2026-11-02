import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final bool isGroup;
  final String? title;
  final String? photoURL;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String?> participantAvatars;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final Map<String, int> unread;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // WhatsApp Advanced Management: Pinned, Archived, and Locked (Secret Biometric/PIN Chat)
  final List<String> pinnedBy;
  final List<String> archivedBy;
  final List<String> lockedBy;

  // WhatsApp Clear Chat: clearedAt timestamp per-user (userId -> DateTime)
  final Map<String, DateTime> clearedAt;

  const Chat({
    required this.id,
    required this.isGroup,
    this.title,
    this.photoURL,
    required this.participants,
    this.participantNames = const {},
    this.participantAvatars = const {},
    this.lastMessage,
    this.lastMessageAt,
    this.lastSenderId,
    this.unread = const {},
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.pinnedBy = const [],
    this.archivedBy = const [],
    this.lockedBy = const [],
    this.clearedAt = const {},
  });

  factory Chat.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data() ?? {};
    final namesRaw = data['participantNames'] as Map<String, dynamic>? ?? {};
    final avatarsRaw = data['participantAvatars'] as Map<String, dynamic>? ?? {};
    final unreadRaw = data['unread'] as Map<String, dynamic>? ?? {};
    final clearedAtRaw = data['clearedAt'] as Map<String, dynamic>? ?? {};
    final clearedAt = <String, DateTime>{};
    clearedAtRaw.forEach((k, v) {
      if (v != null) {
        clearedAt[k] = _parseDateTime(v);
      }
    });

    return Chat(
      id: snapshot.id,
      isGroup: data['isGroup'] as bool? ?? false,
      title: data['title'] as String?,
      photoURL: data['photoURL'] as String?,
      participants: (data['participants'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      participantNames: namesRaw.map((k, v) => MapEntry(k, v.toString())),
      participantAvatars: avatarsRaw.map((k, v) => MapEntry(k, v as String?)),
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: data['lastMessageAt'] != null ? _parseDateTime(data['lastMessageAt']) : null,
      lastSenderId: data['lastSenderId'] as String?,
      unread: unreadRaw.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      pinnedBy: (data['pinnedBy'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      archivedBy: (data['archivedBy'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      lockedBy: (data['lockedBy'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      clearedAt: clearedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'isGroup': isGroup,
      'title': title,
      'photoURL': photoURL,
      'participants': participants,
      'participantNames': participantNames,
      'participantAvatars': participantAvatars,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'lastSenderId': lastSenderId,
      'unread': unread,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'pinnedBy': pinnedBy,
      'archivedBy': archivedBy,
      'lockedBy': lockedBy,
      'clearedAt': clearedAt.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
    };
  }

  bool isPinnedBy(String userId) => pinnedBy.contains(userId);
  bool isArchivedBy(String userId) => archivedBy.contains(userId);
  bool isLockedBy(String userId) => lockedBy.contains(userId);

  DateTime? getClearedAt(String userId) => clearedAt[userId];
  bool isMessageVisibleFor(String userId, DateTime messageCreatedAt) {
    final clearedTime = clearedAt[userId];
    if (clearedTime == null) return true;
    return messageCreatedAt.isAfter(clearedTime);
  }

  String getDisplayTitle(String currentUserId) {
    if (isGroup) {
      return (title != null && title!.isNotEmpty) ? title! : 'Group Chat';
    }
    // For 1-on-1: find the other participant's name
    for (final uid in participants) {
      if (uid != currentUserId) {
        return participantNames[uid] ?? 'User';
      }
    }
    return 'Chat';
  }

  String? getDisplayAvatar(String currentUserId) {
    if (isGroup) {
      return photoURL;
    }
    for (final uid in participants) {
      if (uid != currentUserId) {
        return participantAvatars[uid];
      }
    }
    return null;
  }

  String? getOtherUserId(String currentUserId) {
    if (isGroup) return null;
    for (final uid in participants) {
      if (uid != currentUserId) return uid;
    }
    return null;
  }

  int getUnreadCount(String currentUserId) {
    return unread[currentUserId] ?? 0;
  }

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
