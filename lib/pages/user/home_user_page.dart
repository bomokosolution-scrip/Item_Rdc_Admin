import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc_admin/pages/home_page.dart'; // Pour PdfViewer
import 'package:item_rdc_admin/theme_manager.dart';
import 'package:item_rdc_admin/util/sorting.dart';
import 'package:item_rdc_admin/util/sub_folders.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';

class HomeUserPage extends StatefulWidget {
  final bool isPremium;
  const HomeUserPage({super.key, required this.isPremium});

  @override
  State<HomeUserPage> createState() => _HomeUserPageState();
}

class _HomeUserPageState extends State<HomeUserPage> {
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  bool isSearching = false;
  SortMode _sort = SortMode.newest;

  String get collectionName =>
      widget.isPremium ? "PREMIUM_HOME" : "GENERAL_HOME";

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  /// Fichiers et sous-dossiers (avec leur icône) d'un dossier.
  List<Widget> _itemTiles(List items, String keyPrefix) {
    final theme = Theme.of(context);
    return [
      for (final item in items)
        if (item is Map)
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
                  "${SubFolders.countFiles((item['items'] as List?) ?? const [])} document(s)",
                ),
                children: _itemTiles(
                  (item['items'] as List?) ?? const [],
                  '${keyPrefix}_${item['title']}',
                ),
              ),
            )
          else
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 22, right: 16),
              leading: Icon(
                Icons.picture_as_pdf_rounded,
                color: AppColors.accent(context),
              ),
              title: Text(
                (item['title'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfViewer(
                      url: (item['url'] ?? '').toString(),
                      title: (item['title'] ?? '').toString(),
                    ),
                  ),
                );
              },
            ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: !isSearching
            ? Text(widget.isPremium ? "Premium RDC" : "Général RDC")
            : AppBarSearchField(
                controller: searchController,
                hint: "Rechercher...",
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

          final filtered = snapshot.data!.docs.where((doc) {
            return (doc.data()['title'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchQuery);
          }).toList();

          final docs = Sorting.apply<QueryDocumentSnapshot<Map<String, dynamic>>>(
            filtered,
            _sort,
            title: (d) => (d.data()['title'] ?? '').toString(),
            date: (d) => Sorting.dateOf(
              d.data()['createdAt'],
              pending: d.metadata.hasPendingWrites,
            ),
            count: (d) => SubFolders.countFiles(
              (d.data()['items'] as List?) ?? const [],
            ),
          );

          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.folder_off_rounded,
              title: "Aucun dossier trouvé",
              message: "Essayez un autre mot-clé.",
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: docs.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BrandHeader(
                    icon: widget.isPremium
                        ? Icons.workspace_premium_rounded
                        : Icons.folder_copy_rounded,
                    title: widget.isPremium
                        ? "Documents Premium"
                        : "Documents généraux",
                    subtitle: "${docs.length} dossier(s)",
                  ),
                );
              }

              if (index == 1) {
                return SortBar(
                  value: _sort,
                  onChanged: (m) => setState(() => _sort = m),
                  trailing: "${docs.length} dossier(s)",
                );
              }

              final doc = docs[index - 2];
              final data = doc.data();
              final List items = (data['items'] as List?) ?? const [];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: PageStorageKey('huf_${doc.id}'),
                      tilePadding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                      iconColor: AppColors.accent(context),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: FolderIconBadge(
                        iconKey: (data['icon'] ?? '').toString(),
                        iconUrl: (data['iconUrl'] ?? '').toString(),
                      ),
                      title: Text(
                        (data['title'] ?? '').toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text("${SubFolders.countFiles(items)} document(s)"),
                      children: _itemTiles(items, 'huf_${doc.id}'),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
