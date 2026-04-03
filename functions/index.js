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

/**
 * Creates Stripe client.
 * @return {Stripe}
 */
function getStripeClient() {
  return new Stripe(process.env.STRIPE_SECRET);
}

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
  const uniqueVoterIds = [...new Set(votesSnap.docs
      .map((doc) => (doc.data().voterId || doc.id || "").toString())
      .filter(Boolean))];

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

  batch.set(contestDoc.ref, {
    drawCompleted: true,
    drawCompletedAt: drawAt,
    drawEligibleVoterCount: uniqueVoterIds.length,
    drawWinnerCount: winnerCount,
    drawPrizeAmount: DRAW_PRIZE_AMOUNT,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  await batch.commit();
}

/**
 * Builds a simple one-page PDF.
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
  const lines = [
    {text: "Click Kick - Sponsorship Invoice", x: 50, y: 790, size: 18},
    {text: `Invoice #: ${invoiceNo}`, x: 50, y: 760, size: 12},
    {text: `Date: ${ymd(invoiceDate)}`, x: 50, y: 742, size: 12},
    {text: `Sponsor: ${sponsorName}`, x: 50, y: 706, size: 12},
    {text: `Email: ${sponsorEmail}`, x: 50, y: 688, size: 12},
    {text: `Company: ${companyName || "-"}`, x: 50, y: 670, size: 12},
    {text: `Application: ${applicationName}`, x: 50, y: 634, size: 12},
    {text: `Region: ${country}`, x: 50, y: 616, size: 12},
    {
      text: "Description: Sponsorship Campaign Fee",
      x: 50,
      y: 580,
      size: 12,
    },
    {
      text: `Amount: $${Number(amount || 0).toFixed(2)}`,
      x: 50,
      y: 562,
      size: 12,
    },
    {
      text: `Total Paid: $${Number(amount || 0).toFixed(2)}`,
      x: 50,
      y: 526,
      size: 14,
    },
    {
      text: "Thank you for your sponsorship payment.",
      x: 50,
      y: 488,
      size: 11,
    },
  ];

  const content = lines
      .map((line) =>
        `BT /F1 ${line.size} Tf ${line.x} ${line.y} Td ` +
        `(${pdfEscape(line.text)}) Tj ET`,
      )
      .join("\n");

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
  const sponsor = sponsorSnap && sponsorSnap.exists ?
    sponsorSnap.data() || {} :
    {};
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
  const filePath = `invoices/${generatedInvoiceNumber}.pdf`;
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

  await appRef.set({
    invoiceNumber: generatedInvoiceNumber,
    invoiceUrl,
    invoiceGeneratedAt: invoiceTimestamp,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  const paymentDocs = await db.collection("payments")
      .where("applicationId", "==", applicationId)
      .where("status", "==", "paid")
      .get();
  const batch = db.batch();
  paymentDocs.docs.forEach((doc) => {
    batch.set(doc.ref, {
      sponsorId: effectiveSponsorId,
      invoiceNumber: generatedInvoiceNumber,
      invoiceUrl,
      invoiceGeneratedAt: invoiceTimestamp,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
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
async function getOrCreateStripeCustomer({uid, email, name, appRef, appData}) {
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
        merchantDisplayName: "Video Contest Show",
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
