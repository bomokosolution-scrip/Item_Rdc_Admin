import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc_admin/pages/home_page.dart'; // Pour PdfViewer
import 'package:item_rdc_admin/pages/video_player_page.dart';
import 'package:item_rdc_admin/util/sorting.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';

class UniversityDocumentUserPage extends StatefulWidget {
  final String categoryId;
  final String universityId;
  final String universityName;

  const UniversityDocumentUserPage({
    super.key,
    required this.categoryId,
    required this.universityId,
    required this.universityName,
  });

  @override
  State<UniversityDocumentUserPage> createState() =>
      _UniversityDocumentUserPageState();
}

class _UniversityDocumentUserPageState
    extends State<UniversityDocumentUserPage> {
  String filterType = "All";
  SortMode _sort = SortMode.newest;
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  bool isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: !isSearching
            ? Text(widget.universityName)
            : TextField(
                controller: searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Rechercher un document...",
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => searchQuery = value.toLowerCase());
                },
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ["All", "TFC", "Mémoire", "Stage"].map((type) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(type),
                      selected: filterType == type,
                      onSelected: (_) {
                        setState(() {
                          filterType = type;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          SortBar(
            value: _sort,
            allowCount: false,
            onChanged: (m) => setState(() => _sort = m),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('categories')
                  .doc(widget.categoryId)
                  .collection('universities')
                  .doc(widget.universityId)
                  .collection('documents')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                Map<String, dynamic> dataOf(QueryDocumentSnapshot d) =>
                    (d.data() as Map<String, dynamic>?) ??
                    const <String, dynamic>{};

                var docs = snapshot.data!.docs.where((doc) {
                  final title = (dataOf(doc)['title'] ?? '').toString().toLowerCase();
                  final type = normType(dataOf(doc)['type']);
                  bool matchesType = filterType == "All"
                      ? true
                      : type == filterType;
                  bool matchesSearch = searchQuery.isEmpty
                      ? true
                      : title.contains(searchQuery);
                  return matchesType && matchesSearch;
                }).toList();

                if (filterType == "All") {
                  final seen = <String>{};
                  docs = docs.where((doc) {
                    final t = (dataOf(doc)['title'] ?? '').toString();
                    if (seen.contains(t)) return false;
                    seen.add(t);
                    return true;
                  }).toList();
                }

                docs = Sorting.apply<QueryDocumentSnapshot>(
                  docs,
                  _sort,
                  title: (d) => (dataOf(d)['title'] ?? '').toString(),
                  date: (d) => Sorting.dateOf(
                    dataOf(d)['createdAt'],
                    pending: d.metadata.hasPendingWrites,
                  ),
                );

                if (docs.isEmpty)
                  return const Center(child: Text("Aucun document trouvé"));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final dd = dataOf(doc);
                    final docUrl = (dd['url'] ?? '').toString();
                    final docTitle = (dd['title'] ?? '').toString();
                    
                    Icon _getIcon(String url) {
                      if (url.endsWith('.pdf') || url.contains('drive.google.com')) {
                        return const Icon(Icons.picture_as_pdf, color: Colors.red);
                      } else if (url.endsWith('.mp4') || url.contains('youtube.com') || url.contains('youtu.be')) {
                        return const Icon(Icons.video_library, color: Colors.blue);
                      } else {
                        return const Icon(Icons.insert_drive_file);
                      }
                    }

                    return ListTile(
                      leading: _getIcon(docUrl),
                      title: Text(docTitle),
                      subtitle: Text(normType(dd['type'])),
                      trailing: const Icon(Icons.open_in_new, size: 18, color: Colors.grey),
                      onTap: () {
                        final url = docUrl;
                        final title = docTitle;

                        if (url.endsWith('.pdf') || url.contains('drive.google.com')) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PdfViewer(url: url, title: title),
                            ),
                          );
                        } else if (url.endsWith('.mp4') || url.contains('youtube.com') || url.contains('youtu.be')) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideoPlayerPage(url: url, title: title),
                            ),
                          );
                        }
                      },
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
