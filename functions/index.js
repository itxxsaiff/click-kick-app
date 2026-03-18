const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const Stripe = require("stripe");

admin.initializeApp();
const db = admin.firestore();

/**
 * Creates Stripe client.
 * @return {Stripe}
 */
function getStripeClient() {
  return new Stripe(process.env.STRIPE_SECRET);
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
