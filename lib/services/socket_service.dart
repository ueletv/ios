import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:videoweb_flutter/api/api_client.dart';

/// Socket.IO 直播聊天服务（对应 LiveSocket.kt）
class SocketService {
  IO.Socket? _socket;
  String? _currentRoomId;

  // 回调
  VoidCallback? onConnect;
  VoidCallback? onDisconnect;
  void Function(Map<String, dynamic>)? onAuthenticated;
  void Function(Map<String, dynamic>)? onJoinedRoom;
  void Function(Map<String, dynamic>)? onNewMessage;
  void Function(Map<String, dynamic>)? onNewGift;
  void Function(List<dynamic>)? onHistoryMessages;
  void Function(Map<String, dynamic>)? onStreamerOffline;
  void Function(Map<String, dynamic>)? onUserJoined;
  void Function(Map<String, dynamic>)? onUserLeft;
  void Function(Map<String, dynamic>)? onMyFollow;
  void Function(Map<String, dynamic>)? onError;
  void Function(Map<String, dynamic>)? onAuthError;
  void Function(Map<String, dynamic>)? onLotteryBetMessage;
  /// 大厅列表：主播上/下播（streamer-list-update）
  void Function(String streamerId, int status)? onStreamerListUpdate;

  bool get isConnected => _socket?.connected ?? false;

  /// 连接到直播间服务器
  void connect(String token) {
    if (_socket != null) disconnect();

    final serverUrl = ApiClient.baseUrl.replaceAll(RegExp(r'/$'), '');

    _socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'query': {'token': token},
    });

    _socket!.onConnect((_) {
      onConnect?.call();
      // 认证
      _socket!.emit('authenticate', {'token': token});
    });

    _socket!.onDisconnect((_) {
      onDisconnect?.call();
    });

    _socket!.on('authenticated', (data) {
      if (data is Map) {
        onAuthenticated?.call(Map<String, dynamic>.from(data as Map));
      }
    });

    _socket!.on('auth-error', (data) {
      if (data is Map) {
        onAuthError?.call(Map<String, dynamic>.from(data as Map));
      }
    });

    _socket!.on('joined-room', (data) {
      if (data is Map) {
        onJoinedRoom?.call(Map<String, dynamic>.from(data as Map));
      }
    });

    _socket!.on('new-message', (data) {
      if (data is Map) {
        onNewMessage?.call(Map<String, dynamic>.from(data as Map));
      }
    });

    _socket!.on('new-gift', (data) {
      if (data is Map) {
        onNewGift?.call(Map<String, dynamic>.from(data as Map));
      }
    });

    _socket!.on('history-messages', (data) {
      if (data is List) {
        onHistoryMessages?.call(data as List<dynamic>);
      }
    });

    _socket!.on('streamer-offline', (data) {
      if (data is Map) {
        onStreamerOffline?.call(Map<String, dynamic>.from(data as Map));
      }
    });

    _socket!.on('streamer-list-update', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data as Map);
        final sid = (map['streamer_id'] ?? map['streamerId'] ?? '').toString();
        final status = map['status'] is int ? map['status'] as int : int.tryParse('${map['status']}') ?? 0;
        onStreamerListUpdate?.call(sid, status);
      }
    });

    _socket!.on('user-joined', (data) {
      if (data is Map) {
        onUserJoined?.call(Map<String, dynamic>.from(data as Map));
      }
    });

    _socket!.on('user-left', (data) {
      if (data is Map) {
        onUserLeft?.call(Map<String, dynamic>.from(data as Map));
      }
    });

    _socket!.on('my-follow', (data) {
      if (data is Map) {
        onMyFollow?.call(Map<String, dynamic>.from(data as Map));
      }
    });

    _socket!.on('lottery-bet-message', (data) {
      if (data is Map) {
        onLotteryBetMessage?.call(Map<String, dynamic>.from(data as Map));
      }
    });

    _socket!.connect();
  }

  /// 加入房间
  void joinRoom(String roomId) {
    _currentRoomId = roomId;
    _socket?.emit('join-room', {'roomId': roomId});
  }

  /// 离开房间
  void leaveRoom() {
    if (_currentRoomId != null) {
      _socket?.emit('leave-room');
      _currentRoomId = null;
    }
  }

  /// 发送消息
  void sendMessage(String streamerId, String content, {int isBarrage = 0}) {
    _socket?.emit('send-message', {
      'streamer_id': streamerId,
      'content': content,
      'is_barrage': isBarrage,
    });
  }

  /// 发送礼物（Socket 广播）
  void sendGiftBroadcast({
    required dynamic giftId,
    required String giftName,
    String? giftIcon,
    String? giftImage,
    int displayDuration = 4,
    int count = 1,
  }) {
    _socket?.emit('send-gift', {
      'gift_id': giftId,
      'gift_name': giftName,
      'gift_icon': giftIcon ?? '',
      'gift_image': giftImage ?? '',
      'display_duration': displayDuration,
      'count': count,
    });
  }

  /// 广播下注消息
  void broadcastBet(Map<String, dynamic> betData) {
    _socket?.emit('lottery-bet', betData);
  }

  /// 广播关注消息
  void broadcastFollow(String streamerName) {
    _socket?.emit('follow-streamer', {'streamer_name': streamerName});
  }

  /// 断开连接
  void disconnect() {
    leaveRoom();
    final s = _socket;
    _socket = null;
    if (s == null) return;
    s.clearListeners();
    s.disconnect();
    s.dispose();
  }

  void dispose() {
    disconnect();
    onConnect = null;
    onDisconnect = null;
    onAuthenticated = null;
    onJoinedRoom = null;
    onNewMessage = null;
    onNewGift = null;
    onHistoryMessages = null;
    onStreamerOffline = null;
    onUserJoined = null;
    onUserLeft = null;
    onMyFollow = null;
    onError = null;
    onAuthError = null;
    onLotteryBetMessage = null;
    onStreamerListUpdate = null;
  }
}

typedef VoidCallback = void Function();
