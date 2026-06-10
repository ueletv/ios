/// 视频 ID 请求体（对应 VideoIdBody.kt）
class VideoIdBody {
  final int videoId;

  VideoIdBody({required this.videoId});

  Map<String, dynamic> toJson() => {'video_id': videoId};
}
