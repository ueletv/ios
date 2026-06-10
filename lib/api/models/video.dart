/// 视频分类模型（对应 VideoCategory.kt）
class VideoCategory {
  final dynamic id;
  final String? name;
  final String? icon;
  final String? avatar;
  final dynamic parentId;
  final dynamic typeId;
  final int? sort;

  VideoCategory({
    this.id,
    this.name,
    this.icon,
    this.avatar,
    this.parentId,
    this.typeId,
    this.sort,
  });

  factory VideoCategory.fromJson(Map<String, dynamic> json) {
    return VideoCategory(
      id: json['id'],
      name: json['name'] as String?,
      icon: json['icon'] as String?,
      avatar: json['avatar'] as String?,
      parentId: json['parent_id'],
      typeId: json['type_id'],
      sort: (json['sort'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'avatar': avatar,
    'parent_id': parentId,
    'type_id': typeId,
    'sort': sort,
  };
}

/// 视频模型（对应 Video.kt）
class Video {
  final dynamic id;
  final String? vodName;
  final String? vodPic;
  final int? vodPicWidth;
  final int? vodPicHeight;
  final dynamic vodPlayUrl;
  final String? vodContent;
  final VideoCategory? category;
  final dynamic categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final int? likeCount;
  final int? commentCount;
  final int? favoriteCount;
  final int? shareCount;
  final dynamic isLiked;
  final dynamic isFavorited;
  final bool? hasAccess;
  final bool? needVip;
  final int? videoTrialSeconds;
  final int? viewCount;
  final int? duration;
  final String? createdAt;
  final String? updatedAt;
  // 广告混入字段
  final String? type;
  final dynamic adId;
  final String? adTitle;
  final String? adCover;
  final String? adLinkType;
  final String? adLinkUrl;
  final dynamic adLinkId;
  final String? link;

  Video({
    this.id,
    this.vodName,
    this.vodPic,
    this.vodPicWidth,
    this.vodPicHeight,
    this.vodPlayUrl,
    this.vodContent,
    this.category,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.likeCount,
    this.commentCount,
    this.favoriteCount,
    this.shareCount,
    this.isLiked,
    this.isFavorited,
    this.hasAccess,
    this.needVip,
    this.videoTrialSeconds,
    this.viewCount,
    this.duration,
    this.createdAt,
    this.updatedAt,
    this.type,
    this.adId,
    this.adTitle,
    this.adCover,
    this.adLinkType,
    this.adLinkUrl,
    this.adLinkId,
    this.link,
  });

  /// 获取播放地址
  String? get resolvedPlayUrl {
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

  /// 是否为广告混入项
  bool get isAd => type == 'ad' || adId != null;

  String get displayName => vodName ?? '';

  Video copyWith({
    dynamic id,
    String? vodName,
    String? vodPic,
    int? vodPicWidth,
    int? vodPicHeight,
    dynamic vodPlayUrl,
    String? vodContent,
    VideoCategory? category,
    dynamic categoryId,
    String? categoryName,
    String? categoryIcon,
    int? likeCount,
    int? commentCount,
    int? favoriteCount,
    int? shareCount,
    dynamic isLiked,
    dynamic isFavorited,
    bool? hasAccess,
    bool? needVip,
    int? videoTrialSeconds,
    int? viewCount,
    int? duration,
    String? createdAt,
    String? updatedAt,
    String? type,
    dynamic adId,
    String? adTitle,
    String? adCover,
    String? adLinkType,
    String? adLinkUrl,
    dynamic adLinkId,
    String? link,
  }) {
    return Video(
      id: id ?? this.id,
      vodName: vodName ?? this.vodName,
      vodPic: vodPic ?? this.vodPic,
      vodPicWidth: vodPicWidth ?? this.vodPicWidth,
      vodPicHeight: vodPicHeight ?? this.vodPicHeight,
      vodPlayUrl: vodPlayUrl ?? this.vodPlayUrl,
      vodContent: vodContent ?? this.vodContent,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      shareCount: shareCount ?? this.shareCount,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      hasAccess: hasAccess ?? this.hasAccess,
      needVip: needVip ?? this.needVip,
      videoTrialSeconds: videoTrialSeconds ?? this.videoTrialSeconds,
      viewCount: viewCount ?? this.viewCount,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      adId: adId ?? this.adId,
      adTitle: adTitle ?? this.adTitle,
      adCover: adCover ?? this.adCover,
      adLinkType: adLinkType ?? this.adLinkType,
      adLinkUrl: adLinkUrl ?? this.adLinkUrl,
      adLinkId: adLinkId ?? this.adLinkId,
      link: link ?? this.link,
    );
  }

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'],
      vodName: json['vod_name'] as String?,
      vodPic: json['vod_pic'] as String?,
      vodPicWidth: (json['vod_pic_width'] as num?)?.toInt(),
      vodPicHeight: (json['vod_pic_height'] as num?)?.toInt(),
      vodPlayUrl: json['vod_play_url'],
      vodContent: json['vod_content'] as String?,
      category: json['category'] != null
          ? VideoCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      categoryId: json['category_id'],
      categoryName: json['category_name'] as String?,
      categoryIcon: json['category_icon'] as String?,
      likeCount: (json['like_count'] as num?)?.toInt(),
      commentCount: (json['comment_count'] as num?)?.toInt(),
      favoriteCount: (json['favorite_count'] as num?)?.toInt(),
      shareCount: (json['share_count'] as num?)?.toInt(),
      isLiked: json['is_liked'],
      isFavorited: json['is_favorited'],
      hasAccess: json['has_access'] as bool?,
      needVip: json['need_vip'] as bool?,
      videoTrialSeconds: (json['video_trial_seconds'] as num?)?.toInt(),
      viewCount: (json['view_count'] as num?)?.toInt(),
      duration: (json['duration'] as num?)?.toInt(),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      type: json['type'] as String?,
      adId: json['ad_id'],
      adTitle: json['ad_title'] as String?,
      adCover: json['ad_cover'] as String?,
      adLinkType: json['ad_link_type'] as String?,
      adLinkUrl: json['ad_link_url'] as String?,
      adLinkId: json['ad_link_id'],
      link: json['link'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'vod_name': vodName,
    'vod_pic': vodPic,
    'vod_play_url': vodPlayUrl,
    'vod_content': vodContent,
    'category': category?.toJson(),
    'category_id': categoryId,
    'category_name': categoryName,
    'like_count': likeCount,
    'comment_count': commentCount,
    'favorite_count': favoriteCount,
    'share_count': shareCount,
    'is_liked': isLiked,
    'is_favorited': isFavorited,
    'has_access': hasAccess,
    'need_vip': needVip,
    'video_trial_seconds': videoTrialSeconds,
    'view_count': viewCount,
    'created_at': createdAt,
  };
}
