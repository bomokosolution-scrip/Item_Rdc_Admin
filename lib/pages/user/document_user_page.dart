import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc_admin/util/sorting.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';
import 'university_document_user_page.dart';

class DocumentUserPage extends StatefulWidget {
  final String categoryId;
  final String categoryTitle;

  const DocumentUserPage({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
  });

  @override
  State<DocumentUserPage> createState() => _DocumentUserPageState();
}

class _DocumentUserPageState extends State<DocumentUserPage> {
  SortMode _sort = SortMode.newest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: UniversitySearchUser(
                  categoryId: widget.categoryId,
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categories')
            .doc(widget.categoryId)
            .collection('universities')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          Map<String, dynamic> dataOf(QueryDocumentSnapshot d) =>
              (d.data() as Map<String, dynamic>?) ?? const <String, dynamic>{};

          final docs = Sorting.apply<QueryDocumentSnapshot>(
            snapshot.data!.docs,
            _sort,
            title: (d) => (dataOf(d)['name'] ?? '').toString(),
            date: (d) => Sorting.dateOf(
              dataOf(d)['createdAt'],
              pending: d.metadata.hasPendingWrites,
            ),
          );

          if (docs.isEmpty) {
            return const Center(child: Text("Aucune université trouvée"));
          }

          return Column(
            children: [
              SortBar(
                value: _sort,
                allowCount: false,
                onChanged: (m) => setState(() => _sort = m),
                trailing: "${docs.length} université(s)",
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildUniversityTile(docs[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUniversityTile(DocumentSnapshot uni) {
    final logoUrl = uni.data() != null ? (uni['logoUrl'] ?? "") : "";

    return Card(
      child: ListTile(
        leading: logoUrl.toString().isNotEmpty
            ? CircleAvatar(
                backgroundColor: Colors.grey.shade200,
                child: ClipOval(
                  child: Image.network(
                    logoUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.school),
                  ),
                ),
              )
            : const CircleAvatar(child: Icon(Icons.school)),
        title: Text(uni['name']),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversityDocumentUserPage(
                categoryId: widget.categoryId,
                universityId: uni.id,
                universityName: uni['name'],
              ),
            ),
          );
        },
      ),
    );
  }
}

class UniversitySearchUser extends SearchDelegate {
  final String categoryId;

  UniversitySearchUser({required this.categoryId});

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .doc(categoryId)
          .collection('universities')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var filtered = snapshot.data!.docs.where((doc) {
          return doc['name'].toString().toLowerCase().contains(query.toLowerCase());
        }).toList();

        if (filtered.isEmpty) return const Center(child: Text("Aucune université trouvée"));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final uni = filtered[index];
            final logoUrl = uni['logoUrl'] ?? "";

            return Card(
              child: ListTile(
                leading: logoUrl.toString().isNotEmpty
                    ? CircleAvatar(
                        backgroundColor: Colors.grey.shade200,
                        child: ClipOval(
                          child: Image.network(
                            logoUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.school),
                          ),
                        ),
                      )
                    : const CircleAvatar(child: Icon(Icons.school)),
                title: Text(uni['name']),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}
