-- Storage bucket for listing images.
--
-- technical-architecture.md §8 says images upload to Supabase Storage under
-- `listings/{listing_id}/{position}.jpg`, and the §4 expire_listings function
-- reads from a bucket named "listing-images" — but the doc never states the
-- bucket creation or its RLS policies. Filled in here, following the same
-- ownership shape as the listing_images table policies.

insert into storage.buckets (id, name, public)
values ('listing-images', 'listing-images', true)
on conflict (id) do nothing;

-- Path convention: listings/{listing_id}/{position}.jpg
-- storage.foldername(name) splits the path into segments, e.g.
-- {'listings', '<listing_id>'} for 'listings/<listing_id>/0.jpg'.

create policy "public read listing images"
on storage.objects for select
using (bucket_id = 'listing-images');

create policy "owner uploads own listing images"
on storage.objects for insert
with check (
  bucket_id = 'listing-images'
  and exists (
    select 1 from listings l
    where l.id::text = (storage.foldername(name))[2]
      and l.owner_id = auth.uid()
  )
);

create policy "owner deletes own listing images"
on storage.objects for delete
using (
  bucket_id = 'listing-images'
  and exists (
    select 1 from listings l
    where l.id::text = (storage.foldername(name))[2]
      and l.owner_id = auth.uid()
  )
);

-- No update policy: images are replaced by delete + insert, not in-place edits.
-- The expire_listings Edge Function deletes via the service role key, which
-- bypasses RLS, so it doesn't need a policy here.
