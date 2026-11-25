part of "entry_bloc.dart";

class EntryState extends Equatable {
  final bool isInHomeSection, isLightMode;
  final String uid, message;
  final int year, month, day;
  final Status status;
  const EntryState({
    this.isInHomeSection = true,
    this.isLightMode = true,
    this.uid = "",
    this.message = "",
    this.year = 0,
    this.month = 0,
    this.day = 0,
    this.status = Status.initial,
  });
  EntryState copyWith({
    bool? isInHomeSection,
    bool? isLightMode,
    String? uid,
    String? message,
    int? year,
    int? month,
    int? day,
    Status? status,
  }) => EntryState(
    isInHomeSection: isInHomeSection ?? this.isInHomeSection,
    isLightMode: isLightMode ?? this.isLightMode,
    uid: uid ?? this.uid,
    message: message ?? this.message,
    year: year ?? this.year,
    month: month ?? this.month,
    day: day ?? this.day,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => [
    isInHomeSection,
    isLightMode,
    uid,
    message,
    year,
    month,
    day,
    status,
  ];
}
