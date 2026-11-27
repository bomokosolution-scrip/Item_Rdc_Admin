-- ============================================================
--  Item RDC — Supabase : accepter Word, Excel et PowerPoint
--  (en plus des PDF) dans le bucket « publications ».
--  À exécuter UNE fois : SQL Editor > New query > Run
-- ============================================================
update storage.buckets
set allowed_mime_types = array[
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation'
]
where id = 'publications';
