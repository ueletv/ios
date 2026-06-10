/// Banner / 首页宫格广告模型（对应原生 Banner.kt + HomeGridAdItem）
class BannerModel {
  final int? id;
  final String? title;
  final String? image;
  final String? coverImage;
  final String? link;
  final String? linkType;
  final dynamic linkId;
  final int? sort;
  final int? position;

  BannerModel({
    this.id,
    this.title,
    this.image,
    this.coverImage,
    this.link,
    this.linkType,
    this.linkId,
    this.sort,
    this.position,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: _asInt(json['id']),
      title: json['title']?.toString(),
      image: _firstString(json, const [
        'image',
        'img',
        'pic',
        'icon',
      ]),
      coverImage: _firstString(json, const [
        'cover_image',
        'coverImage',
        'cover',
        'cover_img',
        'coverImg',
        'image',
        'img',
        'pic',
        'icon',
      ]),
      link: _firstString(json, const [
        'link',
        'link_url',
        'linkUrl',
        'url',
      ]),
      linkType: (json['link_type'] ?? json['linkType'])?.toString(),
      linkId: json['link_id'] ?? json['linkId'],
      sort: _asInt(json['sort']),
      position: _asInt(json['position']),
    );
  }

  static String? _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
