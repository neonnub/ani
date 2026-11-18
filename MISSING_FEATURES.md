# MSTP — Missing Features and Production Readiness Gaps

**Audit date:** 12 November 2026  
**Purpose:** Define what is missing, why it matters, what “done” should mean, and in what order to build it.  
**Basis:** Source-verified findings from `FEATURE_INVENTORY.md`, `USER_WORKFLOW.md`, `API_DOCUMENTATION.md`, `DATABASE_DOCUMENTATION.md` and `UI_UX_AUDIT.md`. No application source was modified.

---

## 1. Readiness verdict

MSTP is a **functional local demonstration**, not a production travel product.

What already works:

- a deterministic itinerary planner with real scheduling, scoring and cost logic;
- a destination catalogue with 9 destinations and 66 attractions;
- itinerary review, day editing, activity editing, regeneration, local save, print and JSON export;
- hotel discovery, booking creation, simulated payment and receipt;
- partner registration, login, property CRUD and a bookings dashboard;
- a coherent visual identity and a responsive marketing site.

What prevents public or shared deployment:

| Domain | Current state | Production requirement |
|---|---|---|
| Identity | Browser-local traveller profile; partner password checked but no session | Server-side accounts and sessions for travellers, partners and staff |
| Authorization | Client-supplied `partnerId`; booking lookup by phone | Server-derived identity and ownership checks on every request |
| Booking privacy | Missing/invalid phone can return all bookings | Authenticated history or reference + OTP; no bulk exposure |
| Payments | PIN collected and transmitted; no provider | No PIN handling; hosted/provider flow, callbacks, reconciliation |
| Inventory | One `roomsLeft` counter, no dates | Date-specific room inventory with transactional allocation |
| Booking lifecycle | `PENDING_PAYMENT` and `CONFIRMED` only | Holds with expiry, cancellation, refund, failure and audit states |
| Persistence | Whole-file Java serialization, failures swallowed | Transactional database, atomic writes, backups, restore drills |
| Security | HTTP/JRMP plaintext, open CORS, no headers/rate limits | TLS, security headers, origin allowlist, rate limits, KDF, PII controls |
| Quality | No automated tests, no CI, no Git repository | Unit/integration/e2e tests, CI gates, version control |
| Accessibility | Contrast, focus, tabs, drag and microtype failures | WCAG 2.2 AA baseline and assistive-technology testing |
| Trust | Multiple unsupported claims and published demo credentials | Claims tied to implemented behaviour; legal and support pages |

### Release gate

Do not expose this application beyond a trusted local demo until **all P0 items** are closed. P0 is not a wish list; each item is either a privacy breach, a money/inventory correctness failure, data loss, or a misleading safety claim.

---

## 2. Severity definitions

| Level | Meaning | Release rule |
|---|---|---|
| **P0** | Privacy breach, financial/inventory corruption, data loss, security bypass, or a false safety claim | Blocks any public/shared deployment |
| **P1** | Required for a credible product; major missing journey or accessibility failure | Blocks a paid/public launch |
| **P2** | Growth, polish and differentiation | Can ship after launch |

Effort is indicative person-weeks for one experienced full-stack engineer, including tests and documentation. It excludes design, legal review and third-party onboarding time.

---

## 3. P0 — Stop-the-bleeding gaps

### P0-1. Real authentication and authorization

**Current behaviour**

- Traveller “login” and “sign-up” create a localStorage object. No server call, no password verification, no account record.
- Partner registration and login verify a salted SHA-256 hash, but the returned `Partner` object is the only credential.
- Every partner API trusts a caller-supplied `partnerId`.
- No API uses an `Authorization` header, cookie, token or session.
- Bookings are not linked to any account.

**Why it matters**

Anyone who learns a partner ID can list, create, edit or delete that partner’s properties and read their guest bookings. Traveller accounts provide no ownership, recovery or security. The UI implies an account system that does not exist.

**Required behaviour**

- Server-side `accounts` table with traveller, partner and admin roles.
- Password hashing with Argon2id, bcrypt or scrypt (not single-round SHA-256).
- Opaque session tokens stored hashed, delivered in `HttpOnly`, `Secure`, `SameSite` cookies.
- Session expiry, rotation on privilege change, revocation on logout and password change.
- CSRF protection for state-changing requests.
- Authorization derived only from the session, never from a request body or query parameter.
- Ownership checks for saved trips, bookings, partner properties and payouts.
- Email or phone verification before account activation.

**Acceptance criteria**

- [ ] Unauthenticated requests to protected routes return 401.
- [ ] A partner cannot read or mutate another partner’s property or bookings (403).
- [ ] A traveller cannot read another traveller’s bookings or saved trips.
- [ ] Logout invalidates the server session, not just localStorage.
- [ ] Sessions expire and can be revoked.
- [ ] CSRF tokens are required and validated on writes.
- [ ] Password reset uses a single-use, expiring token.
- [ ] Authorization tests cover every route and role.

**Depends on:** database, account model, email/SMS provider.  
**Estimate:** 4–6 weeks.

---

### P0-2. Private booking lookup

**Current behaviour**

- `GET /api/bookings?phone=...` requires no authentication.
- If `phone` is absent or invalid, the service returns **all** bookings.
- The response includes guest name, phone, hotel, dates and amounts.
- There is no OTP, booking reference, rate limit or audit trail.

**Why it matters**

This is a direct PII breach and an enumeration oracle. A phone number is not a secret. The endpoint cannot be exposed to the public internet in its current form.

**Required behaviour**

Choose one primary model:

1. **Authenticated history:** a signed-in traveller sees only bookings linked to their account.
2. **Guest lookup:** booking reference + one-time code sent to the booking phone/email, with rate limits and short-lived proof.

Additional requirements:

- Never return a collection for an empty or invalid identifier.
- Return 400 for a missing identifier, 404 for no match.
- Mask phone/email in responses unless ownership is proven.
- Rate-limit by IP, phone and account.
- Log every lookup with actor, purpose and result count.
- Expire guest access tokens quickly and bind them to the booking.

**Acceptance criteria**

- [ ] Empty or invalid query returns 400, never a list.
- [ ] Unknown reference returns 404 with no existence leak.
- [ ] Correct reference + OTP returns only that booking.
- [ ] Brute-force attempts are rate-limited and alerted.
- [ ] Lookup is audited.
- [ ] Automated tests prove no cross-account access.

**Estimate:** 1–2 weeks after P0-1.

---

### P0-3. Remove PIN collection and make payment simulation honest

**Current behaviour**

- The payment form asks for a 4–6 digit wallet PIN.
- The PIN is posted to the gateway, passed over RMI and validated by the service.
- A hard-coded demo PIN value triggers a decline; other valid-format PINs succeed.
- The About page claims no PIN is transmitted.
- HTTP 402 is converted into a generic exception, so the decline reason is lost.
- No wallet provider is contacted; no money moves.

**Why it matters**

Asking users to type a wallet PIN into a demo trains unsafe behaviour, creates a real secret-handling obligation, and contradicts the product’s own safety claim. The current decline path is also broken from the user’s perspective.

**Required behaviour**

- Remove the PIN field, the `pin` API parameter and all PIN handling.
- Replace it with one of:
  - an explicit “Simulate successful payment” / “Simulate decline” demo control; or
  - a real provider-hosted checkout with signed callbacks and no card/wallet secrets in this application.
- Make the decline reason a first-class response that the frontend displays.
- Add idempotency keys to payment initiation.
- Store provider references, status and raw callback metadata.
- Never log PINs, tokens or full wallet identifiers.

**Acceptance criteria**

- [ ] No PIN is collected, transmitted, stored or logged anywhere.
- [ ] The demo flow clearly labels itself as a simulation before the user acts.
- [ ] A decline displays the specific reason returned by the server.
- [ ] Repeated submit cannot double-charge or double-confirm.
- [ ] Confirmation only follows a validated provider callback (real mode) or an explicit demo action.
- [ ] Tests cover success, decline, retry, duplicate and out-of-order callbacks.

**Estimate:** 1 week for the demo-safe fix; 3–5 weeks for a real provider.

---

### P0-4. Complete booking lifecycle

**Current behaviour**

- Only `PENDING_PAYMENT` and `CONFIRMED` exist.
- Creating a booking decrements `roomsLeft` immediately.
- Holds never expire.
- There is no cancellation, release, refund, failure or expiry state.
- The booking modal claims a 48-hour demo cancellation policy.
- A pending booking can be paid by anyone who obtains its ID and supplies a valid-format phone and PIN.
- Duplicate booking submissions create duplicates.

**Why it matters**

Inventory leaks permanently, guests cannot cancel, partners cannot recover rooms, and the UI promises a policy that does not exist. This is both a correctness and a consumer-protection problem.

**Required behaviour**

States: `pending`, `confirmed`, `cancelled`, `expired`, `refunded`, `failed`.

- `hold_expires_at` on pending bookings.
- A scheduled job or lazy sweep releases expired holds and restores inventory.
- Cancellation policy by rate/hotel, with a clear cutoff and fee calculation.
- Refund records linked to payments, with provider status.
- Idempotency keys on create, cancel and refund.
- Booking modification rules (dates, rooms, guest) or an explicit “cancel and rebook” policy.
- Guest-visible countdown for holds.
- Partner/admin cancellation with reason and audit.
- No payment without proving control of the booking.

**Acceptance criteria**

- [ ] A pending hold expires at the stated time and inventory is restored exactly once.
- [ ] Cancelling a confirmed booking restores inventory and creates a refund when eligible.
- [ ] Double cancel, double refund and late callbacks are idempotent.
- [ ] A booking cannot be paid after expiry or cancellation.
- [ ] The UI shows hold expiry, cancellation terms and refund status.
- [ ] The 48-hour claim is removed or implemented.
- [ ] Tests cover expiry, cancellation, refund, race conditions and replay.

**Estimate:** 3–4 weeks.

---

### P0-5. Date-specific, transactional inventory

**Current behaviour**

- Each hotel has one `roomsLeft` integer.
- A January booking reduces December availability.
- Partner edits reset `roomsTotal` and `roomsLeft`, ignoring active bookings.
- Deleting a property leaves bookings orphaned.
- Base hotel availability is recomputed on restart from seeded totals minus all persisted bookings.
- There are no room types, occupancy limits, seasonal rates or blackout dates.

**Why it matters**

The product can oversell or falsely show sold-out dates. A travel booking engine without date-level inventory is not a booking engine.

**Required behaviour**

- `room_types` per hotel with name, occupancy and base price.
- `room_inventory` per room type per stay date with `rooms_total`, `rooms_held`, `rooms_sold`.
- Transactional allocation: lock the date rows, validate every night, insert the booking and night rows, commit.
- Availability API that accepts check-in, check-out, rooms and guests.
- Explicit sold-out and partial-availability responses.
- Editing a hotel must not erase sold/held counts.
- Deleting a hotel must be blocked while active bookings exist, or must archive it with a tombstone and preserve booking history.
- Rate plans for seasonal pricing, minimum stay and cancellation policy.

**Acceptance criteria**

- [ ] Availability is calculated per date, not per hotel lifetime.
- [ ] Concurrent requests cannot oversell the same room-night.
- [ ] A multi-night booking fails atomically if any night is unavailable.
- [ ] Partner edits preserve existing holds and sales.
- [ ] Deleting a property with active bookings is blocked or archived safely.
- [ ] Inventory reconciliation report matches bookings and holds.
- [ ] Tests include concurrent booking, sold-out, partial availability and edit/delete.

**Estimate:** 4–6 weeks.

---

### P0-6. Durable, recoverable persistence

**Current behaviour**

- `data/bookings.ser` and `data/partners.ser` are whole-file Java serialization writes.
- Writes open the target file directly; no temp file, fsync, rename or checksum.
- Every write exception is caught and printed; the API still reports success.
- No backup, restore, migration, integrity check, retention or encryption.
- A crash or disk-full condition can corrupt all bookings or partner data.
- Demo partner hotels are reseeded after deletion on restart.

**Why it matters**

A single failed write can destroy the only copy of every booking. Silent failure is worse than an error because the user is told the operation succeeded.

**Required behaviour**

Minimum interim (if a database is not yet available):

- write to a temp file in the same directory;
- flush and fsync;
- atomically rename over the target;
- keep one previous version;
- verify deserialization after write;
- return 5xx on failure;
- scheduled backups with restore tests;
- quarantine corrupt files instead of overwriting them.

Target:

- PostgreSQL (or equivalent) with transactions, constraints, indexes and migrations.
- Point-in-time recovery and encrypted backups.
- A documented restore runbook and periodic drills.
- A migration path from `.ser` files that preserves IDs and history.

**Acceptance criteria**

- [ ] Killing the process during a write leaves the previous valid state.
- [ ] A write failure is visible to the caller and does not report success.
- [ ] Corrupt data is detected and quarantined on startup.
- [ ] A restore from backup is tested and documented.
- [ ] Schema changes are versioned and reversible.
- [ ] Bookings and inventory cannot diverge after a crash.

**Estimate:** 1–2 weeks for atomic interim; 4–6 weeks for the database migration.

---

### P0-7. Correctness defects that must be fixed now

These are small, high-impact bugs that do not require a redesign.

| # | Defect | Current effect | Required fix | Acceptance |
|---|---|---|---|---|
| 1 | HTTP 402 treated as a generic error | Payment decline reason becomes “Request failed (402)” | Read the `PaymentResult` body on 402 and show its message | Decline reason visible and tested |
| 2 | Itinerary nights mismatch | Summary shows `days − 1`; booking pre-fills day allocation | Use one nights calculation everywhere; derive booking nights from stay dates | A 3-day trip consistently shows 2 nights |
| 3 | Partner edit resets inventory | `roomsTotal`/`roomsLeft` overwritten with submitted room count | Preserve sold/held counts; only adjust total with validation | Editing does not make sold rooms available |
| 4 | Property deletion orphans bookings | Bookings remain but disappear from partner view | Block deletion with active bookings or archive with tombstone | Orphan count is zero; history remains visible |
| 5 | Saved trips silently capped at eight | Ninth save is discarded without warning | Warn, paginate, or remove the cap | User is told before data is lost |
| 6 | Demo partner hotels reseed | Deleting all demo properties recreates them on restart | Seed only on a truly empty first run; record a seed marker | Deleted demo data stays deleted |
| 7 | 24-bit booking/partner IDs | Collision probability rises with volume | Use UUIDv7/ULID and uniqueness checks | No overwrite on collision |
| 8 | Price slider cannot reach partner rates above 350,000 | Expensive listings hidden except at “Any” | Derive slider max from data or add a numeric max field | All published hotels are reachable |
| 9 | Duplicate DOM IDs | `saveTrip`/`printTrip` appear twice | Use one instance or unique IDs with shared handlers | Valid HTML and unambiguous labels |
| 10 | Hidden mobile actions | Export/Regenerate vanish at ≤900 px | Keep all actions reachable at every breakpoint | All actions present on mobile |
| 11 | No date-specific availability | One counter for all dates | Covered by P0-5 | — |
| 12 | No confirmation/undo on destructive edits | Accidental loss of itinerary work | Confirm or undo for regenerate/remove | Tests cover cancel path |

**Estimate:** 1–2 weeks for items 1–10 and 12.

---

### P0-8. Security baseline

**Current behaviour**

- Plain HTTP and plain JRMP; no TLS.
- `Access-Control-Allow-Origin: *` on every JSON response.
- No `OPTIONS` preflight handling.
- No CSP, HSTS, `X-Content-Type-Options`, frame protection, referrer policy or permissions policy.
- No rate limiting, lockout or abuse detection.
- Request bodies truncated at 200 KB rather than rejected.
- Partner login reveals whether an email exists.
- Password hashing is single-round salted SHA-256.
- PII and password hashes are unencrypted at rest.
- No audit log, request ID or security monitoring.
- Demo credentials are published in the UI.

**Required behaviour**

- TLS everywhere, including RMI or a replacement RPC layer.
- Strict origin allowlist and correct preflight handling.
- CSP, HSTS, nosniff, frame-ancestors, referrer and permissions policies.
- Rate limits per IP, account and route; exponential backoff and lockout.
- 413 for oversized bodies, with a documented limit.
- Argon2id/bcrypt/scrypt with per-user salt and appropriate work factor.
- Encrypt backups and PII at rest; minimize what is stored.
- Generic authentication errors to prevent account enumeration.
- Structured audit events for login, lookup, booking, payment, refund, partner changes and admin access.
- Secrets in a secret manager, never in source or logs.
- Remove published demo credentials.

**Acceptance criteria**

- [ ] An external TLS scan reports no plaintext endpoints.
- [ ] Security headers are present on every response.
- [ ] Cross-origin writes from unapproved origins fail.
- [ ] Login and lookup are rate-limited and lock out after repeated failures.
- [ ] Oversized bodies return 413.
- [ ] Password hashes use a memory-hard KDF.
- [ ] Audit events exist for every sensitive action.
- [ ] No secret or demo credential is present in the repository or UI.

**Estimate:** 2–4 weeks, excluding organizational policy work.

---

### P0-9. Automated tests for critical paths

**Current behaviour**

- No `tests/` directory.
- No test framework, fixtures, mocks or CI.
- Core logic has no regression protection.

**Why it matters**

Every P0 fix above can regress silently. Booking, inventory, payment and authorization are exactly the areas where manual testing is least reliable.

**Required coverage**

- **Unit:** itinerary scoring/scheduling, cost calculation, phone normalization, date arithmetic, password hashing, inventory allocation.
- **Integration:** API routes, validation, status codes, authorization, persistence, concurrency.
- **End-to-end:** plan → edit → save → book → pay → lookup; partner register → add property → edit → delete; decline and retry.
- **Regression:** the 12 defects in P0-7.
- **Security:** cross-account access, unauthenticated access, rate limits, oversized bodies, invalid JSON.
- **Accessibility:** automated axe checks plus manual keyboard/screen-reader scripts.

**Acceptance criteria**

- [ ] CI runs on every change and blocks merge on failure.
- [ ] Critical modules have meaningful coverage, not just line coverage.
- [ ] Tests run against an isolated database and deterministic fixtures.
- [ ] Concurrency and failure-injection tests exist for inventory and persistence.
- [ ] A release cannot be produced without a green test run.

**Estimate:** 2–3 weeks to establish; ongoing.

---

### P0-10. Remove false claims and unsafe demo content

**Current behaviour**

Unsupported claims include “AI”, “Trusted & Secure”, “24/7 Support”, “live availability”, “no PIN is transmitted”, a 48-hour cancellation policy, and “Book This Trip” (which only opens Hotels). Demo partner credentials are displayed, and credential-like values appear as placeholders.

**Required behaviour**

- Rewrite marketing copy to describe what is actually implemented.
- Replace “AI” with “automated itinerary planner” unless a real model is added.
- Remove security/support claims or implement them.
- Remove the 48-hour policy until cancellation exists.
- Remove the “no PIN” claim by removing the PIN.
- Remove published credentials; provide a labelled demo entry action instead.
- Add a persistent “Demo” badge where simulated payments or data appear.
- Add privacy, terms, cancellation and contact pages before collecting real PII.

**Acceptance criteria**

- [ ] Every claim maps to a tested feature or is removed.
- [ ] No demo credentials are displayed or committed.
- [ ] Legal and contact pages exist.
- [ ] The demo boundary is clear before any payment or personal data entry.

**Estimate:** 1 week plus legal review.

---

## 4. P1 — Required for a credible product

### 4.1 Traveller account completeness

| Missing capability | Why | Acceptance |
|---|---|---|
| Profile view/edit | Users cannot correct name, phone or email | Changes persist server-side and are audited |
| Booking history | Lookup by phone is the only path | Signed-in users see all their bookings |
| Saved trips in account | Browser-local only; lost on device change | Saved trips sync across devices |
| Password change/reset | No recovery path | Verified reset flow with expiring token |
| Account deletion | Privacy requirement | Deletion removes or anonymizes PII with confirmation |
| Data export | User rights | Download bookings, trips and profile as JSON/CSV |
| Session management | No visibility/control | List and revoke active sessions |
| Email/phone verification | No proof of contact | Verification before booking or account activation |

### 4.2 Partner account completeness

| Missing capability | Why | Acceptance |
|---|---|---|
| Server session | Dashboard trusts localStorage | Session-derived identity, expiry and revocation |
| Password reset | Locked-out partners cannot recover | Verified reset flow |
| Email verification | Anyone can register any email | Verification before publishing |
| MFA | High-value account | TOTP or passkey option |
| Team members | One login per business | Invite roles with least privilege |
| Payout statements | “Demo value” only | Commission, statement, settlement status |
| Booking actions | No accept/decline/check-in | Status transitions with audit |
| Guest messaging | No contact path | Templated, privacy-conscious messaging |
| Property media | No image upload | Validated uploads, moderation, CDN |
| Room types/rates | One price/room type | Multiple room types, occupancy, seasonal rates |
| Policies | No cancellation/check-in rules | Per-rate policy with display before booking |

### 4.3 Admin and support console

Missing entirely. Required:

- search accounts, bookings, partners and hotels;
- view and amend bookings with reason codes;
- cancel, refund and release inventory;
- suspend partners and unpublish hotels;
- moderate reviews and content;
- inspect audit events and failed jobs;
- issue customer support replies;
- role-based access and full audit logging.

**Acceptance:** an authorized support agent can resolve a failed payment, a duplicate booking and a partner inventory error without touching the database.

### 4.4 Notifications

Missing: no email, SMS, push or in-app inbox.

Required events:

- booking created / hold expiring / confirmed / cancelled / refunded;
- payment success / failure;
- partner new booking / cancellation;
- password reset and email verification;
- itinerary share (optional).

Requirements:

- templated messages;
- outbox with retries and dead-letter handling;
- provider delivery status;
- unsubscribe/preferences where applicable;
- no PII in logs.

### 4.5 Real payment integration

Missing: no provider, callback, signature verification, settlement or reconciliation.

Required:

- provider-hosted or SDK checkout with no raw wallet credentials in this app;
- signed webhook verification;
- idempotent payment intents;
- capture/void/refund;
- reconciliation job against provider statements;
- dispute/chargeback handling;
- sandbox and production credentials separated.

**Acceptance:** a payment can be initiated, confirmed by callback, refunded and reconciled without manual database edits.

### 4.6 Hotel detail and room selection

Missing: no hotel page, gallery, map, policies, room types, occupancy or reviews.

Required:

- hotel detail route with stable URL;
- gallery and image credits;
- map and nearby attractions;
- room types with occupancy, bed configuration, amenities and rates;
- policies: check-in/out, cancellation, children, pets, smoking;
- availability calendar;
- verified-stay reviews;
- clear total price including taxes/fees.

### 4.7 Itinerary persistence, sharing and history

Missing:

- server-side saved trips;
- shareable read-only links;
- autosave and draft restore (functions exist but are dead);
- undo/redo;
- version history;
- duplicate trip;
- PDF export;
- email delivery.

Required:

- autosave the working draft per account;
- explicit versions on regeneration;
- restore previous version;
- share link with access control and expiry;
- PDF with consistent branding and print layout;
- email/print share.

### 4.8 URL routing and deep links

Missing entirely. Required:

- routes for Home, Destinations, Destination detail, Itinerary, Itinerary tab, Hotels, Hotel detail, Bookings, Guide, Partner, About;
- browser Back/Forward support;
- refresh restores the current view and tab;
- shareable filtered hotel/destination URLs;
- not-found route.

### 4.9 Weather and road routing — implement or remove

Current state:

- gateway proxies exist for `/api/engine/weather` and `/api/route-plan`;
- frontend never calls them;
- weather always says unavailable;
- maps use straight lines and fixed-speed Haversine estimates.

Decision required:

- **Implement:** fetch weather for each destination/date, show provenance and freshness, handle failure honestly; call the route-plan service for real road geometry and travel times; cache and rate-limit.
- **Remove:** delete the dormant proxies, weather chips and route claims; present the map as a schematic only.

Do not leave a permanent “unavailable” state that looks like an outage.

### 4.10 Accessibility remediation (WCAG 2.2 AA)

Required:

- contrast fixes for muted and gold text;
- minimum 12 px functional text, 14 px body;
- skip link;
- modal focus entry, trap, inert background and restore;
- correct tab ARIA and arrow-key navigation;
- announced toasts and errors;
- error-to-field associations and focus management;
- keyboard/touch alternative for activity reordering;
- visible focus on every control;
- target sizes at least 44×44 px where practical;
- 200% zoom and 360 px reflow;
- `lang="my"` for Myanmar script;
- reduced-motion and high-contrast checks;
- screen-reader test scripts for the main journeys.

### 4.11 CSS and dead-code cleanup

Required:

- remove or ship the orphan redesign (`planner-studio.css`, `_studio_block.js`, `_itinerary_block.js`);
- eliminate the two-studio cascade;
- remove dead wizard functions and event branches;
- remove `map.css` or load it intentionally;
- consolidate breakpoints;
- minify and bundle CSS/JS;
- delete unused persistence functions or wire them;
- add a small CSS architecture note and naming convention.

### 4.12 Observability and operations

Missing:

- structured logs with request IDs and actor IDs;
- metrics (latency, error rate, booking conversion, payment failure, inventory conflicts);
- tracing across HTTP → RMI → database;
- error monitoring/alerting;
- health/readiness split that probes RMI, database, disk and external services;
- graceful shutdown and in-flight request draining;
- dashboards for bookings, payments, partner activity and lookup abuse;
- on-call runbook.

### 4.13 Performance

Required:

- JS ≤ 200 KB gzip, CSS ≤ 80 KB gzip on first load;
- LCP ≤ 2.5 s on a mid-range phone over 4G;
- CLS ≤ 0.1;
- responsive images and explicit dimensions;
- lazy-load Leaflet and below-the-fold views;
- gateway compression and immutable caching;
- performance budgets enforced in CI.

### 4.14 Content and legal

Missing:

- privacy policy and cookie notice;
- terms of service;
- cancellation/refund policy;
- accessibility statement;
- contact/support page;
- company information;
- content last-reviewed dates and sources;
- image credits and licensing;
- Myanmar-language content;
- content management workflow.

---

## 5. P2 — Growth and polish

| Capability | Why it matters | Notes |
|---|---|---|
| Reviews and verified-stay badges | Trust and conversion | Requires completed-booking linkage and moderation |
| Favourites/wishlist | Return visits and personalization | Destinations, hotels and trips |
| Recommendation explanations | Users distrust unexplained “AI” | “Because you chose temples and a relaxed pace” |
| Loyalty/referrals | Acquisition and retention | Requires accounts and fraud controls |
| Live FX with provider | Multi-currency credibility | Current rates are fixed placeholders |
| Multi-language UI | Myanmar travellers and international visitors | Start with English + Burmese |
| PWA/offline planning | Travel use case with poor connectivity | Cache catalogue and saved trips |
| PDF itinerary and email delivery | Share and print quality | Server-side renderer |
| Supplier/content integrations | Fresh hotels, prices and availability | Contract and reconciliation work |
| Analytics and funnels | Product learning | Consent-first, privacy-preserving |
| A/B testing and feature flags | Safe iteration | Requires stable identity and metrics |
| SEO/SSR or prerender | Acquisition | SPA currently has one URL and no metadata |
| Native apps | Retention | Only after API and auth stabilize |
| Support chat with human escalation | The current “assistant” is static | Ticketing integration |
| Sustainability/community content | Brand differentiation | Editorial workflow needed |

---

## 6. Engineering gaps

### 6.1 Repository and delivery

| Gap | Current state | Required |
|---|---|---|
| Version control | No Git repository detected | Git with protected main, review and tagged releases |
| CI/CD | None | Build, test, security scan, accessibility scan, deploy |
| Environments | Local only | dev, staging, production with isolated data |
| Configuration | Hard-coded defaults; two engine env vars | Validated config with schema and secret injection |
| Dependency management | Plain `javac`, manual Leaflet/fonts | Locked dependencies, vulnerability scanning |
| Build reproducibility | No build metadata | Version stamp, artifact checksum |
| Migrations | None | Versioned forward/backward migrations |
| Feature flags | None | Safe rollout and kill switches |
| API docs | None in repo | OpenAPI generated from code and tested |
| API versioning | Unversioned routes | `/api/v1` and a deprecation policy |

### 6.2 Reliability

| Gap | Impact | Required |
|---|---|---|
| No graceful shutdown | In-flight requests can fail on restart | Drain connections and close resources |
| Static health check | Reports UP even when RMI/disk are broken | Liveness + readiness with dependency probes |
| No backup/restore | Data loss is unrecoverable | Automated encrypted backups and drills |
| No integrity checks | Corruption can go unnoticed | Checksums, reconciliation jobs, alerts |
| No dead-letter queue | Failed notifications/payments vanish | Retry with backoff and DLQ |
| No idempotency | Duplicate bookings/payments | Keys on all mutating endpoints |
| No optimistic concurrency | Lost updates | Version fields/ETags for edits |

### 6.3 Security operations

| Gap | Required |
|---|---|
| No WAF/rate limiting | Edge and application limits |
| No secret management | Vault/cloud secret manager, rotation |
| No vulnerability management | Dependency and container scanning |
| No audit trail | Immutable events for sensitive actions |
| No incident response | Runbook, contacts, breach notification process |
| No data retention policy | Defined periods, legal hold, deletion |
| No access review | Periodic review of admin/partner access |

### 6.4 Quality

| Gap | Required |
|---|---|
| No unit tests | Core logic coverage |
| No integration tests | API + DB + auth coverage |
| No E2E tests | Critical journeys |
| No visual regression | Screenshot diffs for key pages |
| No accessibility tests | axe + manual scripts |
| No performance tests | Load and soak tests for booking/payment |
| No browser/device matrix | Documented support policy and testing |
| No test data strategy | Deterministic fixtures and anonymized data |

---

## 7. Missing states and edge cases

The current UI does not represent these states. Each needs a design, copy, API behaviour and test.

| State | Current behaviour | Required |
|---|---|---|
| Sold out | Generic “not enough rooms” at submit | Explicit sold-out state before form submit |
| Hold expiring | No indication | Countdown and expiry warning |
| Hold expired | Booking remains pending forever | Terminal expired state, inventory released, rebook CTA |
| Payment pending | No persistent indicator | Pending banner and status polling |
| Payment failed | Generic 402 | Specific reason, retry and change-method paths |
| Refund pending/complete | No state | Status timeline and notification |
| Cancelled | No state | Cancellation summary, fee and refund status |
| Session expired | Dashboard silently resets | Re-auth prompt that preserves the current action |
| Rate limited | No state | 429 message with retry-after |
| Duplicate submit | Creates duplicates | Idempotent response and “already submitted” state |
| Concurrent edit | Last write wins silently | Conflict warning and merge/refresh |
| Offline | Nothing works; no message | Offline banner and cached read-only data |
| Server unavailable | Toast disappears | Persistent status banner with retry |
| Partial failure | Save may silently fail | Explicit success/failure per item |
| Currency mismatch | Display currency converts input only | Clear MMK settlement and rate disclosure |
| Past date | Native input + server error | Prevent selection and explain |
| Invalid phone | Error after submit | Inline format hint and mask |
| Timezone ambiguity | Local timestamps without zone | Store UTC, display with zone |
| Duplicate booking reference | 24-bit collision unchecked | Unique constraint and retry |
| Orphaned hotel | Booking points to deleted hotel | Tombstone/archived hotel display |
| Deleted partner | Properties and bookings orphaned | Cascade/archive policy |
| Corrupt local data | Empty state | Detect, explain and offer reset/export |

---

## 8. Feature acceptance criteria by journey

### 8.1 Traveller: plan and save

- [ ] A traveller can plan a trip without an account.
- [ ] Signing in attaches the draft to the account.
- [ ] The draft autosaves and survives refresh and device change.
- [ ] The traveller can undo/redo edits and restore a previous version.
- [ ] A shared link opens a read-only itinerary with correct permissions.
- [ ] PDF and email export produce the same content as the screen.

### 8.2 Traveller: book and pay

- [ ] Search shows date-specific availability.
- [ ] The total includes taxes/fees and matches the confirmation.
- [ ] The hold has a visible expiry and can be released.
- [ ] Payment never collects a PIN in this application.
- [ ] Decline, retry and change-method paths are clear.
- [ ] Confirmation arrives by email/SMS and appears in account history.
- [ ] Cancellation shows the policy, fee and refund status.
- [ ] No duplicate booking or charge is possible on retry.

### 8.3 Partner: manage a property

- [ ] Partner signs in with a verified account and server session.
- [ ] Partner can add/edit room types, rates, media and policies.
- [ ] Inventory is date-specific and preserved across edits.
- [ ] Deleting a property with active bookings is blocked or archived.
- [ ] New bookings appear with guest contact, status and payout value.
- [ ] Partner can accept/decline or apply automatic confirmation rules.
- [ ] Statements show gross, commission, refunds and net payable.
- [ ] Staff roles have least-privilege access.

### 8.4 Support: resolve a problem

- [ ] Agent can find a booking by reference, phone or account.
- [ ] Agent can see payment, refund and inventory history.
- [ ] Agent can cancel/refund with a reason code.
- [ ] Every action is audited with actor and timestamp.
- [ ] Agent cannot see full wallet credentials or password hashes.

---

## 9. Phased roadmap

### Phase 0 — Stop the harm (1–2 weeks)

1. Remove the PIN field and API parameter.
2. Fix the 402 decline message.
3. Fix the itinerary/booking nights mismatch.
4. Block bulk booking lookup; require a reference or authenticated account.
5. Add confirmation/undo for destructive itinerary actions.
6. Add draft autosave.
7. Fix partner edit inventory reset and orphaned bookings.
8. Remove published demo credentials and false claims.
9. Fix duplicate DOM IDs and hidden mobile actions.
10. Add regression tests for all of the above.

**Exit gate:** no PII breach, no PIN handling, no silent data loss on refresh, decline reason visible.

### Phase 1 — Make it safe and durable (3–5 weeks)

1. Accounts, sessions and authorization for travellers and partners.
2. Argon2id hashing, CSRF, rate limits, security headers and TLS.
3. Atomic persistence, backups and restore drills.
4. Date-specific inventory with transactional allocation.
5. Booking lifecycle: hold expiry, cancel, refund and idempotency.
6. Admin/support console (minimum viable).
7. CI, test suite and environment separation.

**Exit gate:** a security review and a restore drill pass; concurrent booking cannot oversell.

### Phase 2 — Make it a product (4–6 weeks)

1. Real payment provider with callbacks and reconciliation.
2. Email/SMS notifications and outbox.
3. Hotel detail pages, room types and policies.
4. Traveller booking history, profile and data export.
5. Partner room/rate management and payout statements.
6. URL routing, share links, PDF and version history.
7. WCAG 2.2 AA remediation.

**Exit gate:** a traveller can complete and manage a real booking end to end; a partner can operate without database access.

### Phase 3 — Scale and differentiate (ongoing)

1. Reviews, favourites and recommendation explanations.
2. Myanmar-language UI and content.
3. PWA/offline planning.
4. Analytics, experimentation and funnel measurement.
5. Supplier/content integrations.
6. Loyalty, referrals and partnerships.
7. Multi-region deployment, DR and cost optimization.

---

## 10. Definition of done for any new feature

A feature is not done until:

- [ ] The user journey is documented, including failure paths.
- [ ] Server-side authorization is enforced, not assumed.
- [ ] Input is validated on both client and server.
- [ ] Errors are specific, announced and associated with the field.
- [ ] Loading, empty, error and offline states exist.
- [ ] Destructive actions are confirmed or reversible.
- [ ] Data changes are transactional and audited.
- [ ] Unit, integration and E2E tests cover the happy and failure paths.
- [ ] Accessibility is verified with keyboard and screen reader.
- [ ] Analytics events are defined with consent.
- [ ] Documentation and API schema are updated.
- [ ] Rollback and monitoring are in place.

---

## 11. Traceability matrix

| Gap | Evidence |
|---|---|
| Traveller auth is local only | `web/app.js` `openAuth`, `submitAuth`; no API call |
| Partner authz trusts `partnerId` | `WebMain` partner handlers; `TripServiceImpl` partner methods |
| Bulk booking exposure | `TripServiceImpl.getBookings`; `GET /api/bookings` |
| PIN transmission | `web/app.js` `submitPayment`; `TripServiceImpl.pay` |
| 402 handling | `web/app.js` `api()` throws before reading `PaymentResult` |
| Nights mismatch | Itinerary summary vs booking prefill in `web/app.js` |
| Inventory counter | `Hotel.roomsLeft`; `TripServiceImpl.createBooking` |
| Partner edit reset | `savePartnerHotel` sets `roomsTotal`/`roomsLeft` |
| Orphan bookings | `deletePartnerHotel` removes hotel without booking handling |
| Siloed persistence | `TripServiceImpl.loadBookings/saveBookings/loadPartners/savePartners` |
| Silent write failure | Caught exceptions in save methods |
| Demo reseed | `seedDemoPartner()` on startup |
| Saved-trip cap | `persistSaved()` slices to eight |
| Dead wizard | `renderWizard` etc.; no `#wizardPanel` |
| Weather/routing dormant | Gateway handlers; no frontend call |
| Dead redesign | `planner-studio.css`; `_studio_block.js`; `_itinerary_block.js` |
| CSS conflict | `studio.css` vs `planner-studio.css`; 14 overlapping classes |
| Accessibility failures | `UI_UX_AUDIT.md` §9 |
| Print all panels | `style.css` print block line 1313 |
| Mobile hidden actions | `field-guide.css` `@media(max-width:900px){.it-actions{display:none}}` |
| No tests/CI | Repository inspection: no `tests/`, no pipeline |
| No database | `.ser` files; `DATABASE_DOCUMENTATION.md` |

---

## 12. Closing assessment

The fastest path to a responsible product is not a rewrite. It is a sequence of narrow, testable fixes:

1. **Remove the PIN and the bulk booking lookup.** These are the two changes most likely to cause real harm.
2. **Save the user’s work.** Autosave and undo protect the core planning value.
3. **Make inventory and holds real.** Without date-level inventory, the booking flow is a facade.
4. **Put identity on the server.** Partner and traveller accounts must be sessions, not localStorage objects.
5. **Make failures visible.** A user must never be told “saved” when the write failed.

The existing planner, catalogue and visual design are worth keeping. The missing layer is the unglamorous product infrastructure — identity, inventory, money, recovery, accessibility and operations — that turns a convincing demo into a service people can trust with their trips and their data.
