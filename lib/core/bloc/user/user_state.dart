part of "user_bloc.dart";

class UserState extends Equatable {
  final List<Map<String, dynamic>> users;
  final String searchQuery;
  final bool isLoading;

  const UserState({
    this.users = const [],
    this.searchQuery = "",
    this.isLoading = false,
  });

  UserState copyWith({
    List<Map<String, dynamic>>? users,
    String? searchQuery,
    bool? isLoading,
  }) {
    return UserState(
      users: users ?? this.users,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [users, searchQuery, isLoading];
}
