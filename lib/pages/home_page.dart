import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc_admin/pages/pdf_viewer_page.dart';
import 'package:item_rdc_admin/theme_manager.dart';
import 'package:item_rdc_admin/util/sorting.dart';
import 'package:item_rdc_admin/widgets/image_import.dart';
import 'package:item_rdc_admin/util/sub_folders.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';

// Le lecteur PDF vit désormais dans pdf_viewer_page.dart ; on le ré-exporte
// pour que les anciens imports de home_page.dart continuent de fonctionner.
export 'package:item_rdc_admin/pages/pdf_viewer_page.dart';

class HomePage extends StatefulWidget {
  final bool isPremium;
  const HomePage({super.key, required this.isPremium});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  void _showAddFolderDialog() {
    TextEditingController folderController = TextEditingController();
    final iconUrlController = TextEditingController();
    String? iconKey;

    showAppSheet(
      context,
      title: "New folder",
      subtitle: "Separate several names with a comma",
      icon: Icons.create_new_folder_rounded,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppField(
              controller: folderController,
              label: "Folders name",
              icon: Icons.folder_rounded,
              autofocus: true,
            ),
            const SizedBox(height: 18),
            FolderIconPicker(
              urlController: iconUrlController,
              selectedKey: iconKey,
              onKeyChanged: (k) => setSheetState(() => iconKey = k),
            ),
            const SizedBox(height: 20),
            SheetActions(
              confirmLabel: "Done",
              onConfirm: () {
                if (folderController.text.isNotEmpty) {
                  _addFoldersToFirebase(
                    folderController.text,
                    iconKey: iconKey,
                    iconUrl: iconUrlController.text.trim(),
                  );
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Modifier / retirer l'icône d'un dossier existant.
  void _showEditIconSheet(String docId, String title, String? currentKey, String currentUrl) {
    final iconUrlController = TextEditingController(text: currentUrl);
    String? iconKey = (currentKey == null || currentKey.isEmpty) ? null : currentKey;

    showAppSheet(
      context,
      title: "Folder icon",
      subtitle: title,
      icon: Icons.image_rounded,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FolderIconPicker(
              urlController: iconUrlController,
              selectedKey: iconKey,
              onKeyChanged: (k) => setSheetState(() => iconKey = k),
            ),
            const SizedBox(height: 20),
            SheetActions(
              confirmLabel: "Save",
              onConfirm: () {
                final url = iconUrlController.text.trim();
                FirebaseFirestore.instance.collection(collectionName).doc(docId).update({
                  'icon': iconKey ?? FieldValue.delete(),
                  'iconUrl': url.isEmpty ? FieldValue.delete() : url,
                });
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemSheet(String docId, {String? subFolder}) {
    TextEditingController nameController = TextEditingController();
    TextEditingController urlController = TextEditingController();
    final coverController = TextEditingController();
    final ownerController = TextEditingController();
    final detailsController = TextEditingController();

    showAppSheet(
      context,
      title: "Add PDF",
      subtitle: subFolder == null
          ? "Several PDFs: separate with commas"
          : "In sub-folder: $subFolder",
      icon: Icons.picture_as_pdf_rounded,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            controller: nameController,
            label: "PDF name",
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 12),
          AppField(
            controller: urlController,
            label: "PDF URL",
            icon: Icons.link_rounded,
            keyboardType: TextInputType.url,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              "Add multiple pdf separate via comma. The cover, owner and details apply to every PDF added in this step.",
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
              _addItemsToFolder(
                docId,
                nameController.text,
                urlController.text,
                subFolder: subFolder,
                extras: fileExtras(
                  cover: coverController.text,
                  owner: ownerController.text,
                  details: detailsController.text,
                  withDate: true,
                ),
              );
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showFolderOptions(String docId, String title) {
    showAppSheet(
      context,
      title: title,
      subtitle: "Folder options",
      icon: Icons.folder_rounded,
      builder: (ctx) => Column(
        children: [
          ListTile(
            leading: const Icon(Icons.add_box_rounded),
            title: const Text("Add items to this folder"),
            onTap: () {
              Navigator.pop(ctx);
              _showAddItemSheet(docId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_rounded),
            title: const Text("Add sub-folder"),
            onTap: () {
              Navigator.pop(ctx);
              _showAddSubFolderSheet(docId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.image_rounded),
            title: const Text("Change folder icon"),
            onTap: () async {
              Navigator.pop(ctx);
              final snap = await FirebaseFirestore.instance
                  .collection(collectionName)
                  .doc(docId)
                  .get();
              final d = snap.data() ?? {};
              if (!mounted) return;
              _showEditIconSheet(
                docId,
                title,
                (d['icon'] ?? '').toString(),
                (d['iconUrl'] ?? '').toString(),
              );
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever,
              color: Theme.of(ctx).colorScheme.error,
            ),
            title: Text(
              "Delete this entire folder",
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _confirmDeleteFolder(docId, title);
            },
          ),
        ],
      ),
    );
  }

  void _addFoldersToFirebase(String input, {String? iconKey, String iconUrl = ''}) {
    List<String> folders = input.split(',').map((e) => e.trim()).toList();
    for (var name in folders) {
      if (name.isNotEmpty) {
        FirebaseFirestore.instance.collection(collectionName).add({
          'title': name,
          'items': [],
          if (iconKey != null && iconKey.isNotEmpty) 'icon': iconKey,
          if (iconUrl.isNotEmpty) 'iconUrl': iconUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  void _addItemsToFolder(
    String docId,
    String names,
    String urls, {
    String? subFolder,
    Map<String, dynamic> extras = const {},
  }) {
    List<String> nList = names.split(',');
    List<String> uList = urls.split(',');
    List<Map<String, dynamic>> itemsToAdd = [];
    for (int i = 0; i < nList.length; i++) {
      if (i < uList.length &&
          nList[i].trim().isNotEmpty &&
          uList[i].trim().isNotEmpty) {
        itemsToAdd.add({'title': nList[i].trim(), 'url': uList[i].trim(), ...extras});
      }
    }
    if (itemsToAdd.isEmpty) return;
    final ref = FirebaseFirestore.instance.collection(collectionName).doc(docId);
    if (subFolder != null) {
      SubFolders.addFiles(ref, subFolder, itemsToAdd);
      return;
    }
    ref.update({'items': FieldValue.arrayUnion(itemsToAdd)});
  }

  // ------------------------------------------------------------ Sous-dossiers

  DocumentReference<Map<String, dynamic>> _ref(String docId) =>
      FirebaseFirestore.instance.collection(collectionName).doc(docId);

  void _editFileExtras(String docId, Map file, {String? subFolder}) {
    showEditExtrasSheet(
      context,
      fileTitle: (file['title'] ?? '').toString(),
      current: file,
      onSave: (values) => SubFolders.updateFileExtras(
        _ref(docId),
        folderTitle: subFolder,
        file: file,
        values: values,
      ),
    );
  }

  void _showAddSubFolderSheet(String docId) {
    final controller = TextEditingController();
    final iconUrlController = TextEditingController();
    String? iconKey;
    showAppSheet(
      context,
      title: "New sub-folder",
      subtitle: "Separate several names with a comma",
      icon: Icons.create_new_folder_rounded,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppField(
              controller: controller,
              label: "Sub-folder name(s)",
              icon: Icons.folder_open_rounded,
              autofocus: true,
            ),
            const SizedBox(height: 18),
            FolderIconPicker(
              urlController: iconUrlController,
              selectedKey: iconKey,
              onKeyChanged: (k) => setSheetState(() => iconKey = k),
            ),
            const SizedBox(height: 20),
            SheetActions(
              confirmLabel: "Create",
              onConfirm: () {
                final names = controller.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                if (names.isEmpty) return;
                SubFolders.addFolders(
                  _ref(docId),
                  names,
                  iconKey: iconKey,
                  iconUrl: iconUrlController.text.trim(),
                );
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Modifier / retirer l'icône d'un sous-dossier existant.
  void _showEditSubFolderIconSheet(String docId, String title, dynamic item) {
    final iconUrlController = TextEditingController(text: SubFolders.iconUrlOf(item));
    final currentKey = SubFolders.iconKeyOf(item);
    String? iconKey = currentKey.isEmpty ? null : currentKey;

    showAppSheet(
      context,
      title: "Sub-folder icon",
      subtitle: title,
      icon: Icons.image_rounded,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FolderIconPicker(
              urlController: iconUrlController,
              selectedKey: iconKey,
              onKeyChanged: (k) => setSheetState(() => iconKey = k),
            ),
            const SizedBox(height: 20),
            SheetActions(
              confirmLabel: "Save",
              onConfirm: () {
                SubFolders.setIcon(
                  _ref(docId),
                  title,
                  iconKey: iconKey,
                  iconUrl: iconUrlController.text.trim(),
                );
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameSubFolderSheet(String docId, String oldTitle) {
    final controller = TextEditingController(text: oldTitle);
    showAppSheet(
      context,
      title: "Rename sub-folder",
      icon: Icons.drive_file_rename_outline_rounded,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            controller: controller,
            label: "Sub-folder name",
            icon: Icons.folder_open_rounded,
            autofocus: true,
          ),
          const SizedBox(height: 20),
          SheetActions(
            confirmLabel: "Save",
            onConfirm: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              SubFolders.renameFolder(_ref(docId), oldTitle, name);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSubFolder(String docId, String title) async {
    final ok = await confirmDelete(
      context,
      title: "Delete sub-folder?",
      message: "'$title' and its files will be removed.",
    );
    if (ok) SubFolders.removeFolder(_ref(docId), title);
  }

  Widget _buildSubFolder(String docId, dynamic item) {
    final theme = Theme.of(context);
    final title = (item['title'] ?? '').toString();
    final files = ((item['items'] as List?) ?? const []).whereType<Map>().toList();

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('hs_${docId}_$title'),
        tilePadding: const EdgeInsets.only(left: 22, right: 8),
        childrenPadding: const EdgeInsets.only(left: 14),
        iconColor: AppColors.accent(context),
        collapsedIconColor: theme.listTileTheme.iconColor,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: FolderIconBadge(
          iconKey: SubFolders.iconKeyOf(item),
          iconUrl: SubFolders.iconUrlOf(item),
          size: 36,
          fallback: Icons.folder_open_rounded,
        ),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: theme.listTileTheme.textColor,
          ),
        ),
        subtitle: Text(
          "${files.length} file(s)",
          style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 12),
        ),
        children: [
          if (files.isEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                "This sub-folder is empty",
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
            ),
          for (final file in files)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 12, right: 6),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfViewer(
                    url: (file['url'] ?? '').toString(),
                    title: (file['title'] ?? '').toString(),
                  ),
                ),
              ),
              leading: FileLeading(
                cover: (file['cover'] ?? '').toString(),
                url: (file['url'] ?? '').toString(),
                icon: Icons.picture_as_pdf_rounded,
              ),
              title: Text(
                (file['title'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: theme.listTileTheme.textColor),
              ),
              trailing: FileTrailing(
                onEdit: () => _editFileExtras(docId, file, subFolder: title),
                onDelete: () => SubFolders.removeFile(_ref(docId), title, file),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 8, 6),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _showAddItemSheet(docId, subFolder: title),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text("Add PDFs"),
                ),
                TextButton.icon(
                  onPressed: () => _showRenameSubFolderSheet(docId, title),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text("Rename"),
                ),
                TextButton.icon(
                  onPressed: () => _showEditSubFolderIconSheet(docId, title, item),
                  icon: const Icon(Icons.image_rounded, size: 18),
                  label: const Text("Icon"),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  onPressed: () => _confirmDeleteSubFolder(docId, title),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text("Delete"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteFolder(String docId, String title) async {
    final ok = await confirmDelete(
      context,
      title: "Delete Folder?",
      message: "Delete '$title'?",
    );
    if (ok) {
      FirebaseFirestore.instance
          .collection(collectionName)
          .doc(docId)
          .delete();
    }
  }

  void _deleteSingleItem(String docId, Map itemData) {
    FirebaseFirestore.instance.collection(collectionName).doc(docId).update({
      'items': FieldValue.arrayRemove([itemData]),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: !isSearching
            ? Text(widget.isPremium ? "Premium Admin" : "General Admin")
            : AppBarSearchField(
                controller: searchController,
                hint: "Search folders...",
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFolderDialog,
        icon: const Icon(Icons.create_new_folder_rounded),
        label: const Text("Folder"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(collectionName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline_rounded,
              title: "Error loading data",
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final filtered = snapshot.data!.docs.where((doc) {
            final title = (doc.data()['title'] ?? '').toString().toLowerCase();
            return title.contains(searchQuery);
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
            return EmptyState(
              icon: Icons.folder_off_rounded,
              title: searchQuery.isEmpty ? "No folders found" : "No result",
              message: searchQuery.isEmpty
                  ? "Tap “Folder” to create one."
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
                    icon: widget.isPremium
                        ? Icons.workspace_premium_rounded
                        : Icons.folder_copy_rounded,
                    title: widget.isPremium
                        ? "Premium documents"
                        : "General documents",
                    subtitle: "${docs.length} folder(s) · long press for options",
                  ),
                );
              }

              if (index == 1) {
                return SortBar(
                  value: _sort,
                  onChanged: (m) => setState(() => _sort = m),
                  trailing: "${docs.length} folder(s)",
                );
              }

              final doc = docs[index - 2];
              final folderData = doc.data();
              final List items = (folderData['items'] as List?) ?? const [];
              final folderTitle = (folderData['title'] ?? '').toString();
              final folderIconKey = (folderData['icon'] ?? '').toString();
              final folderIconUrl = (folderData['iconUrl'] ?? '').toString();

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: GestureDetector(
                      onLongPress: () =>
                          _showFolderOptions(doc.id, folderTitle),
                      child: ExpansionTile(
                        key: PageStorageKey('hf_${doc.id}'),
                        tilePadding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                        iconColor: AppColors.accent(context),
                        collapsedIconColor: theme.listTileTheme.iconColor,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        leading: FolderIconBadge(
                          iconKey: folderIconKey,
                          iconUrl: folderIconUrl,
                        ),
                        title: Text(
                          folderTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: theme.listTileTheme.textColor,
                          ),
                        ),
                        subtitle: Text(
                          "${SubFolders.countFiles(items)} item",
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        children: [
                          ...items.map<Widget>((item) {
                            if (SubFolders.isFolder(item)) {
                              return _buildSubFolder(doc.id, item);
                            }
                            return ListTile(
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
                              dense: true,
                              contentPadding: const EdgeInsets.only(
                                left: 22,
                                right: 6,
                              ),
                              leading: FileLeading(
                                cover: (item['cover'] ?? '').toString(),
                                url: (item['url'] ?? '').toString(),
                                icon: Icons.picture_as_pdf_rounded,
                              ),
                              title: Text(
                                (item['title'] ?? '').toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: theme.listTileTheme.textColor,
                                ),
                              ),
                              trailing: FileTrailing(
                                onEdit: () => _editFileExtras(doc.id, item),
                                onDelete: () => _deleteSingleItem(doc.id, item),
                              ),
                            );
                          }),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 4,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _showAddItemSheet(doc.id),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text("Add PDFs"),
                                ),
                                TextButton.icon(
                                  onPressed: () => _showAddSubFolderSheet(doc.id),
                                  icon: const Icon(Icons.create_new_folder_rounded, size: 18),
                                  label: const Text("Sub-folder"),
                                ),
                                TextButton.icon(
                                  onPressed: () => _showEditIconSheet(
                                    doc.id,
                                    folderTitle,
                                    folderIconKey,
                                    folderIconUrl,
                                  ),
                                  icon: const Icon(Icons.image_rounded, size: 18),
                                  label: const Text("Icon"),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: theme.colorScheme.error,
                                  ),
                                  onPressed: () => _confirmDeleteFolder(
                                    doc.id,
                                    folderTitle,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                  ),
                                  label: const Text("Delete folder"),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
