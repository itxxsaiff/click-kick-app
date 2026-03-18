# Stripe Payment Setup (Sponsorship Application)

## Security first
- Do **not** store `STRIPE_SECRET` in Flutter app code.
- Keep Stripe secret key only in backend (Firebase Functions config / secret manager).
- Since the key was shared in chat, rotate both test keys in Stripe dashboard after setup.

## Current app flow implemented
- Sponsor clicks **Pay with Stripe** on `sponsorship_applications`.
- App calls Firebase callable function: `createSponsorshipCheckoutSession`.
- Function returns Stripe Checkout URL.
- App opens checkout page.
- Webhook updates Firestore payment/application status.

## Required backend pieces

### 1) Firebase callable function
Create function `createSponsorshipCheckoutSession`.

Expected input:
- `applicationId`
- `successUrl`
- `cancelUrl`

Function responsibilities:
- Read application from `sponsorship_applications/{applicationId}`
- Validate not already paid
- Use Stripe secret key to create Checkout Session
- Return `{ url: session.url }`
- Put metadata: `applicationId`, `sponsorId`

### 2) Stripe webhook
Create webhook endpoint in Firebase Functions (example route: `/stripeWebhook`).
Listen for event:
- `checkout.session.completed`

Webhook responsibilities:
- Read metadata `applicationId`, `sponsorId`
- Mark `sponsorship_applications/{applicationId}`:
  - `paymentStatus: paid`
  - `paidAt`
  - `stripeSessionId`
- Create `payments/{id}` record
- Generate invoice using existing app logic/server logic

## Firestore fields used by app
- `sponsorship_applications/{id}`
  - `paymentStatus` (`unpaid` / `paid`)
  - `applicationFee`
  - `invoiceNumber`
  - `invoiceUrl`

## Notes
- Approval is blocked in admin UI unless payment status is `paid`.
- App currently shows fallback error if callable function is not deployed.
