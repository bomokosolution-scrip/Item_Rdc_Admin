import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:item_rdc_admin/core/push_config.dart';

class PushResult {
  final bool ok;
  final String message;
  const PushResult(this.ok, this.message);
}

/// Envoie une notification push via le relais Cloudflare (gratuit).
class PushSender {
  PushSender._();

  static bool get configured =>
      kPushRelayUrl.startsWith('https://') &&
      !kPushRelayUrl.contains('VOTRE') &&
      kPushRelayKey.length >= 16 &&
      !kPushRelayKey.contains('COLLEZ');

  /// [token] null => envoi à TOUS les utilisateurs ; sinon à un seul téléphone.
  static Future<PushResult> send({
    required String title,
    required String body,
    String? token,
  }) async {
    if (!configured) {
      return const PushResult(
        false,
        "Relais non configuré : renseignez lib/core/push_config.dart",
      );
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.postUrl(Uri.parse(kPushRelayUrl));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      req.headers.set('X-Admin-Key', kPushRelayKey);
      req.add(utf8.encode(jsonEncode({
        'title': title,
        'body': body,
        if (token != null) 'token': token,
      })));
      final resp = await req.close().timeout(const Duration(seconds: 20));
      final text = await resp.transform(utf8.decoder).join();

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {}

      if (resp.statusCode == 200 && data['ok'] == true) {
        return PushResult(
          true,
          token == null ? "Notification envoyée à tous" : "Notification envoyée",
        );
      }
      final err = (data['error'] ?? 'Erreur ${resp.statusCode}').toString();
      return PushResult(false, err);
    } on TimeoutException {
      return const PushResult(false, "Le relais ne répond pas (délai dépassé)");
    } catch (e) {
      return PushResult(false, "Connexion impossible : $e");
    } finally {
      client.close(force: true);
    }
  }
}
