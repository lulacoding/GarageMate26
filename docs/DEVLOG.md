# GarageMate — Dev Log

> Claude Code: read this file before starting any work. Update the "Next Up" and
> "Log" sections before ending your session — this is the only continuity between
> sessions, treat it as load-bearing.

## Next Up
<!-- The single source of truth for "what do I do this session." Keep it short —
     3-5 concrete items max. Overwrite this section each session, don't just append. -->
- [ ] Set up real Supabase project (remote), fill in .env, run `supabase link` + `supabase db push`, deploy expire_listings function, set Vault secrets (project_url, service_role_key)
- [ ] Build auth (Google + email/password, verification, password reset) per product-spec.md §4 — leave a clean seam for Apple Sign-In, don't build it
- [ ] Then screens in order: HomeView → Detail View → MapView → AddView → SavedView → ProfileView (product-spec.md §5)

## Setup still needed before auth/screens can run end-to-end
- No live Supabase project yet — migrations are written but never applied anywhere
- Google Cloud project + Places/Geocoding API key not yet obtained
- Google OAuth client (for Supabase Google Sign-In) not yet configured

## Backlog / Future
<!-- Things known but not next. Move items up to "Next Up" when ready, don't work
     from here directly. -->
- Apple Sign-In (blocked on Apple Developer account — see product-spec.md §0)
- Push notifications for nearby listings (v1.1, out of scope for v1)
- Listing reporting/moderation (v1.1, out of scope for v1)

## Decisions Log
<!-- One line per decision, newest first. Prevents re-litigating settled questions
     across sessions. Full reasoning lives in the two spec docs — this is just an index. -->
- 2026-09-07: Edge Function cron scheduling implemented via pg_cron + pg_net + Vault secrets in a migration, not config.toml — config.toml doesn't actually support Edge Function schedules; technical-architecture.md §4 was wrong/imprecise on this point
- 2026-09-07: Supabase auth session storage uses AsyncStorage (Supabase's own RN recommendation), not SecureStore — session objects can exceed SecureStore's 2KB limit
- 2026-09-07: Listings hard-delete on expiry via hourly Edge Function (no is_active flag) — see technical-architecture.md §4
- 2026-09-07: Suburb search is a required fallback, not optional — see product-spec.md §5.1
- 2026-09-07: Stack locked: Expo + Supabase/PostGIS, not Firebase — see technical-architecture.md §1

## Session Log
<!-- Append-only, newest at top. One entry per session: what got done, what broke,
     what's left half-finished. Be specific enough that a session with zero memory
     of this one can pick up cleanly. -->

### 2026-09-07 — Session 1 (scaffold + schema)
- git init'd the repo (was previously untracked)
- Scaffolded Expo TypeScript app at repo root (create-expo-app blank-typescript,
  built in a scratch dir and moved in — the folder name "GarageMate(2026ver)"
  has parens, which create-expo-app rejects as an npm package name; package.json
  name is "garagemate", app.json display name is "GarageMate")
- Installed @supabase/supabase-js, @tanstack/react-query, React Navigation
  (native + bottom-tabs + native-stack), react-native-maps, expo-location,
  expo-image-picker/manipulator, AsyncStorage, react-native-dotenv
- Added src/lib/supabase.ts client (AsyncStorage-backed auth persistence),
  babel.config.js + env.d.ts + .env.example for @env-based config
- Installed Supabase CLI via Homebrew (the npm `supabase` package has no
  darwin-arm64 binary — `npx supabase` fails outright on this machine, use the
  brew-installed `supabase` binary instead)
- `supabase init` → supabase/config.toml, migrations/, functions/
- Wrote 3 migrations: initial_schema (tables, indexes, signup trigger, RLS,
  nearby_listings + listings_in_view RPCs), storage_buckets (listing-images
  bucket + RLS), schedule_expire_listings (pg_cron/pg_net + Vault, see Decisions Log)
- Wrote supabase/functions/expire_listings/index.ts verbatim from the tech doc
- Verified: `npx tsc --noEmit` clean, `npx expo-doctor` 21/21
- Flagged to user (see Decisions Log): technical-architecture.md §3/§7 never
  wrote RLS/policies for profiles or listing_images, never wrote the signup
  trigger as SQL (only prose in §6), never gave storage bucket creation SQL,
  and §4's "config.toml or dashboard" cron claim doesn't hold up — all filled
  in this session, following the doc's existing patterns
- Not started: no live Supabase project — nothing has been applied/deployed
  anywhere yet, migrations only exist locally. Auth and screens not started.
