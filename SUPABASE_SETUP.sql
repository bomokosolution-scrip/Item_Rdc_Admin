-- ============================================================
--  Item RDC — Supabase Storage (images : icônes, logos, couvertures)
--  À exécuter UNE fois : Supabase > SQL Editor > New query > Run
-- ============================================================

-- 1) Bucket public « media » : images uniquement, 2 Mo maximum par fichier.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 2097152, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update
  set public = true,
      file_size_limit = 2097152,
      allowed_mime_types = array['image/png', 'image/jpeg', 'image/webp'];

-- 2) Lecture publique (affichage des images dans l'application).
drop policy if exists "media_public_read" on storage.objects;
create policy "media_public_read"
  on storage.objects for select
  using (bucket_id = 'media');

-- 3) Envoi depuis l'application ADMIN (clé « anon »).
--    Aucune règle de modification ni de suppression : un fichier envoyé ne
--    peut être ni écrasé ni effacé depuis l'application.
drop policy if exists "media_anon_insert" on storage.objects;
create policy "media_anon_insert"
  on storage.objects for insert
  to anon
  with check (bucket_id = 'media');
