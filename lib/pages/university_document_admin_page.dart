import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc_admin/pages/home_page.dart';
import 'package:item_rdc_admin/pages/video_player_page.dart';
import 'package:item_rdc_admin/theme_manager.dart';
import 'package:item_rdc_admin/util/media_utils.dart';
import 'package:item_rdc_admin/util/sorting.dart';
import 'package:item_rdc_admin/widgets/image_import.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';

class UniversityDocumentAdminPage extends StatefulWidget {
  final String categoryId;
  final String universityId;
  final String universityName;

  const UniversityDocumentAdminPage({
    super.key,
    required this.categoryId,
    required this.universityId,
    required this.universityName,
  });

  @override
  State<UniversityDocumentAdminPage> createState() =>
      _UniversityDocumentAdminPageState();
}

class _UniversityDocumentAdminPageState
    extends State<UniversityDocumentAdminPage> {
  static const _types = ["All", "TFC", "Mémoire", "Stage"];

  String filterType = "All";
  SortMode _sort = SortMode.newest;
  TextEditingController searchController = TextEditingController();
  TextEditingController titleController = TextEditingController();
  TextEditingController urlController = TextEditingController();
  String searchQuery = "";
  bool isSearching = false;

  late final CollectionReference<Map<String, dynamic>> _col = FirebaseFirestore
      .instance
      .collection('categories')
      .doc(widget.categoryId)
      .collection('universities')
      .doc(widget.universityId)
      .collection('documents');

  // Pas de orderBy : un orderBy masque les anciens documents sans `createdAt`.
  // Le tri se fait côté appareil (voir `_sort`).
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _col.snapshots();

  @override
  void dispose() {
    searchController.dispose();
    titleController.dispose();
    urlController.dispose();
    super.dispose();
  }

  void _showAddDocumentSheet() {
    titleController.clear();
    urlController.clear();
    final coverController = TextEditingController();
    final ownerController = TextEditingController();
    final detailsController = TextEditingController();

    showAppSheet(
      context,
      title: "Add document",
      subtitle: widget.universityName,
      icon: Icons.note_add_rounded,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            controller: titleController,
            label: "Document titles (comma separated)",
            icon: Icons.title_rounded,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          AppField(
            controller: urlController,
            label: "URLs (comma separated)",
            icon: Icons.link_rounded,
            keyboardType: TextInputType.url,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              filterType == "All"
                  ? "Added to all types: TFC, Mémoire and Stage."
                  : "Added to the type: $filterType.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).textTheme.bodyMedium?.color,
              ),
            ),
          ),
          FileExtrasFields(
            cover: coverController,
            owner: ownerController,
            details: detailsController,
          ),
          const SizedBox(height: 16),
          SheetActions(
            confirmLabel: "Add",
            onConfirm: () {
              final extras = fileExtras(
                cover: coverController.text,
                owner: ownerController.text,
                details: detailsController.text,
              );
              final titles = titleController.text.split(',').map((e) => e.trim()).toList();
              final urls = urlController.text.split(',').map((e) => e.trim()).toList();

              if (titles.every((t) => t.isEmpty)) return;

              final typesToAdd = filterType == "All"
                  ? ["TFC", "Mémoire", "Stage"]
                  : [filterType];

              for (var type in typesToAdd) {
                for (int i = 0; i < titles.length; i++) {
                  if (titles[i].isNotEmpty) {
                    _col.add({
                      'title': titles[i],
                      'url': i < urls.length ? urls[i] : '',
                      'type': type,
                      'isAll': filterType == "All",
                      ...extras,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  }
                }
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDocument(String docId, String title) async {
    final ok = await confirmDelete(
      context,
      title: "Delete document?",
      message: "'$title' will be removed.",
    );
    if (ok) _col.doc(docId).delete();
  }

  IconData _iconFor(String url) {
    if (MediaUtils.isYoutube(url)) return Icons.ondemand_video_rounded;
    if (MediaUtils.looksLikeVideoFile(url)) return Icons.video_library_rounded;
    if (MediaUtils.isDrive(url)) return Icons.cloud_rounded;
    if (MediaUtils.looksLikePdf(url)) return Icons.picture_as_pdf_rounded;
    return Icons.insert_drive_file_rounded;
  }

  void _open(String url, String title) {
    if (url.trim().isEmpty) {
      showToast(context, "This document has no URL.", error: true);
      return;
    }
    final isVideo = MediaUtils.isYoutube(url) || MediaUtils.looksLikeVideoFile(url);
    final isDoc = MediaUtils.looksLikePdf(url) || MediaUtils.isDrive(url);

    if (isVideo) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoPlayerPage(url: url, title: title)),
      );
    } else if (isDoc) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PdfViewer(url: url, title: title)),
      );
    } else {
      showToast(context, "Unsupported file type.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: !isSearching
            ? Text("${widget.universityName} Admin", maxLines: 1, overflow: TextOverflow.ellipsis)
            : AppBarSearchField(
                controller: searchController,
                hint: "Search documents...",
                onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
              ),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                if (!isSearching) {
                  searchQuery = "";
                  searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDocumentSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text("Document"),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: _types.map((type) {
                final isSelected = filterType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: dark ? AppColors.brandDark : AppColors.brand,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                    ),
                    onSelected: (_) => setState(() => filterType = type),
                  ),
                );
              }).toList(),
            ),
          ),
          SortBar(
            value: _sort,
            allowCount: false,
            onChanged: (m) => setState(() => _sort = m),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: "Error loading documents",
                  );
                }
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs.where((doc) {
                  final d = doc.data();
                  final title = (d['title'] ?? '').toString().toLowerCase();
                  final type = normType(d['type']);
                  final matchesType = filterType == "All" ? true : type == filterType;
                  final matchesSearch = searchQuery.isEmpty ? true : title.contains(searchQuery);
                  return matchesType && matchesSearch;
                }).toList();

                if (filterType == "All") {
                  final seen = <String>{};
                  docs = docs.where((doc) => seen.add((doc.data()['title'] ?? '').toString())).toList();
                }

                docs = Sorting.apply<QueryDocumentSnapshot<Map<String, dynamic>>>(
                  docs,
                  _sort,
                  title: (d) => (d.data()['title'] ?? '').toString(),
                  date: (d) => Sorting.dateOf(
                    d.data()['createdAt'],
                    pending: d.metadata.hasPendingWrites,
                  ),
                );

                if (docs.isEmpty) {
                  return EmptyState(
                    icon: Icons.description_outlined,
                    title: searchQuery.isEmpty ? "No documents yet" : "No result",
                    message: searchQuery.isEmpty ? "Tap “Document” to add one." : "Try another keyword.",
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final d = doc.data();
                    final url = (d['url'] ?? '').toString();
                    final title = (d['title'] ?? '').toString();
                    final isAll = d['isAll'] == true;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: FadeSlideIn(
                        index: index,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                            leading: IconBadge(icon: _iconFor(url)),
                            title: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.listTileTheme.textColor,
                              ),
                            ),
                            subtitle: Text(isAll ? "All" : normType(d['type'])),
                            trailing: FileTrailing(
                              onEdit: () => showEditExtrasSheet(
                                context,
                                fileTitle: title,
                                current: d,
                                onSave: (values) =>
                                    doc.reference.update(extrasUpdate(values)),
                              ),
                              onDelete: () => _deleteDocument(doc.id, title),
                            ),
                            onTap: () => _open(url, title),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
