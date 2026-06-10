import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fijkplayer/fijkplayer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:videoweb_flutter/api/api_client.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/gift.dart';
import 'package:videoweb_flutter/api/models/streamer.dart';
import 'package:videoweb_flutter/api/models/user.dart';
import 'package:videoweb_flutter/services/app_config_cache.dart';
import 'package:videoweb_flutter/utils/live_access_helper.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/services/global_trial_service.dart';
import 'package:videoweb_flutter/services/gift_list_cache.dart';
import 'package:videoweb_flutter/services/guest_auth_helper.dart';
import 'package:videoweb_flutter/utils/fijk_player_helper.dart';
import 'package:videoweb_flutter/utils/screen_wake_lock.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';
import 'package:videoweb_flutter/utils/avatar_helper.dart';
import 'package:videoweb_flutter/utils/image_url.dart';
import 'package:videoweb_flutter/widgets/fijk_video_view.dart';
import 'package:videoweb_flutter/pages/live/gift_svga_util.dart';
import 'package:videoweb_flutter/pages/live/live_message_parser.dart';
import 'package:videoweb_flutter/pages/live/live_room_assets.dart';
import 'package:videoweb_flutter/pages/live/live_room_colors.dart';
import 'package:videoweb_flutter/pages/live/widgets/gift_panel.dart';
import 'package:videoweb_flutter/pages/live/widgets/live_gift_banner_overlay.dart';
import 'package:videoweb_flutter/pages/live/widgets/live_gift_svga_overlay.dart';
import 'package:videoweb_flutter/pages/live/widgets/live_message_bubble.dart';
import 'package:videoweb_flutter/utils/vip_access_helper.dart';

/// 直播间页面（对应原生 LiveRoomActivity.kt）
class LiveRoomPage extends StatefulWidget {
  final String streamerId;
  final String playUrl;
  final String streamerName;
  final String coverUrl;
  final int onlineCount;
  final StreamerCaipiaoInfo? caipiaoInfo;

  const LiveRoomPage({
    super.key,
    required this.streamerId,
    required this.playUrl,
    this.streamerName = '主播',
    this.coverUrl = '',
    this.onlineCount = 0,
    this.caipiaoInfo,
  });

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  IO.Socket? _socket;

  // UI 状态
  bool _isFollowed = false;
  bool _followLoading = false;
  final ValueNotifier<int> _onlineCountNotifier = ValueNotifier(0);
  bool _showChatPanel = false;
  bool _showGiftPanel = false;
  bool _isBarrageMode = false;
  bool _isOffline = false;
  int? _currentUserId;
  String? _currentUserLevelIcon;
  int _userLevel = 0;
  int _minChatLevel = 0;
  int _minBarrageLevel = 0;
  bool _liveVipRequired = false;
  int _barragePrice = 0;
  bool _isActiveVip = false;
  bool _liveVipBlocked = false;
  bool _liveTrialExpired = false;
  bool _vipPromptOpen = false;
  bool _configLoaded = false;
  bool _userLoaded = false;
  bool _liveAccessSetupDone = false;
  String _socketServerUrl = '';

  /// 是否允许直播画面播放（试看结束或未开通 VIP 时禁止）
  bool get _canPlayLive {
    if (_isOffline) return false;
    if (!_liveVipRequired) return true;
    if (_isActiveVip) return true;
    if (_liveVipBlocked || _liveTrialExpired) return false;
    return true;
  }

  bool get _showTrialCountdown =>
      _liveVipRequired && !_isActiveVip && !_liveVipBlocked && !_liveTrialExpired;

  // 消息列表
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _msgScrollCtrl = ScrollController();
  final GlobalKey<LiveGiftSvgaOverlayState> _svgaKey = GlobalKey();
  final GlobalKey<LiveGiftBannerOverlayState> _giftBannerKey = GlobalKey();
  final ValueNotifier<int> _messagesTick = ValueNotifier(0);
  final ValueNotifier<int> _barrageTick = ValueNotifier(0);

  int _lastLocalGiftTs = 0;
  String? _caipiaoBiaoshi;
  bool _roomJoined = false;
  bool _historyLoaded = false;
  final List<Map<String, dynamic>> _pendingMessages = [];
  Timer? _historyFallbackTimer;
  Timer? _messageUiTimer;
  bool _scrollPending = false;

  // 弹幕列表
  final List<Map<String, dynamic>> _barrages = [];
  Timer? _barrageTimer;
  bool _wasBackgrounded = false;
  final GlobalKey<_LiveRoomVideoPlayerState> _videoPlayerKey = GlobalKey();

  // 清屏（对齐原生 LiveRoomActivity：右滑清屏，左滑恢复）
  bool _cleanModeActive = false;
  bool _isDraggingClean = false;
  double _uiTranslateX = 0;
  double _dragStartX = 0;
  double _dragOffsetFromStart = 0;
  AnimationController? _cleanAnimCtrl;
  Animation<double>? _cleanAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _onlineCountNotifier.value = widget.onlineCount;
    _caipiaoBiaoshi = widget.caipiaoInfo?.biaoshi;
    _applyCachedConfig();
    _bootstrapLiveRoom();
    _checkFollowStatus();

    // 若服务端未推送 history-messages，超时后仍展示实时消息
    _historyFallbackTimer = Timer(const Duration(seconds: 2), _finishHistoryLoading);

    // 定时清理弹幕（仅刷新弹幕层，避免整页重建）
    _barrageTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_barrages.isNotEmpty && mounted) {
        _barrages.removeAt(0);
        _barrageTick.value++;
      }
    });
    _cleanAnimCtrl = AnimationController(vsync: this);
    unawaited(ScreenWakeLock.acquire());
  }

  void _applyCachedConfig() {
    final config = AppConfigCache.cached;
    if (config == null) return;
    _applyConfigFields(config);
    _configLoaded = true;
  }

  void _applyConfigFields(Map<String, dynamic> config) {
    var serverUrl = ApiClient.baseUrl.replaceAll(RegExp(r'/$'), '');
    final socketUrl = config['socket_server_url']?.toString().trim();
    if (socketUrl != null &&
        socketUrl.isNotEmpty &&
        !socketUrl.toLowerCase().contains('localhost')) {
      serverUrl = socketUrl.replaceAll(RegExp(r'/$'), '');
    }
    _minChatLevel = _asInt(config['min_chat_level']) ?? 0;
    _minBarrageLevel = _asInt(config['min_barrage_level']) ?? 0;
    _liveVipRequired = config['live_room_vip_required']?.toString() != '0';
    _barragePrice = _asInt(config['barrage_price']) ?? 0;
    _socketServerUrl = serverUrl;
  }

  String _streamerIdForApi() => _normalizeRoomId();

  void _notifyMessages() {
    if (_messageUiTimer != null) return;
    _messageUiTimer = Timer(const Duration(milliseconds: 120), () {
      _messageUiTimer = null;
      if (!mounted) return;
      _messagesTick.value++;
    });
  }

  double _bottomActionsHeight(BuildContext context) {
    return MediaQuery.of(context).padding.bottom + 20 + 36 + 12;
  }

  double _messageListBottom(BuildContext context, {bool chatPanelOpen = false}) {
    if (chatPanelOpen) return _bottomActionsHeight(context) + 230;
    return _bottomActionsHeight(context) + 22;
  }

  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(msg, context: context);
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  /// 发言等级校验（文案与 Go livechat 服务端一致）
  bool _validateChatLevel({required bool isBarrage}) {
    if (_userLevel < _minChatLevel) {
      _toast('您的等级不足，需要达到 $_minChatLevel 级才能发言');
      return false;
    }
    if (isBarrage && _userLevel < _minBarrageLevel) {
      _toast('您的等级不足，需要达到 $_minBarrageLevel 级才能发送弹幕');
      return false;
    }
    return true;
  }

  String _socketErrorMessage(dynamic data, {String fallback = '操作失败'}) {
    if (data is Map) return data['message']?.toString().trim() ?? fallback;
    return data?.toString().trim() ?? fallback;
  }

  String _normalizeRoomId() {
    final id = widget.streamerId.trim();
    if (id.toLowerCase().startsWith('bx')) return id.substring(2);
    return id;
  }

  void _enrichLevelIcon(Map<String, dynamic> msg) {
    final existing = (msg['user_level_icon']?.toString() ?? '').trim();
    if (existing.isNotEmpty) return;

    final uidRaw = msg['user_id'] ?? msg['userId'];
    if (uidRaw == null || _currentUserId == null) return;
    final uid = uidRaw is int ? uidRaw : int.tryParse(uidRaw.toString());
    if (uid == null || uid != _currentUserId) return;

    final fallback = (_currentUserLevelIcon ?? context.read<AppPrefs>().cachedLevelIcon)?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      msg['user_level_icon'] = fallback;
    }
  }

  Future<void> _bootstrapLiveRoom() async {
    unawaited(GiftListCache.prefetch());
    unawaited(GiftListCache.refreshUserBalance());
    await context.read<GlobalTrialService>().refreshFromServer();
    if (!mounted) return;
    await Future.wait([
      _loadLiveConfig(),
      _loadCurrentUser(),
    ]);
    if (!mounted) return;
    await _finishLiveAccessSetup();
  }

  Future<void> _loadLiveConfig() async {
    final prefs = context.read<AppPrefs>();
    await ImageUrl.refreshFromConfig(prefs);

    final hadCache = AppConfigCache.cached != null;
    final config = await AppConfigCache.fetch(force: !hadCache);
    if (!mounted || config == null) return;

    _applyConfigFields(config);
    _configLoaded = true;
    if (mounted) setState(() {});
  }

  Future<void> _finishLiveAccessSetup() async {
    if (!mounted || _liveAccessSetupDone || !_configLoaded || !_userLoaded) return;
    _liveAccessSetupDone = true;

    if (!_liveVipRequired || _isActiveVip) {
      await _connectSocket();
      return;
    }

    final trial = context.read<GlobalTrialService>();
    if (!trial.canWatch(vipRequired: true, type: TrialContentType.live)) {
      await LiveAccessHelper.ensureCanEnterLive(context);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    await _connectSocket();
    _startGlobalTrialWatching();
  }

  void _startGlobalTrialWatching() {
    if (!_liveVipRequired || _isActiveVip) return;
    context.read<GlobalTrialService>().startWatching(
      type: TrialContentType.live,
      onExhausted: () {
      if (!mounted) return;
      _onGlobalTrialExhausted();
    });
  }

  Future<void> _onGlobalTrialExhausted() async {
    if (!mounted || _isActiveVip || !_liveVipRequired) return;
    setState(() {
      _liveTrialExpired = true;
      _liveVipBlocked = true;
    });
    await _videoPlayerKey.currentState?.pausePlayback();
    await _handleLiveVipPromptFlow();
  }

  Future<void> _connectSocket() async {
    final prefs = context.read<AppPrefs>();
    final token = prefs.token ?? '';
    if (token.isEmpty) return;

    var serverUrl = _socketServerUrl;
    if (serverUrl.isEmpty) {
      serverUrl = ApiClient.baseUrl.replaceAll(RegExp(r'/$'), '');
    }
    _setupSocket(serverUrl, token);
  }

  void _teardownSocket() {
    final s = _socket;
    _socket = null;
    _roomJoined = false;
    if (s == null) return;
    s.clearListeners();
    s.disconnect();
    s.dispose();
  }

  void _setupSocket(String serverUrl, String token) {
    _teardownSocket();

    _socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['polling', 'websocket'],
      'path': '/socket.io/',
      'query': {'token': token},
    });

    _socket!.onConnect((_) {
      debugPrint('Socket 已连接');
      _roomJoined = false;
      _socket!.emit('authenticate', {'token': token});
    });

    _socket!.on('authenticated', (_) {
      debugPrint('Socket 认证成功');
      _socket!.emit('join-room', {'roomId': _normalizeRoomId()});
    });

    _socket!.on('auth-error', (data) {
      _toast(_socketErrorMessage(data, fallback: '认证失败'));
      debugPrint('Socket 认证失败: $data');
    });

    _socket!.on('joined-room', (data) {
      debugPrint('已加入房间: $data');
      _roomJoined = true;
    });

    _socket!.on('new-message', (data) {
      if (data is Map) {
        _handleIncomingMessage(LiveMessageParser.parseMessage(Map<String, dynamic>.from(data)));
      }
    });

    _socket!.on('lottery-bet-message', (data) {
      if (data is Map) {
        _handleIncomingMessage(
          LiveMessageParser.parseLotteryMessage(Map<String, dynamic>.from(data), isWin: false),
        );
      }
    });

    _socket!.on('lottery-win-message', (data) {
      if (data is Map) {
        _handleIncomingMessage(
          LiveMessageParser.parseLotteryMessage(Map<String, dynamic>.from(data), isWin: true),
        );
      }
    });

    _socket!.on('my-join', (data) {
      if (data is Map) {
        _handleIncomingMessage(
          LiveMessageParser.parseJoinMessage(Map<String, dynamic>.from(data), isSelf: true),
        );
      }
    });

    _socket!.on('user-joined', (data) {
      if (data is Map) {
        _handleIncomingMessage(
          LiveMessageParser.parseJoinMessage(Map<String, dynamic>.from(data), isSelf: false),
        );
      }
    });

    _socket!.on('new-gift', (data) {
      if (data is! Map) return;
      // 自己送的礼物已在 _handleGiftSent 播放；聊天文案走 new-message，此处只处理动效
      if (DateTime.now().millisecondsSinceEpoch - _lastLocalGiftTs < 3000) {
        _lastLocalGiftTs = 0;
        return;
      }
      final msg = LiveMessageParser.parseGiftEvent(Map<String, dynamic>.from(data));
      _enrichLevelIcon(msg);
      _playGiftSvgaEffect(msg);
      _giftBannerKey.currentState?.show(msg);
    });

    _socket!.on('history-messages', (data) {
      if (data is List) {
        final history = (data as List)
            .whereType<Map>()
            .map((e) => LiveMessageParser.parseMessage(Map<String, dynamic>.from(e)))
            .toList();
        _mergeHistoryMessages(history);
      }
    });

    _socket!.on('my-follow', (data) {
      if (data is Map) {
        _handleIncomingMessage(
          LiveMessageParser.parseFollowMessage(Map<String, dynamic>.from(data), isSelf: true),
        );
      }
    });

    _socket!.on('user-followed', (data) {
      if (data is Map) {
        _handleIncomingMessage(
          LiveMessageParser.parseFollowMessage(Map<String, dynamic>.from(data), isSelf: false),
        );
      }
    });

    _socket!.on('streamer-offline', (data) {
      final msg = data is Map ? (data['message']?.toString() ?? '主播已下播') : '主播已下播';
      _showOfflineDialog(msg);
    });

    _socket!.on('user-left', (_) {
      if (_onlineCountNotifier.value > 0) {
        _onlineCountNotifier.value--;
      }
    });

    _socket!.on('error', (data) {
      final msg = _socketErrorMessage(data);
      if (msg.isNotEmpty) _toast(msg);
      debugPrint('Socket 错误: $data');
    });

    _socket!.on('warning', (data) {
      final msg = _socketErrorMessage(data, fallback: '');
      if (msg.isNotEmpty) _toast(msg);
    });

    _socket!.connect();
  }

  void _mergeHistoryMessages(List<Map<String, dynamic>> history) {
    if (history.isNotEmpty) {
      for (final msg in history) {
        _enrichLevelIcon(msg);
        if (_shouldSkipMessage(msg)) continue;
        _messages.add(msg);
      }
      _trimMessages();
    }
    _finishHistoryLoading();
  }

  void _finishHistoryLoading() {
    if (_historyLoaded) return;
    _historyLoaded = true;
    _historyFallbackTimer?.cancel();
    for (final msg in _pendingMessages) {
      _appendMessage(msg, scroll: false);
    }
    _pendingMessages.clear();
    _notifyMessages();
    _scrollToBottom();
  }

  static const int _maxMessages = 200;

  void _trimMessages() {
    if (_messages.length <= _maxMessages) return;
    final drop = _messages.length - _maxMessages;
    _messages.removeRange(0, drop);
  }

  bool _shouldSkipMessage(Map<String, dynamic> msg) {
    if (msg['is_lottery_bet'] == true || msg['is_lottery_win'] == true) {
      final biaoshi = msg['biaoshi']?.toString() ?? '';
      if (_caipiaoBiaoshi == null || _caipiaoBiaoshi!.isEmpty) return true;
      if (biaoshi.isNotEmpty && biaoshi != _caipiaoBiaoshi) return true;
    }

    final msgUserId = msg['user_id'];
    if (_currentUserId != null && msgUserId != null) {
      final uid = msgUserId is int ? msgUserId : int.tryParse(msgUserId.toString());
      if (uid == _currentUserId) {
        if (msg['is_lottery_bet'] == true || msg['is_lottery_win'] == true) return true;
      }
    }

    final content = msg['content']?.toString() ?? '';
    if (content.contains('关注了')) {
      final isSelfFollow = content.contains('我关注了') ||
          (_currentUserId != null && msgUserId == _currentUserId);
      if (isSelfFollow && !content.startsWith('我关注了')) return true;
    }
    return false;
  }

  void _appendMessage(Map<String, dynamic> msg, {bool scroll = true}) {
    _messages.add(msg);
    _trimMessages();
    if (msg['is_barrage'] == 1 || msg['is_barrage'] == true) {
      _barrages.add(msg);
      _barrageTick.value++;
    }
    _notifyMessages();
    if (scroll) _scrollToBottom();
  }

  void _handleIncomingMessage(Map<String, dynamic> msg) {
    _enrichLevelIcon(msg);
    if (_shouldSkipMessage(msg)) return;

    if (_isOtherUserEnterRoom(msg)) {
      _onlineCountNotifier.value = (_onlineCountNotifier.value + 1).clamp(0, 999999);
    }

    if (!_historyLoaded) {
      _pendingMessages.add(msg);
      return;
    }

    _appendMessage(msg);
  }

  bool _isOtherUserEnterRoom(Map<String, dynamic> msg) {
    final content = msg['content']?.toString() ?? '';
    if (!content.contains('进入直播间')) return false;
    if (_currentUserId == null) return false;
    final uid = msg['user_id'];
    if (uid == null) return true;
    final id = uid is int ? uid : int.tryParse(uid.toString());
    return id != _currentUserId;
  }

  void _playGiftSvgaEffect(Map<String, dynamic> msg) {
    final svgaUrl = GiftSvgaUtil.resolveAnimationUrl(msg);
    if (svgaUrl.isEmpty || !GiftSvgaUtil.isSvgaUrl(svgaUrl)) return;
    final duration = (msg['display_duration'] as int?) ?? 4;
    _svgaKey.currentState?.play(svgaUrl, duration);
  }

  void _handleGiftSent(Gift gift, Map<String, dynamic> localMsg) {
    _lastLocalGiftTs = DateTime.now().millisecondsSinceEpoch;
    if (_currentUserId != null) {
      localMsg['user_id'] = _currentUserId;
    }
    _enrichLevelIcon(localMsg);
    final animUrl = GiftSvgaUtil.resolveSendAnimationUrl(gift);
    if (animUrl.isNotEmpty && GiftSvgaUtil.isSvgaUrl(animUrl)) {
      _svgaKey.currentState?.play(animUrl, (gift.displayDuration ?? 4).clamp(1, 30));
    }
    _giftBannerKey.currentState?.show(localMsg);

    final duration = (gift.displayDuration ?? 4).clamp(1, 30);
    _socket?.emit('send-gift', {
      'gift_id': gift.id,
      'gift_name': gift.name ?? '',
      'gift_icon': gift.icon ?? gift.image ?? '',
      'gift_image': gift.image ?? '',
      'display_duration': duration,
      'count': 1,
    });
  }

  Future<void> _handleLiveVipPromptFlow() async {
    if (!mounted || _isActiveVip || !_liveVipRequired) return;
    if (_vipPromptOpen) return;
    _vipPromptOpen = true;
    await _videoPlayerKey.currentState?.pausePlayback();
    final openedVip = await VipAccessHelper.showVipRequiredDialog(
      context,
      title: '直播试看已结束',
      message: '直播试看时长已用完，开通 VIP 可继续观看精彩直播',
      cancelLabel: '返回大厅',
    );
    _vipPromptOpen = false;
    if (!mounted) return;
    if (!openedVip) {
      Navigator.of(context).pop();
      return;
    }
    await _loadCurrentUser();
    if (!mounted) return;
    if (_isActiveVip) {
      setState(() {
        _liveVipBlocked = false;
        _liveTrialExpired = false;
      });
      await _videoPlayerKey.currentState?.resumePlayback();
      _startGlobalTrialWatching();
      return;
    }
    setState(() => _liveVipBlocked = true);
    await _videoPlayerKey.currentState?.pausePlayback();
    await _handleLiveVipPromptFlow();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final prefs = context.read<AppPrefs>();
      final res = await _api.getUserInfo();
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final user = UserInfo.fromJson(map);
          prefs.cachedLevelIcon = user.resolvedLevelIcon;
          context.read<GlobalTrialService>().syncUser(user);
          final id = map['id'] ?? map['user_id'];
          if (mounted) {
            setState(() {
              _currentUserLevelIcon = user.resolvedLevelIcon;
              _userLevel = user.resolvedLevel;
              _isActiveVip = user.isActiveVip;
              if (id is int) {
                _currentUserId = id;
              } else if (id != null) {
                _currentUserId = int.tryParse(id.toString());
              }
            });
            _userLoaded = true;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _checkFollowStatus() async {
    final prefs = context.read<AppPrefs>();
    final res = await GuestAuthHelper.callWithAuthRetry(prefs, () {
      return _api.checkFollowStatus(_streamerIdForApi());
    });
    if (res != null && ApiResult.isSuccess(res)) {
      final data = res.data['data'];
      if (data is Map) {
        final followed = data['is_followed'] == true || data['is_followed'] == 1;
        if (mounted) setState(() => _isFollowed = followed);
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_followLoading) return;
    final wasFollowed = _isFollowed;
    setState(() => _followLoading = true);

    final prefs = context.read<AppPrefs>();
    final sId = int.tryParse(_streamerIdForApi());
    if (sId == null) {
      setState(() => _followLoading = false);
      _toast('主播ID格式错误');
      return;
    }

    final res = await GuestAuthHelper.callWithAuthRetry(prefs, () {
      return _api.followStreamer({'streamer_id': sId});
    });

    if (!mounted) return;
    if (res != null && ApiResult.isSuccess(res)) {
      setState(() {
        _isFollowed = !wasFollowed;
        _followLoading = false;
      });
      if (_isFollowed) {
        _socket?.emit('follow-streamer', {'streamer_name': widget.streamerName});
      }
    } else {
      setState(() => _followLoading = false);
      _toast(ApiResult.getErrorMessage(res!) ?? '关注失败');
    }
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    if (_socket?.connected != true) {
      _toast('未连接，请稍后重试');
      return;
    }
    if (!_roomJoined) {
      _toast('正在加入房间，请稍候');
      return;
    }
    if (!_validateChatLevel(isBarrage: _isBarrageMode)) return;

    final isBarrage = _isBarrageMode;
    _msgCtrl.clear();
    _socket!.emit('send-message', {
      'content': text,
      'is_barrage': isBarrage ? 1 : 0,
    });
    _closeChatPanel();
  }

  void _openChatPanel() {
    setState(() => _showChatPanel = true);
  }

  void _closeChatPanel() {
    FocusScope.of(context).unfocus();
    setState(() => _showChatPanel = false);
  }

  Widget _buildChatPanel() {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _isBarrageMode = !_isBarrageMode),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isBarrageMode ? Colors.redAccent.withOpacity(0.85) : Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _isBarrageMode && _barragePrice > 0 ? '弹幕$_barragePrice币' : '弹幕',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: TextField(
                  controller: _msgCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Color(0xFF333333), fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: '说点什么',
                    hintStyle: TextStyle(color: Color(0xFF999999)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _sendMessage,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF6B9D), Color(0xFFFF4081)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('发送', style: TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (_cleanModeActive || _scrollPending) return;
    _scrollPending = true;
    Future.delayed(const Duration(milliseconds: 80), () {
      _scrollPending = false;
      if (_msgScrollCtrl.hasClients) {
        _msgScrollCtrl.jumpTo(0);
      }
    });
  }

  void _showOfflineDialog(String msg) {
    if (!mounted) return;
    setState(() => _isOffline = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('提示'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _wasBackgrounded = true;
        context.read<GlobalTrialService>().stopWatching();
        _videoPlayerKey.currentState?.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        if (_wasBackgrounded) {
          _wasBackgrounded = false;
          _onAppResumed();
        }
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _onAppResumed() async {
    await context.read<GlobalTrialService>().refreshFromServer();
    if (!mounted) return;
    await _loadCurrentUser();
    if (!mounted) return;
    if (!_canPlayLive) {
      _videoPlayerKey.currentState?.pausePlayback();
      if (_liveVipBlocked && !_vipPromptOpen && mounted) {
        _handleLiveVipPromptFlow();
      }
    } else {
      _videoPlayerKey.currentState?.onAppResumed();
      _startGlobalTrialWatching();
    }
    if (_socket?.connected != true) {
      _connectSocket();
    }
  }

  @override
  void dispose() {
    try {
      context.read<GlobalTrialService>().stopWatching();
    } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    _barrageTimer?.cancel();
    _historyFallbackTimer?.cancel();
    _messageUiTimer?.cancel();
    _svgaKey.currentState?.clear();
    _messagesTick.dispose();
    _barrageTick.dispose();
    _onlineCountNotifier.dispose();
    _teardownSocket();
    _msgCtrl.dispose();
    _msgScrollCtrl.dispose();
    _cleanAnimCtrl?.dispose();
    unawaited(ScreenWakeLock.release());
    super.dispose();
  }

  double _screenWidth(BuildContext context) => MediaQuery.of(context).size.width;

  double _cleanHiddenX(BuildContext context) => _screenWidth(context) + 200;

  double _cleanThreshold(BuildContext context) => _screenWidth(context) * 0.2;

  void _animateCleanTranslate(double to, {bool? cleanMode, int durationMs = 200}) {
    final ctrl = _cleanAnimCtrl;
    if (ctrl == null) return;
    ctrl.stop();
    ctrl.duration = Duration(milliseconds: durationMs);
    final from = _uiTranslateX;
    _cleanAnim = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: ctrl, curve: Curves.easeOut),
    );
    void listener() {
      if (mounted) setState(() => _uiTranslateX = _cleanAnim!.value);
    }
    ctrl.addListener(listener);
    ctrl.forward(from: 0).whenComplete(() {
      ctrl.removeListener(listener);
      if (!mounted) return;
      setState(() {
        if (cleanMode != null) _cleanModeActive = cleanMode;
      });
    });
  }

  void _onCleanDragStart(DragStartDetails details) {
    if (_showChatPanel || _showGiftPanel) return;
    _cleanAnimCtrl?.stop();
    _isDraggingClean = true;
    _dragStartX = details.globalPosition.dx;
    _dragOffsetFromStart = 0;
  }

  void _onCleanDragUpdate(DragUpdateDetails details) {
    if (!_isDraggingClean || _showChatPanel || _showGiftPanel) return;
    final sw = _screenWidth(context);
    _dragOffsetFromStart = details.globalPosition.dx - _dragStartX;
    setState(() {
      if (_cleanModeActive) {
        if (_dragOffsetFromStart < 0) {
          _uiTranslateX = (sw + _dragOffsetFromStart).clamp(0, sw);
        }
      } else if (_dragOffsetFromStart > 0) {
        _uiTranslateX = _dragOffsetFromStart.clamp(0, sw);
      }
    });
  }

  void _onCleanDragEnd(DragEndDetails details) {
    if (!_isDraggingClean) return;
    _isDraggingClean = false;
    if (_showChatPanel || _showGiftPanel) return;

    final sw = _screenWidth(context);
    final threshold = _cleanThreshold(context);
    final hidden = _cleanHiddenX(context);
    final offset = _dragOffsetFromStart;

    if (_cleanModeActive) {
      if (offset < -threshold) {
        _animateCleanTranslate(0, cleanMode: false);
      } else if (offset < -20) {
        _animateCleanTranslate(hidden, cleanMode: true, durationMs: 150);
      } else {
        setState(() {
          _uiTranslateX = hidden;
          _cleanModeActive = true;
        });
      }
    } else {
      if (offset > threshold) {
        _animateCleanTranslate(hidden, cleanMode: true);
      } else if (offset > 20) {
        _animateCleanTranslate(0, cleanMode: false, durationMs: 150);
      } else {
        setState(() => _uiTranslateX = 0);
      }
    }
  }

  void _onCleanDragCancel() {
    _isDraggingClean = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: _LiveRoomVideoPlayer(
                key: _videoPlayerKey,
                playUrl: widget.playUrl,
                isOffline: _isOffline,
                allowPlayback: _canPlayLive,
                offlinePlaceholder: _buildOfflinePlaceholder(),
              ),
            ),
          ),
          if (_showTrialCountdown) _buildTrialCountdownBadge(),
          Transform.translate(
            offset: Offset(_uiTranslateX, 0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _buildTopBar(),
                _buildGiftBanner(),
                // SVGA 在消息列表下层，且仅在播放时挂载 PlatformView，避免全屏遮挡聊天
                Positioned.fill(child: LiveGiftSvgaOverlay(key: _svgaKey)),
                _buildMessageList(),
                _buildBottomBar(),
                _buildBarrageOverlay(),
              ],
            ),
          ),
          if (!_showChatPanel && !_showGiftPanel)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: _onCleanDragStart,
                onHorizontalDragUpdate: _onCleanDragUpdate,
                onHorizontalDragEnd: _onCleanDragEnd,
                onHorizontalDragCancel: _onCleanDragCancel,
              ),
            ),
          if (_showChatPanel) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeChatPanel,
                child: Container(color: Colors.black.withOpacity(0.3)),
              ),
            ),
            _buildChatPanel(),
          ],
          Offstage(
            offstage: !_showGiftPanel,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _showGiftPanel = false),
                    child: Container(color: Colors.black.withOpacity(0.3)),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: GiftPanel(
                    streamerId: widget.streamerId,
                    onGiftSent: _handleGiftSent,
                    onClose: () => setState(() => _showGiftPanel = false),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialCountdownBadge() {
    return Consumer<GlobalTrialService>(
      builder: (context, trial, _) {
        if (trial.liveTrialRemaining <= 0) return const SizedBox.shrink();
        return Positioned(
          top: MediaQuery.of(context).padding.top + 48,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade400.withOpacity(0.6)),
            ),
            child: Text(
              '试看剩余 ${trial.liveTrialRemaining} 秒',
              style: TextStyle(
                color: Colors.amber.shade200,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOfflinePlaceholder() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            const Text('主播已下播', style: TextStyle(color: Colors.white54, fontSize: 18)),
            const SizedBox(height: 8),
            if (widget.coverUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: widget.coverUrl,
                  width: 200,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[800]),
                  errorWidget: (_, __, ___) => Container(color: Colors.grey[800]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final top = MediaQuery.of(context).padding.top + 8;
    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StreamerInfoPill(
            avatar: widget.coverUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: ImageUrl.getImageUrl(widget.coverUrl),
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _avatarPlaceholder(),
                  )
                : _avatarPlaceholder(),
            name: widget.streamerName,
            roomId: widget.streamerId,
            followed: _isFollowed,
            followLoading: _followLoading,
            onFollowTap: _toggleFollow,
          ),
          ValueListenableBuilder<int>(
            valueListenable: _onlineCountNotifier,
            builder: (_, count, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: LiveRoomColors.streamerPillBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Image.asset(
      AvatarHelper.assetPath,
      width: 36,
      height: 36,
      fit: BoxFit.cover,
    );
  }

  /// 弹幕叠加层
  Widget _buildBarrageOverlay() {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      height: 200,
      child: IgnorePointer(
        child: ValueListenableBuilder<int>(
          valueListenable: _barrageTick,
          builder: (_, __, ___) {
            return Column(
              children: _barrages.reversed.take(5).map((barrage) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4, left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${barrage['username'] ?? ''}: ${barrage['content'] ?? ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGiftBanner() {
    final bottom = _messageListBottom(context, chatPanelOpen: _showChatPanel) + 200 + 6;
    return Positioned(
      left: 10,
      right: 80,
      bottom: bottom,
      child: LiveGiftBannerOverlay(
        key: _giftBannerKey,
        currentUserId: _currentUserId,
      ),
    );
  }

  Widget _buildMessageList() {
    return ValueListenableBuilder<int>(
      valueListenable: _messagesTick,
      builder: (context, _, __) {
        final bottom = _messageListBottom(context, chatPanelOpen: _showChatPanel);
        final maxBubbleWidth = MediaQuery.sizeOf(context).width - 10 - 80 - 8;
        return Positioned(
          left: 10,
          right: 80,
          bottom: bottom,
          height: 200,
          child: ListView.builder(
            controller: _msgScrollCtrl,
            reverse: true,
            cacheExtent: 120,
            addAutomaticKeepAlives: false,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[_messages.length - 1 - index];
              return LiveMessageBubble(
                key: ValueKey(msg['id'] ?? index),
                msg: msg,
                currentUserId: _currentUserId,
                maxWidth: maxBubbleWidth,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final bottom = MediaQuery.of(context).padding.bottom + 20;
    return Positioned(
      bottom: bottom,
      left: 15,
      right: 15,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _openChatPanel,
                    child: Container(
                      height: 36,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: LiveRoomColors.chatInputBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: LiveRoomColors.chatInputStroke),
                      ),
                      child: const Text(
                        '说点什么...',
                        style: TextStyle(color: Color(0x99FFFFFF), fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                if (widget.caipiaoInfo != null) ...[
                  const SizedBox(width: 12),
                  _bottomIconButton(Icons.sports_esports_outlined, _showGameEntry),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _bottomGiftButton(),
          const SizedBox(width: 8),
          _bottomCloseButton(),
        ],
      ),
    );
  }

  Widget _bottomCloseButton() {
    return Material(
      color: Colors.black.withOpacity(0.35),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 36,
        height: 36,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, color: Colors.white, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Widget _bottomGiftButton() {
    return GestureDetector(
      onTap: _openGiftPanel,
      behavior: HitTestBehavior.opaque,
      child: Image.asset(
        LiveRoomAssets.giftIcon,
        width: 36,
        height: 36,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _bottomIconButton(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: Colors.white, size: 26),
        onPressed: onTap,
      ),
    );
  }

  void _showGameEntry() {
    final info = widget.caipiaoInfo;
    if (info == null) return;
    AppToast.show('${info.nameZh ?? info.biaoshi ?? '游戏'} 入口开发中', context: context);
  }

  void _openGiftPanel() {
    setState(() => _showGiftPanel = true);
  }
}

/// 抖音风主播信息胶囊：头像 36 + 昵称/ID + 关注钮（对齐 activity_live_room.xml）
class _StreamerInfoPill extends StatelessWidget {
  static const _pillHeight = 44.0;
  static const _avatarSize = 36.0;
  /// 昵称/ID 固定宽度，超长省略，不把胶囊撑宽（对齐抖音约 4～5 字）
  static const _textWidth = 72.0;

  final Widget avatar;
  final String name;
  final String roomId;
  final bool followed;
  final bool followLoading;
  final VoidCallback onFollowTap;

  const _StreamerInfoPill({
    required this.avatar,
    required this.name,
    required this.roomId,
    required this.followed,
    required this.followLoading,
    required this.onFollowTap,
  });

  @override
  Widget build(BuildContext context) {
    // 右侧在线人数约占 56px，保证胶囊在窄屏也不溢出
    final maxPillWidth = MediaQuery.sizeOf(context).width - 24 - 56;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxPillWidth),
      child: Container(
        height: _pillHeight,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: LiveRoomColors.streamerPillBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipOval(
              child: SizedBox(width: _avatarSize, height: _avatarSize, child: avatar),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _textWidth),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: $roomId',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 10,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _DouyinFollowButton(
              followed: followed,
              loading: followLoading,
              onTap: onFollowTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// 关注钮：高 26、圆角 14，未关注「+ 关注」/ 已关注灰底（对齐原生 bg_live_follow_btn）
class _DouyinFollowButton extends StatelessWidget {
  static const _btnHeight = 26.0;

  final bool followed;
  final bool loading;
  final VoidCallback onTap;

  const _DouyinFollowButton({
    required this.followed,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: _btnHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        constraints: const BoxConstraints(minWidth: 40),
        decoration: BoxDecoration(
          color: followed ? LiveRoomColors.followDoneBg : LiveRoomColors.followActive,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
              )
            : Text(
                followed ? '已关注' : '+ 关注',
                style: TextStyle(
                  color: followed ? LiveRoomColors.followDoneText : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
      ),
    );
  }
}

/// 独立视频层，避免消息刷新时重建播放器
class _LiveRoomVideoPlayer extends StatefulWidget {
  final String playUrl;
  final bool isOffline;
  final bool allowPlayback;
  final Widget offlinePlaceholder;

  const _LiveRoomVideoPlayer({
    super.key,
    required this.playUrl,
    required this.isOffline,
    this.allowPlayback = true,
    required this.offlinePlaceholder,
  });

  @override
  State<_LiveRoomVideoPlayer> createState() => _LiveRoomVideoPlayerState();
}

class _LiveRoomVideoPlayerState extends State<_LiveRoomVideoPlayer> {
  final FijkPlayer _player = FijkPlayer();
  bool _recovering = false;

  /// 应用进入后台时暂停（对齐原生 Surface 销毁行为）
  Future<void> pausePlayback() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  Future<void> resumePlayback() async {
    if (!widget.allowPlayback || widget.isOffline || widget.playUrl.isEmpty) return;
    try {
      if (_player.value.state == FijkState.idle) {
        await _openStream();
      } else {
        await _player.start();
      }
    } catch (_) {}
  }

  Future<void> onAppPaused() async {
    if (widget.isOffline) return;
    await pausePlayback();
  }

  /// 从后台回到前台时重新拉流，恢复直播画面
  Future<void> onAppResumed() async {
    if (!widget.allowPlayback || widget.isOffline || widget.playUrl.isEmpty || _recovering) return;
    _recovering = true;
    try {
      await _recoverPlayback();
    } finally {
      _recovering = false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.allowPlayback) {
      _openStream();
    }
  }

  Future<void> _openStream() async {
    if (!widget.allowPlayback || widget.playUrl.isEmpty || widget.isOffline) return;
    try {
      await FijkPlayerHelper.openUrl(_player, widget.playUrl, isLive: true);
    } catch (e) {
      debugPrint('播放器初始化失败: $e');
    }
  }

  Future<void> _recoverPlayback() async {
    if (!mounted || widget.playUrl.isEmpty || widget.isOffline) return;
    try {
      await _player.reset();
      await FijkPlayerHelper.openUrl(_player, widget.playUrl, isLive: true);
    } catch (e) {
      debugPrint('恢复直播播放失败: $e');
    }
  }

  @override
  void didUpdateWidget(covariant _LiveRoomVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOffline && !oldWidget.isOffline) {
      _player.pause();
      return;
    }
    if (!widget.allowPlayback && oldWidget.allowPlayback) {
      pausePlayback();
    } else if (widget.allowPlayback && !oldWidget.allowPlayback && !widget.isOffline) {
      resumePlayback();
    }
  }

  @override
  void dispose() {
    _player.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOffline) return widget.offlinePlaceholder;
    return FijkVideoView(player: _player, fit: FijkFit.cover);
  }
}
