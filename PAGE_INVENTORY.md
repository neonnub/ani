# MSTP — Page and Surface Inventory

**Audit date:** 12 November 2026  
**Scope:** Every live page, overlay, modal, form and navigation path in the current repository.

This inventory describes what the browser actually renders from `web/index.html` and `web/app.js`. It does not repeat the six-step wizard described by the README, because that wizard has no matching DOM and is not reachable.

---

## 1. Application shell

The SPA has one HTML document and eight `.view` sections. Exactly one view has `.is-active` at a time. There is no URL router, hash router, History API integration or server-side page rendering. Every view shares the root URL, and a refresh returns to Home.

### 1.1 Header navigation

| Element | Type | Action | Destination |
|---|---|---|---|
| Brand mark + “MSTP” | link | `data-go="home"` | Home view |
| Home | link | `data-go="home"` | Home view |
| Destinations | button + dropdown | opens hover/focus menu | — |
| All destinations | link | `data-go="destinations"` | Destinations view |
| Detailed planner | link | `data-scroll="planner"` | Home, Trip Studio anchor |
| My itinerary | link | `data-go="itinerary"` | Itinerary view, or Home with toast if no itinerary |
| Saved trips | link | `data-go="bookings"` | Bookings view |
| Hotels | button + dropdown | opens hover/focus menu | — |
| Find a stay | link | `data-go="hotels"` | Hotels view |
| List your hotel | link | `data-go="partner"` | Partner view |
| Travel Guide | link | `data-go="guide"` | Guide view |
| About | link | `data-go="about"` | About view |
| Search icon | button | `#searchBtn` | Global search modal |
| Login | button | `#loginBtn` | Login modal |
| Sign Up | button | `#signupBtn` | Sign-up modal |
| Account avatar/name | button | `#accountBtn` | Local account panel |
| Mobile menu toggle | button | `#mobileToggle` | Expands mobile navigation |
| Mobile Login / Sign Up | buttons | `#mobileLogin`, `#mobileSignup` | Auth modals |
| Mobile My account | button | `#mobileAccount` | Local account panel |

Navigation is duplicated in a mobile menu (`#mobileMenu`, `#mobileAuth`) with the same destinations plus “Plan Trip”.

### 1.2 Footer

Links: Destinations, Plan a trip, Hotels, For hotel owners, Travel guide, My bookings, About.  
Note text: demo project, simulated payments, curated sample destination data.  
No newsletter, legal, privacy, terms, contact or social links exist.

### 1.3 Global overlays

| Surface | ID | Purpose | Controls |
|---|---|---|---|
| Chat launcher | `#chatFab` | Opens the assistant panel | Toggle panel |
| Chat panel | `#chatPanel` | Static shortcut menu, not an AI chat | Plan a trip, Find a hotel, My bookings, Travel guide, Close |
| Toast | `#toast` | Transient success/error message, 3.4 s | None |
| Modal shell | `#modal` | Hosts all dialogs | Backdrop click, close button, Escape |
| Search modal | dynamic | Destination search | Query input, result buttons |
| Itinerary help button | `#itHelp` | Opens the same chat panel | Open panel |

The chat panel explicitly states that no live agent is connected. It has no message input, conversation history or assistant response logic.

---

## 2. Home view (`#view-home`)

**Purpose:** Marketing landing page, compact planner entry and full one-page Trip Studio.

**Entry points:** Initial load, brand, Home nav link, chat “Plan a trip”, footer “Plan a trip”, any `data-go="home"`, and itinerary “Edit trip”.

### 2.1 Hero

| Control | Type | Action |
|---|---|---|
| “Start Planning” | button | Scrolls to `#planner`; switches Home first if needed |
| Hero photograph | image | Local `images/hero-bagan.jpg`; falls back to a Wikimedia URL, then removes itself |
| Floating planner tabs — AI Trip Planner | tab | Focuses the destination picker; stays on Home |
| Floating planner tabs — Find Destinations | tab | Switches to Destinations view |
| Floating planner tabs — Book Hotels | tab | Switches to Hotels view |
| Floating planner tabs — Travel Guide | tab | Switches to Guide view |

### 2.2 Compact planner form (`#plannerFloat`)

| Field | ID | Behaviour | API use |
|---|---|---|---|
| Destination | `quickDestBtn`, `quickPicker` | Opens a nine-destination checklist; toggles up to six destinations; shows “Done” | None |
| Travel dates | `quickDateBtn`, `quickDate` | Native date picker; changes `state.startDate`; end date is auto-derived | None |
| Travellers | `quickTravelersBtn`, `quickTravelersPanel` | Adults 1–12, children 0–10 | None |
| Budget (MMK) | `quickBudget` | Digits only, formatted with commas, capped at 9 digits | Sent to itinerary API |
| Generate Trip | `quickGenerate` | Validates at least one destination, disables button, calls itinerary API | `POST /api/itinerary` |

The compact form and full studio edit the same global state. Changes in one are reflected in the other.

### 2.3 Popular destinations

Five featured cards: Bagan, Inle Lake, Yangon, Ngapali and Kyaiktiyo.  
Each card opens the destination detail modal. “View All Destinations” switches to the Destinations view.

### 2.4 Feature strip

Five buttons:

- Smart Itinerary with AI → planner anchor.
- Interactive Travel Guide → Guide view.
- Hotel Booking & Easy Payment → Hotels view.
- Trusted & Secure Platform → About view.
- 24/7 Support → About view.

The security and 24/7 support claims are marketing copy; the application has no support channel, security certification or round-the-clock service.

### 2.5 Trip Studio (`#plannerStudio`)

Rendered by `renderPlannerStudio()`. All controls are live.

**Trip overview card**

| Control | ID / selector | Constraints |
|---|---|---|
| Trip title | `#studioTitle` | Free text; updates summary title |
| Start date | `#studioStart` | Native date; changing it auto-adjusts end date if untouched |
| End date | `#studioEnd` | Native date; marks end date as manually touched; total days clamped to 21 |
| Adults | `[data-studio-count="adults"]` | 1–12 |
| Children | `[data-studio-count="children"]` | 0–10 |
| Budget | `#studioBudget` | Numeric, interpreted in selected display currency, stored in MMK |
| Display currency | `#studioCurrency` | MMK, USD, EUR, THB, SGD, GBP at fixed indicative rates |
| Travel style | `[data-studio-style]` | Cultural, Adventure, Relaxation, Foodie, Photography, Family |
| Transport | `[data-studio-transport]` | Private car, Express bus, Domestic flight, Boat & ferry, Mixed |
| Pace | `[data-studio-pace]` | Relaxed, Balanced, Packed |
| Interests | `[data-studio-interest]` | Nine toggles: temples, culture, nature, beaches, food, markets, adventure, sunrise, sunset |

The studio does not expose a hotel-tier selector, although `state.hotelTier` exists and is sent to the engine. It remains at its default (“mid”).

**Your route card**

- Numbered stop list with drag handle.
- Up/down buttons reorder stops.
- Remove button deletes a stop.
- Shows allocated days per stop.
- Warning when the selected date range exceeds 21 days (the date inputs clamp totalDays to 21, so this warning is largely unreachable).

**Add destinations card**

- Search field `#studioSearch` filters by destination name, Myanmar name, region, tagline and attraction names.
- Result cards show recommended days and an Add/Remove button.
- Selection is capped at six by `toggleDestination()`.

**Route map card**

- Leaflet map when the library loads; built-in SVG schematic when it does not.
- Straight dashed polyline between destination coordinates.
- Distance and travel time are Haversine estimates with fixed speeds, not road routing.
- Origin and destination markers with popups.
- Explicit note that this is not a navigation service.

**Trip summary sidebar**

- Route stop count, dates, duration, travellers, budget, style, transport, pace.
- Route estimate (km and hours).
- “Generate My Trip” button.
- Weather-unavailable note.
- Note about activity editing and regeneration.

**API/model:** `POST /api/itinerary` with `TripRequest`; response `Itinerary`.

### 2.6 Guide teaser

Three guide cards plus “All guides”. Each card opens the corresponding guide modal.

---

## 3. Destinations view (`#view-destinations`)

**Purpose:** Browse, filter and search the destination catalogue; open destination details; add a destination or jump to stays.

### 3.1 Controls

| Control | ID | Behaviour |
|---|---|---|
| Region chips | `#destRegionTabs` | “All Myanmar” plus nine regions, derived from server data |
| Search | `#destSearch` | Filters destination names, Myanmar names, regions, taglines and attraction names |
| Destination card | `[data-dest]` | Opens detail modal; keyboard Enter/Space supported |
| Empty state | `#destPageGrid` | “No destinations match that search.” |

### 3.2 Destination detail modal

Contents:

- Hero scene/photo, region, Myanmar name, destination name.
- Description.
- Facts: region, best season, suggested days and stop count.
- Up to nine highlights with category, hours and entry fee.
- “Add to my trip” button.
- “Find stays” button.

Actions:

- Add to my trip → adds destination with its recommended days, closes modal, switches Home, scrolls to planner.
- Find stays → closes modal, opens Hotels view filtered to that destination.
- Close → backdrop, close button or Escape.

**API/model:** destination data from `GET /api/destinations` (`Destination`, `Place`); no write calls.

---

## 4. Itinerary view (`#view-itinerary`)

**Purpose:** Present, edit, save, print, export and regenerate the generated trip.

**Entry condition:** Requires `state.itinerary`. If absent, navigation shows “Generate an itinerary first” and returns Home.

The view has a hero with headline, subtitle, four meta tiles (days/nights, travellers, estimated budget, travel style), and a decorative script overlay.

### 4.1 Toolbar

| Control | ID | Action |
|---|---|---|
| Trip Overview tab | `[data-ittab="overview"]` | Overview panel |
| Daily Itinerary tab | `[data-ittab="daily"]` | Timeline panel |
| Map & Route tab | `[data-ittab="map"]` | Full map panel |
| Hotels tab | `[data-ittab="hotels"]` | Route hotel panel |
| Budget tab | `[data-ittab="budget"]` | Budget panels |
| Save trip | `#saveTrip` | Saves snapshot to localStorage; changes label to “Saved” |
| Print | `#printTrip` | Browser print dialog |
| Export | `#exportTrip` | Downloads the itinerary object as JSON |
| Regenerate | `#regenTrip` | Requests a fresh whole itinerary with `variation + 1` |
| Edit trip | `data-go="home"` | Returns Home; no direct scroll to planner |

There is no delete-trip, share, duplicate, PDF-specific export, autosave or undo action.

### 4.2 Trip Overview panel

- Day cards: day number, date, theme, up to three sights, time range, active hours, “Weather unavailable” chip, “View Details”, “Regenerate”.
- Mini route map with “View Full Map”.
- Recommended hotels panel with “See All”.
- Trip summary panel with destinations, duration, travellers, total budget, “Book This Trip”, Save, Print and Edit trip.

“View Details” opens the Daily tab and scrolls to that day.  
“Regenerate” replaces that day after a server call.  
“Book This Trip” only navigates to the Hotels view; it does not book the itinerary or all stays.

**API/model:** itinerary from `POST /api/itinerary` (`Itinerary`, `DayPlan`, `Activity`); hotels from `GET /api/hotels`.

### 4.3 Daily Itinerary panel

Each day card contains:

- Day header, date, destination, active hours, daily cost.
- Weather-unavailable chip.
- “Regenerate day” and “+ Add activity”.
- Activity rows with time, title, description, slot, hours, category, optional entry cost, Edit and Remove.
- Drag grip for reordering within the same day.

Activities are draggable. Drop retimes the whole day from 08:00 with 30-minute gaps and recalculates costs. Cross-day drag is rejected.

**Activity editor modal**

Fields: title, time, duration (0.25–12 h), category (Temple, Culture, Market, Nature, Adventure, Beach, Food, Transfer, Leisure), group cost (MMK), description.  
Actions: Save activity, close.  
No validation beyond title presence and HTML input constraints.

**Add activity modal**

Lists catalogue attractions for the day's destination that are not already in the day.  
“+ Add” inserts the place after the last activity, computes time and cost from the place and traveller count, recalculates, closes and refreshes.  
Empty state when all catalogue attractions are already present.

**Sidebar**

- Budget panel: estimate, budget comparison, category rows, per-person and per-day figures, warnings.
- “Good to know” tips.
- “Find stays for this route” → Hotels view.

### 4.4 Map & Route panel

- Large Leaflet map with numbered markers and a straight dashed route.
- SVG schematic fallback when Leaflet is missing or the container is hidden.
- Destination list beneath the map.
- Zoom in/out buttons (`data-mapzoom`) adjust the schematic zoom state; these are not native Leaflet controls.
- Text explicitly calls the route schematic/approximate.

No road geometry, turn-by-turn directions, traffic, travel modes per leg or route alternatives exist.

### 4.5 Hotels panel

Fetches hotels for every destination in the itinerary, cached in `state.routeHotels`.  
Cards show the same hotel information as the main Hotels view and a booking button.  
“All stays” opens the Hotels view.

**API/model:** `GET /api/hotels?destinationId=...` per destination; `Hotel`.

### 4.6 Budget panel

Two panels:

1. Donut and legend for stays, transport, food and activities; total versus budget; percentage; spare/over; category rows; per-person and per-group-day figures; warnings.
2. Daily spend list with each day's destination and cost, plus a summed total.

Budget recalculates locally after activity edits using stored food and transport totals. It does not reprice stays or long-distance transport from first principles.

### 4.7 Extra places

If the engine returned `extraPlaces`, an “Also worth a stop” grid shows up to nine cards. Hidden when empty. No interaction beyond reading.

---

## 5. Hotels view (`#view-hotels`)

**Purpose:** Browse stays by destination, filter and sort, and start a booking.

### 5.1 Controls

| Control | ID | Behaviour |
|---|---|---|
| City tabs | `#hotelTabs` | Itinerary destinations first, then remaining catalogue destinations |
| Class chips | `#hotelTiers` | All classes, Budget, Comfort, Luxury |
| Max price slider | `#hotelPrice` | 30,000–350,000 MMK, step 10,000; 350,000 displays “Any” |
| Sort select | `#hotelSort` | Price low→high, rating high→low, class high→low |
| Hotel card | dynamic | Shows visual, area/destination, partner label, name, description, amenities, owner, price, rooms left, rating, “Book stay” |
| List your hotel | button | Partner view |

City tab selection calls `GET /api/hotels?destinationId=...`; changing filters only re-renders the loaded list. “Rooms left” is a single counter from the server, not date-specific availability.

### 5.2 Booking modal

Two-column sheet: hotel summary and guest form.

| Field | ID | Validation |
|---|---|---|
| Guest name | `#guestName` | Prefilled from local profile; at least 2 characters client-side; server repeats |
| Phone | `#guestPhone` | Client requires required field only; server normalizes to `09` + 7–9 digits |
| Check-in | `#checkIn` | Prefilled from itinerary start date; minimum today |
| Nights | `#nights` | 1–30; prefilled from `nightsPerDestination` when the hotel is in the itinerary |
| Rooms | `#rooms` | 1–10 and not more than rooms left |
| Total preview | `#bookingTotal`, `#totalBreak` | Recomputes on input |
| Continue to payment | submit | `POST /api/bookings`; returns 201 `Booking` |

The modal states rooms are held immediately and mentions a 48-hour demo cancellation policy. No cancellation or expiry process exists.

### 5.3 Payment modal

| Control | ID | Behaviour |
|---|---|---|
| KBZPay / WavePay / AYA Pay | radio group | Selects simulated wallet; visual selection only |
| Wallet phone | `#walletPhone` | Prefilled from booking phone; client regex permits digits, plus, spaces, hyphen, min 7 characters |
| Demo PIN | `#pin` | Password input, numeric only, 4–6 digits |
| Pay (demo) | submit | `POST /api/pay` |
| Error area | `#payError` | Displays server or client message |

A processing modal replaces the form during the request. Success opens a receipt modal. Declined payment or a transport error reopens the payment form and attempts to display the message.

**Known defect:** HTTP 402 is converted to an exception by `api()` before `PaymentResult` is read, so the specific decline reason is replaced by “Request failed (402)”. The later catch path displays that generic string.

### 5.4 Receipt modal

Shows booking reference, hotel, destination, guest, check-in/out, rooms/nights, wallet and transaction reference, simulated timestamp and total.  
Actions: “View my bookings” and “Done”.  
Marked as a demo receipt. No download, email, invoice or print action.

---

## 6. Bookings view (`#view-bookings`)

**Purpose:** Local saved trips plus server booking lookup.

### 6.1 Saved trips panel

| Control | ID | Action |
|---|---|---|
| Saved count | `#savedCount` | Shows number saved |
| Saved card | dynamic | Title, summary, saved date |
| Open | `[data-opensaved]` | Loads snapshot into itinerary state and opens Itinerary view |
| Remove | `[data-delsaved]` | Deletes from localStorage and re-renders |
| Empty state | `#savedTrips` | Prompt to generate and save a trip |

Saved trips are browser-local only and capped at eight on write. There is no confirmation before removal and no cross-device sync.

### 6.2 Booking lookup panel

| Control | ID | Behaviour |
|---|---|---|
| Phone | `#lookupPhone` | `tel` input, no client format validation |
| Find my bookings | submit | `GET /api/bookings?phone=...` |
| Result list | `#bookingList` | Cards with hotel, destination, guest, phone, status, reference, dates, total |
| Complete demo payment | button on pending booking | Opens payment modal with the serialized booking object |
| Confirmed row | static | Shows wallet label and transaction reference |

There is no authentication, OTP or booking-reference requirement. An empty phone query is rejected by the frontend; a direct API call without `phone` returns all bookings.

---

## 7. Travel Guide view (`#view-guide`)

**Purpose:** Six static editorial guides.

Cards: Best time to visit, Money & wallets, Getting around, Temple etiquette, What to eat, Health & safety.

Each opens a modal with tag, title, two paragraphs, a bullet list, “Plan a trip” and “Close”.  
Guide content is hard-coded in `app.js`; it is not server data, CMS-managed or localised.  
No search, category filter, bookmark, feedback or date-updated indicator exists.

---

## 8. Partner view (`#view-partner`)

**Purpose:** Hotel-owner registration, login and property/bookings dashboard.

### 8.1 Marketing hero

Headline, description and three claims: free to list, live in customer search, bookings and demo payouts.  
No separate CTA because the auth/dashboard area follows immediately.

### 8.2 Logged-out state (`#partnerArea`)

Tabs: “Join MSTP” and “Partner login”.

**Join form**

| Field | ID | Validation |
|---|---|---|
| Owner/business name | `#pName` | Min 2 characters client; min 2 server |
| Email | `#pEmail` | Email regex client and server; server lowercases |
| Myanmar phone | `#pPhone` | Required client; server normalizes |
| Password | `#pPass` | Min 6 client and server |

Submit → `POST /api/partner/register`. Success stores the returned `Partner` in localStorage and renders the dashboard.  
The page displays a demo partner login in plain text. Those values are intentionally omitted from this audit.

**Login form**

Email and password fields; submit → `POST /api/partner/login`.  
No “forgot password”, email verification, lockout, MFA or account recovery exists.

### 8.3 Dashboard

| Area | Content/actions |
|---|---|
| Header | Owner name, email, phone, join date, “Add a property”, “Sign out” |
| Stats | Properties, rooms left, bookings, confirmed count, demo booking value |
| Properties | Cards with visual, area, destination, name, stars, description, price, rooms left/total, room type |
| Property actions | Edit, Remove, View in customer site |
| Bookings | Guest name, phone, stay dates, total, paid/pending status |
| Footer note | Explains listings are stored by the RMI server and payments are simulated |

**Add/Edit property modal**

Fields: hotel name, destination select, township/area, street address, class, stars, price/night, rooms, room type, contact phone, description, amenities, check-in time, check-out time.  
Submit → `POST /api/partner/hotels` (create) or `PUT /api/partner/hotels` (edit).  
Client validates description length only; server validates name, destination, price, rooms, tier and description.

**Delete confirmation modal**

Shows property name and warns it disappears from customer search and recommendations.  
Confirm → `DELETE /api/partner/hotels?partnerId=...&id=...`.  
No check for existing bookings; orphaned bookings remain.

**Authorization:** The dashboard is rendered from a `Partner` object in localStorage. Every read/write sends `partnerId` as a query or body field. There is no session token, cookie or server-side proof that the caller owns that partner ID.

---

## 9. About view (`#view-about`)

**Purpose:** Explain the planner, cost estimates, simulated payments and architecture; show demo guidance.

Content:

- Four cards: How the planner works, Honest numbers, Simulated payments, Architecture.
- Demo credentials block: payment PIN guidance and phone format; profile accounts noted as browser-local.
- “Plan a trip now” button → planner anchor.

The “no PIN is transmitted” claim is inaccurate: the PIN is sent to the gateway and RMI service for validation, though no wallet provider receives it. The audit deliberately does not reproduce the displayed demo PIN values.

No contact form, company information, legal pages, accessibility statement or privacy policy exists.

---

## 10. Modal and overlay inventory

| # | Surface | Trigger | Key controls | API |
|---|---|---|---|---|
| 1 | Local account panel | Account button | My trips & bookings, Hotel owner dashboard, Sign out | None |
| 2 | Login / Sign Up | Login/Sign Up buttons | Name, email, password, mode tabs, submit | None |
| 3 | Destination detail | Any destination card | Add to my trip, Find stays, Close | None |
| 4 | Activity editor | Edit on an activity | Title, time, duration, category, cost, description, Save | None |
| 5 | Add activity | “+ Add activity” | Catalogue place buttons | None |
| 6 | Guide sheet | Guide card | Plan a trip, Close | None |
| 7 | Booking sheet | “Book stay” | Guest name, phone, check-in, nights, rooms, total, Continue | `POST /api/bookings` |
| 8 | Payment sheet | Booking created / pending booking | Wallet radios, wallet phone, PIN, Pay | `POST /api/pay` |
| 9 | Payment processing | Payment submit | None (spinner) | — |
| 10 | Receipt | Successful payment | View my bookings, Done | None |
| 11 | Partner property form | Add/Edit property | All property fields, Publish/Save | `POST`/`PUT /api/partner/hotels` |
| 12 | Partner delete confirmation | Remove property | Remove property, Keep it listed | `DELETE /api/partner/hotels` |
| 13 | Global search | Header search | Query input, destination results | None (client filter) |

All modals use the same shell, support Escape and backdrop close, and do not trap focus or restore focus to the invoking control.

---

## 11. Dead, orphaned and unreachable surfaces

These are present in source but not part of the live page inventory:

| Item | Location | Status |
|---|---|---|
| Six-step planner wizard | `app.js` functions `renderWizard`, `renderRail`, `stepPanel`, `goNext`, `updateBrief`; event branches `data-stepgoto`, `data-next`, `data-prev`, `data-brief-cta`, `data-tier`, `data-transport`, `data-pace`, `data-style`, `data-interest`, `data-count`, `data-preset`, `#generateBtn` | Dead: `#wizardPanel` and `#wizardRail` do not exist |
| Planner draft persistence | `persistDraft`, `loadDraft` | Dead: never called |
| Itinerary draft persistence | `persistItinerary`, `loadItineraryDraft` | Dead: never called |
| Orphan studio redesign | `web/_studio_block.js` | Not loaded by `index.html` |
| Orphan itinerary redesign | `web/_itinerary_block.js` | Not loaded by `index.html` |
| Map stylesheet | root-level `map.css` | Not loaded |
| Weather and route-plan gateway | `/api/engine/weather`, `/api/route-plan` | Implemented but never called by the frontend |
| Chat conversation | `#chatPanel` | Static shortcut panel only |

---

## 12. Navigation matrix

| From | To | Mechanism |
|---|---|---|
| Any view | Home | Brand, Home nav, footer, `data-go="home"` |
| Any view | Destinations | Nav, dropdown, footer, feature strip? (tab), chat? no |
| Home | Planner | Hero CTA, feature strip, nav dropdown, footer |
| Home | Itinerary | Nav dropdown only; blocked unless an itinerary exists |
| Destinations | Destination detail | Card click or keyboard |
| Destination detail | Home planner | Add to my trip |
| Destination detail | Hotels | Find stays |
| Home planner | Itinerary | Generate success |
| Itinerary | Hotels | Toolbar? no; “Find stays”, “Book This Trip”, “See All”, “All stays” |
| Itinerary | Home | Edit trip |
| Hotels | Booking modal | Book stay |
| Booking modal | Payment modal | Continue to payment |
| Payment modal | Receipt | Successful demo payment |
| Receipt | Bookings | View my bookings |
| Bookings | Itinerary | Open saved trip |
| Any view | Partner | Nav, dropdown, footer, Hotels “List your hotel” |
| Partner dashboard | Hotels | View in customer site |
| Any view | Guide | Nav, footer, feature strip, home teaser |
| Guide modal | Home planner | Plan a trip |
| Any view | About | Nav, feature strip |
| About | Home planner | Plan a trip now |
| Header | Search modal | Search icon |
| Search result | Destination detail | Result button |

No navigation path exposes a URL that can be bookmarked, shared or opened directly.

---

## 13. Page-level API summary

| View / surface | APIs called | Models involved |
|---|---|---|
| App init | `GET /api/destinations`, `GET /api/hotels` | `Destination`, `Place`, `Hotel` |
| Home planner | `POST /api/itinerary` | `TripRequest`, `Itinerary` |
| Home recommended hotels (itinerary overview) | `GET /api/hotels?destinationId=...` | `Hotel` |
| Itinerary route hotels | `GET /api/hotels?destinationId=...` | `Hotel` |
| Itinerary regeneration | `POST /api/itinerary` | `TripRequest`, `Itinerary` |
| Hotels | `GET /api/hotels?destinationId=...` | `Hotel` |
| Booking | `POST /api/bookings` | `Booking` |
| Payment | `POST /api/pay` | `PaymentResult`, `Booking` |
| Booking lookup | `GET /api/bookings?phone=...` | `Booking[]` |
| Partner register/login | `POST /api/partner/register`, `POST /api/partner/login` | `Partner` |
| Partner dashboard | `GET /api/partner/hotels?partnerId=...`, `GET /api/partner/bookings?partnerId=...` | `Hotel[]`, `Booking[]` |
| Partner property save/delete | `POST`/`PUT`/`DELETE /api/partner/hotels` | `Hotel` |
| Global search | None | Client-side `Destination` data |
| Guides / About / auth | None | Static/client-local |

No live page calls `/api/engine/weather` or `/api/route-plan`.
