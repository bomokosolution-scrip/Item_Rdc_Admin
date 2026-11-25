import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
part 'video_events.dart';
part 'video_state.dart';

class VideoBloc extends Bloc<VideoEvents, VideoState> {
  VideoBloc() : super(const VideoState()) {
    on<LoadVideo>(_onLoadVideo);
    on<AddVideo>(_onAddVideos);
    on<RemoveVideo>(_onRemoveVideos);
  }

  Future<void> _onLoadVideo(LoadVideo event, Emitter<VideoState> emit) async {
    await emit.forEach<QuerySnapshot<Map<String, dynamic>>>(
      FirebaseFirestore.instance
          .collection(event.path)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      onData: (snapshot) {
        final List<Map<String, String>> videos = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title']?.toString() ?? '',
            'url': data['url']?.toString() ?? '',
          };
        }).toList();
        return state.copyWith(videos: videos);
      },
      onError: (error, stackTrace) => state, 
    );
  }

  Future<void> _onAddVideos(AddVideo event, Emitter<VideoState> emit) async {
    List<String> tList = event.names.split(',');
    List<String> uList = event.urls.split(',');

    for (int i = 0; i < tList.length; i++) {
      if (i < uList.length && tList[i].trim().isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection(event.path).add({
            'title': tList[i].trim(),
            'url': uList[i].trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
         // print("Error adding video: $e");
        }
      }
    }
  }

  Future<void> _onRemoveVideos(RemoveVideo event, Emitter<VideoState> emit) async {
    try {
      await FirebaseFirestore.instance
          .collection(event.path)
          .doc(event.docId)
          .delete();
    } catch (e) {
   //   print("Error deleting video: $e");
    }
  }
}
