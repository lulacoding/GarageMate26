# GarageMate — Product Specification

**Version:** 1.1 (final draft for build)
**Platform:** Cross-platform (iOS + Android, Expo/React Native)
**Backend:** Supabase (Postgres + PostGIS)

## 0. Prerequisites / Action Items

- **Apple Developer Program account (paid, ~$99/yr) — not yet obtained.** This blocks two things:
  1. Apple Sign-In implementation
  2. Any iOS App Store submission
- **Apple's App Store Review Guideline 4.8** requires that if an app offers a third-party login (Google Sign-In counts), it must also offer Sign in with Apple as an equivalent option — with some narrow exceptions that don't apply here. So Apple Sign-In isn't optional for this app once Google Sign-In is included and it's going on the App Store.
- **Recommended path:** build and develop with Google + email/password auth first (fully usable on Android and for internal iOS testing via TestFlight without App Store submission). Get the Apple Developer account in parallel, add Apple Sign-In before public iOS App Store release.

## 1. Overview

GarageMate is a garage sale discovery app. Users browse nearby garage sales on a list or map, filter by date and distance, save listings they're interested in, and get directions via their native maps app. Sellers can list their own garage sale with photos, a description, and a date/time range.

## 2. Goals

- Make it trivial to find garage sales happening nearby, today or this week.
- Let sellers post a listing in under 2 minutes.
- Keep the map performant even with dense listing areas.

## 3. Target Users

- **Buyers/browsers:** people casually looking for garage sales in their area, often filtering by "today" or "this weekend."
- **Sellers:** individuals hosting a garage sale who want visibility with minimal setup.

## 4. Authentication

### Login
- Google Sign-In
- Apple Sign-In (gated behind Apple Developer account — see §0)
- Email/password
- "Forgot password" flow (email reset link)

### Register
- Google/Apple (one-tap, no extra form)
- Email/password path collects **first name** and **last name** (used to build a display name)
- Email verification required before first login completes

## 5. Screens & Functional Requirements

### 5.1 HomeView
- Custom nav bar (tabs: Home, Map, Saved, Add, Profile)
- Card list of garage sales, each card shows: thumbnail, title, date, distance
- **Date filter:** Today / This Week / This Month / All
- **Location filter:**
  - Default radius: 20km from user's current location
  - Slider to extend up to 50km
  - **Suburb search is a required fallback**, not just a convenience: if the user denies location permission, or simply prefers to search a named suburb, they must be able to enter a suburb name and get results centered on it, with the same radius slider applying. The app must never hard-block browsing on location permission being denied.
- Tapping a card opens **Detail View**

### 5.2 Detail View
- Image carousel
- Title, description, date(s), time range
- "Save" button → adds to Saved list
- "Open in Maps" button → deep-links to Google Maps or Apple Maps (platform-appropriate, or user's default) with the listing address pre-filled

### 5.3 MapView
- Map centered on user's current location by default; if location denied, centers on last-searched suburb or a sensible default (e.g. city center) and prompts the user to search a suburb
- Custom annotations for garage sales in the visible map region
- Annotations load as the visible region gains listings, unload when they leave view (avoid rendering every listing nationwide)
- Tapping an annotation shows a bottom card with a summary (title, date, thumbnail) and a button into Detail View

### 5.4 SavedView
- List of all garage sales the user has saved
- Same card format as HomeView
- Tapping opens Detail View
- If a saved listing expires and is deleted (see §5.7), it's removed from Saved automatically — surface a brief "this listing has ended and was removed" toast the next time Saved is opened, rather than silently vanishing with no explanation

### 5.5 AddView (create listing)
- Image picker, up to 3 images
- Title (required, validated non-empty)
- Description (required)
- Address search bar with autocomplete predictions as the user types
- Date picker:
  - Garage sale date, start time, end time
  - Optional second day (with its own start/end time)
- Input validation before submit (required fields, valid date range, at least 1 image recommended)
- Submit writes the listing to the database, including a derived expiry timestamp (see §5.7)

### 5.6 ProfileView
- User icon, display name, email
- **Edit profile:**
  - Update email
  - Update password
  - Update display name
- **My Listings:**
  - List of the user's own active (non-expired) listings
  - Selecting one opens an action menu: Edit or Delete
- Sign out button

### 5.7 Listing Expiry — Auto-Delete

Resolved behavior: once the local date/time has passed a listing's end date/time, the listing is **automatically and permanently deleted** — not just hidden from browsing.

- At creation, the app computes a single `end_at` timestamp from whichever is later: the end time of day 2 if a second day was added, otherwise the end time of day 1. This is computed in the device's local time zone at creation time (garage sales are inherently local, so this is a reasonable simplification rather than doing timezone lookups by address).
- A scheduled backend job runs periodically (see Technical Architecture doc, §4) and hard-deletes any listing whose `end_at` has passed, cleaning up its images and any users' saved references.
- Practical effect: "My Listings" only ever shows a seller's current/upcoming listings — there's no separate archive of past listings in v1.

## 6. Non-Functional Requirements

- Map annotation loading must not degrade scroll/pan performance in dense areas (viewport-based query, not "load everything").
- Location permission must degrade gracefully — if denied, the suburb search path is fully functional, not a degraded stub.
- Images should be compressed/resized client-side before upload to control storage cost and load time.

## 7. Out of Scope (v1)

- In-app messaging between buyer and seller
- Payments or reservation of items
- Push notifications for new listings nearby (candidate for v1.1)
- Ratings/reviews of sellers
- Reporting/moderation of listings (candidate for v1.1 if listing volume/abuse warrants it)
- Archive of past/expired listings for sellers (listings are fully deleted on expiry per §5.7)
