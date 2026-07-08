const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const Stripe = require("stripe");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();
const DRAW_WINNER_COUNT = 5;
const DRAW_PRIZE_AMOUNT = 10;
const LOGIN_OTP_DIGITS = 6;
const LOGIN_OTP_EXPIRY_MINUTES = 10;
const LOGIN_OTP_RESEND_SECONDS = 60;
const LOGIN_OTP_MAX_ATTEMPTS = 5;

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
 * @return {Promise<void>}
 */
async function cleanupUserPrivateData(targetUid) {
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

  const bucket = admin.storage().bucket();
  const prefixes = [
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
  const voteRef = contestRef.collection("votes").doc(userId);
  const submissionRef = contestRef.collection("submissions").doc(submissionId);

  await db.runTransaction(async (tx) => {
    const [contestSnap, voteSnap, submissionSnap] = await Promise.all([
      tx.get(contestRef),
      tx.get(voteRef),
      tx.get(submissionRef),
    ]);

    if (!contestSnap.exists) {
      throw new HttpsError("not-found", "Contest not found.");
    }
    if (voteSnap.exists) {
      throw new HttpsError("already-exists", "User already voted.");
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
        await runLuckyDrawForContest(contestDoc);
      }
    },
);
