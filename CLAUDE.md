# GarageMate

Garage sale finder app. Cross-platform mobile (Expo/React Native + TypeScript), Supabase backend (Postgres + PostGIS, Auth, Storage, Edge Functions).

## Start every session

1. Read `DEVLOG.md` — check "Next Up" for what to work on, "Decisions Log" for settled questions, "Session Log" for what happened last session.
2. Read `garagemate-product-spec.md` and `garagemate-technical-architecture.md` for anything not already summarized in DEVLOG.md.
3. Before ending the session: update DEVLOG.md — overwrite "Next Up" with the new state, append a "Session Log" entry (what got done, what's half-finished, anything that broke).

## Stack (settled — don't relitigate)

- Expo (React Native + TypeScript)
- Supabase: Postgres + PostGIS, Auth, Storage, Edge Functions
- react-native-maps
- Google Places/Geocoding API (address autocomplete + suburb search)
- TanStack Query
- React Navigation

## Known constraints

- Apple Sign-In is deferred — no paid Apple Developer account yet. Leave a clean seam for it, don't build it.
- Listings hard-delete on expiry via an hourly Edge Function (`end_at` timestamp, no `is_active` flag). Schema and function code are in the technical architecture doc — use as-is.
- Suburb search is a required fallback (location-denied path), not optional — shares the same `nearby_listings` RPC as GPS search.
- Map annotations load/unload based on visible viewport, debounced — never load all listings at once.

## Working conventions

- Ask before any architectural decision not already settled in the spec docs or DEVLOG.md.
- If something in the docs looks wrong once you're in the code, flag it — don't silently deviate.
- Keep commits scoped to one screen/feature at a time, matching the build order in the product spec (§5): Home → Detail → Map → Add → Saved → Profile.
