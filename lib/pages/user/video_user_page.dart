import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc_admin/pages/video_player_page.dart';
import 'package:item_rdc_admin/theme_manager.dart';
import 'package:item_rdc_admin/util/sorting.dart';
import 'package:item_rdc_admin/util/sub_folders.dart';
import 'package:item_rdc_admin/util/video_catalog.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';

class VideoUserPage extends StatefulWidget {
  final bool isPremium;
  const VideoUserPage({super.key, required this.isPremium});

  @override
  State<VideoUserPage> createState() => _VideoUserPageState();
}

class _VideoUserPageState extends State<VideoUserPage> {
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  bool isSearching = false;
  SortMode _sort = SortMode.newest;

  String get collectionName => VideoCatalog.collectionFor(widget.isPremium);

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _openPlayer(String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(url: url, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: !isSearching
            ? Text(widget.isPremium ? "Vidéos Premium" : "Vidéos Générales")
            : AppBarSearchField(
                controller: searchController,
                hint: "Rechercher une vidéo...",
                onChanged: (value) =>
                    setState(() => searchQuery = value.toLowerCase()),
              ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                if (!isSearching) {
                  searchQuery = "";
                  searchController.clear();
                }
              });
            },
            icon: Icon(isSearching ? Icons.close : Icons.search),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection(collectionName).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final catalog = VideoCatalog.fromSnapshot(
            snapshot.data!,
            query: searchQuery,
          );

          final folders = Sorting.apply<VideoFolder>(
            catalog.folders,
            _sort,
            title: (f) => f.title,
            date: (f) => f.createdAt,
            count: (f) => SubFolders.countFiles(f.items),
          );
          final loose = Sorting.apply<LooseVideo>(
            catalog.loose,
            _sort,
            title: (v) => v.title,
            date: (v) => v.createdAt,
          );

          if (catalog.isEmpty) {
            return EmptyState(
              icon: Icons.video_library_rounded,
              title: searchQuery.isEmpty
                  ? "Aucune vidéo pour le moment"
                  : "Aucune vidéo trouvée",
              message: searchQuery.isEmpty
                  ? "Les nouvelles leçons apparaîtront ici."
                  : "Essayez un autre mot-clé.",
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              BrandHeader(
                icon: widget.isPremium
                    ? Icons.workspace_premium_rounded
                    : Icons.play_circle_fill_rounded,
                title: widget.isPremium ? "Leçons Premium" : "Leçons générales",
                subtitle:
                    "${catalog.folders.length} dossier(s) · ${catalog.totalVideos} vidéo(s)",
              ),
              SortBar(
                value: _sort,
                allowCount: folders.isNotEmpty,
                onChanged: (m) => setState(() => _sort = m),
                trailing: "${catalog.totalVideos} vidéo(s)",
              ),
              if (folders.isNotEmpty) ...[
                SectionTitle(
                  "Dossiers",
                  count: folders.length,
                  icon: Icons.folder_rounded,
                ),
                ...folders.map(_buildFolderCard),
              ],
              if (loose.isNotEmpty) ...[
                SectionTitle(
                  folders.isEmpty ? "Vidéos" : "Autres vidéos",
                  count: loose.length,
                  icon: Icons.video_collection_outlined,
                ),
                ...loose.map(_buildLooseTile),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Vidéos et sous-dossiers (avec leur icône) d'un dossier.
  List<Widget> _itemTiles(List<Map<String, dynamic>> items, String keyPrefix) {
    final theme = Theme.of(context);
    return [
      for (final item in items)
        if (SubFolders.isFolder(item))
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey('${keyPrefix}_${item['title']}'),
              tilePadding: const EdgeInsets.only(left: 22, right: 16),
              childrenPadding: const EdgeInsets.only(left: 14),
              iconColor: AppColors.accent(context),
              shape: const Border(),
              collapsedShape: const Border(),
              leading: FolderIconBadge(
                iconKey: SubFolders.iconKeyOf(item),
                iconUrl: SubFolders.iconUrlOf(item),
                size: 36,
                fallback: Icons.folder_open_rounded,
              ),
              title: Text(
                (item['title'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              subtitle: Text(
                "${SubFolders.countFiles((item['items'] as List?) ?? const [])} vidéo(s)",
              ),
              children: _itemTiles(
                ((item['items'] as List?) ?? const [])
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList(),
                '${keyPrefix}_${item['title']}',
              ),
            ),
          )
        else
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 22, right: 16),
            onTap: () => _openPlayer(
              (item['url'] ?? '').toString(),
              (item['title'] ?? '').toString(),
            ),
            leading: Icon(
              Icons.play_circle_fill_rounded,
              color: AppColors.accent(context),
            ),
            title: Text(
              (item['title'] ?? '').toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: theme.listTileTheme.textColor,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
    ];
  }

  Widget _buildFolderCard(VideoFolder folder) {
    final theme = Theme.of(context);
    final searching = searchQuery.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey('vuf_${folder.id}_$searching'),
            initiallyExpanded: searching,
            tilePadding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            iconColor: AppColors.accent(context),
            collapsedIconColor: theme.listTileTheme.iconColor,
            shape: const Border(),
            collapsedShape: const Border(),
            leading: FolderIconBadge(
              iconKey: folder.iconKey,
              iconUrl: folder.iconUrl,
            ),
            title: Text(
              folder.title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: theme.listTileTheme.textColor,
              ),
            ),
            subtitle: Text(
              "${SubFolders.countFiles(folder.items)} vidéo(s)",
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
            children: [
              if (folder.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    "Ce dossier est vide",
                    style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                  ),
                ),
              ..._itemTiles(folder.items, 'vuf_${folder.id}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLooseTile(LooseVideo video) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => _openPlayer(video.url, video.title),
          contentPadding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          leading: const IconBadge(icon: Icons.play_arrow_rounded),
          title: Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.listTileTheme.textColor,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}
