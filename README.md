# MSTP — Myanmar Trip Planner 🧭

A Java RMI trip-planning service with a premium cream-and-emerald editorial web client:
floating navigation, cinematic Bagan hero, floating AI trip planner, destination photo cards,
day-by-day itineraries and simulated Myanmar wallet checkout.

You pick destinations, travel dates, travellers, hotel budget and stay class. The RMI
server scores every attraction, builds a day-by-day itinerary, prices the hotel stay for each
stop (nightly price × nights × rooms) and tells you honestly whether it fits your budget. You
can then book a hotel and complete a clearly-labelled **simulated** KBZPay / WavePay / AYA Pay
checkout. There is no transport question: a mode is never asked for, priced or invented — the
plan only reports that transport advice is unavailable when it has no route data to base it on.

> **Scope note:** this repository is the RMI project you asked for — Java server, RMI client /
> HTTP gateway, and a static SPA. It is deliberately dependency-free, so the redesign is
> implemented with reusable JavaScript render functions rather than React/JSX (adding React
> would require a build step and a rewrite of working flows). The larger production blueprint
> (PostgreSQL, Next.js, server-side accounts, admin CMS) is **not** implemented here; the engine
> and API are structured so that it can be added later without rewriting the planner.
>
> Profile accounts are server-side accounts: register and sign in through `/api/auth/*`,
> with sessions stored in secure HttpOnly cookies. Payments remain simulated. Destination facts are curated sample data.
>
> **Deployment status:** Phase 4 container and backup verification is currently **BLOCKED** in this environment (no Docker daemon / Restic). No public URL is live. See `docs/PHASE4_VERIFICATION_REPORT.md`.

---

## Project status and audit

This repository is a **local demonstration**, not a production platform. A full Phase 0 audit is
in `docs/`:

| Document | Contents |
|---|---|
| `docs/ARCHITECTURE_AUDIT.md` | Current architecture, findings, target design, risks |
| `docs/FEATURE_GAP_ANALYSIS.md` | Implemented / partial / mocked / missing features |
| `docs/SECURITY_AUDIT.md` | Security findings and release gate |
| `docs/DATABASE_DESIGN.md` | `.ser` assessment and PostgreSQL migration plan |
| `docs/API_CONTRACTS.md` | Current API and proposed `/api/v1` contracts |
| `docs/IMPLEMENTATION_ROADMAP.md` | Phase 0–7 plan and first safe batch |
| `docs/TECHNICAL_DEBT.md` | Debt register and remediation batches |
| `DATABASE_SCHEMA.sql` | PostgreSQL DDL derived from the Java models |

Known limitations: traveller accounts are browser-local, partner APIs trust a client-supplied
`partnerId`, booking lookup is unauthenticated, inventory is a single counter, and payments are
simulated. Do not expose this build to the public internet or enter real personal data.

---

## Technology stack (current)

| Layer | Technology | Notes |
|---|---|---|
| Language | Java 17+ | No third-party libraries |
| Remote calls | Java RMI / JRMP | `TripService` remote interface, `UnicastRemoteObject` |
| HTTP gateway | `com.sun.net.httpserver` | JDK built-in server, static files + `/api/*` JSON |
| JSON | Hand-written `Json.java` | Dependency-free parser/writer in `com.mmtrip.client` |
| Frontend | Vanilla JavaScript (ES2020) | `web/app.js`, no framework, no build step |
| Styling | Hand-written CSS | 6 stylesheets, Google Fonts (Fraunces / Manrope) with local fallbacks |
| Catalogue data | `DataStore` (places) + `data/hotels.json` → `HotelCatalogue` | 9 destinations, 66 attractions, 82 real hotels rebuilt at startup |
| Persistence | Java serialization (`.ser`) | `data/bookings.ser`, `data/partners.ser` |
| Client state | Browser `localStorage` | Saved trips, local profile, partner session |
| Partner auth | Salted SHA-256 | Hash stored server-side; password never sent back |
| Payments | Simulated | KPAY / WAVEPAY / AYAPAY statuses only |
| Build | `javac` via batch/shell scripts | Output in `out/` |
| Database | None | No SQL, ORM, migrations or transactions |
| Tests / CI | None | Manual browser testing |

### Request path

```
web/app.js  --HTTP/JSON-->  WebMain (gateway)  --RMI-->  TripServiceImpl
                                                          |-- ItineraryEngine
                                                          |-- DataStore (catalogue)
                                                          `-- data/*.ser
```

---

## Quick start

Requirements: **JDK 17+**, a modern browser. No Maven, no npm, no database.

```bat
cd MyanmarTripPlanner
stop.bat        :: optional — stops any earlier demo instances
run.bat
```

`run.bat` compiles everything and starts:

* an embedded RMI registry + server (default 1099),
* the RMI client / web gateway (from 8080, automatically moving to the next free port),
* your default browser at the actual URL.

Two-process RMI demo (shows the real remote split):

```bat
build.bat
run-server.bat     :: terminal 1 — registry + TripService on 1099
run-client.bat     :: terminal 2 — RMI lookup + web gateway
```

macOS / Linux:

```bash
bash build.sh
bash run.sh
```

### Ports and options

| Component | Default | Override |
|---|---|---|
| RMI registry | `1099` | `-Dtrip.rmi.port=1100` on the server, `--rmi-port 1100` on the client |
| Web gateway | `8080` | `--http-port 9090` (auto-increments if busy) |
| Remote RMI host | `127.0.0.1` | `--host 192.168.1.20` |
| Browser auto-open | on | `--no-browser` |

For a server on another machine, start it with
`java -Djava.rmi.server.hostname=<server-ip> -cp out com.mmtrip.server.ServerMain`.

### Tests

```bat
tests\run-tests.bat        :: JUnit 5 unit tests (downloads the console jar once)
```

```bash
bash tests/run-tests.sh
```

Playwright smoke tests (Node 20+):

```bash
cd tests/e2e
npm install
npx playwright install chromium
npx playwright test
```

The E2E config starts the app on port 8099 in demo mode. CI runs both suites on every push
(`.github/workflows/ci.yml`).

### Database (optional, Phase 1B)

The demo still runs without a database. PostgreSQL is the foundation for Phase 1C/1D and can
be started independently:

```bat
copy env.example .env
:: edit .env and set a strong password
docker compose up -d
set MHT_DB_URL=jdbc:postgresql://localhost:5432/mstp
set MHT_DB_USER=mstp
set MHT_DB_PASSWORD=your-password
build.bat
db\migrate.bat
db\seed.bat
db\export-ser.bat --dry-run
db\export-ser.bat
```

See `docs/RUNBOOK.md` for migration, legacy `.ser` import, backup/restore and verification.
The running RMI service is **not** switched to PostgreSQL in Phase 1B; that wiring belongs to
Phase 1C/1D.

---

## The experience

### 0. Landing page

Floating white navigation, cinematic Bagan hero, a four-field quick planner docked over the
hero (multi-destination picker, dates, travellers, budget), popular destination cards,
feature strip, detailed planner, travel-guide teaser and footer.

### 1. Single-page Trip Studio

Everything is entered in one workspace — there is no step-by-step wizard.

* **Destinations** — 9 Myanmar destinations with region filter, recommended days and a nights
  stepper per stop (max 6 stops).
* **Dates** — start date and editable nights per destination.
* **Travellers & stays** — adults + children and a stay class (budget / comfort / luxury).
* **Budget** — MMK budget with quick presets, or "no limit".
* **Pace** — relaxed, balanced or packed days. There is no transport selection.
* **Optional interests** — sunrise, temples, food and similar tags that re-weight the
  attraction scoring. There is no travel-style question.

The sticky summary always shows the route, dates, travellers, hotel budget, pace and stay class.

### 2. Itinerary output

* Cinematic hero: "AI Trip Plan Generated Successfully", **Your 3-Day Bagan Adventure**,
  meta pills for days/nights, travellers, hotel cost and stay class.
* Five working tabs: **Trip Overview, Daily Itinerary, Map & Route, Hotels, Budget Breakdown**.
* Overview: day cards with date, photo, highlights, time range and "View Details"; a schematic
  route map, recommended hotel with Book Now, and a trip summary with Book This Trip.
* Daily Itinerary: every stop with time, duration, category and group entry cost.
* Map & Route: schematic Myanmar map with destination pins, route order, zoom and per-stop
  details (approximate coordinates, explicitly not for navigation).
* Hotels: all stays along the route, including partner-listed properties.
* Budget: bar against your budget, full breakdown, per-day spend, warnings and assumptions.
* Save the trip to this browser, print/save as PDF, or edit the trip settings.

### 3. Hotel-owner partner portal

Hotel owners can join MSTP and publish properties that immediately appear in customer search,
AI itinerary recommendations and the booking flow.

* Register or sign in at **For hotel owners** (footer, Hotels menu, or the Hotels page CTA).
* Partner dashboard: properties, rooms left, bookings, simulated booking value.
* Add / edit / remove a property: destination, area, address, class, stars, nightly price,
  rooms, room type, description, amenities, contact and check-in/out times.
* **Upload a real photo of your property** in the form (JPEG, PNG or WebP, ≤ 3 MB) — it is
  previewed before saving, stored in `web/images/hotels/`, and replaces the illustrated
  placeholder on your cards immediately. You can also paste an `/images/…` or `https://…` URL.
  Files are validated by their magic bytes on the server, and deleting a listing deletes its
  uploaded photo.
* Passwords are salted and hashed (SHA-256) on the RMI server; accounts and listings persist to
  `data/partners.ser`.
* Partner hotels are tagged **partner** in customer results with "Listed by …".
* **Demo partner:** `partner@mstp.demo` / `partner123` (seeded with two sample properties).

### 4. Stays, booking and demo wallets

* Real hotels per destination with class, stars, the facilities the guide notes, live rooms-left,
  price and either a credited CC photo of the property or a labelled photo of the town.
* Filters: class, maximum price, sort by price / rating / class.
* Booking form validates the guest name, Myanmar phone number, dates, nights and rooms.
* Rooms are held on the server at booking time.
* Checkout with **KBZPay**, **WavePay** or **AYA Pay** — all clearly marked as simulated.
* Booking lookup by phone; unpaid bookings can be completed later.

**Demo payment rules**

* Wallet phone must look like a Myanmar number (`09` + 7–9 digits).
* No PIN is collected or transmitted. Tick **Simulate a declined payment** to preview a decline.
* Statuses: `PENDING_PAYMENT` → `CONFIRMED`. Transactions are stored in `data/bookings.ser`.
* Delete `data/bookings.ser` (with the server stopped) to reset demo data.

---

## Cost model (all figures MMK)

| Item | How it is priced |
|---|---|
| Hotel stays | Nightly price of a listed hotel in the chosen class × nights × rooms (`ceil(travellers / 2)`) |
| Total | Sum of the stays only, compared with the budget |

All money is integer MMK. Hotel stays are the **only** priced item: food, activities,
shopping and transport are deliberately never estimated or added to a total. The itinerary
rings up `nightly price × nights × rooms` per stop and shows the formula in the Budget tab.

## Itinerary engine

For each destination the engine:

1. Scores attractions by rating, optional interests and sunrise/sunset preference.
2. Removes premium experiences (over 100,000 MMK entry) from the auto-plan — they appear as extras.
3. Picks up to five stops per day within the pace budget.
4. Schedules them chronologically from each attraction's recommended time of day, starting
   after arrival/transfer, with travel buffers and lunch on full days.
5. Adds arrival days, transfer mornings and check-out afternoons. A transfer day reserves a
   half-day for the move but never predicts a mode or a travel time.
6. Assigns dinner from the destination's food spots, then prices the hotel stays only.

Transport is not an input. The engine reports `transportRecommendation = "NONE"` for a
single-destination trip and `"UNAVAILABLE"` for a multi-stop route, with a note explaining that
no route, road or timetable data is connected — it never invents a mode or a duration.

Validation: 1–6 destinations, 1–10 nights each, ≤ 21 nights, 1–20 adults, 0–10 children.

## Verified sample data

Nine destinations, 66 attractions and 82 hotels that really exist, taken from the Wikivoyage sleep
guides for each town:

Bagan · Yangon · Mandalay · Inle Lake · Ngapali Beach · Bago · Hpa-An ·
Pyin Oo Lwin · Kyaiktiyo Golden Rock.

Attraction opening times, fees and seasons are curated demo data for this project — not live
supplier data.

Hotel data is different: names, areas and the indicative nightly rate come from the Wikivoyage
`Sleep` listing for each town (`data/hotels.json`, one `source` URL per hotel). Everything else about
a hotel — class label, rooms on sale, availability and the booking flow — is demo data.

Per-town counts vary because they are the properties the guides actually document: Bagan, Yangon,
Mandalay, Inle, Ngapali, Kyaiktiyo and Pyin Oo Lwin have 10 each, Hpa-An has 8 and Bago has 4. No
hotels are invented to fill a quota.

Photos: a photo of the exact property is bundled in `web/images/hotels/` and shown with its
credit and source (`web/images/hotels/CREDITS.json`) for 74 of the 82 hotels. Most are CC-licensed;
the rest were sourced from the web for this school project and are marked "Educational use" in
the credits. The remaining 8 carry `areaPhoto`, a real photo of the town (curated town shots live
in `web/images/areas/` with credits in `areas/CREDITS.json`), rendered as a duotone banner
labelled **City photo** (tooltip: "…not of this property"), so no card is blank and nothing
pretends to be the hotel. No photo is ever presented as a property it does not depict. Owners add
their own photo through the partner form, which then replaces the banner.

---

## Architecture

```
Browser (dark SPA)
   │ fetch /api/*
   ▼
WebMain  ── Java RMI (JRMP) ──▶  TripServiceImpl
  · JSON gateway                    · ItineraryEngine (scoring + scheduling + pricing)
  · static files                    · DataStore (destinations, places, hotels)
  · auto port selection             · bookings + simulated payments
  · opens browser                   · data/bookings.ser persistence
```

* `com.mmtrip.common` — remote interface and serializable models
  (`TripRequest`, `Itinerary`, `DayPlan`, `Activity`, `Destination`, `Place`, `Hotel`,
  `Booking`, `PaymentResult`).
* `com.mmtrip.server` — `ServerMain`, `TripServiceImpl`, `ItineraryEngine`, `DataStore`.
* `com.mmtrip.client` — `WebMain` (RMI lookup, `com.sun.net.httpserver` JSON API, static server,
  browser launch) and `Json` (dependency-free parser/writer).
* `web/` — `index.html`, `style.css`, `app.js` (no framework, no build step, Google Fonts with
  local fallbacks).

### JSON API

| Method | Path | Description |
|---|---|---|
| GET | `/api/health` | Gateway/service status |
| GET | `/api/destinations` | Destinations with all places |
| GET | `/api/hotels?destinationId=bagan` | Hotels for a destination (omit for all) |
| POST | `/api/itinerary` | Generate an itinerary |
| POST | `/api/bookings` | Create a booking and hold rooms |
| POST | `/api/pay` | Simulated wallet payment |
| GET | `/api/bookings?phone=09...` | Bookings for a phone |
| POST | `/api/partner/register` | Create a hotel-owner account |
| POST | `/api/partner/login` | Partner sign-in |
| GET | `/api/partner/hotels?partnerId=...` | Properties owned by a partner |
| POST / PUT | `/api/partner/hotels` | Publish or update a property |
| DELETE | `/api/partner/hotels?partnerId=...&id=...` | Remove a property |
| GET | `/api/partner/bookings?partnerId=...` | Bookings for a partner's rooms |

Itinerary request:

```json
{
  "destinationIds": ["yangon", "bagan", "inle"],
  "days": [1, 3, 2],
  "interests": ["temple", "food", "sunset"],
  "adults": 2,
  "children": 1,
  "budget": 900000,
  "hotelTier": "mid",
  "pace": "balanced",
  "startDate": "2026-12-05"
}
```

Payment request:

```json
{ "bookingId": "BK-1A2B3C", "method": "AYAPAY", "walletPhone": "09771234567", "pin": "1234" }
```

Methods: `KPAY`, `WAVEPAY`, `AYAPAY`.

---

## Project layout

```
MyanmarTripPlanner/
├── build.bat / build.sh
├── run.bat / run.sh              one command, opens the browser
├── run-all.bat                   server + gateway in two consoles
├── run-server.bat / run-client.bat
├── stop.bat                      stops only this project's Java processes
├── src/com/mmtrip/common/        RMI contract + models (incl. Partner)
├── src/com/mmtrip/server/        engine, data, service, launcher
├── src/com/mmtrip/client/        gateway, JSON, launcher
├── web/                          index.html, style.css, app.js
├── data/bookings.ser             created at runtime
├── data/partners.ser             partner accounts, hashes & owner hotels
└── out/                          compiled classes
```

## Design

* Palette: warm cream paper (`#f8f2e6`), deep emerald (`#14503f`), golden amber (`#d9a53a`),
  ink (`#17251f`). Light, editorial, premium.
* Floating white pill navigation with emerald active pills and a gold Sign Up button.
* Cinematic Bagan hero with a left emerald veil, italic gold display type and a script accent.
* Floating planner card with tab strip, four compact fields and a green "Generate Trip" action.
* Display type: Fraunces. UI type: Manrope.
* Destination cards use real Myanmar photography where it is available (Wikimedia Commons),
  with a hand-built SVG scene as an automatic fallback if a file cannot load — so the UI never
  shows a broken image. Add your own photos with `window.MSTP_PHOTOS = { bagan: '/images/bagan.jpg' }`
  before `app.js`, or edit the `PHOTOS` map.
* Hotel cards use bespoke emerald-and-gold poster artwork (arches, monograms, stars) instead of
  repeating one destination photo.
* Responsive: 6→3→1 step rail, 5→3→1 destination grid, 3→2→1 hotel grid, stacked itinerary
  sidebar, two-column mobile planner, slide-down mobile menu, print stylesheet.
* Pages: Home, Destinations (search + region filters + detail modal), Itinerary, Hotels,
  Bookings/Saved trips, Travel Guide, About, plus search, auth and booking modals.

## Troubleshooting

* **Port busy** — the gateway automatically takes the next free port and prints it.
  For RMI, use `-Dtrip.rmi.port=1100` on the server and `--rmi-port 1100` on the client.
* **UI shows “offline”** — the RMI server is not running; run `run-server.bat` or `run.bat`.
* **Old UI after an update** — hard refresh (`Ctrl+F5`); static assets are served `no-cache`.
* **Reset bookings** — stop the server and delete `data/bookings.ser`.
* **Remote host** — set `java.rmi.server.hostname` on the server and open the RMI ports.
