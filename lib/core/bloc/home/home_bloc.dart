import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:bloc/bloc.dart';
import '../../../util/status.dart';
part "home_events.dart";
part "home_state.dart";
class HomeBloc extends Bloc<HomeEvents,HomeState> {
  HomeBloc():super(const HomeState()){
    on<LoadData>(_loadData);
    on<AddFolderInFirebase>(_addFolderInFirebase);
    on<AddItemsInFolder>(_addItemsInFolder);
    on<DeleteFolder>(_deleteFolder);
    on<DeleteItem>(_deleteItem);
    on<ListenFolders>(_listenFolders);      
}

void _loadData(LoadData event,Emitter<HomeState> emit)async{

    emit(state.copyWith(status: Status.loading));
    final snapshot = await FirebaseFirestore.instance.collection(event.path).get();
    final data = snapshot.docs.map((e)=>e.data()).toList();
    emit(state.copyWith(folders: List<Map<String,dynamic>>.from(data),status: .success));
  }
  void _addFolderInFirebase(AddFolderInFirebase event,Emitter<HomeState> emit) async{
    var folders = event.names.split(",").map((e)=>e.trim()).toList();
    for(var folder in folders){
      if(folder.isNotEmpty){
        try{
        await FirebaseFirestore.instance.collection(event.path).add({
          "title":folder,
          "items":[]
        });
        }catch(error){
         // New dart shorthand oparetor ".".
          emit(state.copyWith(message: error.toString(),status:.fail));
        }
      }
    }
  }
  void _addItemsInFolder(AddItemsInFolder event,Emitter<HomeState> emit)async {
    var names = event.names.split(",").map((e)=>e.trim()).toList();
    var urls = event.urls.split(",").map((e)=>e.trim()).toList();
    if(names.length != urls.length){
      emit(state.copyWith(message: "Names and url should equal",status: .fail));
      return;
    }
    List<Map<String,dynamic>> items = [];
    for(int i =0; i <names.length;i++){
      items.add({
        "title":names[i],
        "url":urls[i]
      });
    }
    try{
    await FirebaseFirestore.instance.collection(event.path)
    .doc(event.docId)
    .update({
      "items":FieldValue.arrayUnion(items)
    });
    }catch(error){
      emit(state.copyWith(message: error.toString(),status: .fail));
    }
  }
  void _deleteFolder(DeleteFolder event,Emitter<HomeState> emit)async{
    try{
      await FirebaseFirestore.instance.collection(event.path).doc(event.docId).delete();
    }
    catch(error){
      emit(state.copyWith(message: error.toString(),status: .fail));
    }
  }
  void _deleteItem(DeleteItem event,Emitter<HomeState> emit){
    try{
      FirebaseFirestore.instance.collection(event.path).doc(event.docId).update({
        "items": FieldValue.arrayRemove([event.item])
      });
    }catch(error){
      emit(state.copyWith(message: error.toString(),status: .fail));
    }
  }
  Future<void> _listenFolders(ListenFolders event, Emitter<HomeState> emit) async {
    await emit.forEach<QuerySnapshot<Map<String, dynamic>>>(
      FirebaseFirestore.instance.collection(event.path).snapshots(),
      onData: (snapshot) {
        final data = snapshot.docs.map((e) {
          final map = Map<String, dynamic>.from(e.data());
          map['id'] = e.id;
          return map;
        }).toList();
        return state.copyWith(folders: data, status: Status.success);
      },
      onError: (error, stackTrace) => state.copyWith(
        message: error.toString(),
        status: Status.fail,
      ),
    );
  }
  
}

















