part of "user_bloc.dart";
abstract class UserEvents extends Equatable {
  const UserEvents();
  @override
  List<Object?> get props => [];
}

class LoadUsers extends UserEvents {}

class SearchUser extends UserEvents {
  final String query;
  const SearchUser(this.query);
  @override
  List<Object?> get props => [query];
}
