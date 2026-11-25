import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:item_rdc_admin/util/sorting.dart';
import 'package:item_rdc_admin/util/sub_folders.dart';

/// Vidéo "à plat" (ancien format, sans dossier) : un document = une vidéo.
class LooseVideo {
  final String id;
  final String title;
  final String url;
  final DateTime? createdAt;
  final String cover;
  final String owner;
  final String details;
  const LooseVideo({
    required this.id,
    required this.title,
    required this.url,
    this.createdAt,
    this.cover = '',
    this.owner = '',
    this.details = '',
  });
}

/// Dossier de vidéos : un document `type: folder` contenant `items`.
class VideoFolder {
  final String id;
  final String title;
  final List<Map<String, dynamic>> items;

  /// Icône du dossier : clé prédéfinie (`icon`) et/ou URL d'image (`iconUrl`).
  final String? iconKey;
  final String? iconUrl;
  final DateTime? createdAt;
  const VideoFolder({
    required this.id,
    required this.title,
    required this.items,
    this.iconKey,
    this.iconUrl,
    this.createdAt,
  });
}

/// Contenu d'une collection vidéo (GENERAL_VIDEOS / PREMIUM_VIDEOS).
///
/// - Les documents existants (title + url) restent valides : ils apparaissent
///   dans "Sans dossier".
/// - Les nouveaux dossiers sont des documents `type: 'folder'` dans la même
///   collection, ce qui évite toute modification des règles Firestore.
class VideoCatalog {
  final List<VideoFolder> folders;
  final List<LooseVideo> loose;

  const VideoCatalog({required this.folders, required this.loose});

  int get totalVideos =>
      loose.length +
      folders.fold<int>(0, (sum, f) => sum + SubFolders.countFiles(f.items));

  bool get isEmpty => folders.isEmpty && loose.isEmpty;

  static String collectionFor(bool isPremium) =>
      isPremium ? 'PREMIUM_VIDEOS' : 'GENERAL_VIDEOS';

  /// Une vidéo correspond si son titre contient [q] ; un sous-dossier aussi
  /// si son titre ou l'un de ses fichiers correspond.
  static bool _itemMatches(Map<String, dynamic> e, String q) {
    if ((e['title'] ?? '').toString().toLowerCase().contains(q)) return true;
    if (SubFolders.isFolder(e)) {
      for (final c in (e['items'] as List?) ?? const []) {
        if (c is Map && _itemMatches(Map<String, dynamic>.from(c), q)) return true;
      }
    }
    return false;
  }

  factory VideoCatalog.fromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    String query = '',
  }) {
    final q = query.trim().toLowerCase();
    final folders = <VideoFolder>[];
    final loose = <LooseVideo>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final title = (data['title'] ?? '').toString();
      final created = Sorting.dateOf(
        data['createdAt'],
        pending: doc.metadata.hasPendingWrites,
      );

      if (data['type'] == 'folder') {
        final rawItems = (data['items'] as List?) ?? const [];
        var items = rawItems
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        if (q.isNotEmpty && !title.toLowerCase().contains(q)) {
          items = items.where((e) => _itemMatches(e, q)).toList();
          if (items.isEmpty) continue;
        }
        folders.add(
          VideoFolder(
            id: doc.id,
            title: title,
            items: items,
            iconKey: (data['icon'] ?? '').toString(),
            iconUrl: (data['iconUrl'] ?? '').toString(),
            createdAt: created,
          ),
        );
      } else {
        if (q.isNotEmpty && !title.toLowerCase().contains(q)) continue;
        loose.add(
          LooseVideo(
            id: doc.id,
            title: title,
            url: (data['url'] ?? '').toString(),
            createdAt: created,
            cover: (data['cover'] ?? '').toString(),
            owner: (data['owner'] ?? '').toString(),
            details: (data['details'] ?? '').toString(),
          ),
        );
      }
    }
    return VideoCatalog(folders: folders, loose: loose);
  }
}
