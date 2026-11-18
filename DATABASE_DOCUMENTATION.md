# MSTP — Database and Persistence Documentation

**Audit date:** 12 November 2026  
**Actual persistence:** Two Java serialized files plus in-memory code-defined catalogues.  
**Database management system:** None. No SQL, ORM, migration tool, index, transaction manager or backup process exists.

> File contents were inspected only for structure and serialization signatures. No guest names, phone numbers, hashes or other stored values are reproduced in this report.

---

## 1. Storage overview

| Store | Type | Root object | Written when | Read when |
|---|---|---|---|---|
| `data/bookings.ser` | Java serialization | `HashMap<String, Booking>` | Booking created; payment succeeds | Server constructor |
| `data/partners.ser` | Java serialization | `PartnerData` | Partner registers; partner hotel created/edited/deleted; demo partner seeded | Server constructor |
| `src/com/mmtrip/server/DataStore.java` | Compiled Java code | Static lists | Never, at runtime | Server constructor / first access |
| Browser `localStorage` | JSON strings | Saved trips, profile, partner object | User actions | App start |

The catalogue is **not** persisted data. Nine destinations, 66 places and 27 base hotels are rebuilt from Java code on every server start. A clean start also seeds one demo partner and two partner hotels.

Both `.ser` files begin with the Java serialization stream magic `AC ED 00 05`. They are not databases and cannot be inspected or edited safely with normal tooling.

---

## 2. Runtime lifecycle

### 2.1 Server start

`TripServiceImpl` constructor runs in this order:

1. `loadPartners()`
   - If `data/partners.ser` exists, deserialize `PartnerData`.
   - Put partners into the in-memory map.
   - Put hashes into the hash map.
   - For each partner hotel, **reset `roomsLeft` to `roomsTotal` if `roomsTotal > 0`**, then add it to the `DataStore` registry.
   - Any exception is logged and swallowed.
2. `seedDemoPartner()`
   - If the demo partner email is missing, register it.
   - If that partner owns **no** hotels, create two demo properties.
   - This means deleting all demo partner properties causes them to be recreated on the next start.
3. `loadBookings()`
   - If `data/bookings.ser` exists, deserialize the booking map.
   - For each booking, find its hotel and subtract `booking.rooms` from `roomsLeft`.
   - If the hotel no longer exists, the booking is retained but no inventory is adjusted.
   - Any exception is logged and swallowed.

### 2.2 Server stop

There is no shutdown hook. In-memory state is already written on each mutation, but the last operation may have failed silently. No graceful drain or final flush occurs.

### 2.3 Persistence write path

`saveBookings()`

1. Ensure `data/` exists.
2. Open `data/bookings.ser` for writing directly.
3. Serialize a new `HashMap` copy of the booking map.
4. Close the stream.
5. Catch every exception and print a warning.

`savePartners()`

1. Ensure `data/` exists.
2. Build `PartnerData` from the partner map, hash map and all partner hotels.
3. Open `data/partners.ser` for writing directly.
4. Serialize.
5. Catch every exception and print a warning.

Neither method uses a temporary file, fsync, rename, checksum, lock file or schema version. A crash or disk-full condition during write can leave a truncated or corrupt file. The API still reports success because the write failure is swallowed.

### 2.4 Concurrency

- Booking, payment and partner methods are `synchronized` within one JVM.
- `DataStore` accessors are `synchronized`.
- There is no cross-process lock. Two server processes sharing the same working directory can overwrite each other's files.
- Reads and writes are whole-file; there is no row-level locking or optimistic concurrency.

---

## 3. Entity model

```text
Destination 1 --- * Place
Destination 1 --- * Hotel
Partner     1 --- * Hotel          (ownerId)
Hotel       1 --- * Booking        (hotelId, loose reference)
Booking     1 --- 0..1 Payment     (embedded fields, not an entity)

PartnerData
  ├── partners: List<Partner>
  ├── hashes:   Map<partnerId, salt$sha256>
  └── hotels:   List<Hotel>        (partner-owned only)

Bookings file
  └── HashMap<bookingId, Booking>
```

There are no foreign keys, referential constraints, indexes or cascades. Relationships exist only as string IDs resolved in memory.

---

## 4. Data dictionary

### 4.1 Destination

| Field | Type | Nullable | Meaning | Constraints/source |
|---|---|---|---|---|
| `id` | string | No | Stable slug | Code-defined |
| `name` | string | No | Display name | Code-defined |
| `nameMm` | string | Yes | Myanmar-script name | Code-defined |
| `region` | string | No | Administrative region/state | Code-defined |
| `tagline` | string | Yes | Short marketing line | Code-defined |
| `description` | string | Yes | Editorial description | Code-defined |
| `bestSeason` | string | Yes | Suggested season | Curated, not verified live |
| `gradient` | string | Yes | CSS fallback visual | Code-defined |
| `emoji` | string | Yes | Decorative glyph | Code-defined |
| `recommendedDays` | int | No | Suggested stay | Used for allocation |
| `lat`, `lon` | double | No | Coordinates | Used for maps/distance |
| `places` | list<Place> | No | Attractions | 66 total across nine destinations |

### 4.2 Place

| Field | Type | Nullable | Meaning |
|---|---|---|---|
| `id` | string | No | Stable slug |
| `name` | string | No | Attraction name |
| `category` | string | No | Temple, Culture, Nature, etc. |
| `bestTime` | string | Yes | Suggested visit time |
| `area` | string | Yes | Local area |
| `description` | string | Yes | Editorial copy |
| `hours` | double | No | Visit duration |
| `rating` | double | No | Curated rating |
| `entryFee` | int | No | MMK per person |

### 4.3 Hotel

| Field | Type | Nullable | Meaning | Constraints |
|---|---|---|---|---|
| `id` | string | No | Stable ID | Base IDs code-defined; partner `OWN-` + 6 hex chars |
| `destinationId` | string | No | Destination reference | Must resolve to a destination on save |
| `destinationName` | string | Yes | Denormalised display name | Copied from destination |
| `name` | string | No | Hotel name | Partner save requires ≥ 3 characters |
| `tier` | string | No | Budget, Mid-range, Luxury | Enumerated on partner save |
| `area` | string | Yes | Township/area | Defaults to destination name |
| `description` | string | Yes | Marketing copy | Partner save requires ≥ 15 characters |
| `gradient` | string | Yes | CSS fallback visual | Generated for partner hotels |
| `ownerId` | string | Yes | Partner ID | Null for seeded hotels |
| `ownerName` | string | Yes | Partner display name | Denormalised |
| `address` | string | Yes | Street address | Defaults to area + destination |
| `roomType` | string | Yes | Room description | Defaults to “Deluxe room” |
| `contact` | string | Yes | Contact phone | Normalised or partner phone |
| `checkInTime` | string | Yes | e.g. 14:00 | Defaults |
| `checkOutTime` | string | Yes | e.g. 12:00 | Defaults |
| `pricePerNight` | int | No | MMK per room per night | 5,000–5,000,000 on partner save |
| `rating` | double | No | Curated/default rating | PARTNER DEFAULT 4.4 |
| `stars` | int | No | 1–5 | Clamped/defaulted on save |
| `roomsLeft` | int | No | Available room counter | 1–300 on save; no date dimension |
| `roomsTotal` | int | No | Total rooms | Set equal to submitted rooms on edit |
| `published` | boolean | No | Visibility | Always true for partner saves; no unpublish flow |
| `amenities` | list<string> | No | Facilities | Defaults to Wi-Fi, Breakfast |

### 4.4 Partner

| Field | Type | Nullable | Meaning | Constraints |
|---|---|---|---|---|
| `id` | string | No | Partner ID | `PT-` + 6 hex chars |
| `ownerName` | string | No | Business/person name | ≥ 2 characters |
| `email` | string | No | Login identifier | Lowercased; unique among partners; regex validated |
| `phone` | string | No | Contact | Normalised Myanmar phone |
| `createdAt` | string | No | Local timestamp | `yyyy-MM-dd HH:mm:ss` |

Password material is **not** in `Partner`; it is stored separately in `PartnerData.hashes`.

### 4.5 Password hash

| Field | Type | Meaning |
|---|---|---|
| key | partner ID | Links hash to partner |
| value | string | `salt$sha256(salt + password)` |

- Salt: 12 hex characters from a UUID substring.
- Hash: 64 lowercase hex characters (SHA-256).
- Single round, no work factor, no pepper.
- No rehash-on-login or algorithm marker/version.

### 4.6 PartnerData

| Field | Type | Meaning |
|---|---|---|
| `partners` | `List<Partner>` | All partner accounts |
| `hashes` | `Map<String,String>` | Partner ID → salted hash |
| `hotels` | `List<Hotel>` | All partner-owned hotels |

`serialVersionUID = 1L` for `PartnerData`, `Partner`, `Hotel`, `Booking` and other model classes.

### 4.7 Booking

| Field | Type | Nullable | Meaning | Constraints |
|---|---|---|---|---|
| `id` | string | No | Booking reference | `BK-` + 6 uppercase hex chars; no collision check |
| `hotelId` | string | No | Hotel reference | Resolved at creation; may be orphaned later |
| `hotelName` | string | No | Denormalised name | Snapshot at booking time |
| `destinationName` | string | No | Denormalised destination | Snapshot |
| `guestName` | string | No | Guest name | Trimmed, ≥ 2 characters |
| `phone` | string | No | Guest phone | Normalised `09` + 7–9 digits |
| `checkIn` | string | No | ISO date | Not before today at creation |
| `checkOut` | string | No | ISO date | Computed |
| `nights` | int | No | Stay length | 1–30 |
| `rooms` | int | No | Rooms booked | 1–10 and ≤ inventory at creation |
| `pricePerNight` | int | No | Rate snapshot | Copied from hotel |
| `total` | int | No | Total MMK | `price × nights × rooms` |
| `status` | string | No | `PENDING_PAYMENT` or `CONFIRMED` | No other states used |
| `paymentMethod` | string | Yes | `KPAY`, `WAVEPAY`, `AYAPAY` | Set on success |
| `transactionId` | string | Yes | Simulated reference | Prefix + date + 6 digits |
| `createdAt` | string | No | Local timestamp | String, no timezone |
| `paidAt` | string | Yes | Local timestamp | Set on success |

No cancellation, refund, hold-expiry, tax, commission or provider-reference fields exist.

---

## 5. Identity generation and collision risk

| Entity | Generation | Entropy | Collision handling |
|---|---|---|---|
| Booking | `BK-` + first 6 chars of UUID | 24 bits | None |
| Partner | `PT-` + first 6 chars of UUID | 24 bits | None |
| Partner hotel | `OWN-` + first 6 chars of UUID | 24 bits | None |
| Transaction | Prefix + `yyyyMMdd` + six random digits | ~20 bits/day | None |

At a few thousand records, 24-bit IDs have a meaningful birthday-collision probability. A collision would overwrite or alias records. Production IDs should be UUIDv7/ULID or database-generated, with uniqueness constraints and retry.

---

## 6. Query and access patterns

| Operation | Implementation | Complexity |
|---|---|---|
| Destination lookup | Linear scan over nine items | O(9) |
| Hotel lookup | Linear scan over base + partner hotels | O(n) |
| Bookings by phone | Full scan of booking map | O(n) |
| All bookings | Full map serialization | O(n) |
| Partner hotels | Filter all hotels by owner | O(n) |
| Partner bookings | Full booking scan + hotel lookup per booking | O(n·h) |
| Hotel availability check | Single integer comparison | O(1) |

This is acceptable for a demo with tens of records and inadequate for production volume. No indexes, pagination or query limits exist.

---

## 7. Data lifecycle

### 7.1 Booking

```text
createBooking
  -> validate
  -> decrement hotel.roomsLeft
  -> status PENDING_PAYMENT
  -> saveBookings()

pay success
  -> status CONFIRMED
  -> payment fields set
  -> saveBookings()

pay decline
  -> no persistence
  -> remains PENDING_PAYMENT
  -> rooms still held

cancel/expire/refund
  -> NOT IMPLEMENTED
```

**Lifecycle defects**

- Pending holds never expire or release rooms.
- There is no cancellation state or inventory restoration.
- There is no refund or failure state.
- Repeated booking requests create duplicates.
- A booking can be paid by anyone who obtains its ID and supplies a valid-format wallet phone and PIN.
- On restart, base-hotel availability is recalculated from the code-seeded count minus all persisted bookings. Partner-hotel availability is reset to `roomsTotal` and then decremented by persisted bookings.
- If a hotel is deleted, its bookings remain but no inventory or partner view can resolve them.

### 7.2 Partner hotel

```text
create -> registry + savePartners()
edit   -> overwrite fields + reset roomsTotal/roomsLeft + savePartners()
delete -> remove from registry + savePartners()
```

**Lifecycle defects**

- Edit resets inventory to the submitted count, ignoring current bookings. Availability is overstated until restart, when `roomsLeft = roomsTotal - bookings` is recomputed.
- Delete does not cascade or tombstone; bookings become orphaned.
- Deleting all demo partner hotels causes them to be reseeded on the next start.
- There is no draft, unpublished, archived or suspended state.

### 7.3 Partner account

```text
register -> partners + hash -> savePartners()
login    -> verify hash -> return Partner object
```

- No email verification.
- No password reset.
- No account deletion or deactivation.
- No session records.
- No login audit.
- No lockout.

### 7.4 Catalogue

- Rebuilt from code every start.
- No runtime admin edit.
- No content versioning.
- No publication workflow.

---

## 8. Integrity risks

| Risk | Severity | Impact |
|---|---|---|
| Whole-file non-atomic writes | High | Crash/disk-full can corrupt all bookings or partners |
| Silent write failures | High | API reports success while data is lost |
| No backup/restore | High | Corruption is unrecoverable |
| No schema version/migration | High | Field changes can break deserialization |
| Date-less inventory | High | Wrong availability across seasons |
| Holds never expire | High | Inventory leaks permanently |
| Partner edit resets rooms | High | Overselling |
| Delete orphans bookings | High | Lost partner visibility and reconciliation |
| Demo hotels reseeded after deletion | Medium | Deleted data reappears |
| 24-bit IDs | Medium | Collision/overwrite |
| No cross-process lock | Medium | Lost updates with multiple servers |
| PII unencrypted | High | Privacy breach on file access |
| Single-round SHA-256 | Medium | Faster offline password cracking |
| Denormalised hotel/guest fields | Low | Stale historical display data, though useful as snapshots |
| No foreign keys | Medium | Orphans and inconsistent references |
| Local timestamps without timezone | Low | Ambiguous ordering across zones/DST |
| String date comparisons | Low | Works only while ISO format is preserved |
| Integer MMK amounts | Low | Current maxima fit, but no currency/minor-unit model |

---

## 9. Backup, recovery and retention

**Current state:** none.

- No scheduled backups.
- No point-in-time recovery.
- No write-ahead log.
- No integrity check on startup beyond catching deserialization exceptions.
- No quarantine of corrupt files; a corrupt file is ignored, then may be overwritten by the next save.
- No retention policy for bookings, PII or partner accounts.
- No deletion/export process for data-subject requests.
- No documented recovery runbook.

**Minimum interim practice for the demo**

1. Stop the server before copying `.ser` files.
2. Copy both files to a timestamped backup directory.
3. Record the code version used to create them.
4. Restore only with the same model classes and `serialVersionUID`.
5. Never edit `.ser` files by hand.

This is a manual workaround, not a production backup strategy.

---

## 10. Proposed relational target

The following schema is a recommended production direction, not an implementation in this repository. PostgreSQL is a suitable default.

### 10.1 Core identity and access

```sql
accounts (
  id uuid primary key,
  kind text not null check (kind in ('traveller','partner','admin')),
  email citext unique,
  phone text,
  password_hash text,          -- Argon2id/bcrypt/scrypt
  email_verified_at timestamptz,
  created_at timestamptz not null default now(),
  disabled_at timestamptz
);

sessions (
  id uuid primary key,
  account_id uuid not null references accounts(id),
  token_hash text not null,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  ip inet,
  user_agent text,
  created_at timestamptz not null default now()
);

partner_profiles (
  account_id uuid primary key references accounts(id),
  business_name text not null,
  contact_phone text,
  status text not null default 'pending'
);
```

### 10.2 Catalogue

```sql
destinations (
  id text primary key,
  name text not null,
  name_mm text,
  region text not null,
  description text,
  best_season text,
  recommended_days int not null check (recommended_days between 1 and 10),
  lat numeric(9,6),
  lon numeric(9,6)
);

places (
  id text primary key,
  destination_id text not null references destinations(id),
  name text not null,
  category text not null,
  best_time time,
  area text,
  description text,
  hours numeric(4,2) not null,
  rating numeric(2,1),
  entry_fee_mmk int not null default 0
);
```

### 10.3 Hotels and inventory

```sql
hotels (
  id uuid primary key,
  partner_account_id uuid references accounts(id),
  destination_id text not null references destinations(id),
  name text not null,
  tier text not null check (tier in ('Budget','Mid-range','Luxury')),
  stars int check (stars between 1 and 5),
  area text,
  address text,
  description text,
  contact_phone text,
  check_in_time time,
  check_out_time time,
  status text not null default 'draft'
    check (status in ('draft','published','suspended','archived')),
  rating numeric(3,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

room_types (
  id uuid primary key,
  hotel_id uuid not null references hotels(id),
  name text not null,
  max_occupancy int not null,
  base_price_mmk int not null check (base_price_mmk > 0)
);

room_inventory (
  room_type_id uuid not null references room_types(id),
  stay_date date not null,
  rooms_total int not null check (rooms_total >= 0),
  rooms_held int not null default 0 check (rooms_held >= 0),
  rooms_sold int not null default 0 check (rooms_sold >= 0),
  primary key (room_type_id, stay_date),
  check (rooms_held + rooms_sold <= rooms_total)
);

amenities (
  id serial primary key,
  name text unique not null
);

hotel_amenities (
  hotel_id uuid references hotels(id),
  amenity_id int references amenities(id),
  primary key (hotel_id, amenity_id)
);
```

### 10.4 Bookings, holds, payments, refunds

```sql
bookings (
  id uuid primary key,
  reference text unique not null,
  traveller_account_id uuid references accounts(id),
  hotel_id uuid not null references hotels(id),
  room_type_id uuid not null references room_types(id),
  guest_name text not null,
  guest_phone text not null,
  check_in date not null,
  check_out date not null,
  nights int not null check (nights > 0),
  rooms int not null check (rooms > 0),
  status text not null
    check (status in ('pending','confirmed','cancelled','expired','refunded','failed')),
  price_per_night_mmk int not null,
  subtotal_mmk int not null,
  tax_mmk int not null default 0,
  total_mmk int not null,
  hold_expires_at timestamptz,
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  idempotency_key text unique
);

booking_nights (
  booking_id uuid references bookings(id),
  stay_date date not null,
  rooms int not null,
  rate_mmk int not null,
  primary key (booking_id, stay_date)
);

payments (
  id uuid primary key,
  booking_id uuid not null references bookings(id),
  provider text not null,
  provider_reference text,
  status text not null
    check (status in ('initiated','authorised','captured','failed','refunded')),
  amount_mmk int not null,
  idempotency_key text unique,
  created_at timestamptz not null default now(),
  captured_at timestamptz,
  raw_response jsonb
);

refunds (
  id uuid primary key,
  payment_id uuid not null references payments(id),
  amount_mmk int not null,
  reason text,
  status text not null,
  provider_reference text,
  created_at timestamptz not null default now()
);
```

Inventory updates must use a transaction with row locks:

```sql
begin;
select rooms_total, rooms_held, rooms_sold
from room_inventory
where room_type_id = $1 and stay_date between $2 and $3
for update;
-- validate availability for every night
update room_inventory set rooms_held = rooms_held + $rooms ...
-- insert booking + booking_nights + hold record
commit;
```

### 10.5 Saved trips and itineraries

```sql
saved_trips (
  id uuid primary key,
  account_id uuid not null references accounts(id),
  title text not null,
  summary text,
  itinerary_json jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

itinerary_days (
  id uuid primary key,
  saved_trip_id uuid not null references saved_trips(id) on delete cascade,
  day_number int not null,
  stay_date date,
  destination_id text references destinations(id),
  theme text,
  active_hours numeric(4,2),
  travel_hours numeric(4,2),
  estimated_cost_mmk int
);

itinerary_activities (
  id uuid primary key,
  itinerary_day_id uuid not null references itinerary_days(id) on delete cascade,
  sequence int not null,
  start_time time,
  title text not null,
  description text,
  category text,
  place_id text references places(id),
  hours numeric(4,2),
  cost_mmk int
);
```

A JSON snapshot is acceptable for the generated plan, while normalized rows support editing, search and analytics. If the product is read-heavy and edits remain local, store only `itinerary_json` initially.

### 10.6 Reviews, audit, notifications

```sql
reviews (
  id uuid primary key,
  booking_id uuid unique references bookings(id),
  hotel_id uuid not null references hotels(id),
  account_id uuid not null references accounts(id),
  rating int not null check (rating between 1 and 5),
  title text,
  body text,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

audit_events (
  id bigserial primary key,
  actor_account_id uuid,
  actor_kind text,
  action text not null,
  entity_type text not null,
  entity_id text,
  before jsonb,
  after jsonb,
  request_id text,
  ip inet,
  created_at timestamptz not null default now()
);

outbox (
  id bigserial primary key,
  event_type text not null,
  payload jsonb not null,
  status text not null default 'pending',
  attempts int not null default 0,
  next_attempt_at timestamptz,
  created_at timestamptz not null default now()
);
```

### 10.7 Required indexes and constraints

- Unique: `accounts.email`, `bookings.reference`, `payments.idempotency_key`, `bookings.idempotency_key`.
- Index: `bookings(traveller_account_id, created_at desc)`.
- Index: `bookings(hotel_id, created_at desc)`.
- Index: `room_inventory(room_type_id, stay_date)`.
- Index: `hotels(destination_id, status)`.
- Index: `sessions(token_hash)`, `sessions(expires_at)`.
- Check: `check_out > check_in`; `nights = check_out - check_in`.
- Check: inventory never negative; held + sold ≤ total.
- Foreign keys with explicit `ON DELETE` policies.
- Partial unique index for one review per completed booking.

---

## 11. Migration plan from serialized files

1. **Freeze writes.** Stop the server or put it in read-only mode.
2. **Back up** both `.ser` files and record the exact code commit/version.
3. **Export** with a small Java utility that deserializes using the same classes and writes NDJSON for bookings, partners and partner hotels.
4. **Validate** counts, required fields, phone formats, dates, amounts, orphan hotel references and duplicate IDs.
5. **Transform**:
   - normalize phones;
   - map status strings to the new enum;
   - create one booking-night row per night;
   - create one payment row for confirmed bookings;
   - create partner accounts and hotel ownership;
   - preserve historical hotel/guest snapshots where needed.
6. **Load** into PostgreSQL inside a transaction with deferred constraints.
7. **Reconcile** record counts and sums against the export.
8. **Dual-read** in staging and compare API output.
9. **Cut over** during a maintenance window; disable `.ser` writes.
10. **Archive** the old files encrypted, with a defined retention period.

Do not attempt to parse Java serialization with ad-hoc scripts. Use the original classes or a controlled Java migration tool.

---

## 12. Privacy and compliance requirements

The current store contains:

- guest names;
- guest phone numbers;
- stay dates and amounts;
- partner business names, emails and phones;
- password hashes.

Minimum production requirements:

- encrypt at rest and in transit;
- restrict database access by role and network;
- log access to PII;
- define retention and deletion periods;
- support data export and erasure requests;
- avoid putting PII in logs;
- separate analytics identifiers from booking identity;
- document lawful basis and privacy notice;
- obtain consent where required;
- tokenize or minimize phone numbers in non-essential views;
- mask guest contact details in partner and support interfaces;
- audit staff access.

The current `.ser` files have none of these controls beyond filesystem permissions.

---

## 13. Summary verdict

Persistence is the weakest part of the application. It is suitable only for a local demo with a single process and a small number of records. Before any shared or public deployment:

- replace Java serialization with a transactional database;
- make inventory date-specific and atomic;
- implement hold expiry, cancellation, refund and idempotency;
- stop swallowing write failures;
- add backups, integrity checks and recovery drills;
- encrypt and minimize PII;
- migrate identity and authorization to server-side sessions.
