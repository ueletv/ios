import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/comment.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/services/guest_auth_helper.dart';
import 'package:videoweb_flutter/api/api_parse.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';
import 'package:videoweb_flutter/widgets/user_avatar.dart';
import 'package:videoweb_flutter/utils/comment_time_util.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 热门评论弹窗（对应 HotCommentBottomSheet.kt）
class HotCommentSheet extends StatefulWidget {
  final String videoId;
  final VoidCallback? onCommentAdded;
  final ValueChanged<int>? onCommentCountChanged;

  const HotCommentSheet({
    super.key,
    required this.videoId,
    this.onCommentAdded,
    this.onCommentCountChanged,
  });

  @override
  State<HotCommentSheet> createState() => _HotCommentSheetState();
}

class _HotCommentSheetState extends State<HotCommentSheet> {
  final ApiService _api = ApiService();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<Comment> _comments = [];
  bool _fetching = false;
  bool _initialLoading = true;
  bool _hasMore = true;
  int _page = 1;
  int _commentTotal = 0;
  Set<int> _expandedParents = {};

  // 回复状态
  Comment? _replyTarget;
  final TextEditingController _replyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadComments();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _fetching || !_hasMore) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 80) {
      _loadComments();
    }
  }

  int _parseCommentTotal(Map<String, dynamic> root) {
    final pagination = root['pagination'];
    if (pagination is Map) {
      return ApiParse.asInt(pagination['comment_total']) ??
          ApiParse.asInt(pagination['total']) ??
          0;
    }
    return 0;
  }

  Future<void> _loadComments({bool refresh = false}) async {
    if (_fetching) return;
    if (!refresh && !_hasMore && _page > 1) return;

    setState(() => _fetching = true);
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }

    try {
      final res = await _api.getCommentList(widget.videoId, page: _page, pageSize: 20);
      if (ApiResult.isSuccess(res)) {
        final root = Map<String, dynamic>.from(res.data as Map);
        final list = ApiParse.extractList(root['data'])
            .map((e) => Comment.fromJson(e))
            .toList();
        final total = _parseCommentTotal(root);
        setState(() {
          if (refresh) {
            _comments = list;
            _expandedParents = {};
          } else {
            _comments.addAll(list);
          }
          _hasMore = list.length >= 20;
          if (total > 0) {
            _commentTotal = total;
          } else if (refresh) {
            _commentTotal = _comments.fold<int>(
              0,
              (s, c) => s + 1 + (c.replies?.length ?? 0),
            );
          }
          _page++;
        });
        widget.onCommentCountChanged?.call(_commentTotal);
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _fetching = false;
        _initialLoading = false;
      });
    }
  }

  Future<void> _addComment(String content, {int parentId = 0, int replyCommentId = 0}) async {
    if (content.trim().isEmpty) return;
    final prefs = context.read<AppPrefs>();
    final body = CommentAddBody(
      videoId: int.tryParse(widget.videoId) ?? 0,
      content: content.trim(),
      parentId: parentId,
      replyCommentId: replyCommentId,
    );
    final res = await GuestAuthHelper.callWithAuthRetry(prefs, () {
      return _api.addComment(body);
    });
    if (res != null && ApiResult.isSuccess(res)) {
      _inputCtrl.clear();
      _replyCtrl.clear();
      setState(() => _replyTarget = null);
      widget.onCommentAdded?.call();
      _loadComments(refresh: true);
    }
  }

  Future<void> _toggleLike(Comment comment) async {
    final prefs = context.read<AppPrefs>();
    final cid = comment.commentIdLong;
    if (cid == null) return;
    final res = await GuestAuthHelper.callWithAuthRetry(prefs, () {
      return _api.toggleCommentLike(CommentIdBody(commentId: cid));
    });
    if (res != null && ApiResult.isSuccess(res)) {
      final liked = comment.isLiked != true;
      final count = (comment.likeCount ?? 0) + (liked ? 1 : -1);
      setState(() => _patchCommentLike(cid, liked, count < 0 ? 0 : count));
    }
  }

  void _patchCommentLike(int commentId, bool liked, int likeCount) {
    _comments = _comments.map((main) {
      if (main.commentIdLong == commentId) {
        return Comment(
          id: main.id,
          videoId: main.videoId,
          userId: main.userId,
          parentId: main.parentId,
          username: main.username,
          nickname: main.nickname,
          displayName: main.displayName,
          avatar: main.avatar,
          content: main.content,
          likeCount: likeCount,
          isLiked: liked,
          replyTo: main.replyTo,
          replies: main.replies,
          createdAt: main.createdAt,
          updatedAt: main.updatedAt,
        );
      }
      final replies = main.replies;
      if (replies == null || replies.isEmpty) return main;
      final patched = replies.map((r) {
        if (r.commentIdLong != commentId) return r;
        return Comment(
          id: r.id,
          videoId: r.videoId,
          userId: r.userId,
          parentId: r.parentId,
          username: r.username,
          nickname: r.nickname,
          displayName: r.displayName,
          avatar: r.avatar,
          content: r.content,
          likeCount: likeCount,
          isLiked: liked,
          replyTo: r.replyTo,
          replies: r.replies,
          createdAt: r.createdAt,
          updatedAt: r.updatedAt,
        );
      }).toList();
      return Comment(
        id: main.id,
        videoId: main.videoId,
        userId: main.userId,
        parentId: main.parentId,
        username: main.username,
        nickname: main.nickname,
        displayName: main.displayName,
        avatar: main.avatar,
        content: main.content,
        likeCount: main.likeCount,
        isLiked: main.isLiked,
        replyTo: main.replyTo,
        replies: patched,
        createdAt: main.createdAt,
        updatedAt: main.updatedAt,
      );
    }).toList();
  }

  Future<void> _deleteComment(Comment comment) async {
    final prefs = context.read<AppPrefs>();
    final cid = comment.commentIdLong;
    if (cid == null) return;
    final res = await GuestAuthHelper.callWithAuthRetry(prefs, () {
      return _api.deleteComment(CommentIdBody(commentId: cid));
    });
    if (res != null && ApiResult.isSuccess(res)) {
      _loadComments(refresh: true);
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<_SheetRow> _buildDisplayRows() {
    const visibleReplies = 1;
    final rows = <_SheetRow>[];
    for (final main in _comments) {
      rows.add(_SheetRow(comment: main, isReply: false));
      final parentId = main.commentIdLong;
      if (parentId == null) continue;
      final replies = main.replies ?? [];
      if (replies.isEmpty) continue;
      final expanded = _expandedParents.contains(parentId);
      if (!expanded && replies.length > visibleReplies) {
        for (final r in replies.take(visibleReplies)) {
          rows.add(_SheetRow(comment: r, isReply: true));
        }
        rows.add(_SheetRow.expand(parentId, replies.length - visibleReplies));
      } else {
        for (final r in replies) {
          rows.add(_SheetRow(comment: r, isReply: true));
        }
        if (expanded && replies.length > visibleReplies) {
          rows.add(_SheetRow.collapse(parentId));
        }
      }
    }
    return rows;
  }

  void _submitInput(String text) {
    if (_replyTarget != null) {
      _addComment(
        text,
        parentId: _replyTarget!.threadParentId ?? 0,
        replyCommentId: _replyTarget!.commentIdLong ?? 0,
      );
    } else {
      _addComment(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final displayRows = _buildDisplayRows();
    final countLabel = _commentTotal > 0 ? _commentTotal : _comments.length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$countLabel条评论',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.divider),
          Expanded(
            child: _initialLoading
                ? const Center(child: CircularProgressIndicator())
                : displayRows.isEmpty
                    ? Center(
                        child: Text('暂无评论', style: TextStyle(color: colors.textHint)),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        itemCount: displayRows.length + (_fetching && _hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= displayRows.length) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          final row = displayRows[index];
                          if (row.kind == _SheetRowKind.expand) {
                            return GestureDetector(
                              onTap: () => setState(() => _expandedParents.add(row.parentId!)),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 46, bottom: 10),
                                child: Text(
                                  '展开${row.hiddenCount}条回复',
                                  style: TextStyle(
                                    color: colors.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }
                          if (row.kind == _SheetRowKind.collapse) {
                            return GestureDetector(
                              onTap: () => setState(() => _expandedParents.remove(row.parentId!)),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 46, bottom: 10),
                                child: Text(
                                  '收起回复',
                                  style: TextStyle(
                                    color: colors.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }
                          final comment = row.comment!;
                          return _CommentItem(
                            comment: comment,
                            isReply: row.isReply,
                            colors: colors,
                            onLike: () => _toggleLike(comment),
                            onReply: () => setState(() => _replyTarget = comment),
                            onDelete: () => _deleteComment(comment),
                          );
                        },
                      ),
          ),
          if (_replyTarget != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: colors.chipBg,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '回复 @${_replyTarget!.authorName}',
                      style: TextStyle(color: colors.textSecondary, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyTarget = null),
                    child: Icon(Icons.close, size: 18, color: colors.textHint),
                  ),
                ],
              ),
            ),
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyTarget != null ? _replyCtrl : _inputCtrl,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: _replyTarget != null ? '输入回复...' : '说点什么...',
                      hintStyle: TextStyle(color: colors.textHint),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colors.chipBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    onSubmitted: _submitInput,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send_rounded, color: colors.accent),
                  onPressed: () {
                    final ctrl = _replyTarget != null ? _replyCtrl : _inputCtrl;
                    _submitInput(ctrl.text);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _SheetRowKind { comment, expand, collapse }

class _SheetRow {
  final _SheetRowKind kind;
  final Comment? comment;
  final bool isReply;
  final int? parentId;
  final int? hiddenCount;

  _SheetRow({required this.comment, required this.isReply})
      : kind = _SheetRowKind.comment,
        parentId = null,
        hiddenCount = null;

  _SheetRow.expand(int parentId, int hidden)
      : kind = _SheetRowKind.expand,
        comment = null,
        isReply = false,
        parentId = parentId,
        hiddenCount = hidden;

  _SheetRow.collapse(int parentId)
      : kind = _SheetRowKind.collapse,
        comment = null,
        isReply = false,
        parentId = parentId,
        hiddenCount = null;
}

class _CommentItem extends StatelessWidget {
  final Comment comment;
  final bool isReply;
  final AppColors colors;
  final VoidCallback? onLike;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  const _CommentItem({
    required this.comment,
    required this.isReply,
    required this.colors,
    this.onLike,
    this.onReply,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final avatarSize = isReply ? 28.0 : 36.0;

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 46 : 0, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            rawAvatar: comment.avatar,
            size: avatarSize,
            useServerDefault: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.authorName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      CommentTimeUtil.format(comment.createdAt),
                      style: TextStyle(color: colors.textHint, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (comment.replyTo != null && comment.replyTo!.isNotEmpty)
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 14, height: 1.35, color: colors.textPrimary),
                      children: [
                        TextSpan(
                          text: '回复 ${comment.replyTo} ',
                          style: TextStyle(color: colors.textSecondary, fontSize: 13),
                        ),
                        TextSpan(text: comment.content),
                      ],
                    ),
                  )
                else
                  Text(
                    comment.content,
                    style: TextStyle(fontSize: 14, height: 1.35, color: colors.textPrimary),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onLike,
                      child: Row(
                        children: [
                          Icon(
                            comment.isLiked == true ? Icons.favorite : Icons.favorite_border,
                            size: 14,
                            color: comment.isLiked == true ? Colors.redAccent : colors.textHint,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${comment.likeCount ?? 0}',
                            style: TextStyle(color: colors.textHint, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onReply,
                      child: Row(
                        children: [
                          Icon(Icons.reply, size: 14, color: colors.textHint),
                          const SizedBox(width: 2),
                          Text('回复', style: TextStyle(color: colors.textHint, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: Icon(Icons.delete_outline, size: 16, color: colors.textHint),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
