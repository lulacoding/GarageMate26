-- Hourly schedule for the expire_listings Edge Function.
--
-- technical-architecture.md §4 says this is configured via "supabase/config.toml
-- or dashboard" — but Cron Triggers for Edge Functions aren't actually a
-- config.toml setting; they're either set up in the Dashboard (Edge Functions >
-- Cron), which isn't tracked in this repo, or via pg_cron + pg_net calling the
-- function's HTTPS endpoint on a schedule, which *is* trackable as a migration.
-- Using the latter so the schedule lives in version control like everything else.
--
-- This reads the project URL and service role key from Supabase Vault rather
-- than hardcoding them, since this file is committed to the repo. Before this
-- migration can run, set the two secrets once per environment:
--
--   select vault.create_secret('https://<project-ref>.supabase.co', 'project_url');
--   select vault.create_secret('<service-role-key>', 'service_role_key');

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

select
  cron.schedule(
    'expire-listings-hourly',
    '0 * * * *',
    $$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/expire_listings',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')
      )
    );
    $$
  );
