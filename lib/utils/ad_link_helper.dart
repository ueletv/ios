import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/video.dart';
import 'package:videoweb_flutter/pages/live/live_room_page.dart';
import 'package:videoweb_flutter/utils/live_access_helper.dart';
import 'package:videoweb_flutter/pages/video/video_detail_page.dart';
import 'package:videoweb_flutter/utils/image_url.dart';

/// 广告链接处理（对应 AdLinkHelper.kt）
class AdLinkHelper {
  static bool hasLink(String? linkType, String? linkUrl, dynamic linkId) {
    switch (linkType?.trim() ?? '') {
      case 'video':
      case 'category':
        final id = linkId is int ? linkId : int.tryParse(linkId?.toString() ?? '');
        return (id ?? 0) > 0;
      default:
        return linkUrl?.trim().isNotEmpty == true;
    }
  }

  static Future<void> openLink(
    BuildContext context, {
    String? linkType,
    String? linkUrl,
    dynamic linkId,
  }) async {
    switch (linkType?.trim() ?? '') {
      case 'video':
        final id = linkId is int ? linkId : int.tryParse(linkId?.toString() ?? '');
        if (id == null || id <= 0) return;
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoDetailPage(video: Video(id: id)),
          ),
        );
        return;
      case 'streamer':
        final id = linkId?.toString() ?? '';
        if (id.isEmpty) return;
        await _openStreamerRoom(context, id);
        return;
      case 'url':
      case 'ad':
        await _openExternalUrl(context, linkUrl);
        return;
      default:
        if (linkUrl?.trim().isNotEmpty == true) {
          await _openExternalUrl(context, linkUrl);
        } else if (linkType?.trim() == 'category') {
          AppToast.show('分类跳转暂未开放', context: context);
        }
    }
  }

  static Future<void> _openStreamerRoom(BuildContext context, String streamerId) async {
    try {
      final res = await ApiService().checkStreamerOnline(streamerId);
      var playUrl = '';
      var name = '主播';
      var cover = '';
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is Map) {
          playUrl = data['play_url']?.toString() ?? data['pull_url']?.toString() ?? '';
          name = data['nickname']?.toString() ?? data['name']?.toString() ?? name;
          cover = data['cover']?.toString() ?? data['avatar']?.toString() ?? '';
        }
      }
      if (!context.mounted) return;
      await LiveAccessHelper.openLiveRoomIfAllowed(context, () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LiveRoomPage(
              streamerId: streamerId,
              playUrl: playUrl,
              streamerName: name,
              coverUrl: ImageUrl.getImageUrl(cover),
            ),
          ),
        );
      });
    } catch (_) {
      if (context.mounted) {
        AppToast.show('无法打开直播间', context: context);
      }
    }
  }

  static Future<void> _openExternalUrl(BuildContext context, String? raw) async {
    final url = normalizeUrl(raw);
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        AppToast.show('无法打开链接', context: context);
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.show('无法打开链接', context: context);
      }
    }
  }

  static String? normalizeUrl(String? raw) {
    final u = raw?.trim() ?? '';
    if (u.isEmpty) return null;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    return 'https://$u';
  }

  @Deprecated('Use openLink')
  static Future<bool> handleAdClick(
    BuildContext context, {
    String? linkType,
    String? linkUrl,
    dynamic linkId,
  }) async {
    if (!hasLink(linkType, linkUrl, linkId)) return false;
    await openLink(context, linkType: linkType, linkUrl: linkUrl, linkId: linkId);
    return true;
  }
}
