import 'package:cloud_firestore/cloud_firestore.dart';

class StatusModel {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String text;
  final String? mediaUrl;
  final int backgroundColor;
  final DateTime createdAt;
  final List<String> viewedBy;

  const StatusModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.text,
    this.mediaUrl,
    required this.backgroundColor,
    required this.createdAt,
    this.viewedBy = const [],
  });

  factory StatusModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data() ?? {};
    return StatusModel(
      id: snapshot.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'User',
      userAvatar: data['userAvatar'] as String?,
      text: data['text'] as String? ?? '',
      mediaUrl: data['mediaUrl'] as String?,
      backgroundColor: data['backgroundColor'] as int? ?? 0xFF005C4B,
      createdAt: _parseDateTime(data['createdAt']),
      viewedBy: (data['viewedBy'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'text': text,
      'mediaUrl': mediaUrl,
      'backgroundColor': backgroundColor,
      'createdAt': Timestamp.fromDate(createdAt),
      'viewedBy': viewedBy,
    };
  }

  bool isViewedBy(String uid) => viewedBy.contains(uid);

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
