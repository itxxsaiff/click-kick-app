# Firebase Data Model (Video Contest)

## Collections

- `users/{uid}`
  - `uid`: string
  - `email`: string
  - `displayName`: string
  - `role`: `user | participant | sponsor | adminVideo | adminSponsorship | adminFinance | superAdmin`
  - `photoUrl`: string?
  - `region`: string?
  - `createdAt`: timestamp
  - `updatedAt`: timestamp

- `contests/{contestId}`
  - `title`: string
  - `description`: string
  - `region`: string
  - `submissionStart`: timestamp
  - `submissionEnd`: timestamp
  - `votingStart`: timestamp
  - `votingEnd`: timestamp
  - `prizeAmount`: number
  - `status`: `upcoming | submissionOpen | votingOpen | completed`
  - `bannerUrl`: string?
  - `createdAt`: timestamp
  - `updatedAt`: timestamp

- `contests/{contestId}/submissions/{submissionId}`
  - `userId`: string
  - `videoUrl`: string
  - `thumbnailUrl`: string
  - `durationSeconds`: number (30-45)
  - `status`: `pending | approved | rejected`
  - `rejectionReason`: string?
  - `allowReupload`: bool
  - `voteCount`: number
  - `viewCount`: number
  - `createdAt`: timestamp
  - `updatedAt`: timestamp

- `contests/{contestId}/votes/{voteId}`
  - `videoId`: string
  - `voterId`: string
  - `createdAt`: timestamp

- `sponsorCampaigns/{campaignId}`
  - `sponsorId`: string
  - `title`: string
  - `region`: string
  - `startDate`: timestamp
  - `endDate`: timestamp
  - `assetUrl`: string
  - `contestQuestion`: string?
  - `status`: `draft | paid | pendingReview | needsRevision | approved | rejected`
  - `invoiceId`: string?
  - `revisionNotes`: string?
  - `createdAt`: timestamp
  - `updatedAt`: timestamp

- `invoices/{invoiceId}`
  - `payerId`: string
  - `amount`: number
  - `currency`: string
  - `status`: `draft | paid | refunded | disputed`
  - `stripePaymentIntentId`: string?
  - `refundId`: string?
  - `createdAt`: timestamp

- `auditLogs/{logId}`
  - `actorId`: string
  - `action`: string
  - `targetId`: string
  - `metadata`: map
  - `createdAt`: timestamp

## Core Rules (from spec)

- No guest access. Firebase Auth required for all app features.
- New accounts default to `user` role.
- User role auto-upgrades to `participant` on first submission.
- One submission per user per contest.
- Voting: one vote per user per contest; enforce server-side.
- Video duration must be 30–45 seconds; validate client + server.
- Rejection requires a predefined reason; admin can allow one re-upload.
- Sponsor campaign price: USD 1000; payment required before review.

## Required Indexes

- `contests` by `status`, `votingStart`, `region`
- `contests/{contestId}/submissions` by `status`, `voteCount`, `createdAt`
- `sponsorCampaigns` by `status`, `region`, `createdAt`

## Storage Paths

- `videos/{userId}/{contestId}/{submissionId}.mp4`
- `thumbnails/{userId}/{contestId}/{submissionId}.jpg`
- `sponsors/{sponsorId}/{campaignId}/asset.*`
