# MSTP — UI/UX Audit

**Audit date:** 12 November 2026  
**Scope:** The live single-page application served from `web/index.html` and `web/app.js`, plus its loaded stylesheets, dialogs and print output.  
**Method:** Static code trace of every rendered view and control, cascade analysis of the loaded CSS, measured contrast from the design tokens, and review of the repository screenshots. No application source was modified.

> **Evidence limits.** This is a code-and-screenshot audit, not a moderated usability study. Screenshots are available at 1440×1000 desktop and 780×1688 mobile/tablet width. No screenshot at 360–390 px, no screen-reader session, no real-device touch test, no cross-browser matrix and no Lighthouse/axe run were available. Findings that depend on those conditions are marked as risks rather than confirmed failures.

---

## 1. Overall verdict

The interface is visually distinctive and considerably more polished than a typical student/demo project. The editorial cream-and-emerald identity, serif display type, illustrated destination scenes and print styling create a coherent travel brand. The main planner, itinerary editor and partner dashboard are genuinely usable on a desktop.

The experience breaks down in four areas:

1. **Trust.** Several prominent claims are untrue in this build: “AI”, “live availability”, “Trusted & Secure”, “24/7 Support”, “no PIN is transmitted”, and a 48-hour cancellation policy that does not exist.
2. **Safety and recovery.** Destructive actions have no undo or confirmation, drafts are not saved, payment declines lose their reason, and booking lookups expose other people’s data.
3. **Accessibility.** Muted text fails WCAG AA contrast, much of the interface is set at 8–11 px, dialogs do not manage focus, tabs expose invalid ARIA, and activity reordering is drag-only.
4. **Architecture visible to users.** A loaded 47 KB stylesheet belongs to an unloaded redesign, a 55 KB and a 56 KB orphan script sit beside the live app, and the live studio is a hybrid of two CSS systems.

### Scorecard

| Dimension | Score | Rationale |
|---|---:|---|
| Visual identity and craft | 8 / 10 | Cohesive, memorable, well-composed desktop layouts. |
| Visual consistency | 5 / 10 | Two studio systems, 14 overlapping class selectors, internal implementation copy in the UI. |
| Information architecture | 4 / 10 | Eight views with no URL, no Back support, no deep links; unrelated jobs share the Bookings view. |
| Forms and validation | 5 / 10 | Labels and inline errors exist, but errors are not announced or linked, and several validations are misleading. |
| Feedback and recovery | 4 / 10 | Good loading states, poor failure recovery; destructive actions are irreversible; payment decline reason is lost. |
| Accessibility | 3.5 / 10 | Some strong foundations, but contrast, type size, focus management, tab semantics and drag alternatives fail. |
| Mobile experience | 5 / 10 | Layout reflows at 1180/960/700 px, but hover-only controls, drag interactions and dense data surfaces remain. |
| Performance | 5 / 10 | 374 KB of unminified HTML/CSS/JS plus 2.8 MB of images on first load, no compression or bundling. |
| Content trust | 3 / 10 | Multiple unsupported claims, no legal pages, no content dates, English-only interface. |
| **Overall demo UX** | **5.5 / 10** | Attractive and demonstrable, not production-safe. |

---

## 2. Design system and visual language

### 2.1 Brand and mood

The design is an editorial “Golden Hour” travel system: warm cream paper, deep emerald, antique gold, a high-contrast serif for display and a humanist sans for UI. It reads as a boutique guidebook rather than a generic booking engine, which is a genuine strength.

| Token | Value | Role |
|---|---|---|
| `--cream` | `#f1f3ed` | Page paper |
| `--paper` | `#fbfcf9` | Cards and dialogs |
| `--ink` | `#182920` | Primary text |
| `--ink-2` | `#3d4b42` | Secondary text |
| `--muted` | `#758078` | Captions and helper text |
| `--green` | `#174c3a` | Primary brand and actions |
| `--green-deep` | `#103728` | Dark surfaces |
| `--gold` | `#c3984b` | Accent, rules, stars |
| `--gold-2` | `#e0bf79` | Accent on dark surfaces |
| `--danger` | `#b74a36` | Errors |
| `--radius` | `22px` | Card/dialog rounding |
| `--max` | `1240px` | Content width |

Typography:

- Display: Fraunces (variable, 300–700), used for `h1`, destination names, prices and editorial headings.
- UI: Manrope (variable, 300–800).
- Body: 15 px / 1.6.
- Many eyebrows, labels and captions are 8–11 px with 0.1–0.2 em tracking.

The serif/sans pairing is appropriate and the hierarchy on marketing pages is strong. Destination cards, the hero and the itinerary hero all use original SVG scenes and local photography, which gives the product a recognisable identity.

### 2.2 Measured contrast

Ratios were computed from the exact hex tokens. WCAG 2.2 AA requires 4.5:1 for normal text and 3:1 for large text (≥24 px, or ≥18.66 px bold).

| Foreground / background | Ratio | Normal text | Large text | Typical use |
|---|---:|:---:|:---:|---|
| `--ink` `#182920` / cream `#f1f3ed` | 13.64:1 | Pass | Pass | Body copy |
| `--green` `#174c3a` / cream | 8.81:1 | Pass | Pass | Kickers, links |
| `--muted` `#758078` / cream | **3.67:1** | **Fail** | Pass | Captions, helper text |
| `--muted` / paper `#fbfcf9` | **3.99:1** | **Fail** | Pass | Card captions |
| `--gold` `#c3984b` / cream | **2.37:1** | **Fail** | **Fail** | Stars, decorative text |
| `--gold` / paper | **2.58:1** | **Fail** | **Fail** | Star ratings |
| `#b74a36` danger / paper | 5.04:1 | Pass | Pass | Error text |
| White / `--green` | 9.85:1 | Pass | Pass | Primary buttons |

**Finding:** `--muted` is the single biggest contrast failure because it is used pervasively for 10–14 px helper text, captions and metadata. It is only 0.51 below the AA threshold on paper, but 39 declarations in `style.css` pair muted text with 10–11 px sizes, where the small-text threshold is mandatory. Gold text is mostly decorative, but the 11 px star rating uses it on paper and fails both thresholds.

### 2.3 Type scale and microtype

- `style.css` contains **93 font-size declarations at 11 px or smaller**.
- The three studio stylesheets contain **107 declarations at 11 px or smaller**, including 8 px region labels, 8.5 px footnotes, 9 px field labels and 9.5 px helper copy.
- The body is 15 px, but much of the functional UI (budget labels, route metadata, availability, notes, partner stats) is 9–11 px.
- On a 780 px-wide screenshot the studio is readable but dense; at 360–390 px these sizes would be materially harder to read. This was not visually verified.

**Recommendation:** raise the minimum functional text to 12 px, body/supporting copy to 14 px, and reserve 10–11 px only for non-essential decoration. Never use 8–9 px for information the user must act on.

### 2.4 Motion

- Transitions are 0.18–0.3 s; the payment spinner rotates continuously.
- A global `prefers-reduced-motion` rule collapses animation and transition durations and disables smooth scrolling. This is a genuine accessibility strength.
- The hero balloon drift in `final.css` is also collapsed by the global rule.
- There is no motion that conveys essential information, so reduced-motion users lose nothing.

### 2.5 Visual strengths

- Clear primary action per surface (gold hero CTA, green generate/book/pay buttons).
- Consistent 22 px card radius and soft shadow language on marketing pages.
- Destination and hotel “scenes” avoid the broken-image look and work without external photos.
- Itinerary day cards have a strong editorial layout with dates, themes, times and costs.
- Print CSS exists and makes a deliberate attempt to produce a paper itinerary.
- Focus-visible outlines are defined globally for links, buttons, inputs, selects and `role="button"`.
- Empty states are written in plain language and usually offer a next action.

---

## 3. CSS architecture and maintainability

### 3.1 Loaded stylesheets

Load order in `index.html`: Google Fonts → `style.css` → `field-guide.css` → `final.css` → `studio.css` → `itinerary-edit.css` → `planner-studio.css` → Leaflet CSS.

| File | Size | Role | Live status |
|---|---:|---|---|
| `style.css` | 93.7 KB | Core system, shell, home, old itinerary, hotels, partner, print | Live |
| `field-guide.css` | 6.9 KB | Itinerary/field-guide overrides | Live |
| `final.css` | 4.6 KB | Hero balloon and final polish | Live |
| `studio.css` | 8.0 KB | Original live Trip Studio | Live |
| `itinerary-edit.css` | 3.2 KB | Activity editor and print | Live |
| `planner-studio.css` | 47.4 KB | **Redesign stylesheet for orphan markup** | Loaded, but 177 of its 198 class selectors appear only in unloaded scripts |
| `map.css` (repo root) | — | Old map styling | **Not loaded** |
| `_studio_block.js` | 55.2 KB | Orphan studio redesign | **Not loaded** |
| `_itinerary_block.js` | 56.3 KB | Orphan itinerary redesign | **Not loaded** |

Total loaded CSS: **163.9 KB**, unminified. Total live JS: **173.0 KB**, unminified. `index.html`: **37.8 KB**.

### 3.2 The two-studio cascade

`studio.css` and `planner-studio.css` both style the live Trip Studio shell. `planner-studio.css` loads later, so its declarations win where they overlap:

| Selector | `studio.css` (old) | `planner-studio.css` (later) | Result |
|---|---|---|---|
| `.studio-head h2` | `clamp(28px, 3.4vw, 40px)` | `clamp(36px, 4.5vw, 58px)` | New, much larger heading |
| `.studio-grid` | `minmax(0,1fr) 348px` | `minmax(0,1fr) 380px` | New, wider sidebar |
| `.studio-card` | radius `18px` | radius `24px` | New radius |
| `.studio-side` | sticky `top: 102px` | sticky `top: 104px` | Minor shift |
| `.studio-map`, `.studio-map-card`, `.studio-search`, etc. | Defined | Redefined | Mixed |

Meanwhile, 24 of the 38 `studio-*` classes emitted by the live `renderPlannerStudio()` are **not styled by `planner-studio.css` at all** (for example `studio-stop`, `studio-fields`, `studio-prefs`, `studio-dest`, `studio-route-total`, `studio-summary`). Those components still come from `studio.css`.

The rendered studio is therefore a visual hybrid: new header, grid and card shell on top of old route, preference and destination components. It works, but it is fragile: any edit to one stylesheet can produce an inconsistent combination that is hard to trace.

### 3.3 The orphan redesign stylesheet

Of the 198 class selectors in `planner-studio.css`, **177 also appear in the unloaded `_studio_block.js` / `_itinerary_block.js` files**. Only a small set of shell selectors overlaps the live DOM.

Consequences:

- A 47.4 KB stylesheet is downloaded to style an interface that is not rendered.
- It overrides live shell components, so deleting it would visibly change the current page.
- It creates a false impression that the new studio/itinerary markup is active when only parts of its styling are.
- The dead CSS includes complete design systems for `studio-browse-*`, `studio-metric-*`, `route-stop-*`, `it-activity`, `budget-cat-*` and `it-commandbar` that no live element uses.

**Recommendation:** either finish the redesign (move its markup into `app.js`, delete the old studio CSS) or remove `planner-studio.css` and the two orphan scripts. Do not leave the page between two design systems.

### 3.4 Breakpoint fragmentation

Loaded CSS contains **eleven distinct max-width breakpoints**: 1300, 1240, 1180, 1120, 1000, 980, 960, 900, 760, 720 and 700 px. Three files define their own 700 px mobile rules, and `style.css` alone defines three separate responsive/print clusters for different page groups.

This produces:

- inconsistent reflow points between the home page, studio, itinerary and partner dashboard;
- duplicated rules at 1120/1180 and 900/960;
- a higher chance that a component is optimised for one breakpoint but not its neighbours.

A consolidated set (for example 1200, 900, 640) would be easier to reason about, but the current layout does reflow rather than overflow at the tested widths.

### 3.5 Stylesheet hygiene verdict

| Issue | Severity | Evidence |
|---|---|---|
| Dead redesign stylesheet loaded | High | `planner-studio.css`, 177/198 selectors only in unloaded scripts |
| Two competing studio systems | High | 13 shared `.studio-*` classes with conflicting values |
| Dead `map.css` in repo root | Low | Not linked from `index.html` |
| Two large orphan JS files | Medium | 111.5 KB combined, unloaded |
| No minification or bundling | Medium | 163.9 KB CSS in six requests, 173 KB JS |
| Microtype spread across files | Medium | 200 declarations ≤11 px across live CSS |
| No CSS custom-property layer for spacing | Low | Many one-off pixel values |

---

## 4. Layout and responsive behaviour

### 4.1 Desktop

At 1440×1000 the home page reads well: floating pill navigation, a full-bleed hero, a compact planner card overlapping the hero, popular destination cards, a feature strip and the full studio below. The itinerary at the same width uses a hero, a five-tab toolbar, a two-column overview and a summary sidebar within the Overview panel.

Strengths:

- Clear above-the-fold hierarchy and a visible planning CTA.
- Content max-width of 1240 px keeps line lengths comfortable.
- Cards have generous padding and consistent radii.
- The itinerary overview’s editorial day cards are easy to scan.

Weaknesses:

- The home page contains **two planning surfaces** (the compact hero form and the full studio) that mutate the same state. Users can change a field in one and see the other change without understanding why.
- The hero form asks for a start date but not an end date; the end date is silently derived. The full studio is the only place where duration is explicit.
- The studio is long and dense: overview, route, add-destinations, map and summary all compete on one page. On a 1000 px-tall viewport, the generate action is below the fold.
- The “One page · no stepper” pill exposes an implementation decision instead of a user benefit.
- Several panels repeat the same information (route count, duration, travellers) in the summary and the overview.

### 4.2 Tablet and mobile

Breakpoints that affect the main shell:

| Width | Behaviour |
|---|---|
| ≤1180 px | Studio becomes one column; sidebar moves above/below; popular grid drops to three |
| ≤980 px | Desktop nav hidden; hamburger menu shown; hero shrinks |
| ≤960 px | Studio sidebar becomes one column; itinerary metrics become two columns |
| ≤720 px | Mobile hero stacks; planner card becomes static; grids become one column; pickers become bottom sheets |
| ≤700 px | Studio cards compact; route stops wrap; itinerary tab row scrolls horizontally; activity rows stack |

Screenshots at **780×1688** show a usable mobile home, mobile itinerary and mobile navigation. The layout does not appear horizontally broken at that width.

Unverified risk: 780 px is a small tablet, not a phone. At 360–390 px:

- the itinerary’s five tabs (each 44–48 px high with icon + label) are likely to overflow and rely on horizontal scrolling;
- the route-stop grid (`22px 64px 1fr`) plus controls may become cramped;
- the partner property form has 16 fields in one modal with no step structure;
- 8–9 px labels become effectively unreadable;
- the booking sheet’s two-column summary collapses at 980 px, but the long form still requires substantial scrolling.

### 4.3 Touch and hover

Several controls reveal actions only on hover or focus:

- activity edit/remove tools use `.act:hover .act-tools, .act:focus-within .act-tools`;
- destination arrow affordances are hover-driven;
- dropdown menus open on hover/focus-within.

On touch devices these may require an extra tap or may be undiscoverable. The activity tools are also the only way to edit or delete an activity besides the visible buttons; if they remain hidden until focus, the interaction is ambiguous.

Drag-and-drop is used for:

- reordering route stops (with up/down buttons as fallback);
- reordering activities within a day (no keyboard or button fallback).

Native HTML5 drag is unreliable on touch, so activity reordering is effectively desktop-only.

### 4.4 Density and scrolling

- The full studio at desktop has a sticky 380 px sidebar; at ≤1180 px the sidebar becomes static and may appear before the main editor, pushing the form down.
- At ≤900 px, `field-guide.css` hides the entire `.it-actions` row, so **Export and Regenerate disappear**. Save, Print and Edit survive only as small links in the itinerary summary, and only when the Overview tab is open.
- The five itinerary tabs scroll horizontally at ≤700 px; the hidden action buttons are not part of that scroll.
- The booking modal uses a 315 px summary column plus a form; at ≤980 px it becomes one column, but the summary still consumes vertical space before the form.
- Modals are capped at `max-height: 92vh` and scroll internally, so long partner and activity forms are usable but not comfortable.

---

## 5. Information architecture and navigation

### 5.1 The eight views

Home, Destinations, Itinerary, Hotels, Bookings, Travel Guide, Partner and About are separate `.view` sections toggled by `switchView()`. Only one is visible.

### 5.2 No URL, no Back, no deep links

- The URL never changes when the view, tab or modal changes.
- Browser Back leaves the site or does nothing within the SPA.
- A refresh always returns to Home and discards the current view, tab and unsaved itinerary.
- No itinerary, hotel or booking has a shareable URL.
- Users cannot bookmark “My itinerary”, “Hotels in Bagan” or a partner dashboard.
- The browser cannot restore the user to where they were after a crash or tab discard.

This is the single largest information-architecture gap. For a travel planner, shareable itineraries are a core expectation, not a nice-to-have.

### 5.3 Navigation duplication and naming

- Header, mobile menu and footer repeat the same destinations with different labels (“Saved trips” in the header versus “Bookings” in the view and footer).
- “My itinerary” is a nav item but is unusable until an itinerary exists; clicking it shows a toast and returns Home.
- “Plan Trip” in the header dropdown and “Detailed planner” both scroll to the same anchor.
- “Bookings” combines two unrelated jobs: local saved trips and server booking lookup. A user looking for a hotel reservation must understand that “Saved trips” means itineraries, not bookings.
- The chat launcher is labelled “Travel assistant” but opens a static shortcut menu, not a conversation.
- The search modal promises “Destination or attraction” but only returns destination rows.
- The feature strip’s “Trusted & Secure Platform” and “24/7 Support” navigate to About, where neither is substantiated.

### 5.4 Dead navigation paths

- The six-step wizard is still described in the README, and dead functions and event branches remain, but there is no `#wizardPanel` or `#wizardRail` in the DOM. No user can reach it.
- `data-scroll="planner"` from a non-Home view switches Home and scrolls after 90 ms. If the target is missing, the user lands on Home with no explanation.
- The itinerary “Edit trip” link returns Home but does not scroll to the planner, so the user must find it again.

### 5.5 Navigation matrix issues

| From | Intended destination | Actual behaviour / issue |
|---|---|---|
| Header “My itinerary” (no itinerary) | Itinerary | Toast + Home |
| Itinerary “Book This Trip” | Booking flow | Hotels view only |
| Search result | Attraction detail | Destination detail |
| Chat “Plan a trip” | Planner | Home + scroll, no focus move |
| Guide “Plan a trip” | Planner | Home + scroll |
| Destination “Add to my trip” | Planner | Home + scroll, state.step set to 2 (dead concept) |
| Footer “My bookings” | Booking lookup | Bookings view, which also contains saved trips |
| Account “Hotel owner dashboard” | Partner dashboard | Partner view; may show auth if no local partner |

---

## 6. Page-by-page UX review

### 6.1 Home

**Strengths**

- Strong visual hierarchy; the hero communicates destination, promise and CTA in one screen.
- Compact planner reduces the effort to start compared with the full studio.
- Popular cards and guide teaser provide useful secondary paths.
- The studio’s map and route summary give immediate feedback as destinations are added.

**Problems**

| # | Problem | Severity |
|---|---|---|
| H1 | “AI Trip Planner” is deterministic rule-based logic, not AI/ML. | High (trust) |
| H2 | “Trusted & Secure Platform” and “24/7 Support” are unsupported. | High (trust) |
| H3 | “One page · no stepper” and “All fields editable” are implementation notes, not user copy. | Low |
| H4 | Two planners share state but expose different fields and defaults. | Medium |
| H5 | The hero CTA scrolls without moving keyboard focus to the planner. | Medium (a11y) |
| H6 | The studio’s hotel-tier preference exists in state but has no control, so users cannot change it. | Medium |
| H7 | The route map is a straight-line estimate but sits close to real map tiles, which can imply routing. A note exists but is easy to miss. | Medium |
| H8 | The permanent “Weather unavailable” note looks like a transient outage. | Medium (trust) |
| H9 | The hero image falls back to a remote Wikimedia URL, creating a third-party dependency and a privacy/referrer leak. | Low |
| H10 | No skip link; keyboard users must tab through the full navigation and hero before reaching the planner. | Medium (a11y) |

### 6.2 Destinations

**Strengths**

- Region chips are generated from real data rather than hard-coded.
- Search matches name, Myanmar name, region, tagline and attraction names.
- Detail modal is informative and offers two clear next actions.
- Empty state is clear.

**Problems**

| # | Problem | Severity |
|---|---|---|
| D1 | Destination cards are `<article role="button">`, not links. They cannot be opened in a new tab, copied or crawled. | Medium |
| D2 | No sort control (region only), no favourites, no map view, no “near me”. | Low (product) |
| D3 | The search field is not reflected in the URL, so a filtered view cannot be shared or restored. | Medium |
| D4 | The detail modal can be very long on mobile (nine highlights + facts) and has no internal section navigation. | Low |
| D5 | “Add to my trip” uses the destination’s recommended days without explaining how days are allocated. | Low |
| D6 | No indication of content freshness or source for fees, hours and seasons. | Medium (trust) |

### 6.3 Itinerary

**Strengths**

- The five-tab structure maps well to user questions: what is the plan, what happens each day, where is it, where do I stay, what does it cost.
- Day cards are visually strong and information-dense without feeling cluttered on desktop.
- Editing an activity, adding a catalogue attraction, removing and reordering are all available in context.
- Budget recalculates immediately after edits.
- Print and JSON export exist.

**Problems**

| # | Problem | Severity |
|---|---|---|
| I1 | No autosave or draft restore. A refresh loses the itinerary and all edits unless the user explicitly saved. | Critical |
| I2 | “Regenerate” replaces the day/trip without confirmation and discards edits. No undo. | High |
| I3 | Remove activity and remove saved trip have no confirmation or undo. | High |
| I4 | Weather is always unavailable; the chip repeats on every day card and adds noise without information. | Medium |
| I5 | The map is a straight dashed line. Distance/time are Haversine estimates, not road routes. | Medium |
| I6 | The summary says `totalDays − 1` nights, but hotel booking pre-fills `nightsPerDestination` (the day allocation), so a 3-day trip can pre-fill 3 nights. | Critical (correctness) |
| I7 | “Book This Trip” only opens Hotels; it does not book the itinerary or all stays. | High (misleading) |
| I8 | Tab buttons use `role="tab"` without `aria-selected`, `aria-controls` or arrow-key behaviour. | High (a11y) |
| I9 | Activity rows are drag-only for reordering; no keyboard or touch fallback. | High (a11y) |
| I10 | Saved trips are silently capped at eight. | Medium |
| I11 | Budget recalculation reuses food and transport totals instead of repricing after traveller or route changes. | Medium |
| I12 | Print forces every tab panel visible (`display: block !important`), producing a long mixed document with Overview, Daily, Map, Hotels and Budget. | Medium |
| I13 | “Weather unavailable” and “route estimate” are presented as if temporary/approximate; the limitations are permanent. | Medium |
| I14 | No version history, duplicate, share or PDF export. | Medium (product) |
| I15 | The day-level “Regenerate” is visually similar to the whole-trip action, and neither explains the variation seed. | Low |
| I16 | At ≤900 px the toolbar hides Export and Regenerate; only Save, Print and Edit survive in the summary. | High (mobile) |
| I17 | `id="saveTrip"` and `id="printTrip"` are duplicated in the toolbar and summary, producing invalid HTML and ambiguous accessible naming. | Medium (a11y) |

### 6.4 Hotels

**Strengths**

- City tabs prioritise itinerary destinations, a thoughtful contextual touch.
- Class and price filters plus sorting cover the main discovery needs.
- Partner-created properties are labelled with owner attribution.
- Booking modal shows a live total preview and per-night breakdown.
- Payment is clearly marked as a demo.

**Problems**

| # | Problem | Severity |
|---|---|---|
| B1 | No hotel detail page. Cards show a gradient/SVG scene, amenities, price and rating, but no gallery, map, policies, room types or reviews. | High (product) |
| B2 | “Rooms left” is a single counter, not date-specific availability. Booking in January reduces availability in December. | Critical (correctness) |
| B3 | The price slider tops out at 350,000 MMK and treats that value as “Any”. Partner properties can be priced up to 5,000,000, so expensive listings are invisible at every other slider position. | Medium |
| B4 | No guest/occupancy field; rooms are booked without a maximum occupancy model. | Medium |
| B5 | No taxes, service fees, breakfast inclusion or cancellation terms in the price. | Medium |
| B6 | The booking modal states a 48-hour cancellation policy, but no cancellation exists. | High (trust) |
| B7 | Rooms are “held” immediately but holds never expire and cannot be released. The user has no countdown or expiry information. | Critical (correctness) |
| B8 | Phone validation only happens server-side; the inline error appears after submit. | Low |
| B9 | The “Book stay” flow requires a phone number before the user knows the total or policies. | Low |
| B10 | Hotel cards use the same visual language as destinations, which can obscure that these are commercial listings with different data quality. | Low |

### 6.5 Bookings

**Strengths**

- Saved trips and booking lookup are both visible without hunting.
- Pending bookings can reopen payment.
- Confirmed bookings show wallet and transaction reference.
- Empty states are clear.

**Problems**

| # | Problem | Severity |
|---|---|---|
| K1 | Two unrelated jobs share one view: saved itineraries and hotel reservations. The nav label “Saved trips” does not describe the lookup panel. | High (IA) |
| K2 | Booking lookup is unauthenticated and only requires a phone number. A wrong or missing phone can return **all** bookings at the API level. | Critical (privacy) |
| K3 | Saved trips are local-only, not account-linked, and silently capped at eight. | High |
| K4 | No confirmation before removing a saved trip. | Medium |
| K5 | No cancellation, modification or refund action for a booking. | Critical (product) |
| K6 | No booking reference search, only phone. | Medium |
| K7 | Pending bookings show no hold expiry, so the user cannot tell whether the room is still theirs. | High |
| K8 | No “email me” or download receipt. | Low |
| K9 | The lookup result list has no pagination or date filter. | Low |

### 6.6 Travel Guide

**Strengths**

- Six concise, well-written guides cover the questions travellers actually ask.
- Modal format is readable and offers a direct “Plan a trip” action.
- Content is fully local, so it works offline.

**Problems**

| # | Problem | Severity |
|---|---|---|
| G1 | No search, category filter, bookmark or reading progress. | Low |
| G2 | No publication or review date, author or source. Travel advice can age badly. | Medium (trust) |
| G3 | No Myanmar-language version. | Medium (product) |
| G4 | “Best time to visit” and “Health & safety” give generic advice without linking to current official guidance. | Medium (trust) |
| G5 | No feedback mechanism (“was this useful?”), so content cannot improve. | Low |

### 6.7 Partner

**Strengths**

- The dashboard answers the core questions: properties, rooms left, bookings, confirmed value.
- Add/edit property is a single, understandable form with server-side validation.
- Delete has a confirmation dialog that names the property.
- Empty states for properties and bookings are present.
- Demo nature of payouts is disclosed.

**Problems**

| # | Problem | Severity |
|---|---|---|
| P1 | The page displays demo partner credentials and the login form uses credential-like placeholders. This invites password reuse and looks unprofessional. | High (trust) |
| P2 | No “forgot password”, email verification, lockout or MFA. | High (product) |
| P3 | The dashboard is rendered from a `Partner` object in localStorage; there is no session. Sign-out only clears the browser. | Critical (security) |
| P4 | Every API call trusts a client-supplied `partnerId`; another caller can read or modify the partner’s data. | Critical (security) |
| P5 | Editing a property resets `roomsTotal` and `roomsLeft` to the submitted room count, ignoring active bookings. The dashboard can then overstate availability. | Critical (correctness) |
| P6 | Deleting a property orphans its bookings; they vanish from the partner booking list. | Critical (correctness) |
| P7 | The property form has 16 fields in one modal, no image upload, no map, no policies and no room-type inventory. | High (product) |
| P8 | Client validates only the description length; all other errors arrive after submit. | Medium |
| P9 | The dashboard shows “demo booking value” but no commission, statement or payout schedule. | Medium |
| P10 | The partner hero claims listings appear in “every customer hotel search, itinerary recommendation”. Search inclusion is true; recommendation logic is a simple route lookup. | Medium (trust) |
| P11 | No guest contact, messaging, check-in or booking acceptance actions. | High (product) |
| P12 | No indication that deleting a property will orphan bookings. | High (UX) |

### 6.8 About

**Strengths**

- Explains the deterministic planner, cost model, simulated payments and architecture.
- Discloses that profiles are browser-local and payments are simulated.
- Direct CTA back to the planner.

**Problems**

| # | Problem | Severity |
|---|---|---|
| A1 | States that no PIN is transmitted; the PIN is posted to the gateway and sent over RMI. | Critical (trust) |
| A2 | Displays demo credentials in plain text. | High (trust) |
| A3 | No contact, company, legal, privacy, accessibility or support information. | High (compliance) |
| A4 | Architecture copy is developer-facing and sits beside consumer content. | Low |
| A5 | “Trusted & Secure” is repeated without any security model behind it. | High (trust) |

---

## 7. Forms and validation

### 7.1 Form inventory

| Form | Fields | Client validation | Server validation | Error presentation |
|---|---|---|---|---|
| Compact planner | Destination, date, travellers, budget | Destination required, numeric budget | Itinerary engine | Toast / empty state |
| Studio | Title, dates, adults, children, budget, currency, style, transport, pace, interests | HTML constraints, clamps | Itinerary engine | Button state + toast |
| Auth | Name, email, password | Length/email regex | None | `.form-error` div |
| Activity editor | Title, time, duration, category, cost, description | Required title, numeric ranges | None | `.form-error` div |
| Booking | Name, phone, check-in, nights, rooms | Name length, native date/number constraints | Full validation | `.form-error` div |
| Payment | Method, wallet phone, PIN | Phone regex, 4–6 digits | Full validation | `.form-error` + toast |
| Partner auth | Name, email, phone, password | Length/email regex | Full validation | `.form-error` div |
| Partner property | 16 fields | Description length | Full validation | `.form-error` div |
| Booking lookup | Phone | Required | Phone normalisation | Toast / empty state |

### 7.2 What works

- 41 fields use a wrapping `<label>` with a visible text label, so the accessible name is usually present.
- Native `required`, `minlength`, `min`, `max`, `type="date"`, `type="email"` and `inputmode="numeric"` are used.
- Errors are placed near the submit action and the form stays open on failure.
- Buttons are disabled and show progress during submit.
- Password fields are `type="password"`.

### 7.3 What fails

| Issue | Impact | Severity |
|---|---|---|
| Error containers are not `role="alert"` or `aria-live`, and inputs have no `aria-describedby` or `aria-invalid`. | Screen-reader users may not hear the error and cannot associate it with the field. | High |
| Focus is not moved to the first invalid field or to the error summary. | Keyboard users must search for the problem. | High |
| `autocomplete` is absent on almost every field, including name, email, phone and address. | Mobile autofill and password managers are hindered. | Medium |
| Traveller login accepts any password and overwrites the local profile. | The form teaches a false security model. | High (trust) |
| Phone format is described only in an error message; there is no helper text or mask. | Users must fail once to learn the accepted format. | Medium |
| The booking total preview updates, but nights/rooms limits are only enforced on submit. | Late, avoidable errors. | Medium |
| The partner form validates only the description client-side. | Most errors require a round trip. | Medium |
| The PIN field asks for a wallet PIN in a demo and transmits it. | Safety and trust risk; users may enter a real PIN. | Critical |
| Demo credentials appear as placeholders in the login form. | Encourages reuse and undermines the demo boundary. | High |
| Required fields have no textual “required” indicator beyond browser validation. | Users cannot see which fields are mandatory before submitting. | Low |
| Date inputs use native UI with no timezone or date-format guidance. | Ambiguity for international users. | Low |

### 7.4 Form UX recommendation

1. Remove the PIN field entirely and replace it with an explicit “Simulate approval / Simulate decline” control. This is safer, clearer and removes the false “no PIN transmitted” problem.
2. Add a visible error summary at the top of each form, `role="alert"`, and focus it on submit failure.
3. Link each field to its error with `aria-describedby` and set `aria-invalid`.
4. Add `autocomplete` tokens (`name`, `email`, `tel`, `street-address`, `current-password`, `new-password`).
5. Show phone and date format hints before submit.
6. Make demo boundaries explicit with a persistent “Demo data” badge, not credential-like placeholders.

---

## 8. Feedback, loading and recovery

### 8.1 Loading

Good:

- Generate buttons disable and show a spinner/label.
- Hotels show “Loading stays.”
- Partner dashboard shows “Loading your dashboard.”
- Payment shows a dedicated processing modal.
- The studio and itinerary do not flash empty content while generating.

Gaps:

- No skeletons or progress for a multi-second itinerary generation; the user sees only button text.
- No timeout or cancel action for a slow request.
- No global banner when the catalogue is unavailable; only a toast that disappears after 3.4 seconds.
- No “retry” button after a failure.

### 8.2 Success

- Toasts confirm generation, edits, saves, partner actions and payments.
- Successful payment opens a receipt modal with reference, wallet, transaction and total.
- Partner property changes reload the dashboard.
- Toast duration is 3.4 seconds; important confirmations can disappear before a slow reader finishes.

### 8.3 Errors

| Error | Current presentation | Problem |
|---|---|---|
| Server down at startup | Toast: “Trip server unavailable — start the RMI server first.” | Developer-facing instruction; no retry. |
| Itinerary validation | Toast with server message | Message is not tied to the offending field. |
| Booking validation | Inline `.form-error` | Not announced; field not highlighted. |
| Payment decline | HTTP 402 becomes `Request failed (402)` | The specific decline reason is lost. |
| Payment network failure | Inline error + toast | No retry guidance. |
| Partner dashboard load | Session cleared, auth screen + toast | User is logged out with no explanation of whether data was lost. |
| Persistence write failure | Server logs a warning, API returns success | User believes the booking/property was saved when it may not be. |
| Corrupt localStorage | Empty state | No repair or export path. |
| Static asset 404 | Gateway serves `index.html` with 200 | Broken CSS/JS/images can masquerade as a page. |

### 8.4 Empty states

Present and generally good:

- No saved trips.
- No bookings found for a phone.
- No hotels match filters.
- No attractions left to add.
- No partner properties.
- No partner bookings.
- No destination search matches.

Missing:

- No “server unavailable” full-page state.
- No “this itinerary was restored from a previous session” state because restore is dead.
- No “your session expired” state for partners.
- No “payment pending” persistent banner outside the booking card.

### 8.5 Destructive actions

| Action | Confirmation | Undo | Severity |
|---|---|---|---|
| Remove route stop | No | No | Medium |
| Remove activity | No | No | High |
| Regenerate day | No | No | High |
| Regenerate whole trip | No | No | Critical |
| Remove saved trip | No | No | Medium |
| Delete partner property | Yes (modal) | No | High |
| Pay | Yes (submit) | No | Expected |
| Sign out | No | N/A | Low |

The absence of undo is more damaging than the absence of confirmation for edits, because the user may not notice a mis-click until much later.

### 8.6 Notification accessibility

`#toast` is a plain `<div>` with no `role="status"` or `aria-live`. Screen readers will not announce success or failure messages. The payment processing modal and receipt modal likewise do not move focus, so a screen-reader user may not know the state changed.

---

## 9. Accessibility audit (WCAG 2.2 AA lens)

### 9.1 Summary

| Principle | Assessment | Notes |
|---|---|---|
| 1. Perceivable | **Partial** | Good semantics in places; contrast and type size fail; images mostly decorative with `alt=""`. |
| 2. Operable | **Partial** | Keyboard navigation works for most controls; modals lack focus management; drag-only activity reorder; no skip link. |
| 3. Understandable | **Partial** | Clear copy in most places; misleading claims and form errors reduce understanding. |
| 4. Robust | **Partial** | Invalid tab ARIA; dynamic content not announced; no live regions. |

### 9.2 Confirmed strengths

- `lang="en"` on the document.
- `viewport` meta is present.
- Visible `:focus-visible` outlines for links, buttons, inputs, selects and `role="button"`.
- Destination cards support Enter and Space.
- Escape closes modals, pickers and the chat panel.
- Mobile menu toggles `aria-expanded`.
- Planner/traveller popovers toggle `aria-expanded`.
- Modal shell has `role="dialog"`, `aria-modal="true"` and a label.
- Some icon-only buttons have `aria-label` (search, menu, chat, zoom, remove, move up/down, fewer/more).
- Reduced-motion support is global.
- Decorative SVG scenes are marked `aria-hidden="true"`.
- Form fields are wrapped in labels.
- Color is not the only indicator for most states (text labels accompany status badges).

### 9.3 Confirmed failures and risks

| WCAG criterion | Issue | Evidence | Severity |
|---|---|---|---|
| 1.4.3 Contrast (Minimum) | Muted text 3.67:1 on cream, 3.99:1 on paper; gold 2.37–2.58:1 | Computed from tokens; used at 10–14 px | High |
| 1.4.4 Resize Text | 8–11 px base sizes; zoom to 200% may break dense studio grids | 200 declarations ≤11 px | High |
| 1.4.10 Reflow | 780 px verified; 360–390 px unverified; itinerary tabs overflow at ≤700 px | CSS and screenshots | Medium |
| 2.1.1 Keyboard | Activity reorder is drag-only | `dragstart` handlers, no key alternative | High |
| 2.4.1 Bypass Blocks | No skip link | `index.html` has no skip target | Medium |
| 2.4.3 Focus Order | Modal does not move focus in; no focus trap; no restore on close | `openModal()` sets HTML and `aria-hidden` only | High |
| 2.4.7 Focus Visible | Global outline exists, but `.studio-title-input:focus { outline: none; }` can remove it for that input | `planner-studio.css` line 86 | Medium |
| 2.5.8 Target Size (Minimum) | 26 px counters and 27 px route-stop buttons are above 24 px but below 44 px guidance | `studio.css` | Low |
| 3.3.1 Error Identification | Errors are generic divs, not associated with fields | `.form-error` markup | High |
| 3.3.2 Labels or Instructions | Phone/date format guidance is missing until failure | Booking and payment forms | Medium |
| 4.1.2 Name, Role, Value | Itinerary tabs use `role="tab"` without `aria-selected`/`aria-controls`; state changes are visual only | `switchItTab()` toggles `.on` only | High |
| 4.1.3 Status Messages | Toast and async results are not in a live region | `#toast` has no role | High |
| 3.3.3 Error Suggestion | Server messages are often actionable, but the payment decline message is lost | `api()` throws on 402 | High |
| 1.3.1 Info and Relationships | Some visual grouping is div-only; tabs lack panel relationships | `role="tablist"` without `aria-controls` | Medium |
| 2.4.4 Link Purpose | `role="button"` cards rely on `aria-label`; most are named | Destination cards | Low |
| 3.2.2 On Input | Several controls re-render immediately (filters, toggles) without warning | Expected for filters, but it can move focus | Low |

### 9.4 Focus management detail

`openModal(html, size)`:

1. Sets `#modalBody.innerHTML`.
2. Adds `.open`.
3. Sets `aria-hidden="false"`.
4. Locks body scroll.

It does **not**:

- move focus into the dialog;
- set `tabindex="-1"` on the dialog;
- trap Tab/Shift+Tab;
- make the background inert;
- remember the invoking element;
- restore focus on close.

The search modal is the only exception: it focuses `#modalSearch` after 40 ms. Even there, focus is not restored on close.

### 9.5 Tab semantics detail

- The itinerary tablist has five buttons with `role="tab"`.
- Only the active tab has `.on`; no `aria-selected` attribute is ever set.
- Panels are `<div class="it-panel" id="itPanel-...">` with `hidden` toggled; no `role="tabpanel"` and no `aria-labelledby`.
- Arrow keys do not move between tabs; each tab is in the Tab order.
- The visual state is clear, but assistive technology receives an incomplete model.

### 9.6 Keyboard and drag

- Route stop reordering has up/down buttons (`aria-label="Move up/down"`), which is good.
- Activity rows have a drag handle and Edit/Remove buttons, but no move buttons. Keyboard users cannot reorder activities.
- Cross-day drag is rejected with no message.
- Dropping changes all times from 08:00; the user is not warned that their custom times will be overwritten.

### 9.7 Screen-reader content risks

- The toast is silent.
- Form errors are silent.
- The payment processing modal is silent.
- The “Weather unavailable” chip repeats on every day card; a screen reader hears the same non-information many times.
- Destination cards use `role="button"` and `aria-pressed` in the studio, but `aria-pressed` on a card that navigates/opens may be semantically confusing.
- The chat panel is labelled “Travel assistant” but contains only navigation; its disclosure is visual text, not a status.
- Myanmar-script destination names have no `lang="my"` attribute, so screen readers may mispronounce them.

### 9.8 Accessibility priorities

**P0**

1. Add a skip link.
2. Implement modal focus entry, trap, background inertness and focus restore.
3. Add `role="status"`/`aria-live` to toasts and form errors.
4. Fix itinerary tab ARIA and add arrow-key navigation.
5. Provide a keyboard/touch alternative for activity reordering.
6. Raise muted text contrast to at least 4.5:1 and remove 8–9 px functional text.

**P1**

1. Associate errors with fields via `aria-describedby`/`aria-invalid`.
2. Add `autocomplete` tokens.
3. Add `lang="my"` to Myanmar-script names.
4. Make the chat disclosure explicit to assistive technology.
5. Add target-size padding to 26–34 px controls.
6. Test at 200% zoom and 360 px width.

---

## 10. Content, trust and tone

### 10.1 Unsupported claims visible to users

| Claim | Where | Reality | Severity |
|---|---|---|---|
| “AI Trip Planner” / “crafted by AI” | Hero, itinerary | Deterministic scoring and scheduling; no LLM/ML | High |
| “Trusted & Secure Platform” | Home feature strip | No auth, authorization, TLS, security headers or certification | High |
| “24/7 Support” | Home feature strip | Static chat shortcut menu; no support channel | High |
| “Live availability” | Hotels | Single in-memory room counter; not date-specific | High |
| “No PIN is transmitted” | About / payment copy | PIN is posted to gateway and sent over RMI | Critical |
| “48 h demo cancellation policy” | Booking modal | No cancellation feature | High |
| “Book This Trip” | Itinerary summary | Opens Hotels only | High |
| “Weather unavailable” | Itinerary | Permanently unavailable; no fetch attempted | Medium |
| “Every customer hotel search, itinerary recommendation” | Partner hero | Search inclusion yes; recommendation is a simple route lookup | Medium |
| “Real-time / live” partner visibility | Partner copy | Immediate in one process; no push or multi-instance consistency | Low |
| “61 attractions” | README | 66 places | Low |
| Six-step trip builder | README | One-page studio; wizard is dead | Medium |

### 10.2 Demo credentials

The Partner page and About page display demo credentials, and the partner login form uses credential-like placeholders. This audit deliberately does not reproduce the values. The practice is still a UX problem:

- it encourages users to reuse a real password;
- it blurs the line between a demo and a live account;
- it makes the product look less trustworthy;
- it is unnecessary because the demo can be seeded without publishing credentials.

**Recommendation:** remove published credentials, add a one-click “Enter demo partner account” button that creates a clearly labelled demo session, and never pre-fill password fields.

### 10.3 Tone and microcopy

Strengths:

- Most helper copy is plain and friendly.
- Error messages from the server are specific (“Only N room(s) left…”).
- Empty states offer a next step.
- The footer honestly says the project is a demo with simulated payments.

Weaknesses:

- Internal engineering language leaks into the UI: “One page · no stepper”, “All fields editable”, “RMI server”, “demo booking value”.
- Some copy overpromises (“perfect journey”, “trusted”, “24/7”).
- “Weather unavailable” reads as a temporary outage rather than a product limitation.
- “AI” is used as a synonym for “automated”, which is common marketing but materially misleading here.
- No date-stamped content, author or source for travel advice.

### 10.4 Localisation and inclusion

- The interface is English-only.
- Destination names include Myanmar script, but no `lang` attribute and no Myanmar UI.
- Currency defaults to MMK but supports USD, EUR, THB, SGD and GBP at fixed rates. The UI does not state that rates are indicative and static.
- Dates use native browser controls; no explicit timezone.
- Phone validation is Myanmar-specific, which is appropriate, but the error does not explain accepted prefixes.
- No right-to-left support (not currently required).

### 10.5 Legal and support content

Missing entirely:

- privacy policy;
- terms of service;
- cookie notice/consent;
- cancellation and refund policy;
- accessibility statement;
- contact form or support email;
- company/registration information;
- data export/deletion instructions.

For a travel product that collects names, phone numbers and stay dates, this is a material gap, not polish.

---

## 11. Performance and perceived performance

### 11.1 Payload

| Asset | Size | Notes |
|---|---:|---|
| `index.html` | 37.8 KB | Inline SVG hero, all eight views, modal shell |
| `style.css` + 5 others | 163.9 KB | Six requests, unminified |
| `app.js` | 173.0 KB | Unminified, no modules/bundling |
| Local images | 2.8 MB / 10 files | Largest: Mandalay 460 KB, Hpa-An 383 KB, Yangon 316 KB |
| Google Fonts | external | Fraunces + Manrope variable fonts |
| Leaflet CSS + JS | external | Loaded synchronously from unpkg |
| Orphan JS (not loaded) | 111.5 KB | `_studio_block.js`, `_itinerary_block.js` |
| Orphan CSS (loaded) | 47.4 KB | `planner-studio.css` |

First load is roughly **375 KB of HTML/CSS/JS** before fonts, Leaflet and images, and up to **2.8 MB of images** if all are requested. There is no gzip/Brotli compression, minification, bundling, image resizing or responsive `srcset`.

### 11.2 Request behaviour

- `init()` fetches both `/api/destinations` and `/api/hotels` on first load, even if the user never leaves Home.
- All eight views are present in the DOM; render functions populate several of them at startup.
- The studio map may initialise Leaflet and request tiles before the user scrolls to it. This was not measured, but the code creates the map during studio rendering.
- Leaflet is loaded synchronously in the head/end of body even for users who never open a map.
- Static files are served with `Cache-Control: no-cache`, so repeat visits revalidate every asset.
- The gateway does not compress responses.
- No service worker, manifest or offline cache exists.

### 11.3 Perceived performance

Good:

- Buttons show immediate disabled/spinner feedback.
- The app does not block on hotel data to render the shell.
- Local SVG scenes appear instantly and avoid image pop-in.
- The itinerary is rendered in one pass after generation, not progressively.

Weak:

- No skeleton for the hotel grid or partner dashboard; only text.
- A multi-second generation leaves the rest of the page static; the user may think nothing is happening if the button is off-screen.
- Toasts are the only confirmation for several actions and can be missed.
- No optimistic UI for partner property saves; the dashboard reloads after the request.

### 11.4 Layout shift risks

- `<img>` elements generally lack `width`/`height` attributes; containers often have fixed aspect ratios, but not all.
- The hero photo is absolutely positioned, so it is less likely to shift the layout.
- Google Fonts is a render-blocking third-party stylesheet; preconnect hints are present, but the fonts still depend on an external host.
- The studio map container has a fixed height, which helps.
- Late hotel/partner data can change card heights and push content.

### 11.5 Performance recommendations

1. Remove `planner-studio.css` and the orphan scripts, or complete and ship the redesign.
2. Minify and bundle CSS/JS; enable gzip/Brotli at the gateway.
3. Serve responsive images (`srcset`, WebP/AVIF) and set explicit dimensions.
4. Load Leaflet only when a map panel is opened.
5. Lazy-load below-the-fold views and defer the hotel catalogue until it is needed.
6. Add long-lived cache headers with content hashes.
7. Add a loading skeleton for the hotel grid and partner dashboard.
8. Measure LCP, CLS and INP before and after; set budgets (for example <200 KB JS gzip, LCP <2.5 s on 4G).

---

## 12. Print experience

### 12.1 Intended behaviour

`style.css` print rules:

- hide navigation, footer, chat, page actions, hero, planner, modal and toast;
- force `#view-itinerary` visible;
- remove card shadows and set light borders;
- collapse the itinerary layout to one column;
- keep day cards from breaking across pages in `planner-studio.css`.

`planner-studio.css` print rules also hide `.studio-shell`, `.it-commandbar`, `.it-save-strip`, `.it-help`, chat and the studio, and shrink the itinerary hero.

### 12.2 Actual problems

1. `style.css` line 1313 sets `.it-panel { display: block !important; }` inside the print media query. This comes after `[hidden] { display: none !important; }` (line 52) with equal specificity, so **all five itinerary panels print**, not just the active tab. The output is a long mixed document: Overview, Daily, Map, Hotels and Budget.
2. The map panel may print a large, blank or partially loaded Leaflet canvas, wasting pages.
3. The hero prints in full colour; on a mono printer it becomes a large dark block.
4. There is no print-specific header with trip title, dates, traveller names or page numbers.
5. The toolbar is correctly hidden, but action buttons inside day cards are hidden by `planner-studio.css`, while the live daily cards are rendered by `style.css`; coverage is therefore incomplete.
6. No “Print” guidance distinguishes “print this tab” from “print the whole trip”.
7. No PDF generation; users must use the browser’s print-to-PDF, which may produce different results per browser.

### 12.3 Recommendation

- Add an explicit print scope: “Print this tab” and “Print full itinerary”.
- Hide inactive panels with a print-specific class rather than relying on `hidden` ordering.
- Replace the hero with a compact text header for print.
- Hide the map or render a static route summary instead.
- Add page breaks between days and a budget summary at the end.
- Test in Chrome, Firefox and Safari print preview.

---

## 13. Mobile and touch assessment

### 13.1 Verified

At 780×1688:

- The mobile navigation opens and closes correctly.
- The hero stacks and the planner card becomes a normal block.
- Destination and hotel grids become one column.
- The itinerary is usable, but dense.
- The mobile menu exposes the same destinations plus auth actions.

### 13.2 Risks at phone width

| Risk | Why | Severity |
|---|---|---|
| Itinerary tabs overflow | Five tabs with icon + label at 44–48 px; horizontal scroll at ≤700 px | Medium |
| Export and Regenerate vanish | `.it-actions` is hidden at ≤900 px; the summary has no Export/Regenerate replacements | High |
| Activity reorder impossible | HTML5 drag does not work reliably on touch | High |
| Hover-only edit tools | `.act-tools` appears on hover/focus-within | High |
| Studio too tall | Overview, route, add-destinations, map and summary stack | Medium |
| 8–9 px labels unreadable | Studio destination cards and sidebar | High |
| Partner form overwhelming | 16 fields in one modal | Medium |
| Booking sheet long | Summary then form in one scroll | Medium |
| Map traps page scroll | Leaflet drag gestures can block vertical scrolling | Medium |
| Toasts cover content | Fixed bottom-center; 3.4 s | Low |
| No offline support | No service worker; a travel planner is often used with poor connectivity | High (product) |

### 13.3 Recommendation

- Test at 360, 390, 414 and 768 px on real iOS/Android devices.
- Add up/down buttons for activity reordering.
- Make edit/remove actions always visible on coarse pointers via `@media (hover: none)`.
- Collapse the studio into steps or progressive disclosure on small screens.
- Raise mobile type sizes and reduce metadata.
- Consider a PWA shell with cached destination and itinerary data.

---

## 14. Ranked UX findings

### Critical

1. **Booking lookup exposes PII.** No authentication; a missing/invalid phone can return all bookings.
2. **PIN collection and transmission.** The UI asks for a wallet PIN and sends it to the gateway/RMI service while claiming it does not.
3. **No autosave or draft restore.** Refresh loses the itinerary and all edits.
4. **Payment decline reason is lost.** 402 is turned into “Request failed (402)”.
5. **Nights mismatch.** Summary says `days − 1`; booking pre-fills day allocation.
6. **No cancellation or hold expiry.** Copy promises a 48-hour policy; inventory never releases.
7. **Partner edit resets inventory and delete orphans bookings.** Availability and history become wrong.
8. **Partner authorization trusts a client-supplied ID.** The dashboard is not a secure account.

### High

9. No URL routing, Back support or deep links.
10. Destructive edits and regeneration have no confirmation or undo.
11. Itinerary tabs expose invalid ARIA and no keyboard arrow behaviour.
12. Modal focus is neither moved, trapped nor restored.
13. Toasts and form errors are not announced.
14. Activity reordering is drag-only.
15. Muted text fails contrast; functional text is 8–11 px.
16. Unsupported security, support, AI, availability and cancellation claims.
17. No hotel detail pages; no date-specific availability.
18. Saved trips are browser-local and silently capped at eight.
19. Search promises attractions but returns destinations.
20. “Book This Trip” does not book the trip.

### Medium

21. Two planners share state but expose different fields.
22. The loaded `planner-studio.css` is a redesign stylesheet for unloaded markup.
23. 14 overlapping class selectors create a hybrid visual system.
24. Print outputs every tab panel.
25. Price slider cannot reach partner hotels above 350,000 MMK.
26. Hover-only actions on touch.
27. No skip link.
28. Partner form has no progressive disclosure.
29. No content dates, sources or legal pages.
30. No loading skeleton for hotels or partner dashboard.

### Low

31. Internal implementation copy (“One page · no stepper”).
32. No favourites, reviews, guide search or reading progress.
33. No PDF export or email receipt.
34. 26–34 px compact controls below 44 px touch guidance.
35. Hero falls back to a remote Wikimedia image.
36. No document-title changes per view.
37. No analytics or funnel measurement.

---

## 15. Prioritised recommendations

### Phase 0 — Stop the harm (1–2 weeks)

1. Remove the PIN field; replace with explicit demo approve/decline.
2. Require authentication or booking reference + OTP for lookup; never return all bookings.
3. Fix the 402 handling so the decline reason is shown.
4. Fix the itinerary/booking nights mismatch.
5. Add confirmation and undo for regenerate, remove activity and remove saved trip.
6. Add autosave of the current itinerary to localStorage with an explicit “Restore draft” state.
7. Stop swallowing persistence failures; surface a save error to the user.
8. Fix partner edit inventory reset and block deletion when active bookings exist (or tombstone the property).

### Phase 1 — Make it accessible and navigable (3–5 weeks)

9. Add URL/hash routing for the eight views and the five itinerary tabs; support Back and deep links.
10. Add a skip link and modal focus management (enter, trap, restore, inert background).
11. Fix tab ARIA and add arrow-key navigation.
12. Add `role="status"`/`aria-live` to toasts and form errors; link errors to fields.
13. Add up/down buttons for activity reordering; make edit actions visible on touch.
14. Raise contrast and type sizes; remove 8–9 px functional text.
15. Consolidate CSS and remove the orphan stylesheet/scripts.
16. Print only the selected tab or provide an explicit full-itinerary print layout.

### Phase 2 — Complete the product (6–10 weeks)

17. Real traveller accounts linked to bookings and saved trips.
18. Partner sessions, password reset, email verification and lockout.
19. Date-specific inventory, hold expiry, cancellation, refund and idempotency.
20. Hotel detail pages with policies, map, room types and reviews.
21. Admin/support console for bookings, partners and refunds.
22. Email/SMS confirmation and receipts.
23. Weather and road routing in the live itinerary, or remove the dormant promises.
24. PWA/offline shell for destination and itinerary data.

### Phase 3 — Grow (ongoing)

25. Reviews, favourites and recommendation explanations.
26. Myanmar-language UI and content.
27. PDF itineraries and share links.
28. Analytics, funnels and consent.
29. Supplier/content integrations.
30. Legal, privacy, accessibility and support pages.

---

## 16. UX acceptance criteria

Use these as release gates.

### Navigation

- [ ] Every view and itinerary tab has a unique URL.
- [ ] Browser Back/Forward moves between views and tabs.
- [ ] A copied URL opens the same view, tab and selected destination.
- [ ] Refreshing preserves the current itinerary draft or offers restore.
- [ ] “My itinerary” with no itinerary explains how to create one and links to the planner.

### Forms and feedback

- [ ] Every error is announced and associated with its field.
- [ ] Focus moves to the error summary or first invalid field.
- [ ] Payment decline shows the server’s reason.
- [ ] No PIN is collected or transmitted.
- [ ] Success and failure toasts are announced.
- [ ] Destructive actions require confirmation or offer undo.
- [ ] Loading states exist for every network action longer than 300 ms.
- [ ] Failure states offer a retry path.

### Accessibility

- [ ] Keyboard-only user can plan, generate, edit, save, book, pay, look up and manage a partner property.
- [ ] Modals trap focus and restore it on close.
- [ ] Tabs expose `aria-selected` and support arrow keys.
- [ ] All text meets 4.5:1 (or 3:1 for large text).
- [ ] No functional text below 12 px.
- [ ] Touch targets are at least 44×44 px where practical.
- [ ] 200% zoom and 360 px width are usable without horizontal scrolling.
- [ ] Screen reader announces view changes, errors and payment results.

### Mobile

- [ ] Activity reordering works without drag.
- [ ] Edit/remove actions are visible on touch.
- [ ] All itinerary actions (Save, Print, Export, Regenerate, Edit) are reachable at every breakpoint.
- [ ] Maps do not trap page scroll.
- [ ] Booking and partner forms are usable one-handed.

### Trust

- [ ] No unsupported security, support, AI, availability or cancellation claims.
- [ ] Demo boundaries are explicit and no credentials are published.
- [ ] Content shows a last-reviewed date and source where relevant.
- [ ] Privacy, terms, cancellation and contact pages exist.

### Performance

- [ ] JS ≤ 200 KB gzip on first load.
- [ ] CSS ≤ 80 KB gzip.
- [ ] LCP ≤ 2.5 s on a mid-range phone over 4G.
- [ ] CLS ≤ 0.1.
- [ ] Images are responsive and below 300 KB each.
- [ ] Leaflet loads only when a map is opened.

---

## 17. Evidence map

| Area | Primary evidence |
|---|---|
| Design tokens and type | `web/style.css` `:root`, body and type rules |
| Studio cascade conflict | `web/studio.css`, `web/planner-studio.css`; computed overlaps |
| Orphan redesign | `web/_studio_block.js`, `web/_itinerary_block.js`, `planner-studio.css` selector match |
| Responsive rules | Media queries in all six loaded stylesheets |
| Navigation and views | `web/app.js` `switchView()`, `wireEvents()`; `web/index.html` |
| Modal focus | `web/app.js` `openModal()` / `closeModal()`; `web/index.html` modal shell |
| Tabs | `web/app.js` `renderItinerary()`, `switchItTab()` |
| Toasts | `web/index.html` `#toast`; `web/app.js` `toast()` |
| Contrast | Token hex values measured with WCAG relative-luminance formula |
| Microtype | Font-size declaration counts in live CSS |
| Print | `web/style.css` print blocks, line 1313; `web/planner-studio.css` print block |
| Payment decline | `web/app.js` `api()` and `submitPayment()`; `src/com/mmtrip/server/TripServiceImpl.java` |
| Nights mismatch | `web/app.js` itinerary summary and booking prefill |
| Availability | `src/com/mmtrip/server/DataStore.java`; `TripServiceImpl.createBooking()` |
| Partner defects | `TripServiceImpl` partner save/delete; partner dashboard render |
| Screenshots | `final-home.png`, `it-overview-final.png`, `new-it-budget.png`, `mobile-home.png`, `mobile-itinerary.png`, `partner-dash.png` (1440×1000 / 780×1688) |

---

## 18. Closing assessment

The visual craft is good enough to demo with confidence. The product is not ready for real travellers until the trust, privacy, inventory and accessibility defects are fixed. The highest-leverage work is not a redesign: it is removing the PIN, securing lookup, saving drafts, fixing the nights/hold model, confirming destructive actions, and making the interface keyboard- and screen-reader-safe. Those changes would move the experience from “impressive prototype” to “responsible product” without discarding the design that already works.
