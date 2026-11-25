import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
part 'user_event.dart';
part 'user_state.dart';

class UserBloc extends Bloc<UserEvents, UserState> {
  UserBloc() : super(const UserState()) {
    on<LoadUsers>(_onLoadUsers);
    on<SearchUser>(_onSearchUser);
  }

  Future<void> _onLoadUsers(LoadUsers event, Emitter<UserState> emit) async {
    emit(state.copyWith(isLoading: true));
    
    await emit.forEach<QuerySnapshot<Map<String, dynamic>>>(
      FirebaseFirestore.instance.collection('users').snapshots(),
      onData: (snapshot) {
        final users = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; 
          return data;
        }).toList();
        
        return state.copyWith(users: users, isLoading: false);
      },
      onError: (error, stackTrace) => state.copyWith(isLoading: false),
    );
  }

  void _onSearchUser(SearchUser event, Emitter<UserState> emit) {
    emit(state.copyWith(searchQuery: event.query.toLowerCase()));
  }
}
