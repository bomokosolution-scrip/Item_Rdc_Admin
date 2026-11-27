import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:item_rdc_admin/pages/home_page.dart'; // PdfViewer
import 'package:item_rdc_admin/theme_manager.dart';
import 'package:item_rdc_admin/util/sorting.dart';
import 'package:item_rdc_admin/util/sub_folders.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';
import 'package:item_rdc_admin/widgets/image_import.dart';

/// Validation des ouvrages publiés par les utilisateurs (TFC, Mémoire, Stage).
class PublicationsAdminPage extends StatefulWidget {
  const PublicationsAdminPage({super.key});

  @override
  State<PublicationsAdminPage> createState() => _PublicationsAdminPageState();
}

class _PublicationsAdminPageState extends State<PublicationsAdminPage> {
  final _db = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _col = _db.collection('publications');
  late final DocumentReference<Map<String, dynamic>> _settings =
      _db.collection('settings').doc('publishing');
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _col.snapshots();

  String _filter = 'pending';
  SortMode _sort = SortMode.newest;

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  /// « TFC · 2025-2026 · Catégorie › Université » ou « Document · Dossier › Sous-dossier ».
  String _where(Map<String, dynamic> d) {
    final year = '${d['academicYear'] ?? ''}'.trim();
    final head = ['${d['type'] ?? ''}', if (year.isNotEmpty) year].join(' · ');
    if ('${d['kind'] ?? 'work'}' == 'document') {
      final sub = '${d['subFolderTitle'] ?? ''}'.trim();
      final space = '${d['space'] ?? ''}' == 'PREMIUM' ? 'Premium' : 'General';
      return '$head · $space › ${d['folderTitle'] ?? ''}${sub.isEmpty ? '' : ' › $sub'}';
    }
    return '$head · ${d['categoryTitle'] ?? ''} › ${d['universityName'] ?? ''}';
  }

  /// Un « Document » est rangé dans le dossier (ou sous-dossier) choisi.
  Future<void> _acceptDocument(QueryDocumentSnapshot<Map<String, dynamic>> pub) async {
    final d = pub.data();
    final col = '${d['space'] ?? ''}' == 'PREMIUM' ? 'PREMIUM_HOME' : 'GENERAL_HOME';
    final folderId = '${d['folderId'] ?? ''}';
    final sub = '${d['subFolderTitle'] ?? ''}'.trim();
    if (folderId.isEmpty) {
      _snack("Folder missing.");
      return;
    }
    try {
      final ref = _db.collection(col).doc(folderId);
      final snap = await ref.get();
      if (!snap.exists) {
        _snack("This folder no longer exists. Refuse or ask the user to resend.");
        return;
      }
      final items = (snap.data()?['items'] as List?) ?? const [];
      if (sub.isNotEmpty &&
          !items.any((e) => e is Map && SubFolders.isFolder(e) && e['title'] == sub)) {
        _snack("This sub-folder no longer exists.");
        return;
      }
      final item = <String, dynamic>{
        'title': '${d['title'] ?? ''}',
        'url': '${d['fileUrl'] ?? ''}',
        'owner': '${d['ownerName'] ?? ''}',
        if ('${d['uid'] ?? ''}'.isNotEmpty) 'ownerUid': '${d['uid']}',
        if ('${d['details'] ?? ''}'.trim().isNotEmpty) 'details': '${d['details']}',
        if ('${d['coverUrl'] ?? ''}'.trim().isNotEmpty) 'cover': '${d['coverUrl']}',
        if ('${d['academicYear'] ?? ''}'.trim().isNotEmpty) 'academicYear': '${d['academicYear']}',
        'publicationId': pub.id,
        'createdAt': Timestamp.now(),
      };
      if (sub.isEmpty) {
        await ref.update({'items': FieldValue.arrayUnion([item])});
      } else {
        await SubFolders.addFiles(ref, sub, [item]);
      }
      await pub.reference.update({
        'status': 'approved',
        'reason': '',
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      _snack("Published ✓");
    } catch (e) {
      _snack("Could not publish: $e");
    }
  }

  Future<void> _accept(QueryDocumentSnapshot<Map<String, dynamic>> pub) async {
    final d = pub.data();
    if ('${d['kind'] ?? 'work'}' == 'document') return _acceptDocument(pub);
    final catId = '${d['categoryId'] ?? ''}';
    final uniId = '${d['universityId'] ?? ''}';
    if (catId.isEmpty || uniId.isEmpty) {
      _snack("Catégorie ou université manquante.");
      return;
    }
    try {
      final docRef = _db
          .collection('categories')
          .doc(catId)
          .collection('universities')
          .doc(uniId)
          .collection('documents')
          .doc();
      final batch = _db.batch();
      batch.set(docRef, {
        'title': '${d['title'] ?? ''}',
        'url': '${d['fileUrl'] ?? ''}',
        'type': '${d['type'] ?? ''}',
        'isAll': false,
        if ('${d['academicYear'] ?? ''}'.trim().isNotEmpty) 'academicYear': '${d['academicYear']}',
        'owner': '${d['ownerName'] ?? ''}',
        if ('${d['uid'] ?? ''}'.isNotEmpty) 'ownerUid': '${d['uid']}',
        if ('${d['details'] ?? ''}'.trim().isNotEmpty) 'details': '${d['details']}',
        if ('${d['coverUrl'] ?? ''}'.trim().isNotEmpty) 'cover': '${d['coverUrl']}',
        'publicationId': pub.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(pub.reference, {
        'status': 'approved',
        'reason': '',
        'publishedDocId': docRef.id,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      _snack("Published ✓");
    } catch (e) {
      _snack("Could not publish: $e");
    }
  }

  void _refuse(QueryDocumentSnapshot<Map<String, dynamic>> pub) {
    final reason = TextEditingController();
    showAppSheet(
      context,
      title: "Refuse this work",
      subtitle: '${pub.data()['title'] ?? ''}',
      icon: Icons.cancel_rounded,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            controller: reason,
            label: "Reason (shown to the user)",
            icon: Icons.notes_rounded,
            maxLines: 3,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          SheetActions(
            confirmLabel: "Refuse",
            onConfirm: () async {
              Navigator.pop(ctx);
              try {
                await pub.reference.update({
                  'status': 'refused',
                  'reason': reason.text.trim(),
                  'reviewedAt': FieldValue.serverTimestamp(),
                });
              } catch (e) {
                _snack("Could not save: $e");
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _delete(QueryDocumentSnapshot<Map<String, dynamic>> pub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete this entry?"),
        content: const Text(
          "Only the request is deleted. A work already published stays in the library.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
        ],
      ),
    );
    if (ok == true) await pub.reference.delete();
  }

  Widget _statusChip(String status, String reason) {
    final Color c;
    final String label;
    switch (status) {
      case 'approved':
        c = const Color(0xFF2E9E5B);
        label = 'Published';
        break;
      case 'refused':
        c = const Color(0xFFC62828);
        label = 'Refused';
        break;
      default:
        c = const Color(0xFFE08A00);
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: c)),
    );
  }

  Widget _card(QueryDocumentSnapshot<Map<String, dynamic>> pub) {
    final theme = Theme.of(context);
    final d = pub.data();
    final status = '${d['status'] ?? 'pending'}';
    final date = Sorting.dateOf(d['createdAt'], pending: pub.metadata.hasPendingWrites);
    final muted = theme.textTheme.bodyMedium?.color;
    final reason = '${d['reason'] ?? ''}'.trim();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FileLeading(
                  cover: '${d['coverUrl'] ?? ''}',
                  url: '',
                  icon: Icons.picture_as_pdf_rounded,
                  size: 58,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d['title'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'By ${d['ownerName'] ?? '—'}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _where(d),
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      if (date != null)
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(date),
                          style: TextStyle(fontSize: 11.5, color: muted),
                        ),
                    ],
                  ),
                ),
                _statusChip(status, reason),
              ],
            ),
            if ('${d['details'] ?? ''}'.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${d['details']}', style: TextStyle(fontSize: 12.5, color: muted)),
              ),
            if (status == 'refused' && reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Reason: $reason', style: TextStyle(fontSize: 12.5, color: muted)),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfViewer(
                        url: '${d['fileUrl'] ?? ''}',
                        title: '${d['title'] ?? ''}',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text("Open PDF"),
                ),
                if (status == 'pending') ...[
                  FilledButton.icon(
                    onPressed: () => _accept(pub),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text("Accept"),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _refuse(pub),
                    icon: Icon(Icons.close_rounded, size: 18, color: theme.colorScheme.error),
                    label: Text("Refuse", style: TextStyle(color: theme.colorScheme.error)),
                  ),
                ] else
                  TextButton.icon(
                    onPressed: () => _delete(pub),
                    icon: Icon(Icons.delete_outline_rounded, size: 18, color: theme.colorScheme.error),
                    label: Text("Delete", style: TextStyle(color: theme.colorScheme.error)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchCard() {
    final accent = AppColors.accent(context);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _settings.snapshots(),
      builder: (context, snap) {
        final on = snap.data?.data()?['enabled'] == true;
        return Card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: SwitchListTile(
            value: on,
            activeThumbColor: accent,
            title: const Text("Accept new publications", style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              on
                  ? "Users can submit works from the Library tab."
                  : "Closed: users see « Bientôt » and cannot submit.",
            ),
            secondary: Icon(on ? Icons.lock_open_rounded : Icons.lock_rounded, color: accent),
            onChanged: (v) => _settings.set({
              'enabled': v,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Publications")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text("Error: ${snap.error}"));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final all = snap.data!.docs;
          int count(String s) => all.where((d) => (d.data()['status'] ?? 'pending') == s).length;

          final shown = Sorting.apply<QueryDocumentSnapshot<Map<String, dynamic>>>(
            all.where((d) => (d.data()['status'] ?? 'pending') == _filter),
            _sort,
            title: (d) => '${d.data()['title'] ?? ''}',
            date: (d) => Sorting.dateOf(d.data()['createdAt'], pending: d.metadata.hasPendingWrites),
          );

          Widget chip(String key, String label) => ChoiceChip(
            label: Text('$label (${count(key)})'),
            selected: _filter == key,
            onSelected: (_) => setState(() => _filter = key),
          );

          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              _switchCard(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    chip('pending', 'Pending'),
                    chip('approved', 'Published'),
                    chip('refused', 'Refused'),
                  ],
                ),
              ),
              SortBar(
                value: _sort,
                allowCount: false,
                onChanged: (m) => setState(() => _sort = m),
                trailing: "${shown.length} work(s)",
              ),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.inbox_rounded,
                    title: "Nothing here",
                    message: "Submitted works appear in this list.",
                  ),
                ),
              for (final p in shown) _card(p),
            ],
          );
        },
      ),
    );
  }
}
