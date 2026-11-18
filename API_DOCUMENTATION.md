# MSTP — API Documentation

**Audit date:** 12 November 2026  
**Interface:** HTTP/1.1 JSON gateway (`com.mmtrip.client.WebMain`) over Java RMI (`TripService`)  
**Default base URL:** `http://localhost:8080` (the gateway tries ports 8080–8099 if the port is busy)  
**Documentation source:** implementation trace, not an OpenAPI specification. No OpenAPI/Swagger file exists.

---

## 1. Conventions

### 1.1 Transport and format

- Requests and responses use JSON, except static files.
- The gateway does not require or check `Content-Type`.
- Request bodies are read up to **200,000 bytes** via `readNBytes`. Oversized bodies are truncated rather than rejected with 413.
- The JSON parser is deliberately lenient: unknown fields are ignored, missing fields fall back to defaults, and several malformed constructs are tolerated.
- Responses are UTF-8.
- API responses set `Cache-Control: no-store`.
- Every JSON response, including errors, sets `Access-Control-Allow-Origin: *`.
- There is no authentication header, cookie, API key or session token anywhere in the API.

### 1.2 Error envelope

All application errors use:

```json
{ "error": "Human-readable message" }
```

There is no error code, field-level error array, request ID or documentation link.

### 1.3 Status codes actually used

| Code | Meaning in this API |
|---|---|
| 200 | Success |
| 201 | Booking or partner account created |
| 400 | Business validation failure (`TripException`) or bad engine parameter |
| 402 | Simulated payment declined |
| 405 | Wrong HTTP method for the route |
| 502 | RMI service unavailable or unexpected server exception |
| 503 | Weather/routing engine unavailable |
| 404 | Static index file missing (rare) |

The API does **not** use 401, 403, 409, 413, 422, 429 or 500. Failures that should be 401/403 are either accepted or reported as 400/502. There is no rate limiting.

### 1.4 Route matching

Routes are registered as HTTP context prefixes. A request whose path begins with a registered prefix enters that handler. Method checks are performed inside handlers.

---

## 2. Route summary

| Method | Path | Auth | Purpose | Live frontend use |
|---|---|---|---|---|
| GET | `/api/destinations` | None | Full destination and place catalogue | Yes |
| GET | `/api/hotels` | None | All hotels or hotels for one destination | Yes |
| POST | `/api/itinerary` | None | Generate an itinerary | Yes |
| GET | `/api/bookings` | None | List bookings by phone, or all bookings | Yes |
| POST | `/api/bookings` | None | Create a booking and hold rooms | Yes |
| POST | `/api/pay` | None | Simulate wallet payment | Yes |
| GET | `/api/health` | None | Static health payload | No |
| GET | `/api/engine/weather` | None | Proxy weather forecast | **No** |
| POST | `/api/route-plan` | None | Proxy external trip planning | **No** |
| POST | `/api/partner/register` | None | Create partner account | Yes |
| POST | `/api/partner/login` | None | Verify partner password | Yes |
| GET | `/api/partner/hotels` | `partnerId` query | List owned hotels | Yes |
| POST | `/api/partner/hotels` | `partnerId` body | Create owned hotel | Yes |
| PUT | `/api/partner/hotels` | `partnerId` body | Update owned hotel | Yes |
| DELETE | `/api/partner/hotels` | `partnerId` query | Delete owned hotel | Yes |
| GET | `/api/partner/bookings` | `partnerId` query | List bookings for owned hotels | Yes |
| GET/HEAD | `/` and static paths | None | Serve SPA and assets | Yes |

“Auth” above describes the intended check. In practice, `partnerId` alone is caller-controlled and is not proof of identity.

---

## 3. Endpoint details

### 3.1 GET `/api/destinations`

Returns the full catalogue in code order.

**Request:** no parameters.

**Response 200:** array of `Destination`, each with a nested `places` array.

```json
[
  {
    "id": "bagan",
    "name": "Bagan",
    "nameMm": "…",
    "region": "Mandalay Region",
    "tagline": "Temple plains at golden hour",
    "description": "…",
    "bestSeason": "Nov - Feb",
    "gradient": "linear-gradient(...)",
    "emoji": "…",
    "recommendedDays": 3,
    "lat": 21.17,
    "lon": 94.86,
    "places": [
      {
        "id": "bagan-ananda",
        "name": "Ananda Temple",
        "category": "Temple",
        "bestTime": "08:00",
        "area": "Old Bagan",
        "description": "…",
        "hours": 1.5,
        "rating": 4.8,
        "entryFee": 5000
      }
    ]
  }
]
```

**Errors:** 405 for non-GET; 502 if RMI fails. No pagination, filtering, ETag or cache validation.

---

### 3.2 GET `/api/hotels`

Returns all hotels, or hotels for one destination.

**Query parameters**

| Name | Required | Type | Behaviour |
|---|---|---|---|
| `destinationId` | No | string | If blank or absent, returns all hotels. If present, must match a known destination or the server returns 400. |

**Response 200:** array of `Hotel`.

```json
[
  {
    "id": "bagan-aurora",
    "destinationId": "bagan",
    "destinationName": "Bagan",
    "name": "Aurora Bagan",
    "tier": "Luxury",
    "area": "Old Bagan",
    "description": "…",
    "gradient": "linear-gradient(...)",
    "imageUrl": "/images/hotels/bagan-h9.jpg",
    "imageCredit": "kthypryn / BY 2.0",
    "imageSource": "https://www.flickr.com/photos/...",
    "dataSource": "https://en.wikivoyage.org/wiki/Bagan",
    "ownerId": null,
    "ownerName": null,
    "address": "…",
    "roomType": "Deluxe room",
    "contact": "…",
    "checkInTime": "14:00",
    "checkOutTime": "12:00",
    "pricePerNight": 109000,
    "rating": 0.0,
    "stars": 5,
    "roomsLeft": 8,
    "roomsTotal": 8,
    "published": true,
    "amenities": ["Pool", "Breakfast", "Wi-Fi"]
  }
]
```

**Errors**

| Code | Condition |
|---|---|
| 400 | Unknown `destinationId` |
| 405 | Non-GET |
| 502 | RMI failure |

`roomsLeft` reflects a process-lifetime counter, not date-based availability. It is reduced by bookings and can be reset by partner edits or partner-data reload.

Hotel data is real, not generated: `name`, `area`, `pricePerNight` and `dataSource` come from the
Wikivoyage sleep listing for that town (`data/hotels.json`, regenerated with
`tools/generate_hotel_catalogue.py`). Rates are indicative and converted to MMK, so treat them as
sample prices. Class, `stars`, `roomsLeft`, `roomsTotal` and `amenities` are derived/demo values.

`imageUrl` is a bundled photo of that exact property (`/images/hotels/<id>.jpg`, credited through
`imageCredit` and `imageSource`, see `web/images/hotels/CREDITS.json`) or `null`. Credits are mainly
CC licences; photos added for this school project are labelled "Educational use".
It is never a photo of a different property. A partner can supply any `imageUrl` starting with
`/images/` or `http(s)://` (CSP allows `img-src https:`).

`areaPhoto` (`/images/areas/<town>.jpg` when a curated town photo exists, otherwise
`/images/<town>.jpg`) is set when `imageUrl` is null: a real photo of the destination,
rendered as a duotone banner with a "City photo" label and the tooltip "…not of this property".
It exists so no card is blank without implying the picture is the hotel. `imageUrl` always wins.
Partner hotels have neither until the owner uploads a photo, and then show the illustrated
placeholder.

`rating` is always `0.0`: no guest scores are invented, and the UI hides the field when it is zero.

### Partner photo upload

`POST`/`PUT /api/partner/hotels` accepts either of:

| Field | Type | Meaning |
|---|---|---|
| `photoData` | string | Data URL (`data:image/jpeg;base64,…`). Decoded, validated and stored by the server; wins over `imageUrl`. |
| `imageUrl` | string | Existing site path (`/images/…`) or absolute `http(s)://` URL. Empty means "no photo". |

Upload rules (`com.mmtrip.server.PhotoStore`): JPEG, PNG or WebP detected from the file's magic
bytes (not the declared type), decoded size ≤ 3 MB, base64 required. The file is written as
`web/images/hotels/upload-<12 hex>.<ext>` and the response `Hotel.imageUrl` holds that path.
Failures return `400` with a message safe to show the user, e.g.
`{"error":"Only JPEG, PNG or WebP photos are supported."}`.
Uploaded photos are deleted when the listing is deleted; bundled catalogue photos never are.

---

### 3.3 POST `/api/itinerary`

Generates a plan with the deterministic engine.

**Request body**

| Field | Type | Default | Notes |
|---|---|---|---|
| `destinationIds` | string[] | `[]` | 1–6 known IDs; order defines route order |
| `days` | number[] | `[]` | Day allocation per destination; engine adjusts/clamps |
| `interests` | string[] | `[]` | Free-form interest IDs |
| `adults` | number | `2` | 1–20 after engine validation |
| `children` | number | `0` | 0–10 |
| `travelers` | number | — | Ignored/overwritten as `adults + children` |
| `budget` | number | `0` | MMK; 0 means not set; capped at 1,000,000,000 |
| `hotelTier` | string | `mid` | `budget`, `mid`, `luxury`; unknown falls back |
| `pace` | string | `balanced` | `relaxed`, `balanced`, `packed`; unknown falls back |
| `startDate` | string | null | `yyyy-MM-dd`; engine dates the days |
| `startLocation` | string | `Yangon` | Stored on request; limited engine use |
| `title` | string | null | Optional custom title |
| `variation` | number | `0` | Changes deterministic tie-breaking for regeneration |

Example:

```json
{
  "destinationIds": ["bagan", "inle"],
  "days": [2, 2],
  "interests": ["temple", "food"],
  "adults": 2,
  "children": 0,
  "budget": 900000,
  "hotelTier": "mid",
  "pace": "balanced",
  "startDate": "2026-12-01",
  "title": "Temples and lake",
  "variation": 0
}
```

**Response 200:** `Itinerary`.

**Validation messages**

- “Please choose at least one destination.”
- “A single trip can cover at most 6 destinations.”
- “At least one adult traveller is required.”
- “We support up to 20 adults per trip.”
- “Please choose fewer travellers.”
- “Unknown destination: …”
- Budget/number/days messages from the engine.

**Errors:** 400 for `TripException`; 405 for non-POST; 502 for RMI or unexpected failure.

**Notes**

- No idempotency key; identical requests with the same body and variation return equivalent plans.
- No server-side storage of the result.
- No weather or road-routing data is incorporated.
- The response can be large (all days, activities, tips, warnings and extra places).

---

### 3.4 GET `/api/bookings`

**This is the most security-sensitive route in the application.**

**Query parameters**

| Name | Required | Behaviour |
|---|---|---|
| `phone` | No | Normalises and filters by phone. **If absent or invalid, returns all bookings.** |

**Response 200:** array of `Booking`, newest first.

```json
[
  {
    "id": "BK-1A2B3C",
    "hotelId": "bagan-aurora",
    "hotelName": "Aurora Bagan",
    "destinationName": "Bagan",
    "guestName": "Example Guest",
    "phone": "09XXXXXXXXX",
    "checkIn": "2026-12-01",
    "checkOut": "2026-12-03",
    "nights": 2,
    "rooms": 1,
    "pricePerNight": 148000,
    "total": 296000,
    "status": "PENDING_PAYMENT",
    "paymentMethod": null,
    "transactionId": null,
    "createdAt": "2026-11-12 10:00:00",
    "paidAt": null
  }
]
```

**Security:** no authentication, ownership check, OTP, reference code or rate limit. A caller can enumerate bookings by phone or retrieve the entire set. The response contains guest names, phone numbers, stays and amounts.

**Errors:** 405 for non-GET; 502 for RMI failure. The service method itself does not throw a business exception.

---

### 3.5 POST `/api/bookings`

Creates a booking and immediately decrements available rooms.

**Request body**

| Field | Type | Required | Server validation |
|---|---|---|---|
| `hotelId` | string | Yes | Must resolve to a hotel |
| `guestName` | string | Yes | Trimmed length ≥ 2 |
| `phone` | string | Yes | Normalised to `09` + 7–9 digits |
| `checkIn` | string | Yes | Valid `yyyy-MM-dd`, not before today |
| `nights` | number | No | Defaults to 1; must be 1–30 |
| `rooms` | number | No | Defaults to 1; must be 1–10 and ≤ `roomsLeft` |

```json
{
  "hotelId": "bagan-aurora",
  "guestName": "Example Guest",
  "phone": "09XXXXXXXXX",
  "checkIn": "2026-12-01",
  "nights": 2,
  "rooms": 1
}
```

**Response 201:** the created `Booking` with `status = "PENDING_PAYMENT"`.

**Server side effects**

- Generates `BK-` plus six random uppercase characters.
- Computes `checkOut = checkIn + nights`.
- Computes `total = pricePerNight × nights × rooms`.
- Decrements `roomsLeft` immediately.
- Persists the whole booking map to `data/bookings.ser`.
- Reports success even if persistence throws internally.

**Errors**

| Code | Condition |
|---|---|
| 400 | Hotel missing, bad name/phone/date, nights/rooms out of range, insufficient rooms |
| 405 | Non-POST |
| 502 | RMI failure |

No idempotency key, duplicate suppression, hold expiry or cancellation endpoint exists.

---

### 3.6 POST `/api/pay`

Simulates a wallet payment.

**Request body**

| Field | Type | Required | Validation |
|---|---|---|---|
| `bookingId` | string | Yes | Must exist and not already be confirmed |
| `method` | string | Yes | `KPAY`, `WAVEPAY` or `AYAPAY` (case-insensitive) |
| `walletPhone` | string | Yes | Normalised Myanmar phone |
| `pin` | string | Yes | 4–6 digits |

```json
{
  "bookingId": "BK-1A2B3C",
  "method": "KPAY",
  "walletPhone": "09XXXXXXXXX",
  "pin": "<demo-pin>"
}
```

**Response 200:** successful `PaymentResult`.

```json
{
  "success": true,
  "message": "KBZPay payment successful. Your booking is confirmed.",
  "transactionId": "KP20261201-123456",
  "method": "KPAY",
  "walletPhone": "09XXXXXXXXX",
  "paidAt": "2026-12-01 10:05:00",
  "amount": 296000,
  "booking": { "...": "confirmed Booking" }
}
```

**Response 402:** declined `PaymentResult` (`success=false`, message, method, wallet phone, amount; no booking object). A specific PIN value is hard-coded to trigger this branch for demonstration. That value is intentionally not reproduced here.

**Validation errors (400)**

- “Booking not found.”
- “This booking is already paid.”
- “Choose KBZPay, WavePay or AYA Pay.”
- “Enter the wallet phone number linked to …”
- “Wallet PIN must be 4–6 digits.”

**Notes**

- No real wallet provider is contacted.
- PIN is transmitted to the gateway and RMI service for validation. This contradicts the UI's “no PIN is transmitted” copy.
- Successful payment sets status `CONFIRMED` and stores method, transaction ID and paid timestamp.
- No callback, signature, settlement, refund or reconciliation exists.
- The frontend cannot display the 402 decline message because its shared `api()` helper throws on non-2xx before reading `PaymentResult`.

---

### 3.7 GET `/api/health`

Returns a static payload:

```json
{ "status": "UP", "service": "MyanmarTripService" }
```

- Any HTTP method returns 200 because no method guard exists.
- It does **not** check RMI connectivity, disk access, `.ser` readability, partner data, external engine availability or booking integrity.
- It is not used by the frontend, process supervisor or any monitoring system.

---

### 3.8 GET `/api/engine/weather` (dormant)

Proxies a weather forecast from an external FastAPI service.

**Query parameters**

| Name | Required | Validation/Behaviour |
|---|---|---|
| `destinationId` | Yes | Must match `[A-Za-z0-9_-]{1,100}` |
| `latitude` | Yes | Forwarded URL-encoded |
| `longitude` | Yes | Forwarded URL-encoded |
| `days` | No | Default `16` |
| `timezone` | No | Default `Asia/Yangon` |

**Upstream URL shape:** `<engine-base>/api/v1/weather/<destinationId>/forecast?latitude=…&longitude=…&days=…&timezone=…`

**Responses**

| Code | Condition |
|---|---|
| Upstream 2xx | Body forwarded as-is |
| Upstream non-2xx | Status and body forwarded; error logged |
| 400 | Invalid destination ID or missing coordinates |
| 405 | Non-GET |
| 503 | Connection/timeout or other gateway exception |

**Timeout:** 25 seconds.  
**Frontend use:** none. The UI never requests weather and always says “Weather unavailable”.

---

### 3.9 POST `/api/route-plan` (dormant)

Forwards an arbitrary JSON body to the external planning service at `/api/v1/planning/trip`.

- No body validation at the gateway.
- No allowlist of fields.
- 90-second timeout.
- Upstream status and body forwarded.
- 503 with a truthful “no fabricated travel times” message if unavailable.
- **Frontend use:** none. The UI uses Haversine distance and fixed speeds.

Because the gateway forwards arbitrary JSON, any future exposure should validate and constrain the upstream contract.

---

### 3.10 POST `/api/partner/register`

Creates a hotel-owner account.

**Request body**

| Field | Type | Validation |
|---|---|---|
| `name` | string | Trimmed length ≥ 2 |
| `email` | string | Regex; lowercased; unique among partners |
| `phone` | string | Normalised Myanmar phone |
| `password` | string | Length ≥ 6 |

```json
{
  "name": "Example Hospitality",
  "email": "owner@example.com",
  "phone": "09XXXXXXXXX",
  "password": "<demo-password>"
}
```

**Response 201:** `Partner` (no password or hash).

**Errors:** 400 validation/duplicate; 405; 502.

**Security note:** passwords are salted with a random 12-character salt and hashed with single-round SHA-256. This is not a memory-hard password KDF.

---

### 3.11 POST `/api/partner/login`

**Request body:** `email`, `password`.

**Response 200:** `Partner`.

**Errors:** 400 for missing fields, unknown email or wrong password; 405; 502.  
The service intentionally returns distinct messages for unknown email and wrong password, enabling account enumeration. No rate limit or lockout exists.

---

### 3.12 `/api/partner/hotels`

#### GET

**Query:** `partnerId` (required in practice).

**Response 200:** array of hotels owned by that partner.

#### POST

Creates a property. **Body:** all hotel fields plus `partnerId`.

Required/validated:

- `name` ≥ 3 characters;
- valid `destinationId`;
- `pricePerNight` 5,000–5,000,000 MMK;
- `rooms` 1–300;
- tier exactly `Budget`, `Mid-range` or `Luxury`;
- `description` ≥ 15 characters;
- optional contact phone normalised or falls back to partner phone.

Server fills defaults, assigns `OWN-` ID, owner ID/name, rating 4.4, gradient, address, room type, check-in/out and amenities.

**Response 200:** saved `Hotel`.

#### PUT

Updates an owned property. Same body and validation, with `id` identifying the hotel.

- Rejects if the hotel is missing or not owned by the supplied `partnerId`.
- **Resets `roomsTotal` and `roomsLeft` to the submitted room count**, ignoring bookings.
- Persists partner data.

**Response 200:** saved `Hotel`.

#### DELETE

**Query:** `partnerId`, `id`.

- Rejects missing/unowned property.
- Removes it from the partner registry.
- Leaves existing bookings orphaned.

**Response 200:** `{ "deleted": true }` or `{ "deleted": false }`.

**Common errors:** 400 business validation; 405 unsupported method; 502 RMI failure. There is no 401/403.

**Authorization flaw:** `partnerId` is accepted from the caller with no session token. Any caller who learns a partner ID can list, create, modify or delete that partner's properties.

---

### 3.13 GET `/api/partner/bookings`

**Query:** `partnerId`.

**Response 200:** bookings whose hotel currently exists and is owned by that partner, newest first.

- Deleting a hotel removes its bookings from this view.
- No authorization proof beyond `partnerId`.
- No pagination or date filter.
- Exposes guest name and phone to the caller.

**Errors:** 405 for non-GET; 400 for unknown partner; 502 for RMI failure.

---

## 4. Static file serving

`GET /` and paths without a file extension serve `web/index.html`.  
Paths with an extension resolve under the web root:

- decoding and normalisation are applied;
- traversal outside the web root is rejected;
- if the file is missing, `index.html` is served with **200**, not 404;
- only GET and HEAD are allowed for existing files;
- `Cache-Control: no-cache`;
- MIME types are set for HTML, CSS, JS, JSON, SVG, PNG, WebP, JPEG, WOFF2; unknown types are `application/octet-stream`.

**Consequence:** a broken asset path returns HTML with 200, which can hide deployment errors and confuse browsers expecting CSS, JS or images.

No gzip/Brotli compression, ETag, range requests or immutable caching is implemented.

---

## 5. Data model reference

### 5.1 Destination

| Field | Type | Notes |
|---|---|---|
| `id`, `name`, `nameMm`, `region` | string | Identity and display |
| `tagline`, `description` | string | Marketing copy |
| `bestSeason` | string | Editorial sample |
| `gradient`, `emoji` | string | Visual fallback metadata |
| `recommendedDays` | int | Used for day allocation |
| `lat`, `lon` | double | Map and distance calculations |
| `places` | Place[] | Attractions |

### 5.2 Place

| Field | Type | Notes |
|---|---|---|
| `id`, `name`, `category`, `bestTime`, `area`, `description` | string | Identity and display |
| `hours` | double | Visit duration |
| `rating` | double | Curated score |
| `entryFee` | int | MMK per person |

### 5.3 Hotel

| Field | Type | Notes |
|---|---|---|
| `id`, `destinationId`, `destinationName`, `name`, `tier`, `area`, `description`, `gradient` | string | Identity and display |
| `ownerId`, `ownerName` | string/null | Partner ownership |
| `address`, `roomType`, `contact`, `checkInTime`, `checkOutTime` | string | Operational details |
| `pricePerNight` | int | MMK |
| `rating` | double | Seeded or default 4.4 for partner hotels |
| `stars` | int | 1–5 |
| `roomsLeft`, `roomsTotal` | int | In-memory counters |
| `published` | boolean | Always true for partner saves |
| `amenities` | string[] | Display list |

### 5.4 TripRequest

See §3.3. Serializable with public fields; lists default to empty, adults 2, budget 0, hotelTier `mid`, pace `balanced`, startLocation `Yangon`, variation 0. There is no `transport` or `style` field: legacy `transport`/`style` keys in the request body are ignored.

### 5.5 Itinerary

| Field group | Fields |
|---|---|
| Identity | `id`, `title`, `summary` |
| Preferences | `pace`, `hotelTier`, `transportRecommendation` (`NONE` / `UNAVAILABLE`), `transportNote` |
| Dates/travellers | `startDate`, `totalDays`, `adults`, `children`, `travelers` |
| Coverage | `placesCovered`, `recommendedDays` |
| Budget | `budget`, `budgetSet`, `budgetOk`, `budgetDelta` |
| Costs | `stays[]` (`hotelName`, `pricePerNight`, `nights`, `rooms`, `subtotal`), `estStay`, `estTotal` (always equal to `estStay`; hotel stays are the only priced item) |
| Route | `destinationIds`, `nightsPerDestination` |
| Content | `days`, `tips`, `warnings`, `extraPlaces` |

### 5.6 DayPlan

`day`, `date`, `destinationId`, `destinationName`, `theme`, `activeHours`, `travelHours`, `estCost`, `activities`.

### 5.7 Activity

`time`, `slot`, `title`, `description`, `category`, `area`, `placeId`, `hours`, `cost`.  
`cost` is the whole-group MMK cost, not per person.

### 5.8 Booking

`id`, `hotelId`, `hotelName`, `destinationName`, `guestName`, `phone`, `checkIn`, `checkOut`, `nights`, `rooms`, `pricePerNight`, `total`, `status`, `paymentMethod`, `transactionId`, `createdAt`, `paidAt`.

Status values: `PENDING_PAYMENT`, `CONFIRMED`.

### 5.9 PaymentResult

`success`, `message`, `transactionId`, `method`, `walletPhone`, `paidAt`, `amount`, `booking`.

### 5.10 Partner

`id`, `ownerName`, `email`, `phone`, `createdAt`. No password or hash is serialized to clients.

---

## 6. RMI interface

**Service name:** `MyanmarTripService`  
**Default registry:** `127.0.0.1:1099`  
**Transport:** Java RMI / JRMP, Java serialization.

| Method | Returns | Throws |
|---|---|---|
| `getDestinations()` | `List<Destination>` | `RemoteException` |
| `generateItinerary(TripRequest)` | `Itinerary` | `RemoteException`, `TripException` |
| `getHotels(String destinationId)` | `List<Hotel>` | `RemoteException`, `TripException` |
| `createBooking(hotelId, guestName, phone, checkIn, nights, rooms)` | `Booking` | `RemoteException`, `TripException` |
| `pay(bookingId, method, walletPhone, pin)` | `PaymentResult` | `RemoteException`, `TripException` |
| `getBookings(phone)` | `List<Booking>` | `RemoteException` |
| `registerPartner(ownerName, email, phone, password)` | `Partner` | `RemoteException`, `TripException` |
| `loginPartner(email, password)` | `Partner` | `RemoteException`, `TripException` |
| `getPartnerHotels(partnerId)` | `List<Hotel>` | `RemoteException`, `TripException` |
| `savePartnerHotel(partnerId, Hotel)` | `Hotel` | `RemoteException`, `TripException` |
| `deletePartnerHotel(partnerId, hotelId)` | `boolean` | `RemoteException`, `TripException` |
| `getPartnerBookings(partnerId)` | `List<Booking>` | `RemoteException`, `TripException` |

**Security:** RMI has no authentication or TLS. Binding defaults to loopback, but exposing the registry or service port would allow arbitrary calls, including booking lookup and partner operations. Java serialization on an untrusted network is inherently unsafe.

---

## 7. Gateway configuration

Command-line options:

| Option | Default | Effect |
|---|---|---|
| `--embedded`, `-e` | off | Starts the RMI registry and service in the same process |
| `--no-browser` | browser opens | Suppresses automatic browser launch |
| `--host` | `127.0.0.1` | RMI host used by the gateway client |
| `--rmi-port` | `1099` | RMI registry port |
| `--http-port` | `8080` | First HTTP port to try; searches 20 ports |
| `--web` | `web` | Static web root |

External engine configuration uses environment variables for the engine base URL and an optional internal token. Secret values are not reproduced in this audit. The default engine base is loopback port 8000.

---

## 8. Security assessment

### Critical

1. **Unauthenticated booking enumeration.** `GET /api/bookings` with no/invalid phone returns all bookings. Phone-based lookup leaks PII.
2. **Broken partner authorization.** Every partner operation trusts a caller-supplied `partnerId`. No token, session, expiry, cookie, CSRF protection or ownership proof exists.
3. **PIN transmission.** The simulated wallet PIN is posted to the gateway and passed over RMI. It is not sent to a wallet provider, but it is transmitted and handled by the application.
4. **No real traveller authentication.** Local profiles are not credentials and are not checked by any API.

### High

- Open CORS (`*`) on all JSON responses.
- No TLS; HTTP and RMI are plaintext.
- No security headers or CSP.
- No rate limiting, lockout or abuse detection on booking lookup, partner login, booking or payment.
- Single-round salted SHA-256 password hashing.
- PII and password hashes stored unencrypted in serialized files.
- No audit log.
- No idempotency or replay protection.
- Distinct partner login messages enable account enumeration.
- No method guard on `/api/health`; static fallback masks missing assets.

### Medium

- No `OPTIONS` preflight handling; cross-origin JSON POSTs will fail.
- No `Content-Type` enforcement; the parser accepts lenient JSON.
- Request size is truncated at 200 KB rather than rejected.
- Query decoding uses URLDecoder, which treats `+` as space.
- Errors expose internal/business detail but not stack traces.
- No API versioning or deprecation policy.
- The external route-plan proxy forwards arbitrary JSON without schema validation.

### Positive controls observed

- Server-side validation of booking, payment and partner fields.
- Path traversal protection for static files.
- Dynamic HTML content is generally escaped with `esc()`.
- Partner password hashes are not returned to clients.
- Request bodies are size-limited.
- JSON errors use a consistent envelope.
- Weather/routing failures explicitly avoid fabricating data.

---

## 9. Compatibility and consumer notes

- The frontend uses `fetch` with `Content-Type: application/json` and no credentials.
- The shared helper treats any non-2xx as an error with `data.error`; it cannot consume a structured non-2xx success/decline payload such as the 402 `PaymentResult`.
- There is no client retry, timeout or abort handling.
- Map tiles and Leaflet are external CDN dependencies; the API does not proxy them.
- The API is same-origin in the default deployment. Cross-origin use would require preflight support.

---

## 10. Recommended API changes

### P0

1. Add authenticated traveller and partner sessions; derive identity server-side, never from `partnerId`.
2. Replace booking lookup with an authenticated account history or booking reference + OTP.
3. Remove the PIN from the demo API or replace it with a mock approval flag.
4. Add hold expiry, cancellation, release and refund endpoints with idempotency keys.
5. Add date-specific availability and transactional inventory endpoints.
6. Add standard security headers, origin allowlists, TLS and rate limiting.
7. Return structured error codes and request IDs.
8. Add 401, 403, 409, 413, 422, 429 and 500 semantics where appropriate.

### P1

1. Version the API (`/api/v1/...`) and publish OpenAPI.
2. Add pagination, filtering and explicit field selection for large lists.
3. Add a real health/readiness split that probes RMI, disk and integrations.
4. Add audit events and metrics.
5. Add partner password reset, email verification and session revocation.
6. Add payment provider callbacks and reconciliation.
7. Add ETag/cache policy for static assets and return real 404s.
8. Add input schema validation and reject unknown or oversized payloads explicitly.
