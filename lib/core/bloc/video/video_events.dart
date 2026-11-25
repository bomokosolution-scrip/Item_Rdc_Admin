part of "video_bloc.dart";
abstract class VideoEvents extends Equatable {
  
  const VideoEvents();
    @override
  List<Object?> get props => [];
}
class AddVideo extends VideoEvents{
  final String names,urls,path;
  const AddVideo(this.path,this.names,this.urls);
  @override
  List<Object?> get props => [path,names,urls];

}
class RemoveVideo extends VideoEvents{
  final String path,docId;
  const RemoveVideo(this.path,this.docId);
  
}
class LoadVideo extends VideoEvents {
  final String path;
  const LoadVideo(this.path);
  @override
  List<Object?> get props => [path];
}

class ListendVideo extends VideoEvents{
  final List<Map<String,String>> videos;
  const ListendVideo({this.videos = const []});
    @override
  List<Object?> get props => [videos];

}













