import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/status_model.dart';
import '../models/call_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Chat> get _chatsRef => _firestore
      .collection('chats')
      .withConverter<Chat>(
        fromFirestore: Chat.fromFirestore,
        toFirestore: (c, _) => c.toFirestore(),
      );

  CollectionReference<AppUser> get _usersRef => _firestore
      .collection('users')
      .withConverter<AppUser>(
        fromFirestore: AppUser.fromFirestore,
        toFirestore: (u, _) => u.toFirestore(),
      );

  CollectionReference<Message> _messagesRef(String chatId) => _firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .withConverter<Message>(
        fromFirestore: Message.fromFirestore,
        toFirestore: (m, _) => m.toFirestore(),
      );

  // Stream user chats ordered by last activity
  Stream<List<Chat>> streamUserChats(String currentUserId) {
    return _chatsRef
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  // Stream messages in a chat
  Stream<List<Message>> streamMessages(String chatId) {
    return _messagesRef(chatId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  // Stream a single user profile (for online status / avatar updates)
  Stream<AppUser?> streamUserProfile(String uid) {
    return _usersRef.doc(uid).snapshots().map((snap) => snap.data());
  }

  // Search users by name or email
  Future<List<AppUser>> searchUsers(String query, String currentUserId) async {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return [];

    final snap = await _usersRef.limit(50).get();
    return snap.docs
        .map((d) => d.data())
        .where((u) =>
            u.uid != currentUserId &&
            (u.displayName.toLowerCase().contains(lower) ||
                u.email.toLowerCase().contains(lower)))
        .toList();
  }

  // Get all registered users except self
  Future<List<AppUser>> getAllContacts(String currentUserId) async {
    final snap = await _usersRef.limit(100).get();
    return snap.docs
        .map((d) => d.data())
        .where((u) => u.uid != currentUserId)
        .toList();
  }

  // Create or get existing 1-on-1 chat
  Future<Chat> getOrCreate1on1Chat({
    required AppUser currentUser,
    required AppUser otherUser,
  }) async {
    final query = await _chatsRef
        .where('isGroup', isEqualTo: false)
        .where('participants', arrayContains: currentUser.uid)
        .get();

    for (final doc in query.docs) {
      final chat = doc.data();
      if (chat.participants.contains(otherUser.uid)) {
        return chat;
      }
    }

    // Create new chat doc
    final newDoc = _chatsRef.doc();
    final now = DateTime.now();
    final chat = Chat(
      id: newDoc.id,
      isGroup: false,
      participants: [currentUser.uid, otherUser.uid],
      participantNames: {
        currentUser.uid: currentUser.displayName,
        otherUser.uid: otherUser.displayName,
      },
      participantAvatars: {
        currentUser.uid: currentUser.photoURL,
        otherUser.uid: otherUser.photoURL,
      },
      unread: {
        currentUser.uid: 0,
        otherUser.uid: 0,
      },
      createdBy: currentUser.uid,
      createdAt: now,
      updatedAt: now,
      lastMessageAt: now,
    );

    await newDoc.set(chat);
    return chat;
  }

  // Create group chat
  Future<Chat> createGroupChat({
    required String title,
    required AppUser creator,
    required List<AppUser> members,
    String? photoURL,
  }) async {
    final newDoc = _chatsRef.doc();
    final now = DateTime.now();
    final allMembers = [creator, ...members];

    final participants = allMembers.map((u) => u.uid).toList();
    final participantNames = {for (var u in allMembers) u.uid: u.displayName};
    final participantAvatars = {for (var u in allMembers) u.uid: u.photoURL};
    final unread = {for (var u in allMembers) u.uid: 0};

    final chat = Chat(
      id: newDoc.id,
      isGroup: true,
      title: title,
      photoURL: photoURL,
      participants: participants,
      participantNames: participantNames,
      participantAvatars: participantAvatars,
      unread: unread,
      createdBy: creator.uid,
      createdAt: now,
      updatedAt: now,
      lastMessageAt: now,
    );

    await newDoc.set(chat);
    return chat;
  }

  // Send message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? fileName,
    int? fileSize,
    int? durationSeconds,
    String? replyToId,
    String? replyToSenderName,
    String? replyToText,
    MessageType? replyToType,
    String? pollQuestion,
    List<String>? pollOptions,
    bool isViewOnce = false,
  }) async {
    final docRef = _messagesRef(chatId).doc();
    final now = DateTime.now();

    final message = Message(
      id: docRef.id,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      text: text,
      type: type,
      mediaUrl: mediaUrl,
      fileName: fileName,
      fileSize: fileSize,
      durationSeconds: durationSeconds,
      createdAt: now,
      status: DeliveryStatus.sent,
      readBy: [senderId],
      replyToId: replyToId,
      replyToSenderName: replyToSenderName,
      replyToText: replyToText,
      replyToType: replyToType,
      pollQuestion: pollQuestion,
      pollOptions: pollOptions,
      pollVotes: const {},
      isViewOnce: isViewOnce,
      viewedBy: const [],
    );

    await docRef.set(message);

    // Update parent chat doc
    final preview = type == MessageType.image
        ? (isViewOnce ? '👁️ Photo (View Once)' : '📷 Photo')
        : type == MessageType.voice
            ? '🎤 Voice note'
            : type == MessageType.file
                ? '📎 File'
                : type == MessageType.poll
                    ? '📊 Poll: ${pollQuestion ?? "Question"}'
                    : text;

    await _firestore.runTransaction((tx) async {
      final chatSnap = await tx.get(_chatsRef.doc(chatId));
      if (!chatSnap.exists) return;

      final chat = chatSnap.data()!;
      final newUnread = Map<String, int>.from(chat.unread);
      for (final uid in chat.participants) {
        if (uid != senderId) {
          newUnread[uid] = (newUnread[uid] ?? 0) + 1;
        }
      }

      tx.update(_chatsRef.doc(chatId), {
        'lastMessage': preview,
        'lastMessageAt': Timestamp.fromDate(now),
        'lastSenderId': senderId,
        'unread': newUnread,
        'updatedAt': Timestamp.fromDate(now),
      });
    });
  }

  // Mark all unread messages in chat as read, and update message readBy
  Future<void> markChatAsRead(String chatId, String currentUserId) async {
    try {
      final chatDoc = await _chatsRef.doc(chatId).get();
      if (!chatDoc.exists) return;
      final chat = chatDoc.data()!;

      if ((chat.unread[currentUserId] ?? 0) > 0) {
        final newUnread = Map<String, int>.from(chat.unread);
        newUnread[currentUserId] = 0;
        await _chatsRef.doc(chatId).update({'unread': newUnread});
      }

      // Mark recent messages as read by current user (for blue check read receipts)
      final unreadMsgsSnap = await _messagesRef(chatId)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();

      final batch = _firestore.batch();
      bool hasBatchOps = false;
      for (final doc in unreadMsgsSnap.docs) {
        final msg = doc.data();
        if (msg.senderId != currentUserId && !msg.readBy.contains(currentUserId)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([currentUserId]),
            'status': 'read',
          });
          hasBatchOps = true;
        }
      }
      if (hasBatchOps) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking chat as read: $e');
    }
  }

  // Add / toggle reaction on message
  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final docRef = _messagesRef(chatId).doc(messageId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final msg = snap.data()!;
    final reactions = Map<String, String>.from(msg.reactions);

    if (reactions[userId] == emoji) {
      reactions.remove(userId);
    } else {
      reactions[userId] = emoji;
    }

    await docRef.update({'reactions': reactions});
  }

  // Toggle Star message
  Future<void> toggleStarMessage({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    final docRef = _messagesRef(chatId).doc(messageId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final starredBy = List<String>.from(snap.data()?.starredBy ?? []);
    if (starredBy.contains(userId)) {
      starredBy.remove(userId);
    } else {
      starredBy.add(userId);
    }

    await docRef.update({'starredBy': starredBy});
  }

  // Vote on poll
  Future<void> votePoll({
    required String chatId,
    required String messageId,
    required String userId,
    required int optionIndex,
  }) async {
    final docRef = _messagesRef(chatId).doc(messageId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final pollVotes = Map<String, List<String>>.from(snap.data()?.pollVotes ?? {});
    final key = optionIndex.toString();
    final currentVoters = List<String>.from(pollVotes[key] ?? []);

    if (currentVoters.contains(userId)) {
      currentVoters.remove(userId);
    } else {
      // Single vote per user or multi-vote toggle
      currentVoters.add(userId);
    }
    pollVotes[key] = currentVoters;

    await docRef.update({'pollVotes': pollVotes});
  }

  // Mark View-Once as opened
  Future<void> markViewOnceOpened({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    final docRef = _messagesRef(chatId).doc(messageId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final viewedBy = List<String>.from(snap.data()?.viewedBy ?? []);
    if (!viewedBy.contains(userId)) {
      viewedBy.add(userId);
      await docRef.update({'viewedBy': viewedBy});
    }
  }

  // Stream starred messages across user's chats
  Stream<List<Message>> streamStarredMessages(String userId) {
    return _chatsRef
        .where('participants', arrayContains: userId)
        .snapshots()
        .asyncMap((chatSnap) async {
      final starredList = <Message>[];
      for (final doc in chatSnap.docs) {
        final messagesSnap = await _messagesRef(doc.id)
            .where('starredBy', arrayContains: userId)
            .get();
        starredList.addAll(messagesSnap.docs.map((m) => m.data()));
      }
      starredList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return starredList;
    });
  }

  // Edit message
  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newText,
  }) async {
    final docRef = _messagesRef(chatId).doc(messageId);
    await docRef.update({
      'text': newText,
      'editedAt': Timestamp.now(),
    });
  }

  // Soft delete message
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    final docRef = _messagesRef(chatId).doc(messageId);
    await docRef.update({
      'deleted': true,
      'deletedAt': Timestamp.now(),
      'text': 'This message was deleted',
      'mediaUrl': null,
    });
  }

  // Typing indicator
  Future<void> setTypingStatus({
    required String chatId,
    required String userId,
    required String userName,
    required bool isTyping,
  }) async {
    final typingRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .doc(userId);

    if (isTyping) {
      await typingRef.set({
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await typingRef.delete();
    }
  }

  // Stream typing users
  Stream<List<String>> streamTypingUsers(String chatId, String currentUserId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .snapshots()
        .map((snap) {
      return snap.docs
          .where((d) => d.id != currentUserId)
          .map((d) => d.data()['userName'] as String? ?? 'Someone')
          .toList();
    });
  }

  // WhatsApp Chat Pinning (max 3 pinned chats per user)
  Future<bool> togglePinChat({required String chatId, required String userId}) async {
    final docRef = _chatsRef.doc(chatId);
    final snap = await docRef.get();
    if (!snap.exists) return false;

    final chat = snap.data()!;
    final pinned = List<String>.from(chat.pinnedBy);

    if (pinned.contains(userId)) {
      pinned.remove(userId);
      await docRef.update({'pinnedBy': pinned});
      return false; // unpinned
    } else {
      // Check if user already has 3 pinned chats (client-side count over user's chats to avoid composite index requirement)
      final userChatsSnap = await _chatsRef
          .where('participants', arrayContains: userId)
          .get();
      final currentPinnedCount = userChatsSnap.docs
          .where((d) => d.data().isPinnedBy(userId))
          .length;

      if (currentPinnedCount >= 3) {
        throw Exception('You can only pin up to 3 chats');
      }
      pinned.add(userId);
      await docRef.update({'pinnedBy': pinned});
      return true; // pinned
    }
  }

  // WhatsApp Chat Archiving
  Future<bool> toggleArchiveChat({required String chatId, required String userId}) async {
    final docRef = _chatsRef.doc(chatId);
    final snap = await docRef.get();
    if (!snap.exists) return false;

    final chat = snap.data()!;
    final archived = List<String>.from(chat.archivedBy);

    if (archived.contains(userId)) {
      archived.remove(userId);
      await docRef.update({'archivedBy': archived});
      return false; // unarchived
    } else {
      archived.add(userId);
      await docRef.update({'archivedBy': archived});
      return true; // archived
    }
  }

  // WhatsApp Secret Locked Chat
  Future<bool> toggleLockChat({required String chatId, required String userId}) async {
    final docRef = _chatsRef.doc(chatId);
    final snap = await docRef.get();
    if (!snap.exists) return false;

    final chat = snap.data()!;
    final locked = List<String>.from(chat.lockedBy);

    if (locked.contains(userId)) {
      locked.remove(userId);
      await docRef.update({'lockedBy': locked});
      return false; // unlocked
    } else {
      locked.add(userId);
      await docRef.update({'lockedBy': locked});
      return true; // locked
    }
  }

  // RenChat Contact Block & Unblock System
  Future<bool> toggleBlockUser({required String currentUserId, required String targetUserId}) async {
    final docRef = _usersRef.doc(currentUserId);
    final snap = await docRef.get();
    if (!snap.exists) return false;

    final user = snap.data()!;
    final blocked = List<String>.from(user.blockedUsers);

    if (blocked.contains(targetUserId)) {
      blocked.remove(targetUserId);
      await docRef.update({'blockedUsers': blocked});
      return false; // unblocked
    } else {
      blocked.add(targetUserId);
      await docRef.update({'blockedUsers': blocked});
      return true; // blocked
    }
  }

  Future<void> unblockUser({required String currentUserId, required String targetUserId}) async {
    final docRef = _usersRef.doc(currentUserId);
    final snap = await docRef.get();
    if (!snap.exists) return;
    final user = snap.data()!;
    final blocked = List<String>.from(user.blockedUsers);
    if (blocked.contains(targetUserId)) {
      blocked.remove(targetUserId);
      await docRef.update({'blockedUsers': blocked});
    }
  }

  Future<void> blockUser({required String currentUserId, required String targetUserId}) async {
    final docRef = _usersRef.doc(currentUserId);
    final snap = await docRef.get();
    if (!snap.exists) return;
    final user = snap.data()!;
    final blocked = List<String>.from(user.blockedUsers);
    if (!blocked.contains(targetUserId)) {
      blocked.add(targetUserId);
      await docRef.update({'blockedUsers': blocked});
    }
  }

  Stream<bool> streamIsUserBlocked({required String currentUserId, required String targetUserId}) {
    return _usersRef.doc(currentUserId).snapshots().map((snap) {
      final user = snap.data();
      if (user == null) return false;
      return user.blockedUsers.contains(targetUserId);
    });
  }

  Stream<List<String>> streamBlockedUserIds(String currentUserId) {
    return _usersRef.doc(currentUserId).snapshots().map((snap) {
      final user = snap.data();
      return user?.blockedUsers ?? const [];
    });
  }

  // STATUS / STORY FEATURES
  CollectionReference<StatusModel> get _statusRef => _firestore
      .collection('statuses')
      .withConverter<StatusModel>(
        fromFirestore: StatusModel.fromFirestore,
        toFirestore: (s, _) => s.toFirestore(),
      );

  Future<void> postStatus({
    required String userId,
    required String userName,
    String? userAvatar,
    required String text,
    String? mediaUrl,
    String? musicUrl,
    String? musicTitle,
    required int backgroundColor,
  }) async {
    final docRef = _statusRef.doc();
    final status = StatusModel(
      id: docRef.id,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      text: text,
      mediaUrl: mediaUrl,
      musicUrl: musicUrl,
      musicTitle: musicTitle,
      backgroundColor: backgroundColor,
      createdAt: DateTime.now(),
      viewedBy: [userId],
    );
    await docRef.set(status);
  }

  Stream<List<StatusModel>> streamActiveStatuses() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return _statusRef
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  Future<void> markStatusViewed({
    required String statusId,
    required String viewerId,
  }) async {
    final docRef = _firestore.collection('statuses').doc(statusId);
    await docRef.update({
      'viewedBy': FieldValue.arrayUnion([viewerId]),
    });
  }

  // CALL FEATURES & SIGNALING
  CollectionReference<CallModel> get _callsRef => _firestore
      .collection('calls')
      .withConverter<CallModel>(
        fromFirestore: CallModel.fromFirestore,
        toFirestore: (c, _) => c.toFirestore(),
      );

  Future<String> initiateCall({
    required String callerId,
    required String callerName,
    String? callerAvatar,
    required String receiverId,
    required String receiverName,
    String? receiverAvatar,
    required bool isVideo,
  }) async {
    final docRef = _callsRef.doc();
    final call = CallModel(
      id: docRef.id,
      callerId: callerId,
      callerName: callerName,
      callerAvatar: callerAvatar,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverAvatar: receiverAvatar,
      isVideo: isVideo,
      status: 'calling',
      createdAt: DateTime.now(),
    );
    await docRef.set(call);
    return docRef.id;
  }

  Future<void> updateCallStatus(
    String callId,
    String status, {
    int? durationSeconds,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
    };
    await _firestore.collection('calls').doc(callId).update(updates);
  }

  Stream<List<CallModel>> streamUserCalls(String userId) {
    return _firestore
        .collection('calls')
        .where('callerId', isEqualTo: userId)
        .snapshots()
        .asyncMap((callerSnap) async {
      final receiverSnap = await _firestore
          .collection('calls')
          .where('receiverId', isEqualTo: userId)
          .get();

      final all = <CallModel>[];
      all.addAll(callerSnap.docs.map((d) => CallModel.fromFirestore(d, null)));
      all.addAll(receiverSnap.docs.map((d) => CallModel.fromFirestore(d, null)));
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return all;
    });
  }

  Stream<CallModel?> streamIncomingCall(String currentUserId) {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'calling')
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return CallModel.fromFirestore(snap.docs.first, null);
    });
  }

  // Stream status call tertentu secara realtime (untuk Caller & Receiver)
  Stream<CallModel?> streamCall(String callId) {
    return _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      return CallModel.fromFirestore(snap, null);
    });
  }
}

