import 'package:dio/dio.dart';
import 'package:videoweb_flutter/api/api_client.dart';
import 'package:videoweb_flutter/api/models/comment.dart';
import 'package:videoweb_flutter/api/models/video_id_body.dart';

/// API 接口定义（对应原生 ApiService.kt）
class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  Dio get _dio => ApiClient.dio;

  // ========= 配置 =========

  Future<Response> getConfig() => _dio.get('/config');

  Future<Response> getSplashAds() => _dio.get('/config/splash-ads');

  Future<Response> getPopupAds() => _dio.get('/config/popup-ads');

  Future<Response> getConfigAds(String adType) =>
      _dio.get('/config/ads', queryParameters: {'ad_type': adType});

  // ========= Banner =========

  Future<Response> getBannerList({String? type}) {
    final params = <String, dynamic>{};
    if (type != null) params['type'] = type;
    return _dio.get('/banner/list', queryParameters: params);
  }

  // ========= 公告 =========

  Future<Response> getNoticeList() => _dio.get('/notice/list');

  // ========= 分类 =========

  Future<Response> getCategoryList() => _dio.get('/category/list');

  // ========= 用户 =========

  Future<Response> register(Map<String, String> body) =>
      _dio.post('/user/register', data: body);

  Future<Response> login(Map<String, String> body) =>
      _dio.post('/user/login', data: body);

  Future<Response> loginByPhone(Map<String, String> body) =>
      _dio.post('/user/login-by-phone', data: body);

  Future<Response> getUserInfo() => _dio.get('/user/info');

  Future<Response> consumeTrialSeconds(int seconds, {String type = 'video'}) =>
      _dio.post('/user/trial/consume', data: {'seconds': seconds, 'type': type});

  Future<Response> updateUserInfo(Map<String, dynamic> body) =>
      _dio.post('/user/update', data: body);

  Future<Response> changePassword(Map<String, dynamic> body) =>
      _dio.post('/user/change-password', data: body);

  Future<Response> bindPhone(Map<String, dynamic> body) =>
      _dio.post('/user/bind-phone', data: body);

  // ========= 视频 =========

  Future<Response> getVideoList({
    int? page,
    int? pageSize,
    String? categoryId,
    String? categoryIds,
    String? includeChildren,
    String? keyword,
    String? sort,
    String? order,
  }) {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (pageSize != null) params['page_size'] = pageSize;
    if (categoryId != null) params['category_id'] = categoryId;
    if (categoryIds != null) params['category_ids'] = categoryIds;
    if (includeChildren != null) params['include_children'] = includeChildren;
    if (keyword != null) params['keyword'] = keyword;
    if (sort != null) params['sort'] = sort;
    if (order != null) params['order'] = order;
    return _dio.get('/video/list', queryParameters: params);
  }

  Future<Response> getVideoDetail(String id) =>
      _dio.get('/video/detail', queryParameters: {'id': id});

  Future<Response> getRecommend({int? page, int? pageSize}) {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (pageSize != null) params['page_size'] = pageSize;
    return _dio.get('/video/recommend', queryParameters: params);
  }

  Future<Response> getHotList({int? page, int? pageSize, String? feed}) {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (pageSize != null) params['page_size'] = pageSize;
    if (feed != null) params['feed'] = feed;
    return _dio.get('/video/hot', queryParameters: params);
  }

  Future<Response> toggleLike(VideoIdBody body) =>
      _dio.post('/video/like', data: body.toJson());

  Future<Response> recordVideoView(VideoIdBody body) =>
      _dio.post('/video/view', data: body.toJson());

  Future<Response> getViewHistory({int? page, int? pageSize}) {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (pageSize != null) params['page_size'] = pageSize;
    return _dio.get('/video/view/history', queryParameters: params);
  }

  Future<Response> clearViewHistory() => _dio.post('/video/view/history/clear');

  Future<Response> shareVideo(VideoIdBody body) =>
      _dio.post('/video/share', data: body.toJson());

  Future<Response> searchVideos(String keyword, {int? page, int? pageSize}) {
    final params = <String, dynamic>{'keyword': keyword};
    if (page != null) params['page'] = page;
    if (pageSize != null) params['page_size'] = pageSize;
    return _dio.get('/video/search', queryParameters: params);
  }

  Future<Response> getHotSearchKeywords({int limit = 10}) =>
      _dio.get('/video/search/hot', queryParameters: {'limit': limit});

  // ========= 直播 - 主播 =========

  Future<Response> getStreamerList({
    String? type,
    String? keyword,
    int? page,
    int? pageSize,
  }) {
    final params = <String, dynamic>{};
    if (type != null) params['type'] = type;
    if (keyword != null) params['keyword'] = keyword;
    if (page != null) params['page'] = page;
    if (pageSize != null) params['page_size'] = pageSize;
    return _dio.get('/streamer/list', queryParameters: params);
  }

  Future<Response> checkStreamerOnline(String streamerId) =>
      _dio.get('/streamer/check-online', queryParameters: {'streamer_id': streamerId});

  Future<Response> followStreamer(Map<String, dynamic> body) =>
      _dio.post('/streamer/follow', data: body);

  Future<Response> checkFollowStatus(String streamerId) =>
      _dio.get('/streamer/check-follow', queryParameters: {'streamer_id': streamerId});

  Future<Response> getGiftList() => _dio.get('/streamer/gift-list');

  Future<Response> sendGift(Map<String, dynamic> body) =>
      _dio.post('/streamer/send-gift', data: body);

  Future<Response> getMyGiftRecords({int page = 1, int pageSize = 20}) =>
      _dio.get('/streamer/my-gift-records', queryParameters: {
        'page': page, 'page_size': pageSize,
      });

  Future<Response> getChatMessages(String streamerId, {int page = 1, int pageSize = 50}) =>
      _dio.get('/streamer/chat-messages', queryParameters: {
        'streamer_id': streamerId, 'page': page, 'page_size': pageSize,
      });

  // ========= 收藏 =========

  Future<Response> toggleFavorite(VideoIdBody body) =>
      _dio.post('/favorite/toggle', data: body.toJson());

  Future<Response> getFavoriteList({int? page, int? pageSize}) {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (pageSize != null) params['page_size'] = pageSize;
    return _dio.get('/favorite/list', queryParameters: params);
  }

  // ========= 评论 =========

  Future<Response> getCommentList(String videoId, {int? page, int? pageSize}) {
    final params = <String, dynamic>{'video_id': videoId};
    if (page != null) params['page'] = page;
    if (pageSize != null) params['page_size'] = pageSize;
    return _dio.get('/comment/list', queryParameters: params);
  }

  Future<Response> addComment(CommentAddBody body) =>
      _dio.post('/comment/add', data: body.toJson());

  Future<Response> toggleCommentLike(CommentIdBody body) =>
      _dio.post('/comment/like', data: body.toJson());

  Future<Response> deleteComment(CommentIdBody body) =>
      _dio.post('/comment/delete', data: body.toJson());

  // ========= VIP =========

  Future<Response> getVipPrice({String? type, int? all}) {
    final params = <String, dynamic>{};
    if (type != null) params['type'] = type;
    if (all != null) params['all'] = all;
    return _dio.get('/purchase/vip-price', queryParameters: params);
  }

  Future<Response> purchaseVip(Map<String, dynamic> body) =>
      _dio.post('/purchase/vip', data: body);

  // ========= 彩票 =========

  Future<Response> getCaipiaoList() => _dio.get('/caipiao/list');

  Future<Response> getCaipiaoWanfa(int id, {String? biaoshi}) {
    final params = <String, dynamic>{'id': id};
    if (biaoshi != null) params['biaoshi'] = biaoshi;
    return _dio.get('/caipiao/wanfa', queryParameters: params);
  }

  Future<Response> caipiaoTouzhu(Map<String, dynamic> body) =>
      _dio.post('/caipiao/touzhu', data: body);

  Future<Response> getCaipiaoHistory({
    int? caipiaoId,
    String? biaoshi,
    int? page,
    int? pageSize,
  }) {
    final params = <String, dynamic>{};
    if (caipiaoId != null) params['caipiao_id'] = caipiaoId;
    if (biaoshi != null) params['biaoshi'] = biaoshi;
    if (page != null) params['page'] = page;
    if (pageSize != null) params['page_size'] = pageSize;
    return _dio.get('/caipiao/history', queryParameters: params);
  }

  Future<Response> getCaipiaoTimes({int? caipiaoId, String? biaoshi}) {
    final params = <String, dynamic>{};
    if (caipiaoId != null) params['caipiao_id'] = caipiaoId;
    if (biaoshi != null) params['biaoshi'] = biaoshi;
    return _dio.get('/caipiao/times', queryParameters: params);
  }

  Future<Response> getBeishuList() => _dio.get('/caipiao/beishu-list');

  Future<Response> getMyTouzhu({int? page, int? pageSize, String? biaoshi}) {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (pageSize != null) params['page_size'] = pageSize;
    if (biaoshi != null) params['biaoshi'] = biaoshi;
    return _dio.get('/caipiao/my-touzhu', queryParameters: params);
  }

  // ========= 充值 =========

  Future<Response> getRechargeRules({String? walletType}) {
    final params = <String, dynamic>{};
    if (walletType != null) params['wallet_type'] = walletType;
    return _dio.get('/coin_recharge/list', queryParameters: params);
  }

  Future<Response> createRechargeOrder(Map<String, dynamic> body) =>
      _dio.post('/coin_recharge/create', data: body);

  Future<Response> confirmRecharge(Map<String, dynamic> body) =>
      _dio.post('/coin_recharge/confirm', data: body);

  Future<Response> getRechargeOrders({
    int? page, int? pageSize, String? walletType,
  }) {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (pageSize != null) params['page_size'] = pageSize;
    if (walletType != null) params['wallet_type'] = walletType;
    return _dio.get('/coin_recharge/orders', queryParameters: params);
  }

  // ========= 提现 =========

  Future<Response> getWithdrawConfig() => _dio.get('/withdraw/config');

  Future<Response> createWithdrawOrder(Map<String, dynamic> body) =>
      _dio.post('/withdraw/create', data: body);

  Future<Response> getWithdrawList({int? page, int? pageSize}) {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (pageSize != null) params['page_size'] = pageSize;
    return _dio.get('/withdraw/list', queryParameters: params);
  }

  // ========= 交易/收支 =========

  Future<Response> getTransactionsList({int? page, int? pageSize, String? type}) {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (pageSize != null) params['page_size'] = pageSize;
    if (type != null) params['type'] = type;
    return _dio.get('/transactions/list', queryParameters: params);
  }
}
