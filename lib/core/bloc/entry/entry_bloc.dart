import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../../util/status.dart';
import 'package:shared_preferences/shared_preferences.dart';
part 'entry_events.dart';
part 'entry_state.dart';

class EntryBloc extends Bloc<EntryEvents, EntryState> {
  EntryBloc() : super(const EntryState()) {
    on<ChangeSection>(_changeSection);
    on<ChangeMode>(_changeMode);
    on<InputChageListener>(_inputChangeListener);
    on<UpdateUserInfo>(_updateUserInformation);
  }
  void _changeSection(ChangeSection event, Emitter<EntryState> emit) {
    emit(state.copyWith(isInHomeSection: !state.isInHomeSection));
  }

  Future<void> _changeMode(ChangeMode event, Emitter<EntryState> emit) async {
    final newMode = !state.isLightMode;

    emit(state.copyWith(isLightMode: newMode));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isLightMode", newMode);
  }

  void _inputChangeListener(
    InputChageListener event,
    Emitter<EntryState> emit,
  ) {
    emit(
      state.copyWith(
        uid: event.uid,
        year: event.year,
        month: event.month,
        day: event.day,
      ),
    );
  }

  Future<void> _updateUserInformation(
    UpdateUserInfo event,
    Emitter<EntryState> emit,
  ) async {
    if (state.uid.isEmpty ||
        state.year <= 0 ||
        state.month <= 0 ||
        state.day <= 0) {
      emit(state.copyWith(message: "Field can't be empty or 0", status: .fail));
      return;
    }
    emit(state.copyWith(status: Status.loading));
    try {
      await FirebaseFirestore.instance.collection("users").doc(state.uid).set({
        "premiumBoughtTime": FieldValue.serverTimestamp(),
        "premiumExpiryTime": DateTime(state.year, state.month, state.day),
      }, SetOptions(merge: true));
      emit(
        state.copyWith(
          status: Status.success,
          message: "successfully update premium user ",
        ),
      );
    } catch (error) {
      emit(state.copyWith(status: Status.fail, message: error.toString()));
    }
  }
}
