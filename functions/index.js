const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const {onObjectFinalized} = require("firebase-functions/v2/storage");
const admin = require("firebase-admin");
const Stripe = require("stripe");
const crypto = require("crypto");
const path = require("path");
const os = require("os");
const fs = require("fs");
const {execFile} = require("child_process");
const ffmpegPath = require("ffmpeg-static");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();
const DRAW_WINNER_COUNT = 5;
const DRAW_PRIZE_AMOUNT = 10;
const LOGIN_OTP_DIGITS = 6;
const LOGIN_OTP_EXPIRY_MINUTES = 10;
const LOGIN_OTP_RESEND_SECONDS = 60;
const LOGIN_OTP_MAX_ATTEMPTS = 5;
const RESET_OTP_DIGITS = 6;
const RESET_OTP_EXPIRY_MINUTES = 10;
const RESET_OTP_RESEND_SECONDS = 60;
const RESET_OTP_MAX_ATTEMPTS = 5;
const RESET_TOKEN_EXPIRY_MINUTES = 10;

/**
 * Creates Stripe client.
 * @return {Stripe}
 */
function getStripeClient() {
  return new Stripe(process.env.STRIPE_SECRET);
}

/**
 * Creates a sha256 hash for OTP storage.
 * @param {string} uid
 * @param {string} code
 * @return {string}
 */
function otpHash(uid, code) {
  return crypto
      .createHash("sha256")
      .update(`${uid}:${code}:${process.env.META_WHATSAPP_TOKEN || ""}`)
      .digest("hex");
}

/**
 * Normalizes phone to WhatsApp E.164 without the plus.
 * @param {string} phone
 * @return {string}
 */
function whatsappPhone(phone) {
  return String(phone || "").replace(/[^\d]/g, "");
}

/**
 * Builds user's stored phone.
 * @param {Object} userData
 * @return {string}
 */
function userPhoneE164(userData) {
  const e164 = (userData.phoneE164 || "").toString().trim();
  if (e164) return e164;
  const code = (userData.phoneCountryCode || "").toString().trim();
  const number = (userData.phoneNumber || "").toString().trim();
  if (!code || !number) return "";
  return `${code}${number}`;
}

/**
 * Normalizes email for duplicate checking.
 * @param {string} email
 * @return {string}
 */
function normalizeEmail(email) {
  return String(email || "")
      .trim()
      .toLowerCase();
}

/**
 * Normalizes phone digits for duplicate checking.
 * @param {string} phoneCountryCode
 * @param {string} phoneNumber
 * @return {string}
 */
function normalizePhoneE164(phoneCountryCode, phoneNumber) {
  const code = String(phoneCountryCode || "").trim();
  const digits = String(phoneNumber || "").replace(/[^\d]/g, "");
  if (!code || digits.length < 7) {
    throw new HttpsError(
        "invalid-argument",
        "A valid phone number is required.",
    );
  }
  return `${code}${digits}`;
}

/**
 * Returns true when a user document should still block a new registration.
 * Deleted/removed docs and docs whose Auth account no longer exists are treated
 * as stale and can be safely ignored.
 * @param {FirebaseFirestore.QueryDocumentSnapshot<
 *   FirebaseFirestore.DocumentData
 * >} doc
 * @return {Promise<boolean>}
 */
async function isRegistrationBlockingDoc(doc) {
  const data = doc.data() || {};
  const rawStatus = String(data.status || data.accountStatus || "active")
      .trim()
      .toLowerCase();
  if (["deleted", "removed"].includes(rawStatus)) {
    return false;
  }

  try {
    await admin.auth().getUser(doc.id);
    return true;
  } catch (error) {
    if (error && error.code === "auth/user-not-found") {
      await doc.ref.delete().catch(() => null);
      await db
          .collection("login_otps")
          .doc(doc.id)
          .delete()
          .catch(() => null);
      return false;
    }
    throw error;
  }
}

/**
 * Ensures caller is an admin user.
 * @param {Object} request
 * @return {Promise<{uid: string, data: Object}>}
 */
async function requireAdminUser(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Login required.");
  }

  const snap = await db.collection("users").doc(uid).get();
  const data = snap.data() || {};
  const role = String(data.role || "")
      .trim()
      .toLowerCase();
  if (!["admin", "superadmin", "super_admin"].includes(role)) {
    throw new HttpsError(
        "permission-denied",
        "Only admins can perform this action.",
    );
  }

  return {uid, data};
}

/**
 * Deletes or cleans up private account data for a user.
 * @param {string} targetUid
 * @param {string} reason "self" (user-initiated) or "admin" (removed by staff).
 * @return {Promise<void>}
 */
async function cleanupUserPrivateData(targetUid, reason = "self") {
  // Log the withdrawal before the users doc is gone, so registration
  // analytics can report how many accounts were cancelled over time.
  const userSnap = await db.collection("users").doc(targetUid).get();
  if (userSnap.exists) {
    const userData = userSnap.data() || {};
    await db
        .collection("account_deletions")
        .doc(targetUid)
        .set({
          uid: targetUid,
          role: userData.role || "",
          phoneCountryCode: userData.phoneCountryCode || "",
          country: userData.country || "",
          createdAt: userData.createdAt || null,
          deletedAt: admin.firestore.FieldValue.serverTimestamp(),
          reason,
        })
        .catch(() => null);
  }

  await db
      .collection("login_otps")
      .doc(targetUid)
      .delete()
      .catch(() => null);

  await db
      .collection("click_kick_star")
      .doc(targetUid)
      .delete()
      .catch(() => null);

  await db
      .collection("users")
      .doc(targetUid)
      .delete()
      .catch(() => null);

  // General videos and the follow graph (both directions).
  const generalVideos = await db
      .collection("general_videos")
      .where("userId", "==", targetUid)
      .get()
      .catch(() => null);
  if (generalVideos) {
    for (const videoDoc of generalVideos.docs) {
      await db.recursiveDelete(videoDoc.ref).catch(() => null);
    }
  }
  for (const field of ["followerId", "followingId"]) {
    const followsSnap = await db
        .collection("follows")
        .where(field, "==", targetUid)
        .get()
        .catch(() => null);
    if (!followsSnap) continue;
    for (let i = 0; i < followsSnap.docs.length; i += 400) {
      const batch = db.batch();
      followsSnap.docs.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
      await batch.commit().catch(() => null);
    }
  }

  const bucket = admin.storage().bucket();
  const prefixes = [
    `general_videos/${targetUid}/`,
    `profile_photos/${targetUid}/`,
    `support_attachments/${targetUid}/`,
    `invoices/${targetUid}/`,
  ];
  for (const prefix of prefixes) {
    await bucket.deleteFiles({prefix}).catch(() => null);
  }
}

/**
 * Sends a WhatsApp OTP message through Meta Cloud API.
 * @param {Object} params
 * @return {Promise<void>}
 */
async function sendWhatsAppOtp({toPhoneE164, code}) {
  const token = process.env.META_WHATSAPP_TOKEN;
  const phoneNumberId = process.env.META_WHATSAPP_PHONE_NUMBER_ID;
  if (!token || !phoneNumberId) {
    throw new HttpsError(
        "failed-precondition",
        "WhatsApp OTP is not configured.",
    );
  }

  const graphVersion = process.env.WHATSAPP_GRAPH_VERSION || "v25.0";
  const templateName = process.env.WHATSAPP_OTP_TEMPLATE || "otp_code";
  const templateLanguage = process.env.WHATSAPP_TEMPLATE_LANGUAGE || "en";
  const templateComponents = [
    {
      type: "body",
      parameters: [{type: "text", text: code}],
    },
  ];

  // Copy-code authentication templates are stored by Meta as URL buttons
  // and require the OTP code in both the body and button components.
  templateComponents.push({
    type: "button",
    sub_type: "url",
    index: "0",
    parameters: [{type: "text", text: code}],
  });

  const response = await fetch(
      `https://graph.facebook.com/${graphVersion}/${phoneNumberId}/messages`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to: whatsappPhone(toPhoneE164),
          type: "template",
          template: {
            name: templateName,
            language: {code: templateLanguage},
            components: templateComponents,
          },
        }),
      },
  );

  if (!response.ok) {
    const errorText = await response.text();
    console.error("Meta WhatsApp OTP failed", response.status, errorText);
    throw new HttpsError("internal", "Unable to send OTP. Please try again.");
  }
}

exports.checkRegistrationAvailability = onCall(async (request) => {
  const data = request.data || {};
  const email = normalizeEmail(data.email);
  const phoneE164 = normalizePhoneE164(data.phoneCountryCode, data.phoneNumber);

  if (!email) {
    throw new HttpsError("invalid-argument", "Email is required.");
  }

  const [emailLowerSnap, emailExactSnap, phoneSnap] = await Promise.all([
    db.collection("users").where("emailLower", "==", email).get(),
    db.collection("users").where("email", "==", email).get(),
    db.collection("users").where("phoneE164", "==", phoneE164).get(),
  ]);

  const emailDocsMap = new Map();
  [...emailLowerSnap.docs, ...emailExactSnap.docs].forEach((doc) => {
    emailDocsMap.set(doc.id, doc);
  });
  const emailDocs = [...emailDocsMap.values()];
  const phoneDocs = phoneSnap.docs;

  const [emailBlockingStates, phoneBlockingStates] = await Promise.all([
    Promise.all(emailDocs.map((doc) => isRegistrationBlockingDoc(doc))),
    Promise.all(phoneDocs.map((doc) => isRegistrationBlockingDoc(doc))),
  ]);

  return {
    emailAvailable: !emailBlockingStates.some(Boolean),
    phoneAvailable: !phoneBlockingStates.some(Boolean),
  };
});

exports.checkPasswordResetAvailability = onCall(async (request) => {
  const data = request.data || {};
  const email = normalizeEmail(data.email);

  if (!email) {
    throw new HttpsError("invalid-argument", "Email is required.");
  }

  const [emailLowerSnap, emailExactSnap] = await Promise.all([
    db.collection("users").where("emailLower", "==", email).get(),
    db.collection("users").where("email", "==", email).get(),
  ]);

  const emailDocsMap = new Map();
  [...emailLowerSnap.docs, ...emailExactSnap.docs].forEach((doc) => {
    emailDocsMap.set(doc.id, doc);
  });
  const emailDocs = [...emailDocsMap.values()];
  const blockingStates = await Promise.all(
      emailDocs.map((doc) => isRegistrationBlockingDoc(doc)),
  );

  return {
    emailExists: blockingStates.some(Boolean),
  };
});

exports.incrementContestView = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = request.data || {};
  const contestId = String(data.contestId || "").trim();
  if (!contestId) {
    throw new HttpsError("invalid-argument", "contestId is required.");
  }

  const contestRef = db.collection("contests").doc(contestId);
  const viewerRef = contestRef.collection("viewers").doc(request.auth.uid);

  await db.runTransaction(async (tx) => {
    const [contestSnap, viewerSnap] = await Promise.all([
      tx.get(contestRef),
      tx.get(viewerRef),
    ]);

    if (!contestSnap.exists) {
      throw new HttpsError("not-found", "Contest not found.");
    }
    if (viewerSnap.exists) {
      return;
    }

    tx.set(viewerRef, {
      userId: request.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(
        contestRef,
        {
          viewCount: admin.firestore.FieldValue.increment(1),
          lastViewedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
    );
  });

  return {ok: true};
});

exports.incrementContestShare = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = request.data || {};
  const contestId = String(data.contestId || "").trim();
  if (!contestId) {
    throw new HttpsError("invalid-argument", "contestId is required.");
  }

  const contestRef = db.collection("contests").doc(contestId);
  const contestSnap = await contestRef.get();
  if (!contestSnap.exists) {
    throw new HttpsError("not-found", "Contest not found.");
  }

  await contestRef.set(
      {
        shareCount: admin.firestore.FieldValue.increment(1),
        lastSharedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
  );

  return {ok: true};
});

exports.incrementContestVote = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = request.data || {};
  const contestId = String(data.contestId || "").trim();
  const submissionId = String(data.submissionId || "").trim();
  const userId = request.auth.uid;

  if (!contestId || !submissionId) {
    throw new HttpsError(
        "invalid-argument",
        "contestId and submissionId are required.",
    );
  }

  const contestRef = db.collection("contests").doc(contestId);
  // One user + one video = one vote. A user can vote for every video in a
  // contest, but never twice for the same video.
  const voteRef = contestRef
      .collection("votes")
      .doc(`${userId}_${submissionId}`);
  // Before per-video voting, a vote doc was keyed by the voter id only (one
  // vote per contest). Honour those legacy votes so nobody can vote for the
  // same video a second time.
  const legacyVoteRef = contestRef.collection("votes").doc(userId);
  const submissionRef = contestRef.collection("submissions").doc(submissionId);

  await db.runTransaction(async (tx) => {
    const [contestSnap, voteSnap, legacyVoteSnap, submissionSnap] =
      await Promise.all([
        tx.get(contestRef),
        tx.get(voteRef),
        tx.get(legacyVoteRef),
        tx.get(submissionRef),
      ]);

    if (!contestSnap.exists) {
      throw new HttpsError("not-found", "Contest not found.");
    }
    if (
      voteSnap.exists ||
      (legacyVoteSnap.exists &&
        String((legacyVoteSnap.data() || {}).submissionId || "") ===
          submissionId)
    ) {
      throw new HttpsError(
          "already-exists",
          "User already voted for this video.",
      );
    }
    if (!submissionSnap.exists) {
      throw new HttpsError("not-found", "Submission not found.");
    }

    const submissionData = submissionSnap.data() || {};
    if (String(submissionData.status || "") !== "approved") {
      throw new HttpsError(
          "failed-precondition",
          "Submission is not approved for voting.",
      );
    }
    if (String(submissionData.userId || "") === userId) {
      throw new HttpsError(
          "failed-precondition",
          "Users cannot vote for their own video.",
      );
    }

    const contestData = contestSnap.data() || {};
    const now = new Date();
    const votingStart = contestData.votingStart ?
      contestData.votingStart.toDate() :
      null;
    const votingEnd = contestData.votingEnd ?
      contestData.votingEnd.toDate() :
      null;

    if (votingStart && now < votingStart) {
      throw new HttpsError(
          "failed-precondition",
          "Voting has not started yet.",
      );
    }
    if (votingEnd && now > votingEnd) {
      throw new HttpsError("failed-precondition", "Voting has already ended.");
    }

    const serverNow = admin.firestore.FieldValue.serverTimestamp();
    tx.set(voteRef, {
      contestId,
      submissionId,
      voterId: userId,
      createdAt: serverNow,
    });
    tx.set(
        submissionRef,
        {
          voteCount: admin.firestore.FieldValue.increment(1),
          updatedAt: serverNow,
        },
        {merge: true},
    );
  });

  return {ok: true};
});

exports.incrementAdminVideoView = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = request.data || {};
  const videoId = String(data.videoId || "").trim();
  if (!videoId) {
    throw new HttpsError("invalid-argument", "videoId is required.");
  }

  const videoRef = db.collection("admin_videos").doc(videoId);
  const viewerRef = videoRef.collection("viewers").doc(request.auth.uid);

  await db.runTransaction(async (tx) => {
    const [videoSnap, viewerSnap] = await Promise.all([
      tx.get(videoRef),
      tx.get(viewerRef),
    ]);

    if (!videoSnap.exists) {
      throw new HttpsError("not-found", "Video not found.");
    }
    if (viewerSnap.exists) {
      return;
    }

    tx.set(viewerRef, {
      userId: request.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(
        videoRef,
        {
          viewCount: admin.firestore.FieldValue.increment(1),
          lastViewedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
    );
  });

  return {ok: true};
});

exports.incrementAdminVideoShare = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = request.data || {};
  const videoId = String(data.videoId || "").trim();
  if (!videoId) {
    throw new HttpsError("invalid-argument", "videoId is required.");
  }

  const videoRef = db.collection("admin_videos").doc(videoId);
  const videoSnap = await videoRef.get();
  if (!videoSnap.exists) {
    throw new HttpsError("not-found", "Video not found.");
  }

  await videoRef.set(
      {
        shareCount: admin.firestore.FieldValue.increment(1),
        lastSharedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
  );

  return {ok: true};
});

exports.incrementGeneralVideoView = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = request.data || {};
  const videoId = String(data.videoId || "").trim();
  if (!videoId) {
    throw new HttpsError("invalid-argument", "videoId is required.");
  }

  const videoRef = db.collection("general_videos").doc(videoId);
  const viewerRef = videoRef.collection("viewers").doc(request.auth.uid);

  await db.runTransaction(async (tx) => {
    const [videoSnap, viewerSnap] = await Promise.all([
      tx.get(videoRef),
      tx.get(viewerRef),
    ]);

    if (!videoSnap.exists) {
      throw new HttpsError("not-found", "Video not found.");
    }
    if (String((videoSnap.data() || {}).status || "") !== "approved") {
      throw new HttpsError("failed-precondition", "Video is not approved.");
    }
    if (viewerSnap.exists) {
      return;
    }

    tx.set(viewerRef, {
      userId: request.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(
        videoRef,
        {
          viewCount: admin.firestore.FieldValue.increment(1),
          lastViewedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
    );
  });

  return {ok: true};
});

exports.toggleGeneralVideoLike = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = request.data || {};
  const videoId = String(data.videoId || "").trim();
  if (!videoId) {
    throw new HttpsError("invalid-argument", "videoId is required.");
  }

  const videoRef = db.collection("general_videos").doc(videoId);
  const likeRef = videoRef.collection("likes").doc(request.auth.uid);

  return db.runTransaction(async (tx) => {
    const [videoSnap, likeSnap] = await Promise.all([
      tx.get(videoRef),
      tx.get(likeRef),
    ]);

    if (!videoSnap.exists) {
      throw new HttpsError("not-found", "Video not found.");
    }

    if (likeSnap.exists) {
      tx.delete(likeRef);
      tx.set(
          videoRef,
          {likeCount: admin.firestore.FieldValue.increment(-1)},
          {merge: true},
      );
      return {liked: false};
    }

    tx.set(likeRef, {
      userId: request.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(
        videoRef,
        {likeCount: admin.firestore.FieldValue.increment(1)},
        {merge: true},
    );
    return {liked: true};
  });
});

exports.incrementGeneralVideoShare = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = request.data || {};
  const videoId = String(data.videoId || "").trim();
  if (!videoId) {
    throw new HttpsError("invalid-argument", "videoId is required.");
  }

  const videoRef = db.collection("general_videos").doc(videoId);
  const videoSnap = await videoRef.get();
  if (!videoSnap.exists) {
    throw new HttpsError("not-found", "Video not found.");
  }

  await videoRef.set(
      {
        shareCount: admin.firestore.FieldValue.increment(1),
        lastSharedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
  );

  return {ok: true};
});

exports.deleteUserAccountPermanently = onCall(async (request) => {
  await requireAdminUser(request);

  const data = request.data || {};
  const targetUid = String(data.userId || "").trim();
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "userId is required.");
  }

  const userRef = db.collection("users").doc(targetUid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new HttpsError("not-found", "User profile not found.");
  }

  const userData = userSnap.data() || {};
  const role = String(userData.role || "")
      .trim()
      .toLowerCase();
  if (["admin", "superadmin", "super_admin"].includes(role)) {
    throw new HttpsError(
        "failed-precondition",
        "Admin accounts cannot be deleted from this action.",
    );
  }

  await cleanupUserPrivateData(targetUid, "admin");

  try {
    await admin.auth().deleteUser(targetUid);
  } catch (error) {
    if (!error || error.code !== "auth/user-not-found") {
      throw error;
    }
  }

  return {deleted: true};
});

exports.deleteCurrentUserAccount = onCall(async (request) => {
  const targetUid = request.auth && request.auth.uid;
  if (!targetUid) {
    throw new HttpsError("unauthenticated", "Login required.");
  }

  const userRef = db.collection("users").doc(targetUid);
  const userSnap = await userRef.get();
  const userData = userSnap.data() || {};
  const role = String(userData.role || "")
      .trim()
      .toLowerCase();
  if (["admin", "superadmin", "super_admin"].includes(role)) {
    throw new HttpsError(
        "failed-precondition",
        "Admin accounts cannot be deleted from this action.",
    );
  }

  await cleanupUserPrivateData(targetUid);

  try {
    await admin.auth().deleteUser(targetUid);
  } catch (error) {
    if (!error || error.code !== "auth/user-not-found") {
      throw error;
    }
  }

  return {deleted: true};
});

/**
 * Builds invoice number.
 * @return {string}
 */
function invoiceNumber() {
  const now = new Date();
  const yyyy = now.getUTCFullYear();
  const mm = String(now.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(now.getUTCDate()).padStart(2, "0");
  const rand = String(Math.floor(Math.random() * 900000) + 100000);
  return `INV-${yyyy}${mm}${dd}-${rand}`;
}

/**
 * Formats date.
 * @param {Date} date
 * @return {string}
 */
function ymd(date) {
  const yyyy = date.getUTCFullYear();
  const mm = String(date.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(date.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

/**
 * Escapes PDF text.
 * @param {string} value
 * @return {string}
 */
function pdfEscape(value) {
  return String(value || "")
      .replace(/\\/g, "\\\\")
      .replace(/\(/g, "\\(")
      .replace(/\)/g, "\\)");
}

/**
 * Parses Firestore timestamp/string/date to Date.
 * @param {*} value
 * @return {Date|null}
 */
function parseDate(value) {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

/**
 * Returns a shuffled copy of values.
 * @param {Array<*>} values
 * @return {Array<*>}
 */
function shuffle(values) {
  const copy = [...values];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = crypto.randomInt(0, i + 1);
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

/**
 * Builds the in-app deep-link route for a contest, matching the
 * `/contest-share` route the app already understands.
 * @param {string} contestId
 * @return {string}
 */
function contestRoute(contestId) {
  return `/contest-share?contestId=${contestId}`;
}

/**
 * Writes a `users/{uid}/notifications` doc for each user in [userIds]. The
 * Firestore trigger below turns each one into a real push, so callers never
 * need to touch FCM directly.
 * @param {Array<string>} userIds
 * @param {{title: string, message: string, route: string}} content
 * @return {Promise<void>}
 */
async function notifyUsers(userIds, {title, message, route}) {
  const uniqueIds = [...new Set(userIds.filter(Boolean))];
  const now = admin.firestore.FieldValue.serverTimestamp();
  for (let i = 0; i < uniqueIds.length; i += 400) {
    const batch = db.batch();
    for (const uid of uniqueIds.slice(i, i + 400)) {
      const ref = db
          .collection("users")
          .doc(uid)
          .collection("notifications")
          .doc();
      batch.set(ref, {title, message, route, read: false, createdAt: now});
    }
    await batch.commit().catch(() => null);
  }
}

/**
 * Ids of the users with an approved entry in a contest (i.e. its
 * participants), deduplicated.
 * @param {FirebaseFirestore.DocumentReference} contestRef
 * @return {Promise<Array<string>>}
 */
async function getApprovedParticipantUserIds(contestRef) {
  const snap = await contestRef
      .collection("submissions")
      .where("status", "==", "approved")
      .get();
  return [
    ...new Set(
        snap.docs.map((doc) => (doc.data().userId || "").toString()),
    ),
  ].filter(Boolean);
}

/**
 * Notifies a contest's participants once voting opens, at most once per
 * contest (guarded by `votingStartNotified`).
 * @param {FirebaseFirestore.QueryDocumentSnapshot<
 *   FirebaseFirestore.DocumentData
 * >} contestDoc
 * @return {Promise<void>}
 */
async function notifyVotingStartedForContest(contestDoc) {
  const data = contestDoc.data() || {};
  if (data.votingStartNotified === true) return;
  const votingStart = parseDate(data.votingStart);
  if (!votingStart || votingStart.getTime() > Date.now()) return;

  const userIds = await getApprovedParticipantUserIds(contestDoc.ref);
  const title = (data.title || "This contest").toString();
  await notifyUsers(userIds, {
    title: "Voting has started!",
    message: `Voting is now open for "${title}". Go vote for your favorites!`,
    route: contestRoute(contestDoc.id),
  });
  await contestDoc.ref
      .set({votingStartNotified: true}, {merge: true})
      .catch(() => null);
}

/**
 * Selects lucky draw winners for a single contest.
 * @param {FirebaseFirestore.QueryDocumentSnapshot<
 *   FirebaseFirestore.DocumentData
 * >} contestDoc
 * @return {Promise<void>}
 */
async function runLuckyDrawForContest(contestDoc) {
  const data = contestDoc.data() || {};
  if (data.drawCompleted === true) return;

  const votingEnd = parseDate(data.votingEnd);
  if (!votingEnd || votingEnd.getTime() > Date.now()) return;

  const votesSnap = await contestDoc.ref.collection("votes").get();
  const uniqueVoterIds = [
    ...new Set(
        votesSnap.docs
            .map((doc) => (doc.data().voterId || doc.id || "").toString())
            .filter(Boolean),
    ),
  ];

  const drawAt = admin.firestore.Timestamp.now();
  const winnerCount = Math.min(DRAW_WINNER_COUNT, uniqueVoterIds.length);
  const selectedIds = shuffle(uniqueVoterIds).slice(0, winnerCount);

  const userDocs = await Promise.all(
      selectedIds.map((uid) => db.collection("users").doc(uid).get()),
  );

  const batch = db.batch();
  selectedIds.forEach((uid, index) => {
    const userData = userDocs[index].data() || {};
    const winnerRef = contestDoc.ref.collection("draw_winners").doc(uid);
    batch.set(winnerRef, {
      userId: uid,
      contestId: contestDoc.id,
      contestTitle: (data.title || "").toString(),
      drawAt,
      prizeAmount: DRAW_PRIZE_AMOUNT,
      position: index + 1,
      userName: (userData.displayName || userData.email || "User").toString(),
      userEmail: (userData.email || "").toString(),
      voteEntryId: uid,
      createdAt: drawAt,
      updatedAt: drawAt,
    });
  });

  batch.set(
      contestDoc.ref,
      {
        drawCompleted: true,
        drawCompletedAt: drawAt,
        drawEligibleVoterCount: uniqueVoterIds.length,
        drawWinnerCount: winnerCount,
        drawPrizeAmount: DRAW_PRIZE_AMOUNT,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
  );

  await batch.commit();

  const participantIds = await getApprovedParticipantUserIds(contestDoc.ref);
  await notifyUsers(participantIds, {
    title: "Results are in!",
    message: `Voting has ended for "${(data.title || "your contest")
        .toString()}". Check out the winners.`,
    route: contestRoute(contestDoc.id),
  });
}

/**
 * Builds a branded one-page invoice PDF.
 * @param {Object} params
 * @return {Buffer}
 */
function buildInvoicePdf({
  invoiceNo,
  invoiceDate,
  sponsorName,
  sponsorEmail,
  companyName,
  applicationName,
  country,
  amount,
}) {
  const currencyAmount = `$${Number(amount || 0).toFixed(2)}`;
  const contentParts = [
    "0.12 0.07 0.28 rg",
    "40 720 515 88 re f",

    "0.94 0.91 0.98 rg",
    "40 615 515 24 re f",

    "0 0 0 RG 0.85 w",
    "40 560 515 55 re S",
    "40 505 515 55 re S",

    "0.12 0.07 0.28 rg",
    "BT /F1 24 Tf 58 776 Td (Click Kick) Tj ET",
    "0.90 0.35 0.79 rg",
    "BT /F1 12 Tf 58 755 Td (Sponsorship Invoice) Tj ET",

    "1 1 1 rg",
    `BT /F1 12 Tf 375 778 Td (${pdfEscape(`Invoice #: ${invoiceNo}`)}) Tj ET`,
    `BT /F1 12 Tf 375 760 Td (${pdfEscape(`Date: ${ymd(invoiceDate)}`)}) Tj ET`,
    "BT /F1 12 Tf 375 742 Td (Currency: USD) Tj ET",

    "0 0 0 rg",
    "BT /F1 14 Tf 58 685 Td (Billed To) Tj ET",
    `BT /F1 12 Tf 58 665 Td (${pdfEscape(sponsorName || "-")}) Tj ET`,
    `BT /F1 12 Tf 58 647 Td (${pdfEscape(sponsorEmail || "-")}) Tj ET`,
    `BT /F1 12 Tf 58 629 Td (${pdfEscape(companyName || "-")}) Tj ET`,

    "BT /F1 14 Tf 318 685 Td (Sponsorship Application) Tj ET",
    `BT /F1 12 Tf 318 665 Td (${pdfEscape(
        applicationName || "Sponsorship Application",
    )}) Tj ET`,
    `BT /F1 12 Tf 318 647 Td (${pdfEscape(`Region: ${country || "-"}`)}) Tj ET`,
    `BT /F1 12 Tf 318 629 Td (${pdfEscape(
        `Invoice Date: ${ymd(invoiceDate)}`,
    )}) Tj ET`,

    "0 0 0 rg",
    "BT /F1 12 Tf 58 622 Td (Description) Tj ET",
    "BT /F1 12 Tf 465 622 Td (Amount) Tj ET",

    `BT /F1 12 Tf 58 585 Td (${pdfEscape("Sponsorship Campaign Fee")}) Tj ET`,
    `BT /F1 12 Tf 455 585 Td (${pdfEscape(currencyAmount)}) Tj ET`,

    "BT /F1 12 Tf 58 530 Td (Total) Tj ET",
    "0.48 0.17 0.63 rg",
    `BT /F1 13 Tf 448 530 Td (${pdfEscape(currencyAmount)}) Tj ET`,

    "0 0 0 rg",
    "BT /F1 11 Tf 58 475 Td (Thank you for your sponsorship payment.) Tj ET",
  ];

  const content = contentParts.join("\n");

  const contentLength = Buffer.byteLength(content, "utf8");
  const objects = [
    "1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj",
    "2 0 obj << /Type /Pages /Count 1 /Kids [3 0 R] >> endobj",
    "3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] " +
      "/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >> endobj",
    `4 0 obj << /Length ${contentLength} >> stream\n${content}\n` +
      "endstream endobj",
    "5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj",
  ];

  let pdf = "%PDF-1.4\n";
  const offsets = [0];
  for (const object of objects) {
    offsets.push(Buffer.byteLength(pdf, "utf8"));
    pdf += `${object}\n`;
  }
  const xrefStart = Buffer.byteLength(pdf, "utf8");
  pdf += `xref\n0 ${objects.length + 1}\n`;
  pdf += "0000000000 65535 f \n";
  for (let i = 1; i <= objects.length; i++) {
    pdf += `${String(offsets[i]).padStart(10, "0")} 00000 n \n`;
  }
  pdf += `trailer << /Size ${objects.length + 1} /Root 1 0 R >>\n`;
  pdf += `startxref\n${xrefStart}\n%%EOF`;
  return Buffer.from(pdf, "utf8");
}

/**
 * Generates invoice PDF, uploads it, and writes invoice fields.
 * @param {Object} params
 * @return {Promise<void>}
 */
async function ensureInvoiceForApplication({applicationId, sponsorId}) {
  const appRef = db.collection("sponsorship_applications").doc(applicationId);
  const appSnap = await appRef.get();
  if (!appSnap.exists) return;

  const appData = appSnap.data() || {};
  if (appData.invoiceNumber && appData.invoiceUrl) {
    return;
  }

  const effectiveSponsorId = sponsorId || appData.sponsorId || "";
  const sponsorSnap = effectiveSponsorId ?
    await db.collection("users").doc(effectiveSponsorId).get() :
    null;
  const sponsor =
    sponsorSnap && sponsorSnap.exists ? sponsorSnap.data() || {} : {};
  const now = new Date();
  const generatedInvoiceNumber = invoiceNumber();
  const amount = Number(appData.applicationFee || 1000);
  const pdfBuffer = buildInvoicePdf({
    invoiceNo: generatedInvoiceNumber,
    invoiceDate: now,
    sponsorName: sponsor.displayName || "Sponsor",
    sponsorEmail: sponsor.email || "",
    companyName: sponsor.companyName || "",
    applicationName:
      appData.companySponsorName ||
      appData.applicationName ||
      "Sponsorship Application",
    country: appData.targetCountry || "ALL",
    amount,
  });

  const bucket = admin.storage().bucket();
  const invoiceOwnerPath = effectiveSponsorId || "unassigned";
  const filePath = `invoices/${invoiceOwnerPath}/${generatedInvoiceNumber}.pdf`;
  const token = crypto.randomUUID();
  const file = bucket.file(filePath);
  await file.save(pdfBuffer, {
    contentType: "application/pdf",
    metadata: {
      metadata: {
        firebaseStorageDownloadTokens: token,
      },
    },
  });

  const invoiceUrl =
    `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
    `${encodeURIComponent(filePath)}?alt=media&token=${token}`;
  const invoiceTimestamp = admin.firestore.Timestamp.fromDate(now);

  await appRef.set(
      {
        invoiceNumber: generatedInvoiceNumber,
        invoiceUrl,
        invoiceGeneratedAt: invoiceTimestamp,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
  );

  const paymentDocs = await db
      .collection("payments")
      .where("applicationId", "==", applicationId)
      .where("status", "==", "paid")
      .get();
  const batch = db.batch();
  paymentDocs.docs.forEach((doc) => {
    batch.set(
        doc.ref,
        {
          sponsorId: effectiveSponsorId,
          invoiceNumber: generatedInvoiceNumber,
          invoiceUrl,
          invoiceGeneratedAt: invoiceTimestamp,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
    );
  });
  if (!paymentDocs.empty) {
    await batch.commit();
  }
}

/**
 * Loads sponsorship application and validates owner.
 * @param {string} applicationId
 * @param {string} sponsorId
 * @return {Promise<Object>}
 */
async function getApplicationForSponsor(applicationId, sponsorId) {
  const appRef = db.collection("sponsorship_applications").doc(applicationId);
  const appSnap = await appRef.get();
  if (!appSnap.exists) {
    throw new HttpsError("not-found", "Application not found.");
  }

  const appData = appSnap.data() || {};
  if ((appData.sponsorId || "") !== sponsorId) {
    throw new HttpsError("permission-denied", "Not your application.");
  }

  return {appRef, appData};
}

/**
 * Returns existing Stripe customer or creates a new customer.
 * @param {Object} params
 * @return {Promise<string>}
 */
async function getOrCreateStripeCustomer({
  uid,
  email,
  name,
  appRef,
  appData,
}) {
  if (appData.stripeCustomerId) {
    return appData.stripeCustomerId;
  }

  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();
  const userData = userSnap.data() || {};
  if (userData.stripeCustomerId) {
    await appRef.set(
        {
          stripeCustomerId: userData.stripeCustomerId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
    );
    return userData.stripeCustomerId;
  }

  const stripe = getStripeClient();
  const customer = await stripe.customers.create({
    email: email || undefined,
    name: name || undefined,
    metadata: {uid},
  });

  await userRef.set(
      {
        stripeCustomerId: customer.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
  );
  await appRef.set(
      {
        stripeCustomerId: customer.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
  );
  return customer.id;
}

/**
 * Persists one payment row if not already recorded.
 * @param {Object} params
 * @return {Promise<void>}
 */
async function savePaymentRecord({
  applicationId,
  sponsorId,
  amount,
  provider,
  stripeSessionId = "",
  stripePaymentIntentId = "",
}) {
  const paymentQuery = db.collection("payments");
  let duplicate = false;

  if (stripePaymentIntentId) {
    const existingByIntent = await paymentQuery
        .where("stripePaymentIntentId", "==", stripePaymentIntentId)
        .limit(1)
        .get();
    duplicate = !existingByIntent.empty;
  }
  if (!duplicate && stripeSessionId) {
    const existingBySession = await paymentQuery
        .where("stripeSessionId", "==", stripeSessionId)
        .limit(1)
        .get();
    duplicate = !existingBySession.empty;
  }
  if (duplicate) return;

  await paymentQuery.add({
    applicationId,
    sponsorId,
    amount,
    currency: "usd",
    status: "paid",
    provider,
    stripeSessionId,
    stripePaymentIntentId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    paidAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Marks sponsorship application as paid and stores payment.
 * @param {Object} params
 * @return {Promise<void>}
 */
async function markApplicationPaid({
  applicationId,
  sponsorId,
  stripeSessionId = "",
  stripePaymentIntentId = "",
  provider = "stripe",
}) {
  const appRef = db.collection("sponsorship_applications").doc(applicationId);
  const appSnap = await appRef.get();
  if (!appSnap.exists) return;

  const appData = appSnap.data() || {};
  const amount = Number(appData.applicationFee || 1000);

  await appRef.set(
      {
        paymentStatus: "paid",
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        stripeSessionId: stripeSessionId || appData.stripeSessionId || "",
        stripePaymentIntentId:
        stripePaymentIntentId || appData.stripePaymentIntentId || "",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
  );

  await savePaymentRecord({
    applicationId,
    sponsorId: sponsorId || appData.sponsorId || "",
    amount,
    provider,
    stripeSessionId,
    stripePaymentIntentId,
  });

  await ensureInvoiceForApplication({
    applicationId,
    sponsorId: sponsorId || appData.sponsorId || "",
  });
}

exports.sendLoginOtp = onCall(
    {
      secrets: [
        "META_WHATSAPP_TOKEN",
        "META_WHATSAPP_PHONE_NUMBER_ID",
        "WHATSAPP_OTP_TEMPLATE",
        "WHATSAPP_TEMPLATE_LANGUAGE",
      ],
    },
    async (request) => {
      const uid = request.auth && request.auth.uid;
      if (!uid) throw new HttpsError("unauthenticated", "Login required.");

      const userSnap = await db.collection("users").doc(uid).get();
      if (!userSnap.exists) {
        throw new HttpsError("not-found", "User profile not found.");
      }

      const userData = userSnap.data() || {};
      const phoneE164 = userPhoneE164(userData);
      if (!phoneE164 || whatsappPhone(phoneE164).length < 8) {
        throw new HttpsError(
            "failed-precondition",
            "No phone number found for this account.",
        );
      }

      const otpRef = db.collection("login_otps").doc(uid);
      const otpSnap = await otpRef.get();
      const previous = otpSnap.data() || {};
      const lastSentAt = parseDate(previous.lastSentAt);
      if (
        lastSentAt &&
      Date.now() - lastSentAt.getTime() < LOGIN_OTP_RESEND_SECONDS * 1000
      ) {
        const waitSeconds = Math.ceil(
            (LOGIN_OTP_RESEND_SECONDS * 1000 -
          (Date.now() - lastSentAt.getTime())) /
          1000,
        );
        throw new HttpsError(
            "failed-precondition",
            `Please wait ${waitSeconds}s before requesting another OTP.`,
        );
      }

      const min = 10 ** (LOGIN_OTP_DIGITS - 1);
      const max = 10 ** LOGIN_OTP_DIGITS;
      const code = String(crypto.randomInt(min, max));
      const now = admin.firestore.Timestamp.now();
      const expiresAt = admin.firestore.Timestamp.fromMillis(
          Date.now() + LOGIN_OTP_EXPIRY_MINUTES * 60 * 1000,
      );

      await sendWhatsAppOtp({toPhoneE164: phoneE164, code});

      await otpRef.set(
          {
            uid,
            phoneE164,
            codeHash: otpHash(uid, code),
            attempts: 0,
            verifiedAt: null,
            createdAt: now,
            lastSentAt: now,
            expiresAt,
          },
          {merge: true},
      );

      return {
        sent: true,
        digits: LOGIN_OTP_DIGITS,
        resendAfterSeconds: LOGIN_OTP_RESEND_SECONDS,
        maskedPhone: `****${whatsappPhone(phoneE164).slice(-4)}`,
      };
    },
);

exports.verifyLoginOtp = onCall(
    {
      secrets: ["META_WHATSAPP_TOKEN"],
    },
    async (request) => {
      const uid = request.auth && request.auth.uid;
      if (!uid) throw new HttpsError("unauthenticated", "Login required.");

      const code = String((request.data && request.data.code) || "").trim();
      if (!/^\d{6}$/.test(code)) {
        throw new HttpsError("invalid-argument", "Enter the 6 digit code.");
      }

      const otpRef = db.collection("login_otps").doc(uid);
      const otpSnap = await otpRef.get();
      if (!otpSnap.exists) {
        throw new HttpsError("not-found", "Please request a new OTP.");
      }

      const data = otpSnap.data() || {};
      const expiresAt = parseDate(data.expiresAt);
      if (!expiresAt || expiresAt.getTime() < Date.now()) {
        throw new HttpsError("deadline-exceeded", "OTP expired.");
      }

      const attempts = Number(data.attempts || 0);
      if (attempts >= LOGIN_OTP_MAX_ATTEMPTS) {
        throw new HttpsError(
            "resource-exhausted",
            "Too many attempts. Please request a new OTP.",
        );
      }

      if (data.codeHash !== otpHash(uid, code)) {
        await otpRef.set(
            {
              attempts: admin.firestore.FieldValue.increment(1),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            {merge: true},
        );
        throw new HttpsError("permission-denied", "Invalid OTP.");
      }

      await otpRef.set(
          {
            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
      );

      await db.collection("users").doc(uid).set(
          {
            lastOtpVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
      );

      return {verified: true};
    },
);

/**
 * Hashes a password-reset OTP code for storage (never store the raw code).
 * @param {string} uid
 * @param {string} code
 * @return {string}
 */
function resetOtpHash(uid, code) {
  return crypto
      .createHash("sha256")
      .update(`reset:${uid}:${code}`)
      .digest("hex");
}

/**
 * Sends the password-reset OTP code by email via Gmail SMTP.
 * @param {{toEmail: string, code: string}} args
 * @return {Promise<void>}
 */
async function sendPasswordResetOtpEmail({toEmail, code}) {
  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: process.env.GMAIL_USER,
      pass: process.env.GMAIL_APP_PASSWORD,
    },
  });
  await transporter.sendMail({
    from: `"Click Kick" <${process.env.GMAIL_USER}>`,
    to: toEmail,
    subject: `Your Click Kick password reset code: ${code}`,
    text: `Your password reset code is ${code}. It expires in ` +
      `${RESET_OTP_EXPIRY_MINUTES} minutes. If you didn't request this, ` +
      `you can ignore this email.`,
    html: `<p>Your Click Kick password reset code is:</p>` +
      `<p style="font-size:28px;font-weight:700;letter-spacing:4px;">` +
      `${code}</p>` +
      `<p>It expires in ${RESET_OTP_EXPIRY_MINUTES} minutes. If you ` +
      `didn't request this, you can ignore this email.</p>`,
  });
}

/**
 * Step 1 of the in-app forgot-password flow: emails a 6-digit code. Not
 * authenticated (the caller isn't logged in yet) — rate-limited instead.
 */
exports.sendPasswordResetOtp = onCall(
    {secrets: ["GMAIL_USER", "GMAIL_APP_PASSWORD"]},
    async (request) => {
      const email = String((request.data && request.data.email) || "")
          .trim()
          .toLowerCase();
      if (!email || !email.includes("@")) {
        throw new HttpsError("invalid-argument", "Enter a valid email.");
      }

      let userRecord;
      try {
        userRecord = await admin.auth().getUserByEmail(email);
      } catch (error) {
        throw new HttpsError("not-found", "No user found for that email.");
      }
      const uid = userRecord.uid;

      const otpRef = db.collection("password_reset_otps").doc(uid);
      const otpSnap = await otpRef.get();
      const previous = otpSnap.data() || {};
      const lastSentAt = parseDate(previous.lastSentAt);
      if (
        lastSentAt &&
      Date.now() - lastSentAt.getTime() < RESET_OTP_RESEND_SECONDS * 1000
      ) {
        const waitSeconds = Math.ceil(
            (RESET_OTP_RESEND_SECONDS * 1000 -
          (Date.now() - lastSentAt.getTime())) /
          1000,
        );
        throw new HttpsError(
            "failed-precondition",
            `Please wait ${waitSeconds}s before requesting another OTP.`,
        );
      }

      const min = 10 ** (RESET_OTP_DIGITS - 1);
      const max = 10 ** RESET_OTP_DIGITS;
      const code = String(crypto.randomInt(min, max));
      const now = admin.firestore.Timestamp.now();
      const expiresAt = admin.firestore.Timestamp.fromMillis(
          Date.now() + RESET_OTP_EXPIRY_MINUTES * 60 * 1000,
      );

      await sendPasswordResetOtpEmail({toEmail: email, code});

      await otpRef.set({
        uid,
        email,
        codeHash: resetOtpHash(uid, code),
        attempts: 0,
        verifiedAt: null,
        resetToken: null,
        resetTokenExpiresAt: null,
        createdAt: now,
        lastSentAt: now,
        expiresAt,
      });

      return {
        sent: true,
        digits: RESET_OTP_DIGITS,
        resendAfterSeconds: RESET_OTP_RESEND_SECONDS,
        maskedEmail: email.replace(
            /^(.{1,2}).*(@.*)$/,
            (m, a, b) => `${a}***${b}`,
        ),
      };
    },
);

/**
 * Step 2: verifies the code and issues a short-lived token authorizing the
 * password change in step 3 (so step 3 can't be called by skipping step 2).
 */
exports.verifyPasswordResetOtp = onCall(async (request) => {
  const email = String((request.data && request.data.email) || "")
      .trim()
      .toLowerCase();
  const code = String((request.data && request.data.code) || "").trim();
  if (!/^\d{6}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Enter the 6 digit code.");
  }

  let uid;
  try {
    uid = (await admin.auth().getUserByEmail(email)).uid;
  } catch (error) {
    throw new HttpsError("not-found", "No user found for that email.");
  }

  const otpRef = db.collection("password_reset_otps").doc(uid);
  const otpSnap = await otpRef.get();
  if (!otpSnap.exists) {
    throw new HttpsError("not-found", "Please request a new code.");
  }

  const data = otpSnap.data() || {};
  const expiresAt = parseDate(data.expiresAt);
  if (!expiresAt || expiresAt.getTime() < Date.now()) {
    throw new HttpsError("deadline-exceeded", "Code expired.");
  }

  const attempts = Number(data.attempts || 0);
  if (attempts >= RESET_OTP_MAX_ATTEMPTS) {
    throw new HttpsError(
        "resource-exhausted",
        "Too many attempts. Please request a new code.",
    );
  }

  if (data.codeHash !== resetOtpHash(uid, code)) {
    await otpRef.set(
        {attempts: admin.firestore.FieldValue.increment(1)},
        {merge: true},
    );
    throw new HttpsError("permission-denied", "Invalid code.");
  }

  const resetToken = crypto.randomBytes(24).toString("hex");
  const resetTokenExpiresAt = admin.firestore.Timestamp.fromMillis(
      Date.now() + RESET_TOKEN_EXPIRY_MINUTES * 60 * 1000,
  );
  await otpRef.set(
      {
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        resetToken,
        resetTokenExpiresAt,
      },
      {merge: true},
  );

  return {verified: true, resetToken};
});

/**
 * Step 3: sets the new password, only if a valid, unexpired token from step
 * 2 is presented.
 */
exports.resetPasswordWithOtp = onCall(async (request) => {
  const email = String((request.data && request.data.email) || "")
      .trim()
      .toLowerCase();
  const resetToken = String((request.data && request.data.resetToken) || "");
  const newPassword = String((request.data && request.data.newPassword) || "");
  if (newPassword.length < 6) {
    throw new HttpsError(
        "invalid-argument",
        "Password must be at least 6 characters.",
    );
  }

  let uid;
  try {
    uid = (await admin.auth().getUserByEmail(email)).uid;
  } catch (error) {
    throw new HttpsError("not-found", "No user found for that email.");
  }

  const otpRef = db.collection("password_reset_otps").doc(uid);
  const otpSnap = await otpRef.get();
  const data = otpSnap.data() || {};
  const tokenExpiresAt = parseDate(data.resetTokenExpiresAt);
  if (
    !data.resetToken ||
    data.resetToken !== resetToken ||
    !tokenExpiresAt ||
    tokenExpiresAt.getTime() < Date.now()
  ) {
    throw new HttpsError(
        "permission-denied",
        "Please verify the code again.",
    );
  }

  await admin.auth().updateUser(uid, {password: newPassword});
  await otpRef.delete();

  return {success: true};
});

exports.createSponsorshipPaymentIntent = onCall(
    {secrets: ["STRIPE_SECRET"]},
    async (request) => {
      const uid = request.auth && request.auth.uid;
      if (!uid) throw new HttpsError("unauthenticated", "Login required.");

      const applicationId = request.data && request.data.applicationId;
      if (!applicationId) {
        throw new HttpsError("invalid-argument", "Missing applicationId.");
      }

      const {appRef, appData} = await getApplicationForSponsor(
          applicationId,
          uid,
      );

      if ((appData.paymentStatus || "unpaid") === "paid") {
        throw new HttpsError("failed-precondition", "Already paid.");
      }

      const amount = Number(appData.applicationFee || 1000);
      const amountCents = Math.max(50, Math.round(amount * 100));

      const customerId = await getOrCreateStripeCustomer({
        uid,
        email: request.auth.token && request.auth.token.email,
        name: request.auth.token && request.auth.token.name,
        appRef,
        appData,
      });

      const stripe = getStripeClient();
      const ephemeralKey = await stripe.ephemeralKeys.create(
          {customer: customerId},
          {apiVersion: "2025-01-27.acacia"},
      );

      const paymentIntent = await stripe.paymentIntents.create({
        amount: amountCents,
        currency: "usd",
        customer: customerId,
        automatic_payment_methods: {enabled: true},
        metadata: {
          applicationId,
          sponsorId: uid,
        },
      });

      await appRef.set(
          {
            paymentStatus: "pending",
            stripeCustomerId: customerId,
            stripePaymentIntentId: paymentIntent.id,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
      );

      return {
        paymentIntentClientSecret: paymentIntent.client_secret,
        customerId,
        ephemeralKeySecret: ephemeralKey.secret,
        merchantDisplayName: "Click Kick",
      };
    },
);

exports.createSponsorshipCheckoutSession = onCall(
    {secrets: ["STRIPE_SECRET"]},
    async (request) => {
      const uid = request.auth && request.auth.uid;
      if (!uid) throw new HttpsError("unauthenticated", "Login required.");

      const applicationId = request.data && request.data.applicationId;
      const successUrl = request.data && request.data.successUrl;
      const cancelUrl = request.data && request.data.cancelUrl;

      if (!applicationId || !successUrl || !cancelUrl) {
        throw new HttpsError("invalid-argument", "Missing required fields.");
      }

      const {appRef, appData} = await getApplicationForSponsor(
          applicationId,
          uid,
      );

      if ((appData.paymentStatus || "unpaid") === "paid") {
        throw new HttpsError("failed-precondition", "Already paid.");
      }

      const amount = Number(appData.applicationFee || 1000);
      const amountCents = Math.max(50, Math.round(amount * 100));

      const stripe = getStripeClient();
      const session = await stripe.checkout.sessions.create({
        mode: "payment",
        payment_method_types: ["card"],
        line_items: [
          {
            price_data: {
              currency: "usd",
              product_data: {
                name:
                "Sponsorship Fee - " +
                `${appData.applicationName || "Application"}`,
              },
              unit_amount: amountCents,
            },
            quantity: 1,
          },
        ],
        metadata: {
          applicationId,
          sponsorId: uid,
        },
        success_url: successUrl,
        cancel_url: cancelUrl,
      });

      await appRef.set(
          {
            stripeSessionId: session.id,
            paymentStatus: "pending",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
      );

      return {url: session.url};
    },
);

exports.stripeWebhook = onRequest(
    {secrets: ["STRIPE_SECRET", "STRIPE_WEBHOOK_SECRET"]},
    async (req, res) => {
      const stripe = getStripeClient();
      const sig = req.headers["stripe-signature"];

      let event;
      try {
        event = stripe.webhooks.constructEvent(
            req.rawBody,
            sig,
            process.env.STRIPE_WEBHOOK_SECRET,
        );
      } catch (err) {
        res.status(400).send(`Webhook Error: ${err.message}`);
        return;
      }

      if (event.type === "checkout.session.completed") {
        const session = event.data.object;
        const metadata = session.metadata || {};
        await markApplicationPaid({
          applicationId: metadata.applicationId || "",
          sponsorId: metadata.sponsorId || "",
          stripeSessionId: session.id,
          stripePaymentIntentId: (session.payment_intent || "").toString(),
          provider: "stripe_checkout",
        });
      }

      if (event.type === "payment_intent.succeeded") {
        const intent = event.data.object;
        const metadata = intent.metadata || {};
        await markApplicationPaid({
          applicationId: metadata.applicationId || "",
          sponsorId: metadata.sponsorId || "",
          stripePaymentIntentId: intent.id,
          provider: "stripe",
        });
      }

      res.json({received: true});
    },
);

exports.runContestLuckyDraws = onSchedule(
    {
      schedule: "* * * * *",
      timeZone: "UTC",
    },
    async () => {
      const contestsSnap = await db.collection("contests").get();
      for (const contestDoc of contestsSnap.docs) {
        await notifyVotingStartedForContest(contestDoc);
        await runLuckyDrawForContest(contestDoc);
      }
    },
);

/**
 * Turns every `users/{uid}/notifications` write into a real push. This is
 * the single place that talks to FCM, so every existing and future writer of
 * that collection (admin approve/reject, sponsor reports, the functions
 * above, ...) gets a push for free with no changes on their part.
 */
exports.sendUserNotificationPush = onDocumentCreated(
    "users/{uid}/notifications/{notifId}",
    async (event) => {
      const data = event.data && event.data.data();
      if (!data) return;

      const uid = event.params.uid;
      const userSnap = await db.collection("users").doc(uid).get();
      const tokens = (userSnap.data() || {}).fcmTokens;
      if (!Array.isArray(tokens) || tokens.length === 0) return;

      const title = (data.title || "Click Kick").toString();
      const body = (data.message || "").toString();
      // Prefer an explicit route; otherwise infer one the same way existing
      // writers (which predate this field) already shape their data:
      // a submissionId alongside a contestId is a contest entry, a bare
      // submissionId is a general video.
      let route = (data.route || "").toString();
      if (!route) {
        const contestId = (data.contestId || "").toString();
        const submissionId = (data.submissionId || "").toString();
        if (contestId && submissionId) {
          route = `/contest-share?contestId=${contestId}` +
            `&submissionId=${submissionId}`;
        } else if (submissionId) {
          route = `/general-video?videoId=${submissionId}`;
        }
      }

      let response;
      try {
        response = await admin.messaging().sendEachForMulticast({
          tokens,
          notification: {title, body},
          data: route ? {route} : {},
        });
      } catch (error) {
        console.error("sendUserNotificationPush failed", error);
        return;
      }

      const staleTokens = [];
      response.responses.forEach((r, i) => {
        const code = r.error && r.error.code;
        if (
          code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-argument"
        ) {
          staleTokens.push(tokens[i]);
        }
      });
      if (staleTokens.length > 0) {
        await db
            .collection("users")
            .doc(uid)
            .set(
                {fcmTokens: admin.firestore.FieldValue.arrayRemove(
                    ...staleTokens,
                )},
                {merge: true},
            )
            .catch(() => null);
      }
    },
);

/**
 * Broadcasts a new contest to every device via FCM topic messaging, so it is
 * one send regardless of how many users the app has (rather than writing a
 * notification document per user).
 */
exports.notifyNewContest = onDocumentCreated(
    "contests/{contestId}",
    async (event) => {
      const data = event.data && event.data.data();
      if (!data) return;
      const title = (data.title || "A new contest").toString();
      try {
        await admin.messaging().send({
          topic: "all_users",
          notification: {
            title: "New contest is live!",
            body: `"${title}" just opened — submit your video now.`,
          },
          data: {route: contestRoute(event.params.contestId)},
        });
      } catch (error) {
        console.error("notifyNewContest failed", error);
      }
    },
);

/**
 * Works out which Firestore doc a video's thumbnail belongs to, from its
 * Storage path (`general_videos/{uid}/{videoId}.mp4` or
 * `videos/{uid}/{contestId}/{submissionId}.mp4`) — or null when the upload
 * is something else entirely (profile photo, invoice PDF, ...).
 * @param {string} filePath
 * @return {FirebaseFirestore.DocumentReference|null}
 */
function thumbnailTargetDoc(filePath) {
  const parts = filePath.split("/");
  if (parts[0] === "general_videos" && parts.length === 3) {
    const videoId = path.basename(parts[2], path.extname(parts[2]));
    return db.collection("general_videos").doc(videoId);
  }
  if (parts[0] === "videos" && parts.length === 4) {
    const contestId = parts[2];
    const submissionId = path.basename(parts[3], path.extname(parts[3]));
    return db
        .collection("contests")
        .doc(contestId)
        .collection("submissions")
        .doc(submissionId);
  }
  if (parts[0] === "admin_videos" && parts.length === 3) {
    const docId = parts[1];
    return db.collection("admin_videos").doc(docId);
  }
  return null;
}

/**
 * Extracts a single frame from a video with ffmpeg.
 * @param {string} inputPath
 * @param {string} outputPath
 * @return {Promise<void>}
 */
function extractThumbnailFrame(inputPath, outputPath) {
  return new Promise((resolve, reject) => {
    execFile(
        ffmpegPath,
        [
          "-y",
          "-i", inputPath,
          "-ss", "00:00:01",
          "-frames:v", "1",
          "-update", "1",
          "-vf", "scale=480:-2",
          outputPath,
        ],
        (error) => (error ? reject(error) : resolve()),
    );
  });
}

/**
 * Generates a thumbnail for every General Video / contest submission upload
 * (a real preview frame, not a blank placeholder) and saves its URL back to
 * the matching Firestore doc. Runs on every file upload to the bucket but
 * exits immediately for anything that isn't one of those two video paths.
 */
exports.generateVideoThumbnail = onObjectFinalized(
    {memory: "512MiB", timeoutSeconds: 120},
    async (event) => {
      const object = event.data;
      const filePath = object.name || "";
      const contentType = object.contentType || "";
      if (!contentType.startsWith("video/")) return;
      // Ignore watermarked copies: thumbnailTargetDoc() only strips the file
      // extension, so "<id>_watermarked.mp4" would resolve to a doc id of
      // "<id>_watermarked" — a phantom submission that doesn't exist and
      // gets silently created with nothing but a thumbnailUrl, then shows up
      // in admin moderation as a blank "pending" ghost entry next to the
      // real (already-reviewed) video. The original upload already got its
      // thumbnail before watermarking ever ran, so there's nothing to do
      // here for the watermarked copy anyway.
      if (path.basename(filePath).includes("_watermarked")) return;

      const docRef = thumbnailTargetDoc(filePath);
      if (!docRef) return;

      const tmpVideo = path.join(
          os.tmpdir(),
          `in-${Date.now()}${path.extname(filePath) || ".mp4"}`,
      );
      const tmpThumb = path.join(os.tmpdir(), `out-${Date.now()}.jpg`);
      const bucket = admin.storage().bucket(object.bucket);

      try {
        await bucket.file(filePath).download({destination: tmpVideo});
        await extractThumbnailFrame(tmpVideo, tmpThumb);

        const thumbPath = `${path.dirname(filePath)}/` +
          `${path.basename(filePath, path.extname(filePath))}_thumb.jpg`;
        await bucket.upload(tmpThumb, {
          destination: thumbPath,
          metadata: {
            contentType: "image/jpeg",
            cacheControl: "public, max-age=31536000",
          },
        });
        // The bucket already allows public read of the video at this same
        // path (see storage.rules), so the thumbnail next to it needs no
        // signed URL or download token — just the plain public REST URL.
        const thumbnailUrl =
          `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
          `${encodeURIComponent(thumbPath)}?alt=media`;
        await docRef.set({thumbnailUrl}, {merge: true});
      } catch (error) {
        console.error("generateVideoThumbnail failed", filePath, error);
      } finally {
        fs.unlink(tmpVideo, () => null);
        fs.unlink(tmpThumb, () => null);
      }
    },
);

/**
 * Overlays the Click Kick logo onto a video with ffmpeg, bottom-right corner.
 * @param {string} inputPath
 * @param {string} outputPath
 * @return {Promise<void>}
 */
function watermarkVideo(inputPath, outputPath) {
  return new Promise((resolve, reject) => {
    execFile(
        ffmpegPath,
        [
          "-y",
          "-i", inputPath,
          "-i", path.join(__dirname, "assets", "watermark_logo.png"),
          "-filter_complex",
          // Cap the output at 1280px wide: keeps ffmpeg's memory/CPU use
          // bounded regardless of how large the source upload is (a 4K phone
          // video was blowing past a 2GB function memory limit on its own),
          // and nothing on a phone screen needs a bigger download anyway.
          "[0:v]scale='min(1280,iw)':-2[base];" +
            "[1:v]scale=iw*0.15:-1[wm];" +
            "[base][wm]overlay=W-w-16:H-h-16:format=auto,format=yuv420p",
          // yuv420p + AAC + faststart: anything else (e.g. the 4:4:4 the
          // overlay produces by default) plays as a black screen in Android
          // gallery apps.
          "-c:v", "libx264",
          "-profile:v", "high",
          "-pix_fmt", "yuv420p",
          "-preset", "veryfast",
          "-crf", "23",
          "-c:a", "aac",
          "-b:a", "128k",
          "-movflags", "+faststart",
          outputPath,
        ],
        (error) => (error ? reject(error) : resolve()),
    );
  });
}

/**
 * Generates a watermarked copy of every General Video / contest submission
 * upload (Click Kick logo, bottom-right) and saves its URL back to the
 * matching Firestore doc as `watermarkedVideoUrl`, so downloads can offer a
 * branded copy the same way TikTok/Instagram stamp their logo on saves.
 * Runs on every file upload to the bucket but exits immediately for anything
 * that isn't one of those two video paths.
 */
exports.generateWatermarkedVideo = onObjectFinalized(
    {memory: "4GiB", cpu: 2, timeoutSeconds: 300},
    async (event) => {
      const object = event.data;
      const filePath = object.name || "";
      const contentType = object.contentType || "";
      if (!contentType.startsWith("video/")) return;
      // Ignore the watermarked copies this function itself uploads, so it
      // doesn't try to watermark an already-watermarked file forever.
      if (path.basename(filePath).includes("_watermarked")) return;

      const docRef = thumbnailTargetDoc(filePath);
      if (!docRef) return;

      const tmpVideo = path.join(
          os.tmpdir(),
          `wmin-${Date.now()}${path.extname(filePath) || ".mp4"}`,
      );
      const tmpOut = path.join(
          os.tmpdir(),
          `wmout-${Date.now()}${path.extname(filePath) || ".mp4"}`,
      );
      const bucket = admin.storage().bucket(object.bucket);

      try {
        await bucket.file(filePath).download({destination: tmpVideo});
        await watermarkVideo(tmpVideo, tmpOut);

        const watermarkedPath = `${path.dirname(filePath)}/` +
          `${path.basename(filePath, path.extname(filePath))}` +
          `_watermarked${path.extname(filePath)}`;
        await bucket.upload(tmpOut, {
          destination: watermarkedPath,
          metadata: {
            contentType,
            cacheControl: "public, max-age=31536000",
          },
        });
        // Same public-read Storage rule as the source video covers this path.
        const watermarkedVideoUrl =
          `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
          `${encodeURIComponent(watermarkedPath)}?alt=media`;
        await docRef.set({watermarkedVideoUrl}, {merge: true});
      } catch (error) {
        console.error("generateWatermarkedVideo failed", filePath, error);
      } finally {
        fs.unlink(tmpVideo, () => null);
        fs.unlink(tmpOut, () => null);
      }
    },
);

// The one-time `backfillVideoWatermarks` admin tool (used to watermark
// videos uploaded before automatic watermarking existed, including a second
// pass that added admin promotional videos to its coverage) has been
// removed now that every existing video has been watermarked — new uploads
// are watermarked automatically by `generateWatermarkedVideo` above.

// The one-time `backfillVideoThumbnails` admin tool (used once to generate
// thumbnails for videos uploaded before automatic generation existed) has
// been removed now that every existing video has one — new uploads get a
// thumbnail automatically via `generateVideoThumbnail` above.

/**
 * The non-sensitive subset of a user doc that's safe to expose to anyone,
 * including signed-out visitors (profile browsing, follower lists). Never
 * includes phone/email/fcmTokens/role/etc.
 * @param {Object} data
 * @return {Object}
 */
function publicProfileFields(data) {
  return {
    displayName: (data.displayName || "").toString(),
    photoUrl: (data.photoUrl || "").toString(),
    country: (data.country || "").toString(),
  };
}

/**
 * Keeps `public_profiles/{uid}` (readable by anyone, no sensitive fields) in
 * sync with `users/{uid}` (login-required read, has phone/email/etc.), so
 * profile browsing can work signed-out without exposing private data.
 */
exports.syncPublicProfile = onDocumentWritten("users/{uid}", async (event) => {
  const uid = event.params.uid;
  const after = event.data && event.data.after;
  if (!after || !after.exists) {
    await db.collection("public_profiles").doc(uid).delete().catch(() => null);
    return;
  }
  await db
      .collection("public_profiles")
      .doc(uid)
      .set(publicProfileFields(after.data() || {}), {merge: true});
});

// The one-time `backfillPublicProfiles` admin tool (used once to fill
// `public_profiles` for every account that existed before `syncPublicProfile`
// did) has been removed now that every existing account has been synced —
// new/updated accounts are kept in sync automatically by `syncPublicProfile`
// above.

/**
 * One-line preview text for a chat message notification/inbox row.
 * @param {Object} data
 * @return {string}
 */
function chatMessagePreview(data) {
  const type = (data.type || "text").toString();
  if (type === "image") return "📷 Photo";
  if (type === "video") return "🎬 Video";
  if (type === "audio") return "🎤 Voice message";
  return (data.text || "").toString().slice(0, 120);
}

/**
 * Updates the chat's last-message bookkeeping and bumps the recipient's
 * unread count whenever a new message is created, then pushes a
 * notification through the existing `users/{uid}/notifications` pipeline
 * (see `sendUserNotificationPush` above).
 */
exports.onChatMessageCreated = onDocumentCreated(
    "chats/{chatId}/messages/{messageId}",
    async (event) => {
      const data = event.data && event.data.data();
      if (!data) return;
      const chatId = event.params.chatId;
      const senderId = (data.senderId || "").toString();
      if (!senderId) return;

      const chatRef = db.collection("chats").doc(chatId);
      const chatSnap = await chatRef.get();
      const chatData = chatSnap.data() || {};
      const participants = Array.isArray(chatData.participants) ?
        chatData.participants : [];
      const recipientId = participants.find((id) => id !== senderId);
      if (!recipientId) return;

      const preview = chatMessagePreview(data);
      const now = admin.firestore.Timestamp.now();
      await chatRef.set(
          {
            lastMessageText: preview,
            lastMessageType: (data.type || "text").toString(),
            lastMessageAt: now,
            lastSenderId: senderId,
            [`unreadCounts.${recipientId}`]:
              admin.firestore.FieldValue.increment(1),
          },
          {merge: true},
      );

      const senderSnap = await db
          .collection("public_profiles")
          .doc(senderId)
          .get();
      const senderName =
        (senderSnap.data() || {}).displayName || "Someone";

      await db
          .collection("users")
          .doc(recipientId)
          .collection("notifications")
          .add({
            title: senderName,
            message: preview,
            route: `/chat?userId=${senderId}`,
            type: "chat_message",
            chatId,
            senderId,
            createdAt: now,
            read: false,
          });
    },
);

