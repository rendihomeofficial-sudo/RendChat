import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_model.dart';

/// Manajer riwayat panggilan lokal (offline-first & sync cache)
/// Memastikan panggilan keluar/masuk tetap tersimpan dan langsung muncul
/// di tab Calls meskipun koneksi sedang lambat/offline.
class CallHistoryManager {
  CallHistoryManager._();
  static final CallHistoryManager instance = CallHistoryManager._();

  static const String _storageKey = 'renchat_local_call_history';
  final ValueNotifier<List<CallModel>> callsNotifier = ValueNotifier<List<CallModel>>([]);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List<dynamic>)
            .map((item) => _fromJson(item as Map<String, dynamic>))
            .toList();
        callsNotifier.value = list;
      }
    } catch (e) {
      debugPrint('Error loading local call history: $e');
    }
  }

  Future<void> recordCall(CallModel call) async {
    try {
      final current = List<CallModel>.from(callsNotifier.value);
      // Hapus jika ID sama, lalu tempatkan di posisi paling atas (terbaru)
      current.removeWhere((c) => c.id == call.id);
      current.insert(0, call);
      callsNotifier.value = current;

      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(current.take(60).map((c) => _toJson(c)).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('Error saving local call: $e');
    }
  }

  Future<void> syncRemoteCalls(List<CallModel> remoteCalls) async {
    try {
      final merged = <String, CallModel>{};
      // Masukkan riwayat lokal terlebih dahulu
      for (final c in callsNotifier.value) {
        merged[c.id] = c;
      }
      // Timpa dengan data server terbaru
      for (final c in remoteCalls) {
        merged[c.id] = c;
      }

      final sorted = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      callsNotifier.value = sorted;

      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(sorted.take(60).map((c) => _toJson(c)).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('Error syncing call history: $e');
    }
  }

  Map<String, dynamic> _toJson(CallModel c) {
    return {
      'id': c.id,
      'callerId': c.callerId,
      'callerName': c.callerName,
      'callerAvatar': c.callerAvatar,
      'receiverId': c.receiverId,
      'receiverName': c.receiverName,
      'receiverAvatar': c.receiverAvatar,
      'isVideo': c.isVideo,
      'status': c.status,
      'createdAt': c.createdAt.toIso8601String(),
      'durationSeconds': c.durationSeconds,
    };
  }

  CallModel _fromJson(Map<String, dynamic> map) {
    return CallModel(
      id: map['id'] as String? ?? '',
      callerId: map['callerId'] as String? ?? '',
      callerName: map['callerName'] as String? ?? 'User',
      callerAvatar: map['callerAvatar'] as String?,
      receiverId: map['receiverId'] as String? ?? '',
      receiverName: map['receiverName'] as String? ?? 'User',
      receiverAvatar: map['receiverAvatar'] as String?,
      isVideo: map['isVideo'] as bool? ?? false,
      status: map['status'] as String? ?? 'ended',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      durationSeconds: map['durationSeconds'] as int? ?? 0,
    );
  }
}
