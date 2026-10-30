import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  voice,
  file,
  poll,
}

enum DeliveryStatus {
  sending,
  sent,
  delivered,
  read,
}

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String text;
  final MessageType type;
  final String? mediaUrl;
  final String? fileName;
  final int? fileSize;
  final int? durationSeconds;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool deleted;
  final DateTime? deletedAt;
  final Map<String, String> reactions; // userId -> emoji
  final List<String> readBy;
  final DeliveryStatus status;

  // Starred Message
  final List<String> starredBy; // List of user UIDs who starred this message

  // Swipe-to-Reply (Quoted Message)
  final String? replyToId;
  final String? replyToSenderName;
  final String? replyToText;
  final MessageType? replyToType;

  // Poll
  final String? pollQuestion;
  final List<String>? pollOptions;
  final Map<String, List<String>> pollVotes; // optionIndexStr -> list of userIds

  // View Once
  final bool isViewOnce;
  final List<String> viewedBy; // list of userIds who opened viewOnce

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.type = MessageType.text,
    this.mediaUrl,
    this.fileName,
    this.fileSize,
    this.durationSeconds,
    required this.createdAt,
    this.editedAt,
    this.deleted = false,
    this.deletedAt,
    this.reactions = const {},
    this.readBy = const [],
    this.status = DeliveryStatus.sent,
    this.starredBy = const [],
    this.replyToId,
    this.replyToSenderName,
    this.replyToText,
    this.replyToType,
    this.pollQuestion,
    this.pollOptions,
    this.pollVotes = const {},
    this.isViewOnce = false,
    this.viewedBy = const [],
  });

  bool isStarredBy(String userId) => starredBy.contains(userId);
  bool isViewedBy(String userId) => viewedBy.contains(userId);

  factory Message.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data() ?? {};
    final typeStr = data['type'] as String? ?? 'text';
    final type = MessageType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => MessageType.text,
    );

    final statusStr = data['status'] as String? ?? 'sent';
    final status = DeliveryStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => DeliveryStatus.sent,
    );

    final reactionsRaw = data['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = reactionsRaw.map((k, v) => MapEntry(k, v.toString()));

    final replyTypeStr = data['replyToType'] as String?;
    final replyToType = replyTypeStr != null
        ? MessageType.values.firstWhere((e) => e.name == replyTypeStr, orElse: () => MessageType.text)
        : null;

    final pollVotesRaw = data['pollVotes'] as Map<String, dynamic>? ?? {};
    final pollVotes = <String, List<String>>{};
    pollVotesRaw.forEach((key, val) {
      if (val is List) {
        pollVotes[key] = val.map((e) => e.toString()).toList();
      }
    });

    return Message(
      id: snapshot.id,
      chatId: data['chatId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'User',
      text: data['text'] as String? ?? '',
      type: type,
      mediaUrl: data['mediaUrl'] as String?,
      fileName: data['fileName'] as String?,
      fileSize: (data['fileSize'] as num?)?.toInt(),
      durationSeconds: (data['durationSeconds'] as num?)?.toInt(),
      createdAt: _parseDateTime(data['createdAt']),
      editedAt: data['editedAt'] != null ? _parseDateTime(data['editedAt']) : null,
      deleted: data['deleted'] as bool? ?? false,
      deletedAt: data['deletedAt'] != null ? _parseDateTime(data['deletedAt']) : null,
      reactions: reactions,
      readBy: (data['readBy'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      status: status,
      starredBy: (data['starredBy'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      replyToId: data['replyToId'] as String?,
      replyToSenderName: data['replyToSenderName'] as String?,
      replyToText: data['replyToText'] as String?,
      replyToType: replyToType,
      pollQuestion: data['pollQuestion'] as String?,
      pollOptions: (data['pollOptions'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      pollVotes: pollVotes,
      isViewOnce: data['isViewOnce'] as bool? ?? false,
      viewedBy: (data['viewedBy'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'durationSeconds': durationSeconds,
      'createdAt': Timestamp.fromDate(createdAt),
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'deleted': deleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'reactions': reactions,
      'readBy': readBy,
      'status': status.name,
      'starredBy': starredBy,
      'replyToId': replyToId,
      'replyToSenderName': replyToSenderName,
      'replyToText': replyToText,
      'replyToType': replyToType?.name,
      'pollQuestion': pollQuestion,
      'pollOptions': pollOptions,
      'pollVotes': pollVotes,
      'isViewOnce': isViewOnce,
      'viewedBy': viewedBy,
    };
  }

  Message copyWith({
    String? text,
    DateTime? editedAt,
    bool? deleted,
    DateTime? deletedAt,
    Map<String, String>? reactions,
    List<String>? readBy,
    DeliveryStatus? status,
    List<String>? starredBy,
    String? replyToId,
    String? replyToSenderName,
    String? replyToText,
    MessageType? replyToType,
    String? pollQuestion,
    List<String>? pollOptions,
    Map<String, List<String>>? pollVotes,
    bool? isViewOnce,
    List<String>? viewedBy,
  }) {
    return Message(
      id: id,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      text: text ?? this.text,
      type: type,
      mediaUrl: mediaUrl,
      fileName: fileName,
      fileSize: fileSize,
      durationSeconds: durationSeconds,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      reactions: reactions ?? this.reactions,
      readBy: readBy ?? this.readBy,
      status: status ?? this.status,
      starredBy: starredBy ?? this.starredBy,
      replyToId: replyToId ?? this.replyToId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      replyToText: replyToText ?? this.replyToText,
      replyToType: replyToType ?? this.replyToType,
      pollQuestion: pollQuestion ?? this.pollQuestion,
      pollOptions: pollOptions ?? this.pollOptions,
      pollVotes: pollVotes ?? this.pollVotes,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      viewedBy: viewedBy ?? this.viewedBy,
    );
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
