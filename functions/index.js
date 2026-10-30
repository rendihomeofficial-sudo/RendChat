const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Triggers when a new message is posted in any chat.
 * Sends FCM push notification to all recipients who are offline or have FCM tokens.
 *
 * NOTE: Chat metadata & unread counters are already maintained atomically by
 * the Flutter client (ChatService) in Firestore. To prevent double-counting,
 * this function only dispatches FCM notifications.
 */
exports.onMessageCreated = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const message = snap.data();
    const { chatId, messageId } = event.params;
    const senderId = message.senderId;

    const db = admin.firestore();
    const chatRef = db.collection("chats").doc(chatId);

    // Send FCM push notifications
    try {
      const chatDoc = await chatRef.get();
      if (!chatDoc.exists) return;
      const chatData = chatDoc.data() || {};
      const participants = (chatData.participants || []).filter((uid) => uid !== senderId);

      if (participants.length === 0) return;

      const userDocs = await Promise.all(
        participants.map((uid) => db.collection("users").doc(uid).get())
      );

      const tokens = [];
      for (const uDoc of userDocs) {
        if (!uDoc.exists) continue;
        const u = uDoc.data();
        if (Array.isArray(u.fcmTokens)) {
          tokens.push(...u.fcmTokens.filter(Boolean));
        }
      }

      if (tokens.length === 0) return;

      const senderDoc = await db.collection("users").doc(senderId).get();
      const senderName = senderDoc.exists
        ? senderDoc.data().displayName || "Someone"
        : "Someone";

      const title = chatData.isGroup
        ? `${senderName} in ${chatData.title || "Group"}`
        : senderName;

      const body = message.type === "image"
        ? (message.isViewOnce ? "👁️ Photo (View Once)" : "📷 Sent a photo")
        : message.type === "voice"
        ? "🎤 Sent a voice message"
        : message.type === "file"
        ? "📎 Sent an attachment"
        : message.type === "poll"
        ? `📊 Poll: ${message.pollQuestion || "New poll"}`
        : message.text || "New message";

      const payload = {
        tokens,
        notification: {
          title,
          body,
        },
        data: {
          chatId,
          messageId,
          senderId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "chat_messages",
            sound: "default",
          },
        },
      };

      const resp = await admin.messaging().sendEachForMulticast(payload);
      console.log(`Sent notifications: ${resp.successCount} ok, ${resp.failureCount} failed`);
    } catch (err) {
      console.error("FCM dispatch error:", err);
    }
  }
);
