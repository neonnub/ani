# MSTP — User Workflows

**Audit date:** 12 November 2026  
**Scope:** End-to-end journeys for travellers, bookers and hotel partners, including failure paths.

Each workflow records what the user sees, what the client does, what the server does and where the flow breaks. No demo credential values are reproduced.

---

## 1. Workflow map

```text
Discover
  Home hero / popular cards / destinations page / search modal
      |
      v
Plan
  Quick planner or one-page Trip Studio
      |
      v
Generate itinerary
  POST /api/itinerary -> deterministic engine
      |
      v
Review and edit
  Overview / Daily / Map / Hotels / Budget
      |
      +--> Save in browser
      +--> Print / export JSON
      +--> Regenerate day or whole trip
      |
      v
Book a hotel
  Hotels page or itinerary hotel tab -> Booking modal
      |
      v
Hold rooms
  POST /api/bookings -> roomsLeft decremented, status PENDING_PAYMENT
      |
      v
Simulated payment
  POST /api/pay -> CONFIRMED + receipt, or decline
      |
      v
Look up booking
  Bookings page -> phone lookup (unauthenticated)

Hotel partner
  Partner page -> register/login -> dashboard -> create/edit/delete property
      -> bookings for owned properties
```

---

## 2. First visit and app start

### Happy path

1. User opens `http://localhost:8080` (or the selected fallback port).
2. `DOMContentLoaded` calls `init()`.
3. Browser loads saved trips, local profile and partner object from localStorage.
4. Event handlers are wired.
5. Two API calls run in parallel: `GET /api/destinations` and `GET /api/hotels`.
6. On success, the app renders navigation auth state, popular destinations, the Trip Studio, guide teaser and grid, destinations page, saved trips and synced quick fields.
7. Home is active. No URL fragment or history entry identifies the state.

### Failure path

If either catalogue call fails, the user sees the toast “Trip server unavailable — start the RMI server first.” The shell still renders, but destination and hotel content are empty. There is no retry button, offline message page or diagnostics panel.

### Notes

- A refresh always returns to Home.
- The browser Back button does not move between SPA views.
- The header search, chat launcher and auth controls remain available without catalogue data, but most flows depend on it.

---

## 3. Destination discovery

### 3.1 Browse from Home

1. User clicks a popular destination card.
2. `openDestination(id)` finds the destination in local state.
3. A modal shows description, region, season, suggested days, highlights and actions.

### 3.2 Browse the catalogue

1. User opens Destinations from the header or footer.
2. Region chips are derived from distinct server regions.
3. User selects a region and/or types a query.
4. The grid filters by destination name, Myanmar name, region, tagline or attraction name.
5. Empty state appears when nothing matches.

### 3.3 Global search

1. User clicks the header search icon.
2. Modal opens and focuses the query field.
3. Results are destination rows, even when the match came from an attraction name.
4. Clicking a result opens that destination's detail modal.

**Gap:** The placeholder says “Destination or attraction”, but individual attractions are not listed as results.

### 3.4 Add a destination to the trip

1. In the detail modal, user clicks “Add to my trip”.
2. If not already selected, the destination is added with its `recommendedDays`.
3. `state.step` is set to 2 even though the live studio has no steps.
4. Modal closes, Home becomes active and the planner scrolls into view.
5. The destination appears in the route and destination grid.

**Alternative:** “Find stays” closes the modal, sets the hotel city and opens the Hotels view.

---

## 4. Building a trip

There are two entry surfaces into the same planner state: the compact hero form and the one-page Trip Studio.

### 4.1 Compact planner

1. User selects destinations through the checklist. The picker shows “x of 6 selected”.
2. User picks a start date. The app does not ask for an end date here; the studio derives it.
3. User adjusts adults and children.
4. User enters a budget in MMK.
5. User clicks “Generate Trip”.
6. Client validates at least one destination; if none, it shows a toast and re-syncs fields.
7. Budget is parsed from digits only.
8. Button disables and shows a spinner.
9. `generateItinerary({ fromQuick: true })` builds the request and calls the server.

### 4.2 Full Trip Studio

1. User scrolls to the studio or uses “Detailed planner”.
2. User edits title, start/end date, adults, children, budget and display currency.
3. User chooses travel style, transport, pace and interests.
4. User reorders route stops with drag or up/down buttons.
5. User adds or removes destinations through the searchable grid.
6. User reviews the straight-line route estimate.
7. User clicks “Generate My Trip”.

**Constraints and feedback**

- Selection is capped at six.
- Adults are capped at 12 and children at 10 in the UI.
- Total days are clamped to 21.
- Budget input is converted from the selected display currency back to MMK.
- The route map falls back to SVG if Leaflet is unavailable.
- Hotel tier is not editable in the live studio.

### 4.3 Generation

**Request payload:**

- destination IDs in route order;
- allocated days per destination;
- interests;
- adults and children;
- budget in MMK;
- transport, style, hotel tier and pace;
- start date;
- title;
- variation seed.

**Client behaviour**

- Disables the generate button.
- Calls `POST /api/itinerary`.
- On success: stores the itinerary, renders it, re-renders the studio and quick fields, shows a toast with stop count, switches to the Itinerary view.
- On failure: shows the server's error message, re-renders the studio and leaves the user on Home.

**Typical failures**

| Condition | Message/source |
|---|---|
| No destinations | Client toast before request |
| More than six | Server 400 “at most 6 destinations” |
| Too many travellers | Server 400 |
| Invalid destination ID | Server 400 |
| RMI/gateway down | 502 “Trip server unavailable” |
| Bad JSON/body | 502 in most cases; parser is lenient |

### 4.4 What the engine does

1. Validates and normalises input.
2. Selects candidate places per destination.
3. Scores places by interests, style, rating and time suitability.
4. Allocates days and schedules activities into time slots.
5. Adds transfers, meals and rest according to pace.
6. Costs entries, food, local transport, intercity transfer and stays.
7. Compares total with budget and creates warnings.
8. Returns a complete `Itinerary` object with tips, warnings and extra places.

The browser does not receive progress updates. There is no streaming, job queue or partial result.

---

## 5. Reviewing the itinerary

### 5.1 Overview

1. Hero shows day count, nights (`totalDays - 1`), travellers, estimate and style.
2. User can scan day cards, mini map, recommended hotels and summary.
3. “View Details” opens the Daily tab and scrolls to the day.
4. “Regenerate” replaces that day after a server call.
5. “Book This Trip” opens Hotels; it does not create a multi-property booking.
6. Save, Print and Edit trip are available in the summary.

### 5.2 Daily itinerary

1. User opens the Daily tab.
2. Each day lists activities with time, duration, category, cost and description.
3. Weather is always shown as unavailable.
4. User can edit, remove or add an activity, or drag to reorder within the day.
5. Every edit recalculates entry fees, day costs, active hours, total and budget verdict.
6. A toast confirms the operation.

**Activity edit path**

1. Click Edit.
2. Modal opens with current values.
3. User changes fields and submits.
4. Client trims title, clamps hours, clamps cost, updates the activity.
5. If title is empty, inline error appears and the modal stays open.
6. On success: recalculate, close, re-render Daily, toast.

**Add activity path**

1. Click “+ Add activity”.
2. Modal lists catalogue places for that destination not already in the day.
3. User clicks “+ Add”.
4. Activity is appended after the last activity with computed time, slot and group cost.
5. Recalculate, close, refresh Daily, toast.

**Remove path**

- Immediate removal; no confirmation and no undo.

**Drag reorder path**

- Only within the same day.
- All times are reset from 08:00 with 30-minute gaps.
- Dropping on another day is ignored.

### 5.3 Map & Route

1. Leaflet renders numbered destination markers and a dashed straight line.
2. If Leaflet or container dimensions are unavailable, an SVG schematic renders.
3. Destination list appears under the map.
4. Zoom buttons adjust the schematic zoom state.
5. Copy states that the route is approximate.

### 5.4 Hotels tab

1. Client fetches hotels for each itinerary destination.
2. Cards show availability and a book action.
3. Results are cached in `state.routeHotels` until a partner property is edited or deleted.

### 5.5 Budget tab

1. Donut splits stays, transport, food and activities.
2. Total is compared with the user budget when one was set.
3. Category rows show each component.
4. Per-person and per-group-day figures are shown.
5. Daily spend lists each day.
6. Warnings from the engine are displayed.

### 5.6 Save, print, export

**Save**

1. Click Save trip.
2. Current itinerary is removed from the saved list if the same ID exists.
3. Snapshot is prepended with title, summary, save timestamp and itinerary.
4. localStorage is written with at most eight entries.
5. Button label becomes “Saved”, toast confirms browser-local save.

**Print**

- Calls `window.print()`. Print CSS hides navigation, hero, planner, chat, modal and toast; forces the itinerary view visible; expands panels.

**Export**

- Downloads `<itinerary-id>.json` with the full itinerary object.

### 5.7 Regeneration

**One day**

1. Builds a payload from the last request, increments variation.
2. Calls the engine.
3. Replaces the corresponding day, preserving day number and date.
4. Recalculates and opens Daily.
5. Toast confirms.

**Whole trip**

1. Same request with incremented variation.
2. Replaces the entire itinerary, discarding local edits without confirmation.
3. Opens Overview.

**Failure:** toast with the server message; existing itinerary remains.

---

## 6. Saved trips

### 6.1 Reopen

1. User opens Bookings from the header or footer.
2. Saved trips render from localStorage.
3. “Open” loads the stored itinerary into state, renders it and switches to Itinerary.
4. The itinerary is editable and can be booked from there.

### 6.2 Remove

1. Click Remove.
2. Trip disappears immediately and localStorage is rewritten.
3. No confirmation.

### 6.3 Limits and failure modes

- Browser-local only.
- No server sync.
- No account association.
- Silently capped at eight.
- Corrupt or inaccessible localStorage returns an empty list.
- A saved itinerary does not preserve hotel bookings or payment state.

---

## 7. Hotel discovery and booking

### 7.1 Find a hotel

1. User opens Hotels from nav, footer, destination detail, itinerary or chat.
2. City tabs place itinerary destinations first.
3. Client requests `GET /api/hotels?destinationId=...`.
4. User filters by class and max price and sorts by price, rating or stars.
5. Cards show one visual, amenities, owner attribution, nightly price, rooms left and rating.

### 7.2 Start a booking

1. Click “Book stay”.
2. Client locates the hotel in the current hotel list or route hotel cache.
3. Booking modal opens.
4. Nights default to 2, or to the itinerary's `nightsPerDestination` for that destination.
5. Check-in defaults to the itinerary start date or planner start date.
6. Guest name is prefilled from the local profile if present.

### 7.3 Submit guest details

1. User enters name, phone, check-in, nights and rooms.
2. Total updates on every input.
3. Submit disables the button and shows “Holding your room…”.
4. Client performs minimal checks (name length only); server performs the real validation.
5. On success, `POST /api/bookings` returns 201 with a `Booking`.
6. Client stores the booking, opens the Payment modal and toasts that the room is held.

**Server effects**

- Validates hotel and fields.
- Normalises phone.
- Rejects past dates.
- Checks rooms against `roomsLeft`.
- Computes checkout and total.
- Creates `BK-` reference.
- Decrements `roomsLeft`.
- Stores booking with `PENDING_PAYMENT`.
- Writes the entire bookings file.

**Failure branches**

| Condition | User sees |
|---|---|
| Hotel missing | “That hotel is no longer available.” |
| Invalid name | “Please enter the guest name.” |
| Invalid phone | “Enter a valid Myanmar phone number…” |
| Nights/rooms out of range | Specific message |
| Not enough rooms | “Only N room(s) left…” |
| Past date | “Check-in date cannot be in the past.” |
| Server down | 502 message in inline form error |

The button re-enables and the form remains open on failure.

### 7.4 Pay

1. Payment modal shows amount, hotel, nights and booking reference.
2. User selects KBZPay, WavePay or AYA Pay.
3. Wallet phone defaults to the booking phone.
4. User enters a 4–6 digit demo PIN.
5. Client validates wallet phone shape and PIN digits.
6. A processing modal replaces the form.
7. `POST /api/pay` validates booking, status, method, wallet phone and PIN.
8. Server sleeps ~900 ms, generates a transaction reference and confirms the booking.
9. Client renders the receipt modal.

**Success path**

- Booking status becomes `CONFIRMED`.
- Payment method, transaction ID and paid timestamp are stored.
- Receipt shows booking, hotel, destination, guest, dates, rooms/nights, wallet, transaction, simulated time and total.
- “View my bookings” opens Bookings, prefills the phone and runs lookup.

**Decline path**

- Server returns HTTP 402 with `success=false` and a decline message.
- The shared `api()` helper throws on non-2xx before the caller can inspect the payload.
- Client reopens the payment form and displays “Request failed (402)” instead of the wallet decline reason.
- The booking remains pending and rooms remain held.

**Other failures**

| Condition | Server response | UI |
|---|---|---|
| Booking not found | 400 | Payment form + message |
| Already paid | 400 | Payment form + message |
| Invalid method | 400 | Payment form + message |
| Bad wallet phone | 400 | Payment form + message |
| Bad PIN format | 400 | Payment form + message |
| Server/RMI down | 502 | Payment form + message |

**Important:** The PIN is posted to the gateway and passed to the RMI service. It is not sent to a wallet provider, but it is transmitted and handled by the application, contradicting the UI claim that no PIN is transmitted.

---

## 8. Booking lookup

### 8.1 Happy path

1. User opens Bookings.
2. Enters the phone used at booking.
3. Submits the form.
4. Client requests `GET /api/bookings?phone=...`.
5. Server normalises the phone and returns matching bookings sorted newest first.
6. Cards show confirmed or pending status, reference, dates, total and actions.
7. Pending bookings offer “Complete demo payment”, which opens the payment modal using the serialized booking object.
8. Confirmed bookings show wallet label and transaction reference.

### 8.2 Empty and error states

- No phone → toast.
- No results → “No bookings found for …”.
- Server error → empty state with the message.
- Invalid phone format → server normalises to null and, critically, returns **all** bookings.

### 8.3 Security failure

- Anyone who knows or guesses a phone number can retrieve its bookings.
- A direct request with no `phone` parameter returns every booking in the system.
- No OTP, booking reference, session or rate limit protects the lookup.
- The response includes guest name, phone, hotel, dates and amounts.

This workflow should not be exposed publicly in its current form.

---

## 9. Traveller profile

### 9.1 Sign up

1. User clicks Sign Up.
2. Modal opens in sign-up mode.
3. User enters full name, email and password.
4. Client validates name length, email regex and password length (4+).
5. Client creates `{ name, email, since }`.
6. Profile is written to localStorage.
7. Toast says the profile is stored in the browser.
8. Nav shows the user's initial and first name.

**No server call occurs.** The password is never stored or checked.

### 9.2 Login

1. User clicks Login.
2. Modal opens in login mode.
3. User enters any valid name, email and 4+ character password.
4. The same profile creation path runs.
5. There is no comparison with an existing profile, no error for wrong credentials and no account recovery.

### 9.3 Account panel

- Shows avatar, name, email.
- Links to Bookings and Partner dashboard.
- Sign out removes the local profile.
- No edit, delete, password change or session expiry.

### 9.4 Consequences

- The profile provides convenience prefill only.
- It does not own bookings, saved trips or partner data.
- It gives a misleading impression of account security.
- Clearing site data removes it.

---

## 10. Partner workflows

### 10.1 Join

1. Open Partner from nav, footer, Hotels or account panel.
2. Partner page shows marketing hero and join/login tabs.
3. Join form asks for owner/business name, email, phone and password.
4. Client validates name, email and password length.
5. `POST /api/partner/register` validates again, normalises phone, checks duplicate email, hashes password and persists.
6. Server returns a `Partner` object without the hash.
7. Client stores the partner object in localStorage, updates nav and renders the dashboard.

**Failure branches:** invalid name/email/phone/password, duplicate email, server down. Inline error appears in the form.

### 10.2 Login

1. Switch to Partner login.
2. Enter email and password.
3. `POST /api/partner/login`.
4. Server finds the email, verifies the salted hash and returns the partner object.
5. Client stores it and renders the dashboard.

**Failure branches:** missing fields, unknown email, wrong password, server down. No lockout or rate limit exists.

**Session weakness:** the returned partner ID is the sole credential for all later calls. There is no token, cookie, expiry or server-side session. Anyone with the ID can act as that partner.

### 10.3 Dashboard load

1. If a stored partner exists, dashboard shell renders.
2. Two calls run in parallel: partner hotels and partner bookings.
3. On success, stats and lists render.
4. On failure, the client clears the partner session, persists null and returns to the auth screen with a toast.

### 10.4 Add a property

1. Click “Add a property” or the empty-state link.
2. Modal opens with defaults.
3. User fills name, destination, area, address, class, stars, price, rooms, room type, contact, description, amenities and check-in/out times.
4. Client validates description length only.
5. Submit → `POST /api/partner/hotels` with `partnerId` in the body.
6. Server validates ownership context (only that the partner ID exists), name, destination, price, rooms, tier, description; fills defaults; assigns owner, rating and gradient; adds to the in-memory registry; persists partners.
7. Client closes the modal, invalidates route hotel cache, removes any stale copy from the hotel list, toasts and reloads dashboard data.

**Result:** property appears immediately in customer hotel searches and destination lists.

### 10.5 Edit a property

1. Click Edit on a property card.
2. Modal is prefilled.
3. Submit → `PUT /api/partner/hotels`.
4. Server verifies the hotel exists and is owned by the supplied partner ID.
5. Server overwrites all editable fields.
6. **Defect:** `roomsTotal` and `roomsLeft` are both reset to the submitted room count, ignoring existing bookings. This can make sold rooms available again or erase inventory history.

### 10.6 Remove a property

1. Click Remove.
2. Confirmation modal shows the property name.
3. Confirm → `DELETE /api/partner/hotels?partnerId=...&id=...`.
4. Server verifies ownership, removes from the partner registry and persists.
5. Customer search no longer shows it.
6. **Defect:** existing bookings for that hotel are orphaned. They remain in booking storage but disappear from the partner's booking list because the hotel can no longer be resolved.

### 10.7 View bookings

- Dashboard lists bookings whose hotel currently belongs to the partner.
- Shows guest name, phone, stay dates, total and paid/pending status.
- No guest contact action, cancellation, check-in or messaging.
- Booking value is explicitly demo-only.

### 10.8 Sign out

- Clears partner object and cached hotels/bookings from memory.
- Removes localStorage partner entry.
- Re-renders auth screen.
- Does not invalidate anything server-side because no session exists.

---

## 11. Chat assistant workflow

1. User clicks the floating chat button or itinerary help button.
2. Static panel opens with a greeting, four shortcut buttons and a note that no live agent is connected.
3. Shortcuts navigate to planner, hotels, bookings or guide.
4. Close button, Escape or the launcher hides the panel.

There is no message input, intent detection, conversation state or support escalation. The “assistant” is a navigation menu.

---

## 12. Error and recovery flows

| Situation | Current behaviour | Recovery |
|---|---|---|
| Server down at startup | Toast; empty catalogue | Restart server and refresh manually |
| Catalogue request fails later | Empty state or toast | Refresh |
| Itinerary validation error | Inline toast with server message | Adjust inputs and retry |
| RMI unavailable | 502 message | Restart server |
| Booking validation error | Inline form error | Correct and resubmit |
| Payment decline | Generic 402 message | Retry payment; reason is lost |
| Payment network error | Payment form + message | Retry |
| Partner auth error | Inline form error | Retry |
| Partner dashboard load error | Session cleared; auth screen | Sign in again |
| Saved data corrupt | Empty saved/profile state | No repair path |
| Refresh with unsaved itinerary | Itinerary lost | Regenerate |
| Browser storage full/blocked | Writes silently ignored | No warning |
| Persistence write failure | Server logs warning but returns success | No user-visible error; data may be lost |

### Missing recovery capabilities

- No retry buttons.
- No offline queue.
- No draft autosave.
- No idempotency keys.
- No conflict detection.
- No “contact support” path.
- No error reference or request ID.
- No backup/restore instructions in the UI.

---

## 13. Cross-workflow state rules

| State | Stored where | Survives refresh | Shared across devices |
|---|---|---|---|
| Catalogue and hotels | Server memory | Yes, while server runs | Yes, same server |
| Current itinerary | Browser memory | No | No |
| Saved trips | localStorage | Yes | No |
| Traveller profile | localStorage | Yes | No |
| Partner session object | localStorage | Yes | No |
| Bookings | `data/bookings.ser` | Yes | Yes, same server |
| Partner accounts and hotels | `data/partners.ser` | Yes | Yes, same server |
| View/tab state | Browser memory | No | No |
| Payment state | Server booking record | Yes | Yes |

---

## 14. Ideal target workflows (recommended)

These are not implemented; they describe the minimum production-grade shape.

### Traveller

1. Sign up or sign in with a verified email/phone.
2. Plan and generate a trip; autosave a draft server-side.
3. Receive a shareable, access-controlled itinerary link.
4. Select a hotel and dates; see only genuinely available room types.
5. Hold a room with a visible expiry countdown and idempotent booking reference.
6. Pay through a real provider with a signed callback.
7. Receive confirmation by email/SMS.
8. View, modify or cancel the booking from an authenticated account.
9. Receive refund status and a final invoice.

### Partner

1. Register with email verification and a strong password.
2. Sign in to a server session with expiry and CSRF protection.
3. Manage properties and date-level inventory.
4. Receive bookings with accept/decline or automatic confirmation rules.
5. View statements, commission and settlement status.
6. Cancel or modify inventory without corrupting existing bookings.
7. Recover the account through a verified reset flow.

### Operations

1. Admin console for bookings, partners, inventory and refunds.
2. Audit log for every state change.
3. Health checks that include RMI, disk and integrations.
4. Backups, restore drills and integrity monitoring.
5. Alerting for failed payments, persistence errors and unusual lookup volume.
