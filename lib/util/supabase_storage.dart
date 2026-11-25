import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Configuration Supabase Storage.
///
/// 1. Créez un projet sur https://supabase.com
/// 2. Exécutez le fichier SUPABASE_SETUP.sql (SQL Editor) : il crée le bucket
///    public `media` et les règles d'accès.
/// 3. Remplacez les deux valeurs ci-dessous (Project Settings > API) :
///    « Project URL » et la clé « anon public » (JAMAIS la clé `service_role`).
class SupabaseConfig {
  SupabaseConfig._();

  // Deux façons de renseigner ces valeurs :
  //  - directement ici (remplacez le texte entre guillemets), ou
  //  - à la compilation (GitHub Actions) : --dart-define=SUPABASE_URL=...
  //    --dart-define=SUPABASE_ANON_KEY=...  (rien à modifier dans ce fichier).
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://eovmshzuovdagxvanpcl.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_dbO4dWACu1H0Qd0_RJ5EoQ_tJTD0kjI',
  );
  static const String bucket = 'media';

  static bool get isConfigured =>
      !url.contains('VOTRE') && !anonKey.contains('VOTRE');
}

/// Envoi d'images vers Supabase Storage (sans paquet supplémentaire).
/// Les images sont réduites AVANT l'envoi : fichiers légers = affichage rapide.
class SupabaseStorage {
  SupabaseStorage._();

  static final Random _rnd = Random();

  /// Réduit l'image (plus grand côté = [maxSide]) et la ré-encode en PNG.
  static Future<Uint8List> prepareImage(Uint8List raw, {int maxSide = 512}) async {
    final probe = await ui.instantiateImageCodec(raw);
    final first = (await probe.getNextFrame()).image;
    final w = first.width;
    final h = first.height;
    first.dispose();
    probe.dispose();

    final biggest = max(w, h);
    ui.Codec codec;
    if (biggest > maxSide) {
      codec = w >= h
          ? await ui.instantiateImageCodec(raw, targetWidth: maxSide)
          : await ui.instantiateImageCodec(raw, targetHeight: maxSide);
    } else {
      codec = await ui.instantiateImageCodec(raw);
    }
    final img = (await codec.getNextFrame()).image;
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    codec.dispose();
    if (data == null) throw const FormatException("Image illisible.");
    return data.buffer.asUint8List();
  }

  /// Envoie l'image et renvoie son URL publique.
  /// [folder] : « icons », « covers », « logos »…
  static Future<String> uploadImage(
    Uint8List raw, {
    required String folder,
    int maxSide = 512,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
        "Supabase n'est pas configuré : renseignez l'URL et la clé dans lib/util/supabase_storage.dart.",
      );
    }
    final png = await prepareImage(raw, maxSide: maxSide);
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${_rnd.nextInt(1 << 30).toRadixString(36)}.png';
    final path = '$folder/$name';

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.postUrl(
        Uri.parse('${SupabaseConfig.url}/storage/v1/object/${SupabaseConfig.bucket}/$path'),
      );
      req.headers.set('apikey', SupabaseConfig.anonKey);
      // Ancienne clé « anon » (JWT, commence par eyJ) : aussi en Authorization.
      // Nouvelle clé « publishable » (sb_publishable_…) : l'en-tête apikey suffit.
      if (!SupabaseConfig.anonKey.startsWith('sb_')) {
        req.headers.set('Authorization', 'Bearer ${SupabaseConfig.anonKey}');
      }
      req.headers
        ..set('Content-Type', 'image/png')
        ..set('Cache-Control', 'max-age=31536000')
        ..set('x-upsert', 'false');
      req.contentLength = png.length;
      req.add(png);
      final res = await req.close().timeout(const Duration(seconds: 40));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HttpException("Envoi refusé (${res.statusCode}). $body");
      }
      return '${SupabaseConfig.url}/storage/v1/object/public/${SupabaseConfig.bucket}/$path';
    } finally {
      client.close(force: true);
    }
  }
}
