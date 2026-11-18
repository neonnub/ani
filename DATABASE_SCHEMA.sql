-- ============================================================================
-- MHT-SmartPlanner / MSTP — PostgreSQL schema
-- Derived from the current Java models (com.mmtrip.common) and extended with
-- the tables required by the target architecture.
--
-- Status legend:
--   [LIVE]    Mirrors a class that exists in the Java code today.
--   [PLANNED] Target-architecture table; no Java code writes to it yet.
--
-- Money: the Java code uses int MMK. Here money is NUMERIC(12,2) so that
--        payments, refunds and invoices can carry sub-kyat precision later.
--        Convert with BigDecimal, never double.
-- Target: PostgreSQL 14+
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "citext";     -- case-insensitive email

-- Shared updated_at trigger -------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- 1. IDENTITY & ACCESS
-- ============================================================================

-- [PLANNED] Travellers and staff. Today the traveller "profile" lives only in
-- browser localStorage; there is no server-side account.
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           CITEXT UNIQUE,
    phone           VARCHAR(20) UNIQUE,
    display_name    VARCHAR(120) NOT NULL,
    password_hash   TEXT,                       -- NULL until a real login exists
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
                    CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DELETED')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at      TIMESTAMPTZ
);
CREATE TRIGGER users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- [PLANNED] Role catalogue: GUEST, TRAVELLER, HOTEL_PARTNER, SHOP_PARTNER,
-- ADMIN, SUPER_ADMIN, plus admin sub-roles (operations, booking, commerce,
-- support). Authorization must be enforced in the API, not only in the UI.
CREATE TABLE roles (
    id              SMALLSERIAL PRIMARY KEY,
    code            VARCHAR(40) NOT NULL UNIQUE,
    name            VARCHAR(80) NOT NULL,
    description     TEXT
);

CREATE TABLE permissions (
    id              SMALLSERIAL PRIMARY KEY,
    code            VARCHAR(80) NOT NULL UNIQUE,   -- e.g. 'hotel:write'
    description     TEXT
);

CREATE TABLE role_permissions (
    role_id         SMALLINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id   SMALLINT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE user_roles (
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id         SMALLINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    granted_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, role_id)
);

-- [PLANNED] Server-side sessions. Today only the partner object is kept in
-- localStorage and the traveller has no session at all.
CREATE TABLE user_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash      TEXT NOT NULL UNIQUE,
    user_agent      TEXT,
    ip_address      INET,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ
);
CREATE INDEX user_sessions_user_idx ON user_sessions (user_id, expires_at);

-- [LIVE] com.mmtrip.common.Partner + PartnerData.partners
-- IDs keep the current 'PT-XXXXXX' format.
CREATE TABLE partners (
    id              VARCHAR(20) PRIMARY KEY,
    owner_name      VARCHAR(160) NOT NULL,
    email           CITEXT NOT NULL UNIQUE,
    phone           VARCHAR(20) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING', 'APPROVED', 'SUSPENDED')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER partners_updated_at BEFORE UPDATE ON partners
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- [LIVE] PartnerData.hashes — currently "salt$sha256(salt+password)".
-- Replace SHA-256 with bcrypt/argon2 when real accounts are introduced.
CREATE TABLE partner_credentials (
    partner_id      VARCHAR(20) PRIMARY KEY REFERENCES partners(id) ON DELETE CASCADE,
    password_hash   TEXT NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- [PLANNED] Partner KYC / business documents.
CREATE TABLE partner_documents (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id      VARCHAR(20) NOT NULL REFERENCES partners(id) ON DELETE CASCADE,
    doc_type        VARCHAR(40) NOT NULL,
    file_url        TEXT NOT NULL,
    verified        BOOLEAN NOT NULL DEFAULT FALSE,
    uploaded_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ============================================================================
-- 2. TRAVEL CATALOGUE
-- ============================================================================

-- [LIVE] com.mmtrip.common.Destination (DataStore, rebuilt from code today)
CREATE TABLE destinations (
    id                  VARCHAR(40) PRIMARY KEY,          -- 'bagan', 'inle'
    name                VARCHAR(120) NOT NULL,
    name_mm             VARCHAR(160),
    region              VARCHAR(120) NOT NULL,
    tagline             VARCHAR(240),
    description         TEXT,
    best_season         VARCHAR(120),
    recommended_days    SMALLINT NOT NULL DEFAULT 1 CHECK (recommended_days BETWEEN 1 AND 30),
    lat                 NUMERIC(9,6),
    lon                 NUMERIC(9,6),
    gradient            VARCHAR(160),                     -- UI fallback artwork
    emoji               VARCHAR(16),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER destinations_updated_at BEFORE UPDATE ON destinations
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- [LIVE] com.mmtrip.common.Place (nested inside Destination)
CREATE TABLE places (
    id              VARCHAR(60) PRIMARY KEY,              -- 'bagan-ananda'
    destination_id  VARCHAR(40) NOT NULL REFERENCES destinations(id) ON DELETE CASCADE,
    name            VARCHAR(160) NOT NULL,
    category        VARCHAR(40) NOT NULL,                 -- Temple, Food, Nature...
    best_time       VARCHAR(10),                          -- 'HH:MM' recommended slot
    area            VARCHAR(120),
    hours           NUMERIC(4,1) NOT NULL DEFAULT 1.0 CHECK (hours > 0),
    rating          NUMERIC(2,1) CHECK (rating BETWEEN 0 AND 5),
    entry_fee       INTEGER NOT NULL DEFAULT 0 CHECK (entry_fee >= 0),  -- MMK / person
    description     TEXT,
    is_premium      BOOLEAN NOT NULL DEFAULT FALSE,       -- >100,000 MMK extras
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX places_destination_idx ON places (destination_id, category);
CREATE TRIGGER places_updated_at BEFORE UPDATE ON places
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- [LIVE] com.mmtrip.common.Hotel (base hotels + partner-owned hotels)
-- rooms_total / rooms_left are kept for compatibility with the current
-- single-pool inventory. Date-based availability lives in room_inventory.
CREATE TABLE hotels (
    id                  VARCHAR(40) PRIMARY KEY,          -- 'bagan-h1', 'OWN-XXXXXX'
    destination_id      VARCHAR(40) NOT NULL REFERENCES destinations(id),
    owner_id            VARCHAR(20) REFERENCES partners(id) ON DELETE SET NULL,
    name                VARCHAR(160) NOT NULL,
    tier                VARCHAR(20) NOT NULL
                        CHECK (tier IN ('Budget', 'Mid-range', 'Luxury')),
    stars               SMALLINT NOT NULL DEFAULT 3 CHECK (stars BETWEEN 1 AND 5),
    area                VARCHAR(120),
    address             VARCHAR(240),
    description         TEXT,
    room_type           VARCHAR(120),
    contact             VARCHAR(20),
    check_in_time       VARCHAR(5) NOT NULL DEFAULT '14:00',
    check_out_time      VARCHAR(5) NOT NULL DEFAULT '12:00',
    price_per_night     NUMERIC(12,2) NOT NULL CHECK (price_per_night >= 0),
    rating              NUMERIC(2,1) CHECK (rating BETWEEN 0 AND 5),
    rooms_total         SMALLINT NOT NULL DEFAULT 0 CHECK (rooms_total >= 0),
    rooms_left          SMALLINT NOT NULL DEFAULT 0 CHECK (rooms_left >= 0),
    published           BOOLEAN NOT NULL DEFAULT TRUE,
    gradient            VARCHAR(160),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at          TIMESTAMPTZ,
    CONSTRAINT hotels_rooms_left_le_total CHECK (rooms_left <= rooms_total)
);
CREATE INDEX hotels_destination_idx ON hotels (destination_id) WHERE deleted_at IS NULL;
CREATE INDEX hotels_owner_idx ON hotels (owner_id) WHERE owner_id IS NOT NULL;
CREATE TRIGGER hotels_updated_at BEFORE UPDATE ON hotels
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- [LIVE] Hotel.amenities (List<String>)
CREATE TABLE hotel_amenities (
    hotel_id        VARCHAR(40) NOT NULL REFERENCES hotels(id) ON DELETE CASCADE,
    amenity         VARCHAR(60) NOT NULL,
    PRIMARY KEY (hotel_id, amenity)
);

-- [PLANNED] A hotel can sell several room types; the current model has one.
CREATE TABLE room_types (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hotel_id        VARCHAR(40) NOT NULL REFERENCES hotels(id) ON DELETE CASCADE,
    name            VARCHAR(120) NOT NULL,
    capacity        SMALLINT NOT NULL DEFAULT 2 CHECK (capacity BETWEEN 1 AND 20),
    base_price      NUMERIC(12,2) NOT NULL CHECK (base_price >= 0),
    total_rooms     SMALLINT NOT NULL CHECK (total_rooms >= 0),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX room_types_hotel_idx ON room_types (hotel_id);

-- [PLANNED] Date-based inventory. Replaces the single roomsLeft counter so
-- concurrent bookings cannot oversell the same night.
CREATE TABLE room_inventory (
    room_type_id    UUID NOT NULL REFERENCES room_types(id) ON DELETE CASCADE,
    stay_date       DATE NOT NULL,
    rooms_total     SMALLINT NOT NULL CHECK (rooms_total >= 0),
    rooms_held      SMALLINT NOT NULL DEFAULT 0 CHECK (rooms_held >= 0),
    rooms_booked    SMALLINT NOT NULL DEFAULT 0 CHECK (rooms_booked >= 0),
    price           NUMERIC(12,2) NOT NULL CHECK (price >= 0),
    PRIMARY KEY (room_type_id, stay_date),
    CONSTRAINT room_inventory_not_oversold
        CHECK (rooms_held + rooms_booked <= rooms_total)
);


-- ============================================================================
-- 3. TRIP PLANNING & ITINERARY
-- ============================================================================

-- [PLANNED] Server-side trip storage. Today saved trips exist only in
-- browser localStorage (SAVED_KEY).
CREATE TABLE trips (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    title           VARCHAR(200),
    start_date      DATE,
    adults          SMALLINT NOT NULL DEFAULT 2 CHECK (adults BETWEEN 1 AND 20),
    children        SMALLINT NOT NULL DEFAULT 0 CHECK (children BETWEEN 0 AND 10),
    budget          NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (budget >= 0),
    transport       VARCHAR(20) NOT NULL DEFAULT 'private_car'
                    CHECK (transport IN ('private_car', 'bus', 'flight', 'boat', 'mixed')),
    style           VARCHAR(20) NOT NULL DEFAULT 'cultural'
                    CHECK (style IN ('cultural', 'adventure', 'relaxation',
                                     'foodie', 'photography', 'family')),
    hotel_tier      VARCHAR(10) NOT NULL DEFAULT 'mid'
                    CHECK (hotel_tier IN ('budget', 'mid', 'luxury')),
    pace            VARCHAR(10) NOT NULL DEFAULT 'balanced'
                    CHECK (pace IN ('relaxed', 'balanced', 'packed')),
    start_location  VARCHAR(120) NOT NULL DEFAULT 'Yangon',
    share_token     VARCHAR(40) UNIQUE,          -- shareable trip link
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX trips_user_idx ON trips (user_id, created_at DESC);
CREATE TRIGGER trips_updated_at BEFORE UPDATE ON trips
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- [LIVE] TripRequest.destinationIds + TripRequest.days (parallel lists)
CREATE TABLE trip_destinations (
    trip_id         UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    destination_id  VARCHAR(40) NOT NULL REFERENCES destinations(id),
    position        SMALLINT NOT NULL CHECK (position >= 0),
    nights          SMALLINT NOT NULL CHECK (nights BETWEEN 1 AND 10),
    PRIMARY KEY (trip_id, destination_id),
    UNIQUE (trip_id, position)
);

-- [LIVE] com.mmtrip.common.Itinerary (generated, currently never persisted)
CREATE TABLE itineraries (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id             UUID REFERENCES trips(id) ON DELETE CASCADE,
    variation           SMALLINT NOT NULL DEFAULT 0,
    title               VARCHAR(200) NOT NULL,
    summary             TEXT,
    total_days          SMALLINT NOT NULL CHECK (total_days BETWEEN 1 AND 21),
    places_covered      SMALLINT NOT NULL DEFAULT 0,
    est_entry_fees      NUMERIC(12,2) NOT NULL DEFAULT 0,
    est_food            NUMERIC(12,2) NOT NULL DEFAULT 0,
    est_transport       NUMERIC(12,2) NOT NULL DEFAULT 0,
    est_stay            NUMERIC(12,2) NOT NULL DEFAULT 0,
    est_total           NUMERIC(12,2) NOT NULL DEFAULT 0,
    budget_set          BOOLEAN NOT NULL DEFAULT FALSE,
    budget_ok           BOOLEAN,
    budget_delta        NUMERIC(12,2),
    tips                TEXT[] NOT NULL DEFAULT '{}',
    warnings            TEXT[] NOT NULL DEFAULT '{}',
    generated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX itineraries_trip_idx ON itineraries (trip_id, generated_at DESC);

-- [LIVE] com.mmtrip.common.DayPlan
CREATE TABLE itinerary_days (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    itinerary_id        UUID NOT NULL REFERENCES itineraries(id) ON DELETE CASCADE,
    day_number          SMALLINT NOT NULL CHECK (day_number >= 1),
    day_date            DATE,
    destination_id      VARCHAR(40) REFERENCES destinations(id),
    theme               VARCHAR(160),
    active_hours        NUMERIC(4,1) NOT NULL DEFAULT 0,
    travel_hours        NUMERIC(4,1) NOT NULL DEFAULT 0,
    est_cost            NUMERIC(12,2) NOT NULL DEFAULT 0,
    UNIQUE (itinerary_id, day_number)
);

-- [LIVE] com.mmtrip.common.Activity
CREATE TABLE activities (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    itinerary_day_id    UUID NOT NULL REFERENCES itinerary_days(id) ON DELETE CASCADE,
    place_id            VARCHAR(60) REFERENCES places(id) ON DELETE SET NULL,
    position            SMALLINT NOT NULL DEFAULT 0,
    time_label          VARCHAR(10),              -- 'HH:MM'
    slot                VARCHAR(20),              -- morning / afternoon / evening
    title               VARCHAR(200) NOT NULL,
    description         TEXT,
    category            VARCHAR(40),
    area                VARCHAR(120),
    hours               NUMERIC(4,1) NOT NULL DEFAULT 1.0,
    cost                NUMERIC(12,2) NOT NULL DEFAULT 0,   -- whole group
    UNIQUE (itinerary_day_id, position)
);
CREATE INDEX activities_day_idx ON activities (itinerary_day_id, position);


-- ============================================================================
-- 4. BOOKING & INVENTORY
-- ============================================================================

-- [LIVE] com.mmtrip.common.Booking
-- Status values match com.mmtrip.common.Models:
--   PENDING_PAYMENT -> CONFIRMED (plus CANCELLED / EXPIRED / REFUNDED).
CREATE TABLE bookings (
    id                  VARCHAR(20) PRIMARY KEY,          -- 'BK-XXXXXX'
    user_id             UUID REFERENCES users(id) ON DELETE SET NULL,
    hotel_id            VARCHAR(40) NOT NULL REFERENCES hotels(id),
    guest_name          VARCHAR(160) NOT NULL,
    phone               VARCHAR(20) NOT NULL,
    check_in            DATE NOT NULL,
    check_out           DATE NOT NULL,
    nights              SMALLINT NOT NULL CHECK (nights BETWEEN 1 AND 30),
    rooms               SMALLINT NOT NULL CHECK (rooms BETWEEN 1 AND 10),
    price_per_night     NUMERIC(12,2) NOT NULL CHECK (price_per_night >= 0),
    total               NUMERIC(12,2) NOT NULL CHECK (total >= 0),
    status              VARCHAR(20) NOT NULL DEFAULT 'PENDING_PAYMENT'
                        CHECK (status IN ('PENDING_PAYMENT', 'CONFIRMED',
                                          'CANCELLED', 'EXPIRED', 'REFUNDED')),
    idempotency_key     VARCHAR(80) UNIQUE,               -- prevents double submit
    hold_expires_at     TIMESTAMPTZ,                      -- room hold countdown
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT bookings_dates_ok CHECK (check_out > check_in)
);
CREATE INDEX bookings_phone_idx ON bookings (phone, created_at DESC);
CREATE INDEX bookings_hotel_idx ON bookings (hotel_id, check_in);
CREATE INDEX bookings_status_idx ON bookings (status, hold_expires_at);
CREATE TRIGGER bookings_updated_at BEFORE UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- [PLANNED] Per-room-type lines for a booking.
CREATE TABLE booking_rooms (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id      VARCHAR(20) NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    room_type_id    UUID NOT NULL REFERENCES room_types(id),
    rooms           SMALLINT NOT NULL CHECK (rooms >= 1),
    price_per_night NUMERIC(12,2) NOT NULL CHECK (price_per_night >= 0)
);

-- [PLANNED] Append-only status trail (audit requirement).
CREATE TABLE booking_status_history (
    id              BIGSERIAL PRIMARY KEY,
    booking_id      VARCHAR(20) NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    from_status     VARCHAR(20),
    to_status       VARCHAR(20) NOT NULL,
    reason          TEXT,
    changed_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX booking_status_history_booking_idx
    ON booking_status_history (booking_id, changed_at);


-- ============================================================================
-- 5. PAYMENTS
-- ============================================================================

-- [LIVE] com.mmtrip.common.PaymentResult + Booking.paymentMethod/transactionId
-- Today payments are simulated; this table is the shape a real provider needs.
CREATE TABLE payments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id          VARCHAR(20) NOT NULL REFERENCES bookings(id) ON DELETE RESTRICT,
    method              VARCHAR(20) NOT NULL
                        CHECK (method IN ('KPAY', 'WAVEPAY', 'AYAPAY', 'CARD', 'CASH')),
    amount              NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    currency            CHAR(3) NOT NULL DEFAULT 'MMK',
    status              VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                        CHECK (status IN ('PENDING', 'AUTHORIZED', 'PAID',
                                          'FAILED', 'REFUNDED', 'PARTIALLY_REFUNDED')),
    provider_ref        VARCHAR(120),                     -- provider-side id
    transaction_id      VARCHAR(60) UNIQUE,               -- 'KP20261112-000123'
    wallet_phone        VARCHAR(20),
    failure_reason      TEXT,
    paid_at             TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX payments_booking_idx ON payments (booking_id, created_at DESC);
CREATE INDEX payments_status_idx ON payments (status);
CREATE TRIGGER payments_updated_at BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- [PLANNED] Raw provider callbacks. Store the payload and whether the
-- signature was verified; never store a wallet PIN.
CREATE TABLE payment_events (
    id                  BIGSERIAL PRIMARY KEY,
    payment_id          UUID REFERENCES payments(id) ON DELETE CASCADE,
    event_type          VARCHAR(60) NOT NULL,
    payload             JSONB NOT NULL,
    signature_verified  BOOLEAN NOT NULL DEFAULT FALSE,
    received_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX payment_events_payment_idx ON payment_events (payment_id, received_at);

-- [PLANNED] Cancellation / refund workflow.
CREATE TABLE refunds (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id      UUID NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
    amount          NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    reason          TEXT,
    status          VARCHAR(20) NOT NULL DEFAULT 'REQUESTED'
                    CHECK (status IN ('REQUESTED', 'APPROVED', 'PROCESSED',
                                      'REJECTED', 'FAILED')),
    requested_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at    TIMESTAMPTZ
);
CREATE INDEX refunds_payment_idx ON refunds (payment_id);


-- ============================================================================
-- 6. SEASONAL COMMERCE  [all PLANNED]
-- ============================================================================

CREATE TABLE categories (
    id              SMALLSERIAL PRIMARY KEY,
    slug            VARCHAR(60) NOT NULL UNIQUE,
    name            VARCHAR(120) NOT NULL,
    parent_id       SMALLINT REFERENCES categories(id) ON DELETE SET NULL
);

CREATE TABLE products (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id     SMALLINT NOT NULL REFERENCES categories(id),
    partner_id      VARCHAR(20) REFERENCES partners(id) ON DELETE SET NULL,
    sku             VARCHAR(60) NOT NULL UNIQUE,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    season_tags     TEXT[] NOT NULL DEFAULT '{}',   -- 'winter', 'monsoon', 'trekking'
    price           NUMERIC(12,2) NOT NULL CHECK (price >= 0),
    currency        CHAR(3) NOT NULL DEFAULT 'MMK',
    image_url       TEXT,
    published       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX products_category_idx ON products (category_id) WHERE published;
CREATE TRIGGER products_updated_at BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE product_variants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id      UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    size            VARCHAR(20),
    colour          VARCHAR(40),
    sku             VARCHAR(60) NOT NULL UNIQUE,
    price_delta     NUMERIC(12,2) NOT NULL DEFAULT 0
);

CREATE TABLE product_stock (
    variant_id      UUID PRIMARY KEY REFERENCES product_variants(id) ON DELETE CASCADE,
    quantity        INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    reserved        INTEGER NOT NULL DEFAULT 0 CHECK (reserved >= 0),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT product_stock_not_oversold CHECK (reserved <= quantity)
);

CREATE TABLE carts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    status          VARCHAR(20) NOT NULL DEFAULT 'OPEN'
                    CHECK (status IN ('OPEN', 'CHECKED_OUT', 'ABANDONED')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE cart_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id         UUID NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
    variant_id      UUID NOT NULL REFERENCES product_variants(id),
    quantity        SMALLINT NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    UNIQUE (cart_id, variant_id)
);

CREATE TABLE orders (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    order_number    VARCHAR(30) NOT NULL UNIQUE,
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING', 'PAID', 'PACKED', 'SHIPPED',
                                      'DELIVERED', 'CANCELLED', 'REFUNDED')),
    subtotal        NUMERIC(12,2) NOT NULL DEFAULT 0,
    shipping_fee    NUMERIC(12,2) NOT NULL DEFAULT 0,
    total           NUMERIC(12,2) NOT NULL DEFAULT 0,
    shipping_address JSONB,
    placed_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX orders_user_idx ON orders (user_id, placed_at DESC);
CREATE TRIGGER orders_updated_at BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE order_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    variant_id      UUID NOT NULL REFERENCES product_variants(id),
    quantity        SMALLINT NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0)
);


-- ============================================================================
-- 7. WEATHER, NOTIFICATIONS, AUDIT  [all PLANNED]
-- ============================================================================

-- Weather must be shown as 'unavailable' or 'stale' when data is missing or
-- expired; never fill it with AI-generated values.
CREATE TABLE weather_snapshots (
    id              BIGSERIAL PRIMARY KEY,
    destination_id  VARCHAR(40) NOT NULL REFERENCES destinations(id) ON DELETE CASCADE,
    observed_at     TIMESTAMPTZ NOT NULL,
    source          VARCHAR(60) NOT NULL,
    temp_c          NUMERIC(4,1),
    condition       VARCHAR(60),
    rain_mm         NUMERIC(6,2),
    wind_kph        NUMERIC(5,1),
    raw             JSONB,
    fetched_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (destination_id, observed_at, source)
);
CREATE INDEX weather_snapshots_latest_idx
    ON weather_snapshots (destination_id, observed_at DESC);

CREATE TABLE weather_alerts (
    id              BIGSERIAL PRIMARY KEY,
    destination_id  VARCHAR(40) NOT NULL REFERENCES destinations(id) ON DELETE CASCADE,
    severity        VARCHAR(20) NOT NULL CHECK (severity IN ('INFO', 'WATCH', 'WARNING')),
    message         TEXT NOT NULL,
    starts_at       TIMESTAMPTZ NOT NULL,
    ends_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE notifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    channel         VARCHAR(20) NOT NULL CHECK (channel IN ('EMAIL', 'SMS', 'PUSH', 'IN_APP')),
    template        VARCHAR(60) NOT NULL,
    payload         JSONB NOT NULL DEFAULT '{}',
    status          VARCHAR(20) NOT NULL DEFAULT 'QUEUED'
                    CHECK (status IN ('QUEUED', 'SENT', 'FAILED', 'READ')),
    sent_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX notifications_user_idx ON notifications (user_id, created_at DESC);

CREATE TABLE notification_preferences (
    user_id         UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    email_opt_in    BOOLEAN NOT NULL DEFAULT TRUE,
    sms_opt_in      BOOLEAN NOT NULL DEFAULT FALSE,
    push_opt_in     BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE audit_logs (
    id              BIGSERIAL PRIMARY KEY,
    actor_id        UUID REFERENCES users(id) ON DELETE SET NULL,
    actor_role      VARCHAR(40),
    action          VARCHAR(80) NOT NULL,          -- 'booking.cancel', 'hotel.update'
    entity_type     VARCHAR(60) NOT NULL,
    entity_id       VARCHAR(80),
    before_state    JSONB,
    after_state     JSONB,
    ip_address      INET,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX audit_logs_entity_idx ON audit_logs (entity_type, entity_id, created_at DESC);
CREATE INDEX audit_logs_actor_idx ON audit_logs (actor_id, created_at DESC);


-- ============================================================================
-- 8. SEED: roles and permissions (safe to re-run)
-- ============================================================================

INSERT INTO roles (code, name, description) VALUES
    ('GUEST',         'Guest',          'Browse destinations, hotels and products'),
    ('TRAVELLER',     'Traveller',      'Plan trips, save trips, book and shop'),
    ('HOTEL_PARTNER', 'Hotel Partner',  'Manage own hotels, rooms and bookings'),
    ('SHOP_PARTNER',  'Shop Partner',   'Manage own products, stock and orders'),
    ('ADMIN',         'Admin',          'Manage the platform'),
    ('SUPER_ADMIN',   'Super Admin',    'Manage admins, roles and settings')
ON CONFLICT (code) DO NOTHING;

INSERT INTO permissions (code, description) VALUES
    ('trip:write',    'Create and edit trips'),
    ('booking:write', 'Create and cancel own bookings'),
    ('hotel:read',    'Read hotel inventory'),
    ('hotel:write',   'Create and edit owned hotels'),
    ('product:write', 'Create and edit owned products'),
    ('order:read',    'Read orders'),
    ('admin:read',    'Access admin dashboards'),
    ('admin:write',   'Perform admin actions'),
    ('system:write',  'Change system settings')
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- End of schema.
-- Migration note: the current .ser files must be exported to these tables
-- before the file-based persistence is removed. Keep the .ser readers until
-- the export has been verified against a full booking/partner count.
-- ============================================================================
