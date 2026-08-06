const functions = require("firebase-functions");
const admin = require("firebase-admin");
const express = require("express");
const cors = require("cors");

if (!admin.apps.length) {
  admin.initializeApp();
}

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// Helper middleware to verify admin auth
async function verifyAdminAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Unauthorized: Missing Bearer token." });
  }

  const idToken = authHeader.split("Bearer ")[1];
  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const uid = decodedToken.uid;
    const roleDoc = await admin.firestore().collection("roles").doc(uid).get();

    if (!roleDoc.exists || (roleDoc.data().role !== "admin" && roleDoc.data().role !== "manager" && roleDoc.data().role !== "accountant")) {
      return res.status(403).json({ error: "Forbidden: Administrator role required." });
    }

    req.user = decodedToken;
    next();
  } catch (error) {
    return res.status(401).json({ error: "Unauthorized token verification failed.", details: error.message });
  }
}

// ── 1. POST /api/notifications/send-to-user ──
app.post("/send-to-user", verifyAdminAuth, async (req, res) => {
  const { targetUserId, title, body, channelId, data } = req.body;
  if (!targetUserId || !title || !body) {
    return res.status(400).json({ error: "Missing targetUserId, title, or body." });
  }

  try {
    const devicesSnapshot = await admin
      .firestore()
      .collection("devices")
      .where("userId", "==", targetUserId)
      .where("isActive", "==", true)
      .get();

    if (devicesSnapshot.empty) {
      return res.status(404).json({ message: "No active devices found for user." });
    }

    const tokens = devicesSnapshot.docs.map((doc) => doc.data().fcmToken).filter(Boolean);
    if (!tokens.length) {
      return res.status(404).json({ message: "No valid FCM tokens found." });
    }

    const messagePayload = {
      notification: { title, body },
      data: data || {},
      android: {
        priority: "high",
        notification: {
          channelId: channelId || "academy_important_alerts",
          sound: "default",
          priority: "high",
        },
      },
      apns: {
        payload: {
          aps: { sound: "default", badge: 1 },
        },
      },
      tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(messagePayload);
    return res.status(200).json({ success: true, successCount: response.successCount, failureCount: response.failureCount });
  } catch (error) {
    return res.status(500).json({ error: "Failed to send user notification", details: error.message });
  }
});

// ── 2. POST /api/notifications/send-to-class ──
app.post("/send-to-class", verifyAdminAuth, async (req, res) => {
  const { className, title, body, channelId, data } = req.body;
  if (!className || !title || !body) {
    return res.status(400).json({ error: "Missing className, title, or body." });
  }

  const topicName = `class_${className.toLowerCase().replace(/[^a-z0-9]/g, "_")}`;

  try {
    const message = {
      topic: topicName,
      notification: { title, body },
      data: data || {},
      android: {
        notification: {
          channelId: channelId || "general_notifications",
          sound: "default",
        },
      },
    };

    const response = await admin.messaging().send(message);
    return res.status(200).json({ success: true, messageId: response });
  } catch (error) {
    return res.status(500).json({ error: "Failed to send topic notification", details: error.message });
  }
});

// ── 3. POST /api/notifications/send-fee-reminders ──
app.post("/send-fee-reminders", verifyAdminAuth, async (req, res) => {
  const { studentIds, customMessage } = req.body;

  try {
    let query = admin.firestore().collection("students").where("isActive", "==", true);
    const snapshot = await query.get();

    let defaulters = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    if (studentIds && Array.isArray(studentIds) && studentIds.length > 0) {
      defaulters = defaulters.filter((s) => studentIds.includes(s.id));
    } else {
      defaulters = defaulters.filter((s) => (s.feeRemaining || 0) > 0);
    }

    let sentCount = 0;
    for (const student of defaulters) {
      const title = "Pending Fee Reminder";
      const body = customMessage || `Dear ${student.firstName || student.name}, you have a pending fee balance. Please check your Student Portal for details.`;

      // Save notification to Firestore
      await admin.firestore().collection("notifications").add({
        title,
        message: body,
        studentId: student.id,
        studentName: `${student.firstName || student.name} ${student.lastName || ""}`.trim(),
        notificationType: "fee_reminder",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
      });

      sentCount++;
    }

    return res.status(200).json({ success: true, totalRemindersSent: sentCount });
  } catch (error) {
    return res.status(500).json({ error: "Failed to send fee reminders", details: error.message });
  }
});

exports.api = functions.https.onRequest(app);

// ── Firestore Trigger: Automatically send push notifications when trigger doc created ──
exports.onNotificationTriggerCreated = functions.firestore
  .document("notification_triggers/{triggerId}")
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    if (!data) return;

    const { targetTopic, targetUserId, title, body, channelId, payload } = data;

    try {
      if (targetTopic) {
        await admin.messaging().send({
          topic: targetTopic,
          notification: { title, body },
          data: payload || {},
          android: { notification: { channelId: channelId || "academy_important_alerts" } },
        });
      } else if (targetUserId) {
        const devices = await admin.firestore().collection("devices").where("userId", "==", targetUserId).where("isActive", "==", true).get();
        const tokens = devices.docs.map((d) => d.data().fcmToken).filter(Boolean);
        if (tokens.length) {
          await admin.messaging().sendEachForMulticast({
            tokens,
            notification: { title, body },
            data: payload || {},
            android: { notification: { channelId: channelId || "academy_important_alerts" } },
          });
        }
      }
      await snapshot.ref.update({ status: "processed", processedAt: admin.firestore.FieldValue.serverTimestamp() });
    } catch (e) {
      await snapshot.ref.update({ status: "failed", error: e.message });
    }
  });
