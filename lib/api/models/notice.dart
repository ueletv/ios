/// 公告模型（对应 Notice.kt）
class Notice {
  final int? id;
  final String? content;
  final int? sort;

  Notice({
    this.id,
    this.content,
    this.sort,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: (json['id'] as num?)?.toInt(),
      content: json['content'] as String?,
      sort: (json['sort'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'sort': sort,
  };
}
