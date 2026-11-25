import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc_admin/theme_manager.dart';
import 'package:item_rdc_admin/util/sorting.dart';
import 'package:item_rdc_admin/widgets/image_import.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';
import 'university_document_admin_page.dart';

class DocumentAdminPage extends StatefulWidget {
  final String categoryId;
  final String categoryTitle;

  const DocumentAdminPage({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
  });

  @override
  State<DocumentAdminPage> createState() => _DocumentAdminPageState();
}

class _DocumentAdminPageState extends State<DocumentAdminPage> {
  final TextEditingController universityController = TextEditingController();
  final TextEditingController logoController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  bool isSearching = false;
  SortMode _sort = SortMode.newest;

  late final CollectionReference<Map<String, dynamic>> _col = FirebaseFirestore
      .instance
      .collection('categories')
      .doc(widget.categoryId)
      .collection('universities');

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _col.snapshots();

  /// Universités de la catégorie (mises à jour à chaque snapshot) pour l'export.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allUnis = [];

  @override
  void dispose() {
    universityController.dispose();
    logoController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _addUniversitySheet() {
    universityController.clear();
    logoController.clear();

    showAppSheet(
      context,
      title: "Add universities",
      subtitle: "Separate several names with a comma",
      icon: Icons.school_rounded,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            controller: universityController,
            label: "University name(s)",
            icon: Icons.school_rounded,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          AppField(
            controller: logoController,
            label: "Logo URL (optional)",
            icon: Icons.image_rounded,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          ImageImportButton(
            controller: logoController,
            folder: 'logos',
            maxSide: 192,
            label: "Import logo from gallery",
          ),
          const SizedBox(height: 20),
          SheetActions(
            confirmLabel: "Add",
            onConfirm: () async {
              final input = universityController.text.trim();
              final logoUrl = logoController.text.trim();
              if (input.isEmpty) return;

              final universities = input
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              Navigator.pop(ctx);
              for (var uniName in universities) {
                await _col.add({
                  'name': uniName,
                  'logoUrl': logoUrl.isEmpty ? null : logoUrl,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ Export

  Future<void> _showExportSheet() async {
    if (_allUnis.isEmpty) {
      showToast(context, "No universities to export", error: true);
      return;
    }
    QuerySnapshot<Map<String, dynamic>> catSnap;
    try {
      catSnap = await FirebaseFirestore.instance.collection('categories').get();
    } catch (e) {
      if (mounted) showToast(context, "Cannot load categories: $e", error: true);
      return;
    }
    if (!mounted) return;

    final others = catSnap.docs.where((d) => d.id != widget.categoryId).toList();
    if (others.isEmpty) {
      showToast(context, "Create another category first", error: true);
      return;
    }

    final unis = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(_allUnis);
    final selUnis = <String>{for (final u in unis) u.id};
    final selCats = <String>{};
    bool copyDocs = false;

    await showAppSheet(
      context,
      title: "Export universities",
      subtitle: "Copied to the chosen categories (originals are kept)",
      icon: Icons.ios_share_rounded,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final theme = Theme.of(ctx);
          final allSelected = selUnis.length == unis.length;
          final invalid = selUnis.isEmpty || selCats.isEmpty;
          final headStyle = TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.textTheme.bodyLarge?.color,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "1. Universities (${selUnis.length}/${unis.length})",
                      style: headStyle,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setSheet(() {
                      if (allSelected) {
                        selUnis.clear();
                      } else {
                        selUnis.addAll(unis.map((u) => u.id));
                      }
                    }),
                    child: Text(allSelected ? "None" : "All"),
                  ),
                ],
              ),
              for (final u in unis)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selUnis.contains(u.id),
                  onChanged: (v) => setSheet(() {
                    if (v == true) {
                      selUnis.add(u.id);
                    } else {
                      selUnis.remove(u.id);
                    }
                  }),
                  title: Text((u.data()['name'] ?? '').toString()),
                ),
              const SizedBox(height: 10),
              Text("2. Destination categories (${selCats.length})", style: headStyle),
              for (final c in others)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selCats.contains(c.id),
                  onChanged: (v) => setSheet(() {
                    if (v == true) {
                      selCats.add(c.id);
                    } else {
                      selCats.remove(c.id);
                    }
                  }),
                  title: Text((c.data()['title'] ?? '').toString()),
                ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: copyDocs,
                onChanged: (v) => setSheet(() => copyDocs = v),
                title: const Text("Also copy their documents"),
                subtitle: const Text("Otherwise only the name and logo are copied"),
              ),
              if (invalid)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "Select at least one university and one category",
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 6),
              SheetActions(
                confirmLabel: "Export",
                confirmIcon: Icons.ios_share_rounded,
                onConfirm: () {
                  if (invalid) return;
                  final chosen = unis.where((u) => selUnis.contains(u.id)).toList();
                  final cats = selCats.toList();
                  Navigator.pop(ctx);
                  _runExport(chosen, cats, copyDocs);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _runExport(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> unis,
    List<String> categoryIds,
    bool copyDocs,
  ) async {
    showToast(context, "Export in progress…");
    int added = 0;
    int skipped = 0;
    try {
      for (final catId in categoryIds) {
        final target = FirebaseFirestore.instance
            .collection('categories')
            .doc(catId)
            .collection('universities');
        final existing = await target.get();
        final names = existing.docs
            .map((d) => (d.data()['name'] ?? '').toString().trim().toLowerCase())
            .toSet();

        for (final u in unis) {
          final data = u.data();
          final name = (data['name'] ?? '').toString().trim();
          if (name.isEmpty) continue;
          if (names.contains(name.toLowerCase())) {
            skipped++; // déjà présente dans cette catégorie
            continue;
          }
          final newRef = await target.add({
            'name': name,
            'logoUrl': data['logoUrl'],
            'createdAt': FieldValue.serverTimestamp(),
          });
          names.add(name.toLowerCase());
          added++;
          if (copyDocs) await _copyDocuments(u.reference, newRef);
        }
      }
      if (!mounted) return;
      showToast(context, "$added exported, $skipped already existed");
    } catch (e) {
      if (mounted) showToast(context, "Export failed: $e", error: true);
    }
  }

  Future<void> _copyDocuments(
    DocumentReference<Map<String, dynamic>> from,
    DocumentReference<Map<String, dynamic>> to,
  ) async {
    final docs = await from.collection('documents').get();
    var batch = FirebaseFirestore.instance.batch();
    var n = 0;
    for (final d in docs.docs) {
      batch.set(to.collection('documents').doc(), d.data());
      n++;
      if (n >= 400) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        n = 0;
      }
    }
    if (n > 0) await batch.commit();
  }

  Future<void> _deleteUniversity(String universityId, String uniName) async {
    final ok = await confirmDelete(
      context,
      title: "Delete university?",
      message: "'$uniName' will be removed.",
    );
    if (ok) await _col.doc(universityId).delete();
  }

  void _showUniversityOptions(String universityId, String uniName) {
    showAppSheet(
      context,
      title: uniName,
      subtitle: "University options",
      icon: Icons.school_rounded,
      builder: (ctx) => ListTile(
        leading: Icon(Icons.delete_outline_rounded, color: Theme.of(ctx).colorScheme.error),
        title: Text(
          "Delete university",
          style: TextStyle(color: Theme.of(ctx).colorScheme.error),
        ),
        onTap: () {
          Navigator.pop(ctx);
          _deleteUniversity(universityId, uniName);
        },
      ),
    );
  }

  Widget _logo(String logoUrl) {
    if (logoUrl.isEmpty) return const IconBadge(icon: Icons.school_rounded);
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 42,
        height: 42,
        color: Colors.white,
        child: Image.network(
          logoUrl,
          fit: BoxFit.cover,
          cacheWidth: 120,
          errorBuilder: (_, _, _) => const IconBadge(icon: Icons.school_rounded),
        ),
      ),
    );
  }

  Widget _buildUniversityTile(QueryDocumentSnapshot<Map<String, dynamic>> uni, int index) {
    final theme = Theme.of(context);
    final data = uni.data();
    final logoUrl = (data['logoUrl'] ?? "").toString();
    final name = (data['name'] ?? "").toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: FadeSlideIn(
        index: index,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
            leading: _logo(logoUrl),
            title: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.listTileTheme.textColor,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: "Delete",
                  icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                  onPressed: () => _deleteUniversity(uni.id, name),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.textTheme.bodyMedium?.color),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UniversityDocumentAdminPage(
                    categoryId: widget.categoryId,
                    universityId: uni.id,
                    universityName: name,
                  ),
                ),
              );
            },
            onLongPress: () => _showUniversityOptions(uni.id, name),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: !isSearching
            ? Text(widget.categoryTitle)
            : AppBarSearchField(
                controller: searchController,
                hint: "Search universities...",
                onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
              ),
        actions: [
          IconButton(
            tooltip: "Export universities",
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: _showExportSheet,
          ),
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
        onPressed: _addUniversitySheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text("University"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline_rounded,
              title: "Error loading universities",
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          _allUnis = snapshot.data!.docs;

          final filtered = snapshot.data!.docs.where((d) {
            return (d.data()['name'] ?? '').toString().toLowerCase().contains(searchQuery);
          }).toList();

          final docs = Sorting.apply<QueryDocumentSnapshot<Map<String, dynamic>>>(
            filtered,
            _sort,
            title: (d) => (d.data()['name'] ?? '').toString(),
            date: (d) => Sorting.dateOf(
              d.data()['createdAt'],
              pending: d.metadata.hasPendingWrites,
            ),
          );

          if (docs.isEmpty) {
            return EmptyState(
              icon: Icons.school_outlined,
              title: searchQuery.isEmpty ? "No universities yet" : "No result",
              message: searchQuery.isEmpty
                  ? "Tap “University” to add one."
                  : "Try another keyword.",
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: docs.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BrandHeader(
                    icon: Icons.school_rounded,
                    title: widget.categoryTitle,
                    subtitle: "${docs.length} university(ies)",
                  ),
                );
              }
              if (index == 1) {
                return SortBar(
                  value: _sort,
                  onChanged: (m) => setState(() => _sort = m),
                  allowCount: false,
                  trailing: "${docs.length} university(ies)",
                );
              }
              return _buildUniversityTile(docs[index - 2], index - 2);
            },
          );
        },
      ),
    );
  }
}
