# GarageMate — Dev Log

> Claude Code: read this file before starting any work. Update the "Next Up" and
> "Log" sections before ending your session — this is the only continuity between
> sessions, treat it as load-bearing.

## Next Up
<!-- The single source of truth for "what do I do this session." Keep it short —
     3-5 concrete items max. Overwrite this section each session, don't just append. -->
- [ ] Scaffold Expo app + Supabase project structure
- [ ] Apply schema + RLS + expire_listings Edge Function from technical-architecture.md

## Backlog / Future
<!-- Things known but not next. Move items up to "Next Up" when ready, don't work
     from here directly. -->
- Apple Sign-In (blocked on Apple Developer account — see product-spec.md §0)
- Push notifications for nearby listings (v1.1, out of scope for v1)
- Listing reporting/moderation (v1.1, out of scope for v1)

## Decisions Log
<!-- One line per decision, newest first. Prevents re-litigating settled questions
     across sessions. Full reasoning lives in the two spec docs — this is just an index. -->
- 2026-09-07: Listings hard-delete on expiry via hourly Edge Function (no is_active flag) — see technical-architecture.md §4
- 2026-09-07: Suburb search is a required fallback, not optional — see product-spec.md §5.1
- 2026-09-07: Stack locked: Expo + Supabase/PostGIS, not Firebase — see technical-architecture.md §1

## Session Log
<!-- Append-only, newest at top. One entry per session: what got done, what broke,
     what's left half-finished. Be specific enough that a session with zero memory
     of this one can pick up cleanly. -->

### 2026-09-07 — Session 0 (planning)
- Wrote product-spec.md and technical-architecture.md
- Resolved: expiry behavior, suburb search requirement, Apple Dev account status
- No code written yet
