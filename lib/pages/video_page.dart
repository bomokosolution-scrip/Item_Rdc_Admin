import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc_admin/pages/video_player_page.dart';
import 'package:item_rdc_admin/theme_manager.dart';
import 'package:item_rdc_admin/util/sorting.dart';
import 'package:item_rdc_admin/widgets/image_import.dart';
import 'package:item_rdc_admin/util/sub_folders.dart';
import 'package:item_rdc_admin/util/video_catalog.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';

class VideoPage extends StatefulWidget {
  final bool isPremium;
  const VideoPage({super.key, required this.isPremium});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  bool isSearching = false;
  SortMode _sort = SortMode.newest;

  /// Dossiers connus (mis à jour à chaque snapshot) pour le choix de destination.
  List<VideoFolder> _knownFolders = [];

  String get collectionName => VideoCatalog.collectionFor(widget.isPremium);

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(collectionName);

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------- Ajouts

  void _showAddMenu() {
    showAppSheet(
      context,
      title: "Add content",
      subtitle: widget.isPremium ? "Premium videos" : "General videos",
      icon: Icons.add_circle_outline_rounded,
      builder: (ctx) => Column(
        children: [
          _menuTile(
            ctx,
            icon: Icons.create_new_folder_rounded,
            title: "New folder",
            subtitle: "Group videos by course or topic",
            onTap: () {
              Navigator.pop(ctx);
              _showAddFolderSheet();
            },
          ),
          const SizedBox(height: 10),
          _menuTile(
            ctx,
            icon: Icons.video_call_rounded,
            title: "Add videos",
            subtitle: "In a folder or without folder",
            onTap: () {
              Navigator.pop(ctx);
              _showAddVideoSheet();
            },
          ),
        ],
      ),
    );
  }

  Widget _menuTile(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(ctx).scaffoldBackgroundColor.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconBadge(icon: icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Theme.of(ctx).textTheme.bodyLarge?.color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(ctx).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(ctx).textTheme.bodyMedium?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddFolderSheet() {
    final controller = TextEditingController();
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
              controller: controller,
              label: "Folder name(s)",
              hint: "Ex: Anatomy, Physiology",
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
              confirmLabel: "Create",
              onConfirm: () {
                if (controller.text.trim().isEmpty) return;
                _addFolders(
                  controller.text,
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

  /// Modifier / retirer l'icône d'un dossier existant.
  void _showEditIconSheet(VideoFolder folder) {
    final iconUrlController = TextEditingController(text: folder.iconUrl ?? '');
    String? iconKey = (folder.iconKey == null || folder.iconKey!.isEmpty) ? null : folder.iconKey;

    showAppSheet(
      context,
      title: "Folder icon",
      subtitle: folder.title,
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
                _col.doc(folder.id).update({
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

  /// [initialFolderId] : dossier présélectionné (null = sans dossier).
  void _showAddVideoSheet({String? initialFolderId}) {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final coverController = TextEditingController();
    final ownerController = TextEditingController();
    final detailsController = TextEditingController();
    String? selectedFolder = initialFolderId;

    showAppSheet(
      context,
      title: "Add videos",
      subtitle: "Several videos: separate with commas",
      icon: Icons.video_call_rounded,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppField(
              controller: titleController,
              label: "Video title",
              icon: Icons.title_rounded,
            ),
            const SizedBox(height: 12),
            AppField(
              controller: urlController,
              label: "Video URL",
              icon: Icons.link_rounded,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: selectedFolder,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: "Destination",
                prefixIcon: Icon(Icons.folder_open_rounded, size: 20),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text("No folder"),
                ),
                ..._knownFolders.map(
                  (f) => DropdownMenuItem<String?>(
                    value: f.id,
                    child: Text(f.title, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) => setSheetState(() => selectedFolder = value),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "Titles and URLs must contain the same number of comma-separated values. YouTube videos get their cover automatically.",
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
                final ok = _addVideos(
                  titleController.text,
                  urlController.text,
                  selectedFolder,
                  extras: fileExtras(
                    cover: coverController.text,
                    owner: ownerController.text,
                    details: detailsController.text,
                    withDate: true,
                  ),
                );
                if (ok) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Firestore

  void _addFolders(String input, {String? iconKey, String iconUrl = ''}) {
    for (final name in input.split(',').map((e) => e.trim())) {
      if (name.isEmpty) continue;
      _col.add({
        'type': 'folder',
        'title': name,
        'items': [],
        if (iconKey != null && iconKey.isNotEmpty) 'icon': iconKey,
        if (iconUrl.isNotEmpty) 'iconUrl': iconUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Retourne false (et prévient l'utilisateur) si la saisie est invalide.
  bool _addVideos(
    String titles,
    String urls,
    String? folderId, {
    Map<String, dynamic> extras = const {},
  }) {
    final tList = titles.split(',');
    final uList = urls.split(',');
    final items = <Map<String, dynamic>>[];

    for (int i = 0; i < tList.length; i++) {
      if (i < uList.length &&
          tList[i].trim().isNotEmpty &&
          uList[i].trim().isNotEmpty) {
        items.add({'title': tList[i].trim(), 'url': uList[i].trim(), ...extras});
      }
    }

    if (items.isEmpty) {
      _snack("Please enter at least one title and one URL");
      return false;
    }

    if (folderId == null) {
      for (final item in items) {
        _col.add({
          ...item,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } else {
      _col.doc(folderId).update({'items': FieldValue.arrayUnion(items)});
    }
    _snack("${items.length} video(s) added");
    return true;
  }

  Future<void> _deleteVideo(LooseVideo video) async {
    final ok = await confirmDelete(
      context,
      title: "Delete video?",
      message: "'${video.title}' will be removed.",
    );
    if (ok) _col.doc(video.id).delete();
  }

  Future<void> _deleteItem(String folderId, Map<String, dynamic> item) async {
    final ok = await confirmDelete(
      context,
      title: "Delete video?",
      message: "'${item['title']}' will be removed from this folder.",
    );
    if (ok) {
      _col.doc(folderId).update({
        'items': FieldValue.arrayRemove([item]),
      });
    }
  }

  Future<void> _deleteFolder(VideoFolder folder) async {
    final ok = await confirmDelete(
      context,
      title: "Delete folder?",
      message:
          "'${folder.title}' and its ${folder.items.length} video(s) will be removed.",
    );
    if (ok) _col.doc(folder.id).delete();
  }

  void _renameFolder(VideoFolder folder) {
    final controller = TextEditingController(text: folder.title);
    showAppSheet(
      context,
      title: "Rename folder",
      icon: Icons.drive_file_rename_outline_rounded,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            controller: controller,
            label: "Folder name",
            icon: Icons.folder_rounded,
            autofocus: true,
          ),
          const SizedBox(height: 20),
          SheetActions(
            confirmLabel: "Save",
            onConfirm: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              _col.doc(folder.id).update({'title': name});
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Sous-dossiers

  DocumentReference<Map<String, dynamic>> _folderRef(String folderId) =>
      _col.doc(folderId);

  void _editFileExtras(String folderId, Map file, {String? subFolder}) {
    showEditExtrasSheet(
      context,
      fileTitle: (file['title'] ?? '').toString(),
      current: file,
      onSave: (values) => SubFolders.updateFileExtras(
        _folderRef(folderId),
        folderTitle: subFolder,
        file: file,
        values: values,
      ),
    );
  }

  void _showAddSubFolderSheet(String folderId) {
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
                  _folderRef(folderId),
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
  void _showEditSubFolderIconSheet(String folderId, String title, Map<String, dynamic> item) {
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
                  _folderRef(folderId),
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

  void _showAddToSubFolderSheet(String folderId, String subTitle) {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final coverController = TextEditingController();
    final ownerController = TextEditingController();
    final detailsController = TextEditingController();
    showAppSheet(
      context,
      title: "Add videos",
      subtitle: "In sub-folder: $subTitle",
      icon: Icons.video_call_rounded,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            controller: titleController,
            label: "Video title",
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 12),
          AppField(
            controller: urlController,
            label: "Video URL",
            icon: Icons.link_rounded,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          const Text(
            "Several videos: separate titles and URLs with commas.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          FileExtrasFields(
            cover: coverController,
            owner: ownerController,
            details: detailsController,
          ),
          const SizedBox(height: 16),
          SheetActions(
            confirmLabel: "Add",
            onConfirm: () {
              final tList = titleController.text.split(',');
              final uList = urlController.text.split(',');
              final files = <Map<String, dynamic>>[];
              for (int i = 0; i < tList.length; i++) {
                if (i < uList.length &&
                    tList[i].trim().isNotEmpty &&
                    uList[i].trim().isNotEmpty) {
                  files.add({
                    'title': tList[i].trim(),
                    'url': uList[i].trim(),
                    ...fileExtras(
                      cover: coverController.text,
                      owner: ownerController.text,
                      details: detailsController.text,
                      withDate: true,
                    ),
                  });
                }
              }
              if (files.isEmpty) {
                _snack("Please enter at least one title and one URL");
                return;
              }
              SubFolders.addFiles(_folderRef(folderId), subTitle, files);
              Navigator.pop(ctx);
              _snack("${files.length} video(s) added");
            },
          ),
        ],
      ),
    );
  }

  void _showRenameSubFolderSheet(String folderId, String oldTitle) {
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
              SubFolders.renameFolder(_folderRef(folderId), oldTitle, name);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubFolder(String folderId, String title) async {
    final ok = await confirmDelete(
      context,
      title: "Delete sub-folder?",
      message: "'$title' and its videos will be removed.",
    );
    if (ok) SubFolders.removeFolder(_folderRef(folderId), title);
  }

  Future<void> _deleteSubItem(String folderId, String subTitle, Map file) async {
    final ok = await confirmDelete(
      context,
      title: "Delete video?",
      message: "'${file['title']}' will be removed from this sub-folder.",
    );
    if (ok) SubFolders.removeFile(_folderRef(folderId), subTitle, file);
  }

  Widget _buildSubFolder(VideoFolder folder, Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final title = (item['title'] ?? '').toString();
    final files = ((item['items'] as List?) ?? const []).whereType<Map>().toList();

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('vs_${folder.id}_$title'),
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
          "${files.length} video(s)",
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
              onTap: () => _openPlayer(
                (file['url'] ?? '').toString(),
                (file['title'] ?? '').toString(),
              ),
              leading: FileLeading(
                cover: (file['cover'] ?? '').toString(),
                url: (file['url'] ?? '').toString(),
                icon: Icons.play_circle_fill_rounded,
              ),
              title: Text(
                (file['title'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: theme.listTileTheme.textColor,
                ),
              ),
              trailing: FileTrailing(
                onEdit: () => _editFileExtras(folder.id, file, subFolder: title),
                onDelete: () => _deleteSubItem(folder.id, title, file),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 8, 6),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _showAddToSubFolderSheet(folder.id, title),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text("Add videos"),
                ),
                TextButton.icon(
                  onPressed: () => _showRenameSubFolderSheet(folder.id, title),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text("Rename"),
                ),
                TextButton.icon(
                  onPressed: () => _showEditSubFolderIconSheet(folder.id, title, item),
                  icon: const Icon(Icons.image_rounded, size: 18),
                  label: const Text("Icon"),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  onPressed: () => _deleteSubFolder(folder.id, title),
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

  void _openPlayer(String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(url: url, title: title),
      ),
    );
  }

  // -------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: !isSearching
            ? Text(widget.isPremium ? "Premium Video" : "General Video")
            : AppBarSearchField(
                controller: searchController,
                hint: "Search videos or folders...",
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMenu,
        icon: const Icon(Icons.add_rounded),
        label: const Text("Add"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _col.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline_rounded,
              title: "Error loading videos",
              message: "Check your connection and try again.",
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Catalogue complet (pour la liste des destinations) + filtré.
          _knownFolders = VideoCatalog.fromSnapshot(snapshot.data!).folders;
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
              title: searchQuery.isEmpty ? "No videos yet" : "No result",
              message: searchQuery.isEmpty
                  ? "Tap “Add” to create a folder or add videos."
                  : "Try another keyword.",
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              BrandHeader(
                icon: widget.isPremium
                    ? Icons.workspace_premium_rounded
                    : Icons.video_library_rounded,
                title: widget.isPremium ? "Premium library" : "General library",
                subtitle:
                    "${catalog.folders.length} folder(s) · ${catalog.totalVideos} video(s)",
              ),
              SortBar(
                value: _sort,
                onChanged: (m) => setState(() => _sort = m),
                allowCount: folders.isNotEmpty,
                trailing: "${catalog.totalVideos} video(s)",
              ),
              if (folders.isNotEmpty) ...[
                SectionTitle(
                  "Folders",
                  count: folders.length,
                  icon: Icons.folder_rounded,
                ),
                ...folders.map(_buildFolderCard),
              ],
              if (loose.isNotEmpty) ...[
                SectionTitle(
                  "No folder",
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
            key: PageStorageKey('vf_${folder.id}_$searching'),
            initiallyExpanded: searching,
            tilePadding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
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
              "${SubFolders.countFiles(folder.items)} video(s)",
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
            children: [
              if (folder.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    "This folder is empty",
                    style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                  ),
                ),
              ...folder.items.map((item) => _buildFolderItem(folder, item)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showAddVideoSheet(initialFolderId: folder.id),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text("Add videos"),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddSubFolderSheet(folder.id),
                      icon: const Icon(Icons.create_new_folder_rounded, size: 18),
                      label: const Text("Sub-folder"),
                    ),
                    TextButton.icon(
                      onPressed: () => _renameFolder(folder),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text("Rename"),
                    ),
                    TextButton.icon(
                      onPressed: () => _showEditIconSheet(folder),
                      icon: const Icon(Icons.image_rounded, size: 18),
                      label: const Text("Icon"),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      onPressed: () => _deleteFolder(folder),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text("Delete"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderItem(VideoFolder folder, Map<String, dynamic> item) {
    if (SubFolders.isFolder(item)) return _buildSubFolder(folder, item);
    final theme = Theme.of(context);
    final title = (item['title'] ?? '').toString();
    final url = (item['url'] ?? '').toString();

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 22, right: 6),
      onTap: () => _openPlayer(url, title),
      leading: FileLeading(
        cover: (item['cover'] ?? '').toString(),
        url: url,
        icon: Icons.play_circle_fill_rounded,
      ),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: theme.listTileTheme.textColor,
        ),
      ),
      trailing: FileTrailing(
        onEdit: () => _editFileExtras(folder.id, item),
        onDelete: () => _deleteItem(folder.id, item),
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
          contentPadding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
          leading: FileLeading(
            cover: video.cover,
            url: video.url,
            icon: Icons.play_arrow_rounded,
          ),
          title: Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.listTileTheme.textColor,
            ),
          ),
          trailing: FileTrailing(
            onEdit: () => showEditExtrasSheet(
              context,
              fileTitle: video.title,
              current: {
                'cover': video.cover,
                'owner': video.owner,
                'details': video.details,
              },
              onSave: (values) => _col.doc(video.id).update(extrasUpdate(values)),
            ),
            onDelete: () => _deleteVideo(video),
          ),
        ),
      ),
    );
  }
}
