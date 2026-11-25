part of "entry_bloc.dart";

class EntryEvents extends Equatable {
  @override
  List<Object?> get props => [];
}

// class HomeRoute extends EntryEvents{}
// class VideoRoute extends EntryEvents{}
// class UserRoute extends EntryEvents{}
class ChangeSection extends EntryEvents {}

class ChangeMode extends EntryEvents {}

class UpdateUserInfo extends EntryEvents {}

class InputChageListener extends EntryEvents {
  final String? uid;
  final int? year, month, day;
  InputChageListener({this.uid, this.year, this.month, this.day});
  @override
  List<Object?> get props => [uid, year, month, day];
}
