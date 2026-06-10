/// 热搜结果（对应 HotSearchResult.kt）
class HotSearchResult {
  final List<String>? keywords;
  final List<HotSearchKeywordItem>? list;

  HotSearchResult({this.keywords, this.list});

  List<String> get allKeywords {
    if (keywords != null) return keywords!;
    if (list != null) return list!.map((e) => e.keyword ?? '').where((k) => k.isNotEmpty).toList();
    return [];
  }

  factory HotSearchResult.fromJson(Map<String, dynamic> json) {
    List<String>? kw;
    if (json['keywords'] is List) {
      kw = (json['keywords'] as List).map((e) => e.toString()).toList();
    }
    List<HotSearchKeywordItem>? itemList;
    if (json['list'] is List) {
      itemList = (json['list'] as List)
          .map((e) => HotSearchKeywordItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return HotSearchResult(keywords: kw, list: itemList);
  }

  Map<String, dynamic> toJson() => {
    'keywords': keywords,
    'list': list?.map((e) => e.toJson()).toList(),
  };
}

/// 热搜关键词项
class HotSearchKeywordItem {
  final String? keyword;

  HotSearchKeywordItem({this.keyword});

  factory HotSearchKeywordItem.fromJson(Map<String, dynamic> json) {
    return HotSearchKeywordItem(keyword: json['keyword'] as String?);
  }

  Map<String, dynamic> toJson() => {'keyword': keyword};
}
