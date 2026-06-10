/// 评论模型（对应 Comment.kt）
class Comment {
  final dynamic id;
  final dynamic videoId;
  final dynamic userId;
  final int? parentId;
  final String? username;
  final String? nickname;
  final String? displayName;
  final String? avatar;
  final String content;
  final int? likeCount;
  final bool? isLiked;
  final String? replyTo;
  final List<Comment>? replies;
  final String? createdAt;
  final String? updatedAt;

  Comment({
    this.id,
    this.videoId,
    this.userId,
    this.parentId,
    this.username,
    this.nickname,
    this.displayName,
    this.avatar,
    required this.content,
    this.likeCount,
    this.isLiked,
    this.replyTo,
    this.replies,
    this.createdAt,
    this.updatedAt,
  });

  String get authorName => displayName ?? nickname ?? username ?? '用户';

  int? get authorUserId {
    if (userId is int) return userId as int;
    if (userId is String) return int.tryParse(userId as String);
    if (userId is double) return (userId as double).toInt();
    return null;
  }

  bool isOwnComment(int? currentUserId) {
    final uid = authorUserId;
    return uid != null && currentUserId != null && uid == currentUserId;
  }

  int? get commentIdLong {
    if (id is int) return id as int;
    if (id is String) return int.tryParse(id as String);
    if (id is double) return (id as double).toInt();
    return null;
  }

  int? get threadParentId {
    if (parentId != null && parentId! > 0) return parentId;
    return commentIdLong;
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      videoId: json['video_id'],
      userId: json['user_id'],
      parentId: (json['parent_id'] as num?)?.toInt(),
      username: json['username'] as String?,
      nickname: json['nickname'] as String?,
      displayName: json['display_name'] as String?,
      avatar: json['avatar'] as String?,
      content: json['content'] as String? ?? '',
      likeCount: (json['like_count'] as num?)?.toInt(),
      isLiked: json['is_liked'] as bool?,
      replyTo: json['reply_to'] as String?,
      replies: json['replies'] != null
          ? (json['replies'] as List)
              .map((e) => Comment.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'video_id': videoId,
    'user_id': userId,
    'parent_id': parentId,
    'username': username,
    'nickname': nickname,
    'display_name': displayName,
    'avatar': avatar,
    'content': content,
    'like_count': likeCount,
    'is_liked': isLiked,
    'reply_to': replyTo,
    'replies': replies?.map((e) => e.toJson()).toList(),
    'created_at': createdAt,
  };
}

/// 评论提交请求体（对应 CommentAddBody.kt + CommentIdBody.kt）
class CommentAddBody {
  final int videoId;
  final String content;
  final int parentId;
  final int replyCommentId;

  CommentAddBody({
    required this.videoId,
    required this.content,
    this.parentId = 0,
    this.replyCommentId = 0,
  });

  Map<String, dynamic> toJson() => {
    'video_id': videoId,
    'content': content,
    'parent_id': parentId,
    'reply_comment_id': replyCommentId,
  };
}

class CommentIdBody {
  final int commentId;

  CommentIdBody({required this.commentId});

  Map<String, dynamic> toJson() => {
    'comment_id': commentId,
  };
}
