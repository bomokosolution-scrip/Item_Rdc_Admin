import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc_admin/util/sorting.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';
import 'document_admin_page.dart';

class LibraryAdminPage extends StatefulWidget {
  const LibraryAdminPage({super.key});

  @override
  State<LibraryAdminPage> createState() => _LibraryAdminPageState();
}

class _LibraryAdminPageState extends State<LibraryAdminPage> {
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  bool isSearching = false;
  SortMode _sort = SortMode.newest;

  final Stream<QuerySnapshot> _stream = FirebaseFirestore.instance
      .collection('categories')
      .snapshots();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _showAddCategorySheet() {
    final categoryController = TextEditingController();

    showAppSheet(
      context,
      title: "New category",
      icon: Icons.category_rounded,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            controller: categoryController,
            label: "Category name",
            icon: Icons.label_rounded,
            autofocus: true,
          ),
          const SizedBox(height: 20),
          SheetActions(
            confirmLabel: "Create",
            onConfirm: () {
              if (categoryController.text.trim().isEmpty) return;
              FirebaseFirestore.instance.collection('categories').add({
                'title': categoryController.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              });
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(String categoryId, String title) async {
    final ok = await confirmDelete(
      context,
      title: "Delete category?",
      message: "'$title' will be removed.",
    );
    if (ok) {
      FirebaseFirestore.instance.collection('categories').doc(categoryId).delete();
    }
  }

  void _showCategoryOptions(String categoryId, String title) {
    showAppSheet(
      context,
      title: title,
      subtitle: "Category options",
      icon: Icons.category_rounded,
      builder: (ctx) => ListTile(
        leading: Icon(Icons.delete_outline_rounded, color: Theme.of(ctx).colorScheme.error),
        title: Text(
          "Delete category",
          style: TextStyle(color: Theme.of(ctx).colorScheme.error),
        ),
        onTap: () {
          Navigator.pop(ctx);
          _deleteCategory(categoryId, title);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: !isSearching
            ? const Text("Library")
            : AppBarSearchField(
                controller: searchController,
                hint: "Search categories...",
                onChanged: (value) =>
                    setState(() => searchQuery = value.toLowerCase()),
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
        onPressed: _showAddCategorySheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text("Category"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline_rounded,
              title: "Error loading categories",
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          Map<String, dynamic> dataOf(QueryDocumentSnapshot d) =>
              (d.data() as Map<String, dynamic>?) ?? const <String, dynamic>{};

          final filtered = snapshot.data!.docs.where((doc) {
            return (dataOf(doc)['title'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchQuery);
          }).toList();

          final docs = Sorting.apply<QueryDocumentSnapshot>(
            filtered,
            _sort,
            title: (d) => (dataOf(d)['title'] ?? '').toString(),
            date: (d) => Sorting.dateOf(
              dataOf(d)['createdAt'],
              pending: d.metadata.hasPendingWrites,
            ),
          );

          if (docs.isEmpty) {
            return EmptyState(
              icon: Icons.local_library_outlined,
              title: searchQuery.isEmpty ? "No categories yet" : "No result",
              message: searchQuery.isEmpty
                  ? "Tap “Category” to create the first one."
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
                    icon: Icons.local_library_rounded,
                    title: "University library",
                    subtitle: "${docs.length} category(ies) · long press for options",
                  ),
                );
              }
              if (index == 1) {
                return SortBar(
                  value: _sort,
                  onChanged: (m) => setState(() => _sort = m),
                  allowCount: false,
                  trailing: "${docs.length} category(ies)",
                );
              }
              final doc = docs[index - 2];
              final docTitle = (dataOf(doc)['title'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: FadeSlideIn(
                  index: index - 2,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                      leading: const IconBadge(icon: Icons.category_rounded),
                      title: Text(
                        docTitle,
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
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: theme.colorScheme.error,
                            ),
                            onPressed: () => _deleteCategory(doc.id, docTitle),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DocumentAdminPage(
                              categoryId: doc.id,
                              categoryTitle: docTitle,
                            ),
                          ),
                        );
                      },
                      onLongPress: () => _showCategoryOptions(doc.id, docTitle),
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
