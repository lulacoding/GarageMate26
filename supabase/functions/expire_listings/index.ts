// Source: garagemate-technical-architecture.md §4 — used as-is.
import { createClient } from "@supabase/supabase-js";

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")! // service role: bypasses RLS for cleanup
  );

  const { data: expired, error } = await supabase
    .from("listings")
    .select("id, listing_images(storage_path)")
    .lt("end_at", new Date().toISOString());

  if (error) throw error;
  if (!expired?.length) return new Response("no expired listings");

  for (const listing of expired) {
    const paths = listing.listing_images.map((img: { storage_path: string }) => img.storage_path);
    if (paths.length) {
      await supabase.storage.from("listing-images").remove(paths);
    }
  }

  const ids = expired.map((l) => l.id);
  // Cascades to listing_images and saved_listings automatically.
  const { error: delError } = await supabase.from("listings").delete().in("id", ids);
  if (delError) throw delError;

  return new Response(`deleted ${ids.length} expired listings`);
});
