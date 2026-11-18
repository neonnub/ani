# MSTP — Complete Project Analysis

**Project:** Myanmar Smart Travel Planner (MSTP)  
**Audit date:** 12 November 2026  
**Audit type:** Read-only architecture, feature, data, API and UX assessment  
**Repository root:** `MyanmarTripPlanner`

---

## 1. Executive verdict

MSTP is a **functional local demonstration application**, not a production travel platform.

The strongest end-to-end path is real and source-verified:

1. The browser loads nine destinations and the hotel catalogue from a Java gateway.
2. A traveller builds a route and preferences in a one-page planner.
3. A deterministic Java engine scores attractions, schedules days, estimates costs and returns a structured itinerary.
4. The browser renders a five-tab itinerary with itinerary editing, local saving, printing, JSON export and hotel links.
5. A hotel can be booked, rooms are decremented in memory, and a clearly labelled simulated wallet payment changes the booking from pending to confirmed.
6. Hotel owners can register or sign in, publish properties, edit or delete them, and see bookings for their rooms.

However, the application is **not safe or complete enough for public deployment**. The most serious gaps are:

- bookings can be retrieved by phone number without authentication;
- any caller who knows a partner ID can read or modify that partner's properties and bookings;
- "login" for travellers is a browser-local profile with no password verification or server account;
- the wallet PIN is transmitted to the gateway and RMI server even though the UI says it is not transmitted;
- room holds never expire and there is no cancellation, release or refund flow;
- availability is a single rooms-left counter, not date-specific inventory;
- persistence is non-transactional Java serialization with silent write failures;
- the weather and road-routing gateway endpoints exist but are not used by the UI;
- the UI contains dead wizard code, orphaned redesign files and two overlapping CSS systems;
- there is no automated test suite, no database, no admin surface, no notification system and no production observability.

**Readiness summary**

| Dimension | Assessment |
|---|---|
| Local demo completeness | High |
| Visual polish | Medium-high, with responsive and accessibility defects |
| Production readiness | Low |
| Security and privacy | Low |
| Booking and payment correctness | Low |
| Data integrity and recoverability | Low |
| Maintainability | Medium-low; duplicated UI systems and dead code |
| Automated testing | None in this repository |
| Documentation accuracy | Medium-low; README describes an older UI and understates the catalogue |
| Observability and support | Very low; console logs only |

**Bottom line:** keep this as a local demo until the P0 items in `MISSING_FEATURES.md` are addressed. Do not expose it to the public internet or enter real personal or payment data.

---

## 2. Scope and method

This audit examined the repository in its current hybrid state rather than the intended future architecture described by the README.

Inspected areas:

- all Java source under `src/com/mmtrip/common`, `server` and `client`;
- `web/index.html`, `web/app.js` and every linked stylesheet;
- the live rendering and event paths in the SPA;
- `data/*.ser` file type and persistence logic, without exposing file contents;
- build and run scripts;
- README claims versus actual implementation;
- the external weather/routing engine referenced by the gateway, where relevant to unused integration surfaces;
- bundled desktop and mobile screenshots for visual evidence.

Audit constraints:

- No application source files were modified.
- No secrets, passwords, API keys or environment-variable values are reproduced in these reports.
- Features are classified by source trace, not by the presence of a button or marketing claim.
- No formal usability test or production penetration test was performed.

---

## 3. System at a glance

```text
Browser SPA (index.html + app.js, no framework/build step)
        |
        |  fetch /api/*
        v
Java HTTP gateway (WebMain, com.sun.net.httpserver, port 8080+)
        |
        |  Java RMI / JRMP
        v
TripServiceImpl (port 1099 by default)
   |             |
   |             +--> DataStore: 9 destinations, 66 places, 27 seeded hotels,
   |                           plus partner-created hotels in memory
   |
   +--> ItineraryEngine: scoring, scheduling, cost estimation, warnings
   |
   +--> Java serialization: data/bookings.ser, data/partners.ser

Dormant integration surface:
WebMain --> external FastAPI weather/routing service on port 8000 by default
             /api/v1/weather/{destinationId}/forecast
             /api/v1/planning/trip
             The browser never calls either gateway proxy.
```

### Runtime components

| Component | Actual responsibility |
|---|---|
| `web/index.html` | Eight page views, navigation, overlays, chat shell, modal shell |
| `web/app.js` | All UI state, rendering, validation, API calls, localStorage, Leaflet maps, booking and partner flows |
| `WebMain` | Static file server, JSON gateway, RMI lookup, browser launch, auto port selection, weather/routing proxy |
| `TripServiceImpl` | Destinations, itinerary generation, bookings, simulated payments, partner accounts and hotel CRUD |
| `ItineraryEngine` | Deterministic attraction scoring, day scheduling, cost model, tips and warnings |
| `DataStore` | In-memory catalogue and partner-hotel registry |
| `data/bookings.ser` | Persistent map of bookings |
| `data/partners.ser` | Persistent partner accounts, salted password hashes and partner hotels |

There is no relational database, ORM, migration tool, background worker, message queue, cache layer or dedicated authentication service in this project.

---

## 4. What is actually implemented

### 4.1 Pages and navigation

Eight live views exist in `web/index.html`:

1. Home
2. Destinations
3. Itinerary
4. Hotels
5. Bookings
6. Travel Guide
7. Partner portal
8. About

Navigation is client-side only. There is no hash or History API routing, so URLs do not identify a page, browser Back does not move between views, and a refresh always returns to Home. Deep links and sharing a page state are not possible.

### 4.2 Destination discovery

- Nine destinations are served from `DataStore`: Bagan, Yangon, Mandalay, Inle Lake, Ngapali, Bago, Hpa-An, Pyin Oo Lwin and Kyaiktiyo.
- The catalogue contains **66 places**, not the 61 stated in the README.
- Region filtering and text search inspect destination names and attraction names.
- Destination detail modals show description, region, season, suggested days, highlights, fees and links to add the destination or find stays.
- Six editorial travel guides are hard-coded in the SPA, not fetched from the server.
- A global search modal returns matching destinations; it does not return individual attractions, hotels or guides.

### 4.3 Planner

There are two live entry points into the same planner:

- the compact planner over the Home hero;
- the full one-page Trip Studio lower on the Home page.

Both edit the same in-memory state. There is also a dead six-step wizard implementation left in `app.js` with no matching HTML.

Live planner capabilities:

- select up to six destinations;
- reorder the route by buttons or drag-and-drop;
- choose start and end dates, with an automatic suggested end date;
- set adults and children;
- set a budget or leave it at zero for an estimate only;
- display estimates in six currencies using fixed indicative conversion rates;
- choose travel style, transport, pace and interests;
- view a straight-line route preview on Leaflet or a built-in SVG fallback;
- generate an itinerary through `POST /api/itinerary`.

The “AI” label is a product description. No LLM, external model or machine-learning service is called. The live planner is a deterministic scoring and scheduling engine.

The engine validates:

- one to six destinations;
- one to twenty adults and zero to ten children, with no more than twenty travellers;
- one to ten days per destination and no more than twenty-one days total;
- valid destination identifiers;
- budget capped at one billion MMK;
- known style, transport, tier and pace values falling back to defaults.

### 4.4 Itinerary output and editing

The live itinerary page has five working tabs:

1. **Trip Overview** — day cards, route map, recommended hotel, trip summary.
2. **Daily Itinerary** — timeline, weather-unavailable indicators, day tools, activity editor.
3. **Map & Route** — Leaflet map with destination pins and a schematic fallback.
4. **Hotels** — stays fetched for every destination in the route.
5. **Budget** — total and daily estimate, category breakdown and warnings.

Implemented itinerary operations:

- save a snapshot to browser localStorage;
- print via the browser print dialog;
- export the full itinerary object as JSON;
- regenerate the whole trip with a variation seed;
- regenerate one day;
- edit activity title, time, duration, category, group cost and description;
- remove an activity;
- add a catalogue attraction that is not already in the day;
- drag-reorder activities within the same day, with recomputed times;
- recalculate entry fees, daily cost and total after local edits;
- open hotel booking from the itinerary.

Important limitations:

- The itinerary is not saved on the server.
- Browser drafts and itinerary persistence functions exist but are never called.
- A refresh loses the current unsaved itinerary.
- The saved-trip store is capped at eight entries when written, without telling the user.
- In-memory state can contain more than eight saved trips until the next reload.
- There is no undo, conflict handling or autosave indication.
- Regeneration replaces user edits without confirmation.
- Bookings default to the destination's day allocation as **nights**, so a three-day/two-night itinerary can prefill a three-night hotel stay.

### 4.5 Hotels, booking and payment

Hotel capabilities:

- fetch all hotels or filter by destination;
- filter by tier and maximum price; sort by price, rating or stars;
- display partner ownership, amenities, rating and rooms left;
- show server-supplied rooms-left counts;
- create a booking and decrement available rooms;
- simulate KBZPay, WavePay and AYA Pay payment;
- confirm a booking and show a demo receipt;
- look up bookings by phone;
- resume payment for a pending booking.

What is real:

- server-side validation of hotel, guest name, phone, dates, nights, rooms and status;
- room counter decrement;
- booking and payment records persisted to `data/bookings.ser`;
- booking status transition from `PENDING_PAYMENT` to `CONFIRMED`.

What is not real:

- no wallet provider is contacted;
- no money moves;
- no payment callback or reconciliation exists;
- no date-level availability exists;
- no cancellation, refund, release or expiry exists;
- “live availability” means an in-memory integer, not a booking calendar.

A failed payment returns HTTP 402 with a `PaymentResult`. The shared front-end API helper treats every non-2xx response as an exception and reads only an `error` field, so the server's specific decline message is replaced by a generic “Request failed (402)” message.

### 4.6 Traveller profile

The “Login” and “Sign Up” forms create a profile object in browser localStorage. They do not call the server, do not compare against a stored password and do not create a reusable account.

Consequences:

- any email/password combination creates or replaces a local profile;
- the profile is not connected to bookings or saved trips;
- clearing browser storage removes it;
- “sign out” only removes the local object;
- profile data is not available on another browser or device.

### 4.7 Partner portal

Server-backed partner features:

- registration with owner name, email, phone and password;
- login with email and password;
- salted SHA-256 password hashes stored in `data/partners.ser`;
- create, update and delete owned hotel listings;
- list properties and bookings for a partner;
- dashboard totals for properties, rooms, bookings and confirmed demo value;
- seeded demo partner account and two sample properties on a clean start.

Security limitation:

- login returns a `Partner` object to the browser, which stores it in localStorage;
- every subsequent partner request authorizes by the client-supplied `partnerId` query or body field;
- there is no session token, expiry, cookie, CSRF protection or server-side verification that the caller is the authenticated partner;
- anyone who obtains a partner ID can impersonate that partner.

This is server-backed password checking but **not a secure authentication or authorization system**.

### 4.8 Weather and routing

The gateway exposes:

- `GET /api/engine/weather`
- `POST /api/route-plan`

Both proxy an external FastAPI service if configured and return truthful failure messages when it is unavailable. Neither endpoint is called by `web/app.js`.

The UI always displays “Weather unavailable”. Planner route distances and travel times are rough straight-line/Haversine estimates with fixed speeds, not road routes. The Map & Route tab uses Leaflet tiles and straight dashed polylines between destinations.

Therefore:

- weather integration: **missing from the live UX**;
- road routing integration: **missing from the live UX**;
- gateway proxies: **implemented but unused**;
- itinerary travel duration: **not derived from a routing provider**.

---

## 5. Architecture assessment

### Strengths

- The RMI split is genuine: the HTTP gateway communicates with a remote Java service.
- The model is simple and serializable, with a small dependency-free JSON layer.
- The engine is deterministic and testable in principle.
- Validation is duplicated sensibly between browser and server for critical booking fields.
- The UI explicitly labels estimates, simulated payments and unavailable weather instead of inventing data.
- Partner passwords are not returned to clients and are salted/hashed rather than stored in plain text.
- The application is easy to run locally with a JDK and no package manager.

### Weaknesses

- The HTTP gateway and RMI service have no user/partner session model.
- The RMI service is unauthenticated; the default local binding reduces exposure but remote use would be unsafe.
- Java serialization is the database, with no schema, migrations, indexes, transactions or atomic writes.
- HTTP health is shallow and does not prove the RMI service is usable.
- Static asset fallback returns `index.html` for missing files with a 200 status, which can mask broken asset deployments.
- Error handling logs to stdout/stderr only.
- No request IDs, structured logs, metrics, tracing or alerting.
- No input rate limiting, request size limiting beyond 200 KB, or abuse controls.
- CORS is open to every origin, but there is no `OPTIONS` preflight handling.
- There is no CSP, frame-ancestor policy, content-type sniffing protection, HSTS or TLS.
- The project is not a Git repository, so there is no change history, review trail or rollback mechanism.

### Front-end architecture

- The SPA is a single 3,568-line JavaScript file with global mutable state and string-template rendering.
- View state is not represented in the URL.
- The code contains a live one-page studio plus a dead six-step wizard.
- `web/_studio_block.js` and `web/_itinerary_block.js` are large orphan redesign files that are not loaded.
- Two design systems overlap: `studio.css` styles the live planner markup, while `planner-studio.css` is loaded later and redefines many of the same `.studio-*` selectors. `planner-studio.css` also contains numerous selectors for markup that the live app does not generate.
- the root-level `map.css` is not loaded, and no design-specification text files remain in the project root.
- External runtime dependencies include Google Fonts, Leaflet from unpkg, OpenStreetMap tiles and Wikimedia images for four destinations.

---

## 6. Persistence and data assessment

There is no database management system. Persistence consists of two Java serialized files:

| File | Root object | Purpose |
|---|---|---|
| `data/bookings.ser` | `HashMap<String, Booking>` | All bookings, keyed by booking ID |
| `data/partners.ser` | `PartnerData` | Partner accounts, salted hashes and partner hotel listings |

The catalogue is code, not persisted data: `DataStore` rebuilds nine destinations, sixty-six places and twenty-seven base hotels on every server start. A clean start also seeds two partner hotels.

Key risks:

- entire-file rewrites on every booking/payment/partner change;
- no atomic temp-file-and-rename write;
- write errors are caught and logged, but the API still reports success;
- no backup, recovery or integrity check;
- no versioned schema;
- no date-specific inventory;
- rooms are never released after pending holds or cancellations because no such flow exists;
- editing a partner hotel resets its inventory to the submitted room count, potentially erasing active bookings;
- deleting a partner hotel leaves its bookings orphaned;
- partner data and guest PII are stored unencrypted on disk;
- file paths are relative to the process working directory;
- a second server process could overwrite another process's changes.

Details and field definitions are in `DATABASE_DOCUMENTATION.md`.

---

## 7. Security and privacy assessment

### Critical

1. **Unauthenticated booking lookup.** `GET /api/bookings?phone=...` returns bookings for a phone number. With no phone parameter it returns all bookings. No OTP, session or ownership check exists.
2. **Broken partner authorization.** Partner property and booking APIs trust a caller-supplied `partnerId` and accept no token.
3. **Sensitive wallet data transmitted.** The demo PIN is posted to the gateway and passed over RMI for validation. It is not sent to a real wallet, but the UI's absolute “no PIN is transmitted” statement is false.
4. **No real traveller authentication.** Local profiles do not protect anything and create a misleading sense of account security.
5. **No rate limiting or abuse controls** on bookings, lookup, partner login or public catalogue endpoints.

### High

- Open CORS (`Access-Control-Allow-Origin: *`) on all API responses.
- No TLS, security headers or CSP.
- No persistent audit log of partner or booking actions.
- Partner password hashing uses salted single-round SHA-256, not a password KDF.
- Unauthenticated RMI registry if exposed beyond localhost.
- Serialized files contain PII and password hashes without encryption or access control beyond filesystem permissions.

### Medium

- No booking ownership check before payment; a booking ID plus wallet form is enough.
- No idempotency keys on booking or payment.
- No CSRF token and no origin allowlist.
- No brute-force protection on partner login.
- No content sanitization issue found in the live string renderer: dynamic values generally pass through `esc()`. However, inline HTML is assembled widely and future changes are fragile.

---

## 8. Functional inconsistencies and bugs

1. **Wrong hotel night count.** Itinerary shows `totalDays - 1` nights in the summary, but the booking modal prefills nights from `nightsPerDestination`, which is the day allocation. A three-day trip can prefill three nights.
2. **Declined payment message lost.** HTTP 402 is treated as a generic fetch failure, so the specific decline reason is never displayed.
3. **Room holds never expire.** Every pending booking permanently removes rooms until data is manually deleted.
4. **Cancellation is advertised but absent.** A 48-hour demo cancellation note appears at booking, but no cancellation endpoint or UI exists.
5. **Partner inventory reset.** Editing a property resets rooms and can erase the effect of existing bookings.
6. **Partner delete leaves bookings.** Deleting a property removes it from catalogue lookups but does not resolve its bookings.
7. **Saved-trip cap is silent.** Persistence truncates to eight trips.
8. **Draft persistence is dead.** Planner and itinerary draft helpers are defined but never invoked.
9. **Dead wizard remains.** Six-step rendering and event handlers remain, but the required DOM no longer exists.
10. **Deep links do not work.** All views share the same URL.
11. **Header search overpromises.** Placeholder says destination or attraction; results are destinations only.
12. **“Book This Trip” only navigates to the hotel page.** It does not book the itinerary, transport or all stays.
13. **README drift.** Six-step wizard, 61 attractions, API omissions and security wording no longer match the live app.
14. **Local image mapping drift.** Local JPGs exist for Mandalay, Hpa-An, Bago and Pyin Oo Lwin, but the front end still points those keys at Wikimedia URLs.

---

## 9. Reliability and operations assessment

| Area | Current state |
|---|---|
| Error tracking | Console logs only |
| Metrics/tracing | None |
| Health check | Returns a static UP payload; does not probe RMI or disk persistence |
| Backup | None |
| Recovery | Restart with potentially partially written `.ser` files |
| Atomicity | None |
| Graceful shutdown | None |
| Background jobs | None |
| Notifications | None |
| Rate limiting | None |
| API versioning/OpenAPI | None |
| Tests | No `tests/` directory in this repository |
| CI/CD | None |
| Deployment hardening | None; local Java process plus static files |

Ad-hoc files such as screenshot scripts and old UI text snapshots exist, but they are not a maintained test suite.

---

## 10. Documentation drift

The README still accurately explains the broad demo, RMI split, cost model and local run commands, but it is stale in several material ways:

- says the live planner is a six-step builder; the live UI is a one-page studio;
- says the catalogue has 61 attractions; the code has 66;
- documents 27 hotels but does not mention the two seeded partner properties that can make the initial runtime catalogue larger;
- omits the unused weather and route-plan gateway routes;
- presents partner passwords and account behavior without describing the missing session authorization;
- states that no PIN is transmitted in a way that conflicts with the gateway/server handling;
- describes profile accounts and “premium” visual features that do not all match current files;
- does not warn that the current URL cannot deep-link or preserve view state.

The reports in this audit supersede the README for actual implementation status, but **the README was not modified**.

---

## 11. Prioritized recommendations

### P0 — before any public or shared deployment

1. Add real authentication and authorization for travellers and partners. Use server-side sessions or signed tokens; never trust a client-supplied partner ID.
2. Remove or protect the unrestricted booking lookup. Require booking reference plus OTP, or authenticated account ownership.
3. Stop collecting the wallet PIN in the demo, or change the copy and threat model. Prefer a mock approval control instead of a PIN-like secret.
4. Implement booking lifecycle rules: hold expiry, cancellation, release, refund state, and idempotency.
5. Replace serialized whole-file persistence with a transactional database and atomic inventory updates.
6. Add rate limiting, security headers, origin restrictions and TLS termination.
7. Add automated tests for authorization, booking inventory, payment state transitions and persistence failure.

### P1 — production feature completeness

1. Date-specific room inventory and availability search.
2. User accounts, booking ownership, cancellation and refund UX.
3. Real payment-provider integration with verified callbacks and reconciliation.
4. Notification service for booking confirmation, cancellation and partner events.
5. Admin/support console for bookings, partners, hotels and disputes.
6. Route and weather integration in the live itinerary, or remove the dormant promises and endpoints.
7. Structured logging, metrics, tracing, health checks and backups.
8. Fix the nights mismatch, decline-message handling, inventory reset and silent-save failures.
9. Consolidate the CSS and delete/archive dead wizard and orphan redesign code.
10. Add URL routing, shareable states and autosave/undo.

### P2 — experience and growth

- reviews and ratings from verified stays;
- favourites and recommendation explanations;
- i18n and Myanmar-language content;
- accessibility remediation to WCAG 2.2 AA;
- PWA/offline planning;
- supplier integrations and live content;
- analytics, funnel measurement and experimentation;
- legal pages, privacy policy, terms, support and complaint handling.

---

## 12. Report index

- `PAGE_INVENTORY.md` — every page, modal and control, with APIs and navigation.
- `FEATURE_INVENTORY.md` — implemented, partial, mocked, dead and missing capabilities.
- `USER_WORKFLOW.md` — end-to-end user and partner journeys, including failure paths.
- `API_DOCUMENTATION.md` — gateway routes, payloads, validation, status codes and security notes.
- `DATABASE_DOCUMENTATION.md` — serialization model, entity relationships, persistence risks and proposed relational schema.
- `UI_UX_AUDIT.md` — visual system, responsive behavior, accessibility, content trust and print.
- `MISSING_FEATURES.md` — production blockers and phased feature roadmap.

---

## 13. Audit statement

No application source code, configuration, data files or README content was modified during this audit. The only files created are these Markdown reports.
