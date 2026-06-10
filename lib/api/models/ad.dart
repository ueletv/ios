import 'package:videoweb_flutter/api/api_parse.dart';

String? _adString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String? _adCoverImage(Map<String, dynamic> json) {
  for (final key in const [
    'cover_image',
    'coverImage',
    'cover',
    'image',
    'img',
    'pic',
  ]) {
    final value = _adString(json[key]);
    if (value != null) return value;
  }
  return null;
}

/// 开屏广告（对应 SplashAdItem.kt）
class SplashAdItem {
  final int id;
  final String? title;
  final String? coverImage;
  final String? linkUrl;
  final String? linkType;
  final int? linkId;
  final int duration;
  final int autoSkip;
  final int manualSkip;
  final int tapToEnter;
  final int sortOrder;
  final int showOnce;

  SplashAdItem({
    required this.id,
    this.title,
    this.coverImage,
    this.linkUrl,
    this.linkType,
    this.linkId,
    this.duration = 3,
    this.autoSkip = 1,
    this.manualSkip = 1,
    this.tapToEnter = 0,
    this.sortOrder = 0,
    this.showOnce = 0,
  });

  factory SplashAdItem.fromJson(Map<String, dynamic> json) {
    return SplashAdItem(
      id: ApiParse.asInt(json['id']) ?? 0,
      title: _adString(json['title']),
      coverImage: _adCoverImage(json),
      linkUrl: _adString(json['link_url'] ?? json['linkUrl'] ?? json['link']),
      linkType: _adString(json['link_type'] ?? json['linkType']),
      linkId: ApiParse.asInt(json['link_id'] ?? json['linkId']),
      duration: ApiParse.asInt(json['duration']) ?? 3,
      autoSkip: ApiParse.asInt(json['auto_skip']) ?? 1,
      manualSkip: ApiParse.asInt(json['manual_skip']) ?? 1,
      tapToEnter: ApiParse.asInt(json['tap_to_enter']) ?? 0,
      sortOrder: ApiParse.asInt(json['sort_order']) ?? 0,
      showOnce: ApiParse.asInt(json['show_once']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'cover_image': coverImage,
    'link_url': linkUrl,
    'link_type': linkType,
    'link_id': linkId,
    'duration': duration,
    'auto_skip': autoSkip,
    'manual_skip': manualSkip,
  };
}

/// 首页宫格广告（对应 HomeGridAdItem.kt）
class HomeGridAdItem {
  final int id;
  final int position;
  final String? title;
  final String? coverImage;
  final String? linkUrl;
  final String? linkType;
  final int? linkId;

  HomeGridAdItem({
    required this.id,
    required this.position,
    this.title,
    this.coverImage,
    this.linkUrl,
    this.linkType,
    this.linkId,
  });

  factory HomeGridAdItem.fromJson(Map<String, dynamic> json) {
    return HomeGridAdItem(
      id: ApiParse.asInt(json['id']) ?? 0,
      position: ApiParse.asInt(json['position']) ?? 0,
      title: _adString(json['title']),
      coverImage: _adCoverImage(json),
      linkUrl: _adString(json['link_url'] ?? json['linkUrl'] ?? json['link']),
      linkType: _adString(json['link_type'] ?? json['linkType']),
      linkId: ApiParse.asInt(json['link_id'] ?? json['linkId']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'position': position,
    'title': title,
    'cover_image': coverImage,
    'link_url': linkUrl,
    'link_type': linkType,
    'link_id': linkId,
  };
}

/// 弹窗广告（对应 PopupAdItem.kt）
class PopupAdItem {
  final int id;
  final String? title;
  final String? coverImage;
  final String? content;
  final String? linkUrl;
  final String? linkType;
  final int? linkId;
  final int sortOrder;
  final int showOnce;

  PopupAdItem({
    required this.id,
    this.title,
    this.coverImage,
    this.content,
    this.linkUrl,
    this.linkType,
    this.linkId,
    this.sortOrder = 0,
    this.showOnce = 0,
  });

  factory PopupAdItem.fromJson(Map<String, dynamic> json) {
    return PopupAdItem(
      id: ApiParse.asInt(json['id']) ?? 0,
      title: _adString(json['title']),
      coverImage: _adCoverImage(json),
      content: _adString(json['content']),
      linkUrl: _adString(json['link_url'] ?? json['linkUrl'] ?? json['link']),
      linkType: _adString(json['link_type'] ?? json['linkType']),
      linkId: ApiParse.asInt(json['link_id'] ?? json['linkId']),
      sortOrder: ApiParse.asInt(json['sort_order']) ?? 0,
      showOnce: ApiParse.asInt(json['show_once']) ?? 0,
    );
  }

  bool get hasDisplayContent {
    final hasCover = coverImage?.isNotEmpty == true;
    final hasText = content?.isNotEmpty == true;
    final hasTitle = title?.isNotEmpty == true;
    return hasCover || hasText || hasTitle;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'cover_image': coverImage,
    'content': content,
    'link_url': linkUrl,
    'link_type': linkType,
    'link_id': linkId,
  };
}
