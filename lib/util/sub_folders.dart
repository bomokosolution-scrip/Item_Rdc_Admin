import 'package:cloud_firestore/cloud_firestore.dart';

/// Sous-dossiers : un élément de `items` de la forme
/// `{type: 'folder', title: '...', items: [ {title, url}, ... ]}`.
/// Les anciens éléments `{title, url}` restent valides.
class SubFolders {
  SubFolders._();

  static bool isFolder(dynamic item) =>
      item is Map && (item['type'] == 'folder' || item['items'] is List);

  /// Nombre de fichiers, sous-dossiers compris.
  static int countFiles(Iterable items) {
    var n = 0;
    for (final e in items) {
      if (e is! Map) continue;
      n += isFolder(e) ? countFiles((e['items'] as List?) ?? const []) : 1;
    }
    return n;
  }

  /// Modifie la liste `items` d'un document de façon atomique.
  static Future<void> _edit(
    DocumentReference<Map<String, dynamic>> ref,
    void Function(List<Map<String, dynamic>> items) change,
  ) {
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final raw = (snap.data()?['items'] as List?) ?? const [];
      final items = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      change(items);
      tx.update(ref, {'items': items});
    });
  }

  static int _indexOf(List<Map<String, dynamic>> items, String title) =>
      items.indexWhere(
        (e) => isFolder(e) && (e['title'] ?? '').toString() == title,
      );

  /// Icône d'un sous-dossier : clé prédéfinie (`icon`) et/ou URL (`iconUrl`).
  static String iconKeyOf(dynamic item) =>
      item is Map ? (item['icon'] ?? '').toString() : '';

  static String iconUrlOf(dynamic item) =>
      item is Map ? (item['iconUrl'] ?? '').toString() : '';

  static Future<void> addFolders(
    DocumentReference<Map<String, dynamic>> ref,
    Iterable<String> names, {
    String? iconKey,
    String iconUrl = '',
  }) {
    final url = iconUrl.trim();
    return _edit(ref, (items) {
      for (final n in names.map((e) => e.trim()).where((e) => e.isNotEmpty)) {
        if (_indexOf(items, n) >= 0) continue; // déjà présent
        items.add({
          'type': 'folder',
          'title': n,
          'items': <Map<String, dynamic>>[],
          if (iconKey != null && iconKey.isNotEmpty) 'icon': iconKey,
          if (url.isNotEmpty) 'iconUrl': url,
          // Pas de serverTimestamp dans un tableau Firestore : heure de l'appareil.
          'createdAt': Timestamp.now(),
        });
      }
    });
  }

  /// Définit (ou retire) l'icône d'un sous-dossier.
  static Future<void> setIcon(
    DocumentReference<Map<String, dynamic>> ref,
    String folderTitle, {
    String? iconKey,
    String iconUrl = '',
  }) {
    final url = iconUrl.trim();
    return _edit(ref, (items) {
      final i = _indexOf(items, folderTitle);
      if (i < 0) return;
      if (iconKey == null || iconKey.isEmpty) {
        items[i].remove('icon');
      } else {
        items[i]['icon'] = iconKey;
      }
      if (url.isEmpty) {
        items[i].remove('iconUrl');
      } else {
        items[i]['iconUrl'] = url;
      }
    });
  }

  static Future<void> addFiles(
    DocumentReference<Map<String, dynamic>> ref,
    String folderTitle,
    List<Map<String, dynamic>> files,
  ) {
    return _edit(ref, (items) {
      final i = _indexOf(items, folderTitle);
      if (i < 0) return;
      final list = List<dynamic>.from((items[i]['items'] as List?) ?? const []);
      list.addAll(files);
      items[i]['items'] = list;
    });
  }

  static Future<void> removeFile(
    DocumentReference<Map<String, dynamic>> ref,
    String folderTitle,
    Map file,
  ) {
    return _edit(ref, (items) {
      final i = _indexOf(items, folderTitle);
      if (i < 0) return;
      final list = List<dynamic>.from((items[i]['items'] as List?) ?? const []);
      final idx = list.indexWhere(
        (e) => e is Map && e['title'] == file['title'] && e['url'] == file['url'],
      );
      if (idx >= 0) list.removeAt(idx);
      items[i]['items'] = list;
    });
  }

  static void _applyExtras(Map<String, dynamic> m, Map<String, String> values) {
    values.forEach((k, v) {
      final t = v.trim();
      if (t.isEmpty) {
        m.remove(k);
      } else {
        m[k] = t;
      }
    });
  }

  /// Modifie couverture / propriétaire / détails d'un fichier déjà ajouté.
  /// [folderTitle] = null : fichier au premier niveau du dossier ;
  /// sinon : fichier rangé dans ce sous-dossier.
  static Future<void> updateFileExtras(
    DocumentReference<Map<String, dynamic>> ref, {
    String? folderTitle,
    required Map file,
    required Map<String, String> values,
  }) {
    bool same(dynamic e) =>
        e is Map &&
        !isFolder(e) &&
        e['title'] == file['title'] &&
        e['url'] == file['url'];

    return _edit(ref, (items) {
      if (folderTitle == null) {
        final idx = items.indexWhere(same);
        if (idx >= 0) _applyExtras(items[idx], values);
        return;
      }
      final i = _indexOf(items, folderTitle);
      if (i < 0) return;
      final list = List<dynamic>.from((items[i]['items'] as List?) ?? const []);
      final idx = list.indexWhere(same);
      if (idx >= 0) {
        final m = Map<String, dynamic>.from(list[idx] as Map);
        _applyExtras(m, values);
        list[idx] = m;
      }
      items[i]['items'] = list;
    });
  }

  static Future<void> removeFolder(
    DocumentReference<Map<String, dynamic>> ref,
    String folderTitle,
  ) {
    return _edit(ref, (items) {
      final i = _indexOf(items, folderTitle);
      if (i >= 0) items.removeAt(i);
    });
  }

  static Future<void> renameFolder(
    DocumentReference<Map<String, dynamic>> ref,
    String oldTitle,
    String newTitle,
  ) {
    return _edit(ref, (items) {
      final i = _indexOf(items, oldTitle);
      if (i < 0 || _indexOf(items, newTitle) >= 0) return;
      items[i]['title'] = newTitle;
    });
  }
}
