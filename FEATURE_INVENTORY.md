# MSTP — Feature Inventory

**Audit date:** 12 November 2026  
**Classification method:** Each capability was traced from the rendered UI through `web/app.js` to the gateway and RMI service. Status reflects observable code behaviour, not README or marketing copy.

## Status definitions

| Status | Meaning |
|---|---|
| **Implemented** | Works end to end for the stated scope. |
| **Partial** | Works, but has material missing behaviour, correctness or safety gaps. |
| **Mocked** | Simulates a capability without the real external service or security model. |
| **Dead** | Code exists but is unreachable from the live UI. |
| **Missing** | No implementation exists. |

---

## 1. Summary scorecard

| Domain | Implemented | Partial | Mocked | Dead | Missing |
|---|---:|---:|---:|---:|---:|
| Discovery and content | 7 | 2 | 0 | 0 | 3 |
| Planner and engine | 8 | 4 | 0 | 1 | 4 |
| Itinerary | 10 | 4 | 0 | 2 | 7 |
| Hotels and booking | 6 | 4 | 1 | 0 | 6 |
| Accounts and partner | 5 | 3 | 1 | 0 | 7 |
| Integrations | 0 | 2 | 1 | 2 | 4 |
| Platform, security and operations | 2 | 3 | 0 | 0 | 15 |

The application is strong as a local demonstration of itinerary generation, hotel booking and partner CRUD. It is weak wherever production identity, money movement, inventory correctness, integration or operability is required.

---

## 2. Discovery and content

| Feature | Status | Evidence and limitations |
|---|---|---|
| Destination catalogue | **Implemented** | `DataStore.destinations()` supplies nine destinations and 66 places. Served by `GET /api/destinations`. |
| Curated attraction data | **Implemented** | Each `Destination` contains `Place` records with category, best time, hours, rating, entry fee and description. |
| Region filtering | **Implemented** | `renderDestinationsPage()` builds region chips from live data and filters by exact `region`. |
| Destination text search | **Implemented** | Matches name, Myanmar name, region, tagline and attraction names on the Destinations page and in the studio. |
| Global header search | **Partial** | Modal placeholder promises “Destination or attraction”; results are destination rows only and clicking opens the destination, not the matched attraction. |
| Destination detail modal | **Implemented** | Shows description, season, suggested days, up to nine highlights, fees, add-to-trip and find-stays actions. |
| Featured destinations | **Implemented** | Five fixed IDs: Bagan, Inle Lake, Yangon, Ngapali, Kyaiktiyo. |
| Editorial travel guides | **Implemented** | Six hard-coded guides with modal articles. Not CMS-managed or localised. |
| Guide search/filter/bookmark | **Missing** | No controls or persistence. |
| Reviews and ratings from travellers | **Missing** | Only seeded hotel ratings and place ratings exist. No user review model, submission or moderation. |
| Favourites/wishlist | **Missing** | Saved trips exist, but no destination or hotel favourites. |
| Myanmar-language interface | **Missing** | Destination names include Myanmar script, but all UI and guide copy are English. |
| Content freshness/updated dates | **Missing** | No publication or review dates on destination or guide content. |

**Unsupported content claims**

- Home feature strip says “Trusted & Secure Platform” and “24/7 Support”. Neither is implemented.
- About says “no PIN is transmitted”; the PIN is transmitted to the gateway and RMI server.
- README says 61 attractions; source contains 66.
- Hotels page says “live availability”; availability is a single in-memory counter per property, not a dated inventory.

---

## 3. Planner and itinerary engine

| Feature | Status | Evidence and limitations |
|---|---|---|
| One-page Trip Studio | **Implemented** | `renderPlannerStudio()` renders title, dates, travellers, budget, currency, style, transport, pace, interests, route, destination search, map and summary. |
| Compact hero planner | **Implemented** | Shares the same state; destination picker, date, travellers, budget and generate. |
| Six-step wizard | **Dead** | `renderWizard`, `renderRail`, `stepPanel`, `goNext`, `updateBrief` and related event branches remain, but `#wizardPanel` and `#wizardRail` do not exist. README still describes it. |
| Destination selection, max six | **Implemented** | `toggleDestination()` caps selection at six. Server also rejects more than six. |
| Route reordering | **Implemented** | Up/down buttons and HTML drag-and-drop update `routeOrder`. |
| Date range and duration | **Implemented** | Start/end dates, automatic end date, 21-day clamp, day allocation proportional to recommended days. |
| Traveller counts | **Implemented** | Adults 1–12 in UI, children 0–10; server permits up to 20 total but the UI is stricter. |
| Budget input and verdict | **Implemented** | Budget is optional; server returns `budgetSet`, `budgetOk`, `budgetDelta`, warnings. |
| Multi-currency display | **Partial** | Six currencies with fixed indicative rates. All server values remain MMK. Input is interpreted in the selected currency. Not live FX. |
| Travel style, transport, pace | **Implemented** | Values influence attraction scoring, day scheduling and cost assumptions. |
| Hotel tier preference | **Partial** | `state.hotelTier` is sent to the engine, but the live studio has no control for it. Defaults to `mid`. |
| Interest scoring | **Implemented** | `ItineraryEngine` scores places against interests, style and ratings, then schedules by time slot and pace. |
| Deterministic “AI” generation | **Implemented** | The engine is rule-based and deterministic except for controlled variation. No LLM or ML service is used. |
| Controlled regeneration | **Implemented** | `variation` changes tie-breaking and selection. Whole-trip and per-day regeneration work. |
| Validation and error messages | **Implemented** | Server validates destinations, travellers, days, budget, identifiers and options; gateway maps `TripException` to HTTP 400. |
| Shareable itinerary URL | **Missing** | No URL state or server-stored itinerary ID lookup. |
| Autosave and draft restore | **Dead** | `persistDraft`, `loadDraft`, `persistItinerary`, `loadItineraryDraft` exist but are never called. |
| Undo/redo | **Missing** | Edits apply immediately. |
| Weather-aware planning | **Missing** | Weather is never fetched. UI always shows “Weather unavailable”. |
| Road-route-aware planning | **Partial** | Gateway proxy exists; frontend uses Haversine distance and fixed speeds. |
| Accessibility of drag-only ordering | **Partial** | Up/down buttons provide a non-drag path for route stops and activity rows? Activity rows have no up/down buttons, only drag. |

### Engine behaviour verified

- Validates 1–6 destinations, 1–20 adults, 1–10 children, no more than 20 travellers.
- Caps budget at 1,000,000,000 MMK.
- Falls back to defaults for unknown style, transport, tier and pace.
- Schedules around sunrise-to-sunset slots, arrival/transfer days, meals and rest.
- Costs entries, food, local transport, intercity transfers and stays.
- Uses `totalDays - 1` nights for stay cost.
- Produces tips, warnings, extra places and a recommended-days value.

---

## 4. Itinerary output and editing

| Feature | Status | Evidence and limitations |
|---|---|---|
| Five-tab itinerary shell | **Implemented** | Overview, Daily Itinerary, Map & Route, Hotels, Budget. |
| Trip hero and meta bar | **Implemented** | Headline, place, days/nights, travellers, estimate, style. |
| Overview day cards | **Implemented** | Theme, sights, time range, active hours, weather-unavailable chip, details and regenerate. |
| Daily timeline | **Implemented** | Activities with time, description, slot, duration, category, cost, edit/remove. |
| Activity editing | **Implemented** | Modal edits title, time, duration, category, group cost and description. |
| Add catalogue attraction | **Implemented** | Only places for the day's destination that are not already present. No free-form place creation. |
| Remove activity | **Implemented** | Immediate removal, recalculation and toast. |
| Drag reorder within day | **Implemented** | Retimes from 08:00 with 30-minute gaps. Cross-day moves rejected. |
| Recalculate after edits | **Implemented** | Recomputes entry fees, day costs, active hours and total; budget verdict updates. |
| Regenerate one day | **Implemented** | Calls the engine again and replaces the day, preserving day number and date. |
| Regenerate whole trip | **Implemented** | Replaces the itinerary without confirmation, discarding edits. |
| Save trip locally | **Implemented** | Stores itinerary snapshot under `mstp.trips.v2`; deduplicates by itinerary ID. |
| Server-side trip saving | **Missing** | No itinerary persistence endpoint or model. |
| Saved-trip capacity | **Partial** | Persistence silently truncates to eight entries. In-memory list can exceed eight until reload. |
| Saved-trip management | **Partial** | Open and remove only. No rename, duplicate, export-all, folders or sync. |
| Print | **Implemented** | Browser print with dedicated print CSS. Fidelity depends on browser and hidden panels. |
| JSON export | **Implemented** | Downloads raw itinerary object. |
| PDF export | **Missing** | No PDF generator or print-to-PDF guidance beyond browser print. |
| Share link / social share | **Missing** | No URL state or share action. |
| Booking from itinerary | **Partial** | “Book This Trip” only opens the Hotels view; it does not book stays, transport or the full plan. |
| Recommended hotels in overview | **Implemented** | Loads hotels for route destinations, shows one recommendation plus “See All”. |
| Route hotels tab | **Implemented** | Loads hotels for every destination; cached until partner changes invalidate it. |
| Map tab | **Partial** | Leaflet tiles and straight dashed lines; no road geometry or directions. |
| Weather on itinerary | **Missing** | Static unavailable chip only. |
| Extra places | **Implemented** | Displays engine `extraPlaces`, up to nine. |
| Budget donut and daily spend | **Implemented** | Category split, budget comparison, warnings, per-day costs. |
| Undo/version history | **Missing** | Regeneration and edits are destructive. |
| Conflict handling/multi-device sync | **Missing** | Browser-local only. |

### Itinerary correctness issues

1. **Night mismatch:** summary uses `totalDays - 1`; booking prefill uses `nightsPerDestination`, which is the day allocation. A three-day trip can prefill three hotel nights.
2. **Silent truncation:** `persistSaved()` writes `state.saved.slice(0, 8)` without warning.
3. **No draft restore:** refreshing loses the current plan unless it was explicitly saved.
4. **No confirmation:** regenerate discards edits.
5. **Local recalculation approximates:** food and local transport totals are reused rather than repriced after traveller or route changes.

---

## 5. Hotels, booking and payment

| Feature | Status | Evidence and limitations |
|---|---|---|
| Hotel catalogue | **Implemented** | 27 seeded hotels plus partner properties, served by `GET /api/hotels`. |
| Destination tabs | **Implemented** | Itinerary destinations first, then all remaining destinations. |
| Tier filter | **Implemented** | All, Budget, Mid-range/Comfort, Luxury. |
| Price filter | **Implemented** | Slider 30,000–350,000 MMK; 350,000 means “Any”. Hotels above 350,000 are unreachable through the slider except at “Any”. |
| Sorting | **Implemented** | Price, rating, stars. |
| Partner attribution | **Implemented** | Shows owner name and partner label for owner-created hotels. |
| Hotel detail page | **Missing** | No dedicated page; only cards and the booking modal. No gallery, map, policies or reviews. |
| Availability display | **Partial** | Single `roomsLeft` integer per hotel. No dates, room types or per-night calendar. |
| Booking creation | **Implemented** | Server validates hotel, guest, phone, dates, nights, rooms and inventory; returns 201. |
| Room hold | **Partial** | Decrements `roomsLeft` immediately. Holds never expire and no release occurs. |
| Date-specific inventory | **Missing** | A booking in January reduces availability in December. |
| Booking modification | **Missing** | No change dates, rooms, guest or hotel. |
| Cancellation | **Missing** | Copy mentions a 48-hour demo policy; no endpoint or UI exists. |
| Refund | **Missing** | No refund state or process. |
| Booking lookup by phone | **Implemented but unsafe** | `GET /api/bookings?phone=...` needs no authentication. Without phone it returns all bookings. |
| Booking ownership | **Missing** | No link between profile accounts and bookings. |
| Saved booking history | **Partial** | Lookup must be repeated by phone; no account history. |
| Payment simulation | **Mocked** | KBZPay, WavePay and AYA Pay are labels. No provider contact, money movement, callback or reconciliation. |
| Payment validation | **Implemented** | Method, wallet phone and 4-6 digit PIN validated server-side; one hard-coded demo PIN value triggers a decline. That value is not reproduced in this audit. |
| Decline UX | **Partial** | Server returns 402 with a `PaymentResult`, but the frontend throws on non-2xx and displays “Request failed (402)” instead of the reason. |
| Receipt | **Implemented** | On-screen demo receipt with transaction reference. No email/download. |
| Idempotency | **Missing** | Repeated payment calls are blocked only by booking status; repeated booking calls create duplicates. |
| Payment retry | **Implemented** | Pending booking can reopen payment from lookup or immediately after decline. |
| Real wallet integration | **Missing** | No provider SDK, signature verification, webhook or settlement. |
| Payouts to partners | **Missing** | Dashboard shows “demo booking value” only. |
| Taxes, fees, invoices | **Missing** | Price is nightly rate × nights × rooms. No tax, service fee or invoice. |

### Booking validation reference

- Guest name at least 2 characters.
- Myanmar phone normalized to `09` plus 7–9 digits; accepts `+95`, `95` and `959` prefixes.
- Nights 1–30; rooms 1–10 and not greater than `roomsLeft`.
- Check-in valid ISO date, not before today.
- Check-out computed as check-in + nights.
- Booking ID prefix `BK-`, six random uppercase characters.
- Total = `pricePerNight × nights × rooms`.
- Status starts `PENDING_PAYMENT`; successful payment sets `CONFIRMED`.

---

## 6. Accounts, saved state and partner portal

| Feature | Status | Evidence and limitations |
|---|---|---|
| Traveller sign-up | **Mocked** | Any valid-looking name/email/password creates a localStorage profile. No server call, verification or uniqueness. |
| Traveller login | **Mocked** | The submitted password is not compared with anything; any password of 4+ characters opens or replaces the local profile. |
| Traveller account panel | **Partial** | Shows name/email, links to trips and partner dashboard, sign out. No profile editing, password change or deletion. |
| Account-linked bookings | **Missing** | Bookings are keyed by phone, not account. |
| Account-linked saved trips | **Missing** | Saved trips are browser-local and available even when signed out. |
| Partner registration | **Implemented** | Server-side validation, duplicate email check, salted hash persistence. |
| Partner login | **Partial** | Password hash is verified server-side, but the returned `Partner` object is the only credential thereafter. |
| Partner session/authorization | **Missing** | No token, cookie, expiry or server-side session. APIs trust `partnerId`. |
| Partner dashboard | **Implemented** | Properties, rooms, bookings, confirmed count and demo value. |
| Partner property create | **Implemented** | Validates name, destination, price, rooms, tier, description; assigns owner and default rating. |
| Partner property edit | **Partial** | Works, but resets `roomsTotal`/`roomsLeft` to the submitted room count, potentially erasing active booking effects. |
| Partner property delete | **Partial** | Removes listing; existing bookings are orphaned and disappear from the partner's booking list. |
| Partner bookings view | **Implemented** | Shows bookings whose hotel currently belongs to the partner. |
| Partner booking management | **Missing** | No accept/decline, check-in, cancellation or guest messaging. |
| Partner payout reporting | **Missing** | Demo value only; no statement, commission or settlement. |
| Partner password reset | **Missing** | No recovery path. |
| Partner email verification | **Missing** | Email is not verified. |
| Partner MFA / lockout | **Missing** | No brute-force protection. |
| Admin console | **Missing** | No staff view for partners, hotels, bookings, refunds or content. |

### Partner security note

Registration and login perform real password hashing (salted SHA-256, single round). That is better than plaintext, but the authorization model is broken: any caller who knows a partner ID can list, create, edit or delete that partner's hotels and read their bookings. This is **not** an authenticated partner system.

---

## 7. Integrations and external services

| Integration | Status | Evidence and limitations |
|---|---|---|
| Java RMI transport | **Implemented** | Gateway looks up `MyanmarTripService`; RMI port 1099 by default. |
| HTTP JSON gateway | **Implemented** | `com.sun.net.httpserver`, eight-thread pool, auto port search from 8080. |
| Weather proxy | **Partial** | `GET /api/engine/weather` validates a safe destination ID and required coordinates, forwards to FastAPI, returns truthful 503 on failure. Never called by the frontend. |
| Road routing proxy | **Partial** | `POST /api/route-plan` forwards arbitrary JSON to the external planning service. Never called by the frontend. |
| Weather in UI | **Missing** | Always “Weather unavailable”. |
| Road routing in UI | **Missing** | Straight-line estimates only. |
| Map tiles | **Implemented dependency** | Leaflet 1.9.4 from unpkg; OpenStreetMap tiles. No API key. |
| Local photography | **Partial** | Local JPGs exist for several destinations; the front end still points Mandalay, Hpa-An, Bago and Pyin Oo Lwin at Wikimedia URLs. |
| Google Fonts | **Implemented dependency** | Fraunces and Manrope loaded from Google Fonts. |
| Payment provider | **Missing** | No external wallet integration. |
| Email/SMS notifications | **Missing** | No provider, templates or outbox. |
| Analytics | **Missing** | No tags, events or consent handling. |
| Error monitoring | **Missing** | Console/stdout only. |
| Object storage/CDN | **Missing** | Static files served by the Java process. |
| Search service | **Missing** | Client-side array filtering only. |

### Gateway environment variables

The gateway reads two environment variables for the dormant engine integration: one for the engine base URL and one for an internal token. Their values are intentionally not reproduced. No frontend configuration, API key or secret is present in the repository.

---

## 8. UX, accessibility and content

| Feature | Status | Evidence and limitations |
|---|---|---|
| Responsive layout | **Partial** | Multiple breakpoints at 1180, 1020, 960, 900, 820, 760, 700, 620 and 480 px. Screenshots show usable mobile layout, but dense itinerary/booking surfaces and touch target sizes need verification. |
| Keyboard support | **Partial** | Destination cards support Enter/Space; Escape closes modals; focus-visible styling exists. No focus trap, focus restoration, roving tabs or skip link. |
| Screen-reader semantics | **Partial** | Some roles and labels are present; dynamic tab panels lack `aria-controls`/`aria-selected` updates; toasts are not announced; modal label is generic. |
| Colour contrast | **Partial** | Several muted/gold combinations fail WCAG AA at normal text size. Measurements: gold `#c3984b` on cream ≈ 2.37:1; muted `#758078` on cream ≈ 3.67:1. |
| Reduced motion | **Implemented** | `prefers-reduced-motion` collapses animation and transition durations. |
| Touch drag alternative | **Partial** | Route stops have up/down buttons; activity reordering has drag only. |
| Loading feedback | **Implemented** | Spinners, disabled buttons, loading empty states and toasts. |
| Error feedback | **Partial** | Generic toasts and inline errors. Payment decline is lost. No retry guidance for server outages beyond a toast. |
| Empty states | **Implemented** | No saved trips, no bookings, no hotel matches, no attractions left, no partner properties/bookings. |
| Offline support | **Missing** | No service worker, manifest or offline cache. |
| Deep links / Back button | **Missing** | No URL routing. Browser Back leaves the app or does nothing within views. |
| Form autofill/accessibility | **Partial** | Some `autocomplete` absent; labels wrap inputs; required indicators are not textual. |
| Print layout | **Partial** | Print CSS hides chrome and expands itinerary panels, but hidden tab panels are forced visible, which can produce a long mixed document. |
| Localisation | **Missing** | English only. |
| Legal/privacy pages | **Missing** | No privacy policy, terms, cookie notice or data-deletion instructions. |

---

## 9. Security and privacy capabilities

| Capability | Status | Notes |
|---|---|---|
| Traveller authentication | **Missing** | Local profile only. |
| Partner authentication | **Partial** | Password verified, but no session. |
| Authorization | **Missing** | Client-supplied partner ID; booking lookup unauthenticated. |
| Password storage | **Partial** | Salted SHA-256, not a memory-hard KDF such as Argon2id/bcrypt/scrypt. |
| Transport encryption | **Missing** | Plain HTTP and JRMP; no TLS. |
| CORS policy | **Partial** | Present but permissive (`*`); no preflight handling. |
| Security headers | **Missing** | No CSP, HSTS, frame-ancestors, nosniff, referrer policy or permissions policy. |
| CSRF protection | **Missing** | No tokens or origin checks. |
| Rate limiting | **Missing** | No limits on lookup, login, booking or payment. |
| Input size limit | **Partial** | Request bodies capped at 200 KB. |
| Input validation | **Implemented** | Server validates booking, payment and partner fields. |
| Output escaping | **Implemented** | Dynamic text generally passes through `esc()`. Some inline HTML construction remains fragile. |
| Audit logging | **Missing** | stdout messages only; no actor, request ID or durable audit trail. |
| PII protection at rest | **Missing** | Guest names, phones, booking data and password hashes are serialized unencrypted. |
| Data deletion | **Missing** | No account, booking or partner deletion workflow. |
| Privacy consent | **Missing** | No consent capture. |
| Secret exposure in repo | **None found** | No API keys or passwords in source aside from the intentionally displayed demo partner credentials. |

---

## 10. Operations and engineering

| Capability | Status | Notes |
|---|---|---|
| Build scripts | **Implemented** | `build.bat`, `build.sh`; plain `javac`, no dependency manager. |
| Run scripts | **Implemented** | Embedded all-in-one and split client/server modes. |
| Health endpoint | **Partial** | Returns static UP; does not probe RMI, disk or external engine. |
| Automated tests | **Missing** | No `tests/` directory or test framework in this repository. |
| CI/CD | **Missing** | No pipeline configuration. |
| Database | **Missing** | Java serialization files only. |
| Migrations | **Missing** | No schema versioning. |
| Atomic writes | **Missing** | Whole-file overwrite without temp-file rename. |
| Backup/restore | **Missing** | No backup job or documented recovery. |
| Graceful shutdown | **Missing** | No shutdown hook or in-flight request draining. |
| Structured logging | **Missing** | Ad-hoc stdout/stderr lines. |
| Metrics/tracing | **Missing** | None. |
| Request IDs | **Missing** | None. |
| Rate limiting/quotas | **Missing** | None. |
| API documentation | **Missing in repo** | No OpenAPI/Swagger; this audit supplies a manual reference. |
| API versioning | **Missing** | Routes are unversioned. |
| Static asset cache policy | **Partial** | `no-cache` for static files; missing files return `index.html` with 200, masking broken deployments. |
| Admin/support tooling | **Missing** | None. |
| Data export for users | **Partial** | Itinerary JSON export only; no booking or account export. |
| Accessibility testing | **Missing** | No automated or manual test record. |
| Browser support policy | **Missing** | No documented matrix. |

---

## 11. Unsupported or inflated claims

| Claim | Location | Actual state |
|---|---|---|
| Six-step trip builder | README | Live UI is a one-page studio; wizard code is dead. |
| 61 attractions | README | 66 places in `DataStore`. |
| “Trusted & Secure Platform” | Home feature strip | No authentication, authorization, TLS or security certification. |
| “24/7 Support” | Home feature strip | Static chat shortcuts only; no support channel or staff. |
| “Live availability” | Hotels page | Single in-memory room counter, not dated inventory. |
| “No PIN is transmitted” | About, payment copy | PIN is posted to the gateway and sent over RMI for validation. No wallet provider receives it. |
| “48 h demo cancellation policy” | Booking modal | No cancellation feature exists. |
| “Properties … included in every customer hotel search, itinerary recommendation” | Partner dashboard | Hotels appear in searches; itinerary “recommended hotel” selection is a simple route-based lookup, not a full recommendation engine. |
| “AI Trip Plan” | Hero and itinerary | Deterministic rule engine; no AI/LLM. |
| “Weather unavailable” as a temporary condition | Itinerary | Permanent in this build; no fetch is attempted. |
| “Book This Trip” | Itinerary summary | Navigates to Hotels only. |
| “Real-time / live” partner visibility | Partner copy | Changes are immediate in the same server process, but there is no push or multi-instance consistency. |

---

## 12. Highest-value missing features

### P0 — correctness and safety

1. Server-side authentication and authorization for travellers and partners.
2. Authenticated booking lookup with booking reference plus OTP or account ownership.
3. Remove PIN collection or stop transmitting it; use a mock approval control.
4. Booking hold expiry, cancellation, release and refund states.
5. Date-specific inventory with transactional room allocation.
6. Atomic, recoverable persistence with backup and integrity checks.
7. Rate limiting, security headers, origin restrictions and TLS.
8. Automated tests for authorization, inventory, payment and persistence.
9. Fix the 402 decline-message handling and the itinerary/booking night mismatch.
10. Fix partner edit inventory reset and orphaned bookings on delete.

### P1 — product completeness

1. Real traveller accounts linked to bookings and saved trips.
2. Partner session tokens and password reset.
3. Admin/support console.
4. Email/SMS booking notifications.
5. Real payment provider with callbacks and reconciliation.
6. Weather and road routing in the live itinerary, or removal of the dormant promises.
7. URL routing, deep links, autosave, undo and shareable itineraries.
8. Dedicated hotel detail pages with policies, maps, room types and reviews.
9. Accessible drag alternatives and full WCAG 2.2 AA remediation.
10. Consolidation of CSS and removal/archival of dead wizard and orphan redesign code.

### P2 — growth and polish

- reviews and verified-stay badges;
- favourites and recommendation explanations;
- Myanmar-language UI and content;
- PWA/offline planning;
- PDF itineraries and email delivery;
- analytics and funnel measurement;
- supplier/content integrations;
- legal, privacy and support pages;
- social sharing and referral codes.

---

## 13. Feature evidence map

| Area | Primary source |
|---|---|
| View switching and dead routing | `web/app.js` `switchView`, `wireEvents` |
| Planner and compact form | `web/app.js` `renderPlannerStudio`, `quickGenerate`, `buildPayload` |
| Wizard dead code | `web/app.js` `renderWizard` through `updateBrief` |
| Itinerary rendering and editing | `web/app.js` `renderItinerary`, `renderDaily`, `recalcItinerary`, activity functions |
| Maps | `web/app.js` `renderStudioMap`, `renderRouteMapElement`, `routeMapSvg` |
| Hotels and booking | `web/app.js` `loadHotels`, `openBooking`, `submitBooking` |
| Payment | `web/app.js` `openPayment`, `submitPayment`, `showReceipt`; `TripServiceImpl.pay` |
| Booking lookup | `web/app.js` `lookupBookings`; `TripServiceImpl.getBookings` |
| Saved trips | `web/app.js` `saveCurrentTrip`, `persistSaved`, `renderSavedTrips` |
| Traveller profile | `web/app.js` `openAuth`, `submitAuth` |
| Partner portal | `web/app.js` `renderPartnerAuth`, `renderPartnerDash`, `submitPartnerHotel`; `TripServiceImpl` partner methods |
| Gateway routes | `src/com/mmtrip/client/WebMain.java` |
| Persistence | `TripServiceImpl.loadBookings/saveBookings/loadPartners/savePartners`; `PartnerData` |
| Catalogue | `src/com/mmtrip/server/DataStore.java` |
| Engine | `src/com/mmtrip/server/ItineraryEngine.java` |
