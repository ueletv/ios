import 'package:videoweb_flutter/api/api_parse.dart';

/// 主播模型（对应原生 Streamer.kt）
class Streamer {
  final String? id;
  final String? name;
  final String? vodName;
  final String? cover;
  final String? vodPic;
  final String? playUrl;
  final dynamic vodPlayUrl; // 可能为数组或字符串
  final int? onlineCount;
  final int? viewCount;
  final int? likeCount;
  final int? sort;
  final String? createdAt;
  final String? updatedAt;
  final bool? isLive;
  final bool? isLiked;
  final bool? isFavorited;
  final StreamerCaipiaoInfo? caipiaoInfo;
  final dynamic caipiao; // 彩票信息
  final dynamic category; // 分类信息

  Streamer({
    this.id,
    this.name,
    this.vodName,
    this.cover,
    this.vodPic,
    this.playUrl,
    this.vodPlayUrl,
    this.onlineCount,
    this.viewCount,
    this.likeCount,
    this.sort,
    this.createdAt,
    this.updatedAt,
    this.isLive,
    this.isLiked,
    this.isFavorited,
    this.caipiaoInfo,
    this.caipiao,
    this.category,
  });

  /// 获取播放地址
  String? get resolvedPlayUrl {
    if (playUrl != null && playUrl!.isNotEmpty) return playUrl;
    if (vodPlayUrl is List) {
      final list = vodPlayUrl as List;
      if (list.isNotEmpty && list[0] is Map) {
        return (list[0] as Map)['url'] as String?;
      }
    }
    if (vodPlayUrl is String && (vodPlayUrl as String).isNotEmpty) {
      return vodPlayUrl as String;
    }
    return null;
  }

  /// 获取封面图
  String? get resolvedCover => (vodPic?.isNotEmpty == true) ? vodPic : cover;

  /// 获取显示名称
  String get displayName =>
      (vodName?.isNotEmpty == true) ? vodName! : (name ?? '');

  factory Streamer.fromJson(Map<String, dynamic> json) {
    StreamerCaipiaoInfo? cpInfo;
    if (json['caipiao_info'] is Map) {
      cpInfo = StreamerCaipiaoInfo.fromJson(
        Map<String, dynamic>.from(json['caipiao_info'] as Map),
      );
    } else if (json['caipiao'] is Map) {
      cpInfo = StreamerCaipiaoInfo.fromJson(
        Map<String, dynamic>.from(json['caipiao'] as Map),
      );
    }

    return Streamer(
      id: json['id']?.toString(),
      name: json['name'] as String?,
      vodName: json['vod_name'] as String?,
      cover: json['cover'] as String?,
      vodPic: json['vod_pic'] as String?,
      playUrl: json['play_url'] as String?,
      vodPlayUrl: json['vod_play_url'],
      onlineCount: ApiParse.asInt(json['online_count']) ??
          ApiParse.asInt(json['view_count']),
      viewCount: ApiParse.asInt(json['view_count']),
      likeCount: ApiParse.asInt(json['like_count']),
      sort: ApiParse.asInt(json['sort']),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      isLive: json['is_live'] as bool? ?? true,
      isLiked: json['is_liked'] as bool?,
      isFavorited: json['is_favorited'] as bool?,
      caipiaoInfo: cpInfo,
      caipiao: json['caipiao'],
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'vod_name': vodName,
      'cover': cover,
      'vod_pic': vodPic,
      'play_url': playUrl,
      'vod_play_url': vodPlayUrl,
      'online_count': onlineCount,
      'view_count': viewCount,
      'like_count': likeCount,
      'sort': sort,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_live': isLive,
      'is_liked': isLiked,
      'is_favorited': isFavorited,
      'caipiao_info': caipiaoInfo?.toJson(),
      'caipiao': caipiao,
      'category': category,
    };
  }
}

/// 主播关联的彩票信息
class StreamerCaipiaoInfo {
  final int id;
  final String? nameZh;
  final String? biaoshi;
  final String? icon;

  StreamerCaipiaoInfo({
    required this.id,
    this.nameZh,
    this.biaoshi,
    this.icon,
  });

  factory StreamerCaipiaoInfo.fromJson(Map<String, dynamic> json) {
    return StreamerCaipiaoInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nameZh: json['name_zh'] as String?,
      biaoshi: json['biaoshi'] as String?,
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_zh': nameZh,
      'biaoshi': biaoshi,
      'icon': icon,
    };
  }
}
