import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc_admin/util/sorting.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';
import 'document_user_page.dart';

class LibraryUserPage extends StatefulWidget {
  const LibraryUserPage({super.key});

  @override
  State<LibraryUserPage> createState() => _LibraryUserPageState();
}

class _LibraryUserPageState extends State<LibraryUserPage> {
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  bool isSearching = false;
  SortMode _sort = SortMode.newest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: !isSearching
            ? const Text("Bibliothèque")
            : TextField(
                controller: searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Rechercher une catégorie...",
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
            
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

          if (docs.isEmpty)
            return const Center(child: Text("Aucune catégorie trouvée"));

          return Column(
            children: [
              SortBar(
                value: _sort,
                allowCount: false,
                onChanged: (m) => setState(() => _sort = m),
                trailing: "${docs.length} catégorie(s)",
              ),
              Expanded(child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              final docTitle = (dataOf(doc)['title'] ?? '').toString();
              return Card(
                child: ListTile(
                  title: Text(docTitle),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocumentUserPage(
                          categoryId: doc.id,
                          categoryTitle: docTitle,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          )),
            ],
          );
        },
      ),
    );
  }
}
