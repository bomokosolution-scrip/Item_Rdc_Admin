-- ============================================================
--  Item RDC — Supabase : bucket des ouvrages publiés (PDF)
--  À exécuter UNE fois : SQL Editor > New query > Run
--  (SUPABASE_SETUP.sql doit déjà avoir été exécuté : il gère les images.)
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('publications', 'publications', true, 26214400, array['application/pdf'])
on conflict (id) do update
  set public = true,
      file_size_limit = 26214400,
      allowed_mime_types = array['application/pdf'];

drop policy if exists "publications_public_read" on storage.objects;
create policy "publications_public_read"
  on storage.objects for select
  using (bucket_id = 'publications');

-- Envoi depuis l'application (clé publique). Pas de modification ni de
-- suppression possibles depuis l'application.
drop policy if exists "publications_anon_insert" on storage.objects;
create policy "publications_anon_insert"
  on storage.objects for insert
  to anon
  with check (bucket_id = 'publications');
