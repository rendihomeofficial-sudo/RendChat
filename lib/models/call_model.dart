import 'package:cloud_firestore/cloud_firestore.dart';

class CallModel {
  final String id;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final String receiverId;
  final String receiverName;
  final String? receiverAvatar;
  final bool isVideo;
  final String status; // 'calling', 'connected', 'ended', 'rejected', 'missed'
  final DateTime createdAt;
  final int durationSeconds;

  const CallModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar,
    required this.isVideo,
    required this.status,
    required this.createdAt,
    this.durationSeconds = 0,
  });

  factory CallModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data() ?? {};
    return CallModel(
      id: snapshot.id,
      callerId: data['callerId'] as String? ?? '',
      callerName: data['callerName'] as String? ?? 'User',
      callerAvatar: data['callerAvatar'] as String?,
      receiverId: data['receiverId'] as String? ?? '',
      receiverName: data['receiverName'] as String? ?? 'User',
      receiverAvatar: data['receiverAvatar'] as String?,
      isVideo: data['isVideo'] as bool? ?? false,
      status: data['status'] as String? ?? 'calling',
      createdAt: _parseDateTime(data['createdAt']),
      durationSeconds: data['durationSeconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverAvatar': receiverAvatar,
      'isVideo': isVideo,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'durationSeconds': durationSeconds,
    };
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
