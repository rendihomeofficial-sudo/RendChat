import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

class PresenceService with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentUid;
  Timer? _heartbeatTimer;

  void initialize(String uid) {
    _currentUid = uid;
    WidgetsBinding.instance.addObserver(this);
    setOnline(true);

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_currentUid != null) {
        setOnline(true);
      }
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    if (_currentUid != null) {
      setOnline(false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_currentUid == null) return;
    if (state == AppLifecycleState.resumed) {
      setOnline(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      setOnline(false);
    }
  }

  Future<void> setOnline(bool isOnline) async {
    if (_currentUid == null) return;
    try {
      await _firestore.collection('users').doc(_currentUid).update({
        'online': isOnline,
        'lastSeen': Timestamp.now(),
      });
    } catch (_) {}
  }
}
