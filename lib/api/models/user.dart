/// 用户等级信息（对应 UserLevelInfo）
class UserLevelInfo {
  final int level;
  final String levelName;
  final String? levelIcon;
  final int exp;
  final int nextLevel;
  final int nextLevelExp;
  final String? nextLevelName;
  final int expNeeded;
  final double expProgress;
  final bool isMaxLevel;

  const UserLevelInfo({
    required this.level,
    required this.levelName,
    this.levelIcon,
    required this.exp,
    required this.nextLevel,
    required this.nextLevelExp,
    this.nextLevelName,
    required this.expNeeded,
    required this.expProgress,
    required this.isMaxLevel,
  });

  factory UserLevelInfo.fromJson(Map<String, dynamic> json) {
    return UserLevelInfo(
      level: UserInfo._asInt(json['level']) ?? 0,
      levelName: json['level_name']?.toString() ?? '等级',
      levelIcon: json['level_icon']?.toString(),
      exp: UserInfo._asInt(json['exp']) ?? 0,
      nextLevel: UserInfo._asInt(json['next_level']) ?? 0,
      nextLevelExp: UserInfo._asInt(json['next_level_exp']) ?? 0,
      nextLevelName: json['next_level_name'] as String?,
      expNeeded: UserInfo._asInt(json['exp_needed']) ?? 0,
      expProgress: (json['exp_progress'] as num?)?.toDouble() ?? 0,
      isMaxLevel: json['is_max_level'] == true,
    );
  }
}

/// 用户信息模型（对应原生 User.kt 中的 UserInfo）
class UserInfo {
  final dynamic id;
  final String? username;
  final String? nickname;
  final String? avatar;
  final String? phone;
  final String? email;
  final dynamic coin;
  final dynamic coinBalance;
  final dynamic balance;
  final int? vipLevel;
  final String? vipExpireTime;
  final int? level;
  final String? levelIcon;
  final int? exp;
  final int? nextLevel;
  final int? nextLevelExp;
  final String? nextLevelName;
  final int? expNeeded;
  final double? expProgress;
  final bool? isMaxLevel;
  final UserLevelInfo? levelInfo;
  final int? followCount;
  final int? favoriteCount;
  final bool? isGuest;
  final String? accountLabel;
  final String? formalAt;
  final int? trialRemainingSeconds;
  final int? videoTrialRemainingSeconds;
  final int? liveTrialRemainingSeconds;

  UserInfo({
    this.id,
    this.username,
    this.nickname,
    this.avatar,
    this.phone,
    this.email,
    this.coin,
    this.coinBalance,
    this.balance,
    this.vipLevel,
    this.vipExpireTime,
    this.level,
    this.levelIcon,
    this.exp,
    this.nextLevel,
    this.nextLevelExp,
    this.nextLevelName,
    this.expNeeded,
    this.expProgress,
    this.isMaxLevel,
    this.levelInfo,
    this.followCount,
    this.favoriteCount,
    this.isGuest,
    this.accountLabel,
    this.formalAt,
    this.trialRemainingSeconds,
    this.videoTrialRemainingSeconds,
    this.liveTrialRemainingSeconds,
  });

  String get displayName {
    if (accountLabel != null && accountLabel!.isNotEmpty) return accountLabel!;
    if (nickname != null && nickname!.isNotEmpty) return nickname!;
    return username ?? '';
  }

  /// 优先 level_info.level_icon，兼容顶层 level_icon（对齐原生 ProfileFragment / LevelActivity）
  String? get resolvedLevelIcon {
    final fromInfo = levelInfo?.levelIcon?.trim();
    if (fromInfo != null && fromInfo.isNotEmpty) return fromInfo;
    final top = levelIcon?.trim();
    if (top != null && top.isNotEmpty) return top;
    return null;
  }

  bool get isActiveVip {
    if ((vipLevel ?? 0) != 1) return false;
    final expire = vipExpireTime?.trim();
    if (expire == null || expire.isEmpty) return true;
    try {
      return DateTime.parse(expire.replaceFirst(' ', 'T')).isAfter(DateTime.now());
    } catch (_) {
      return true;
    }
  }

  int get resolvedLevel => levelInfo?.level ?? level ?? 0;

  double get resolvedExpProgress {
    if (levelInfo != null) return levelInfo!.expProgress;
    return expProgress ?? 0;
  }

  bool get resolvedIsMaxLevel => levelInfo?.isMaxLevel ?? isMaxLevel == true;

  UserLevelInfo? get effectiveLevelInfo {
    if (levelInfo != null) return levelInfo;
    final lv = resolvedLevel;
    final userExp = exp ?? 0;
    if (lv <= 0 && userExp <= 0) return null;
    return UserLevelInfo(
      level: lv,
      levelName: '等级',
      levelIcon: resolvedLevelIcon,
      exp: exp ?? 0,
      nextLevel: nextLevel ?? 0,
      nextLevelExp: nextLevelExp ?? 0,
      nextLevelName: nextLevelName,
      expNeeded: expNeeded ?? 0,
      expProgress: resolvedExpProgress,
      isMaxLevel: resolvedIsMaxLevel,
    );
  }

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    final levelInfoRaw = json['level_info'];
    return UserInfo(
      id: json['id'],
      username: json['username'] as String?,
      nickname: json['nickname'] as String?,
      avatar: json['avatar'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      coin: json['coin'],
      coinBalance: json['coin_balance'],
      balance: json['balance'],
      vipLevel: _asInt(json['vip_level']),
      vipExpireTime: json['vip_expire_time'] as String?,
      level: _asInt(json['level']),
      levelIcon: json['level_icon']?.toString(),
      exp: _asInt(json['exp']) ?? _asInt(json['level_exp']),
      nextLevel: _asInt(json['next_level']),
      nextLevelExp: _asInt(json['next_level_exp']),
      nextLevelName: json['next_level_name'] as String?,
      expNeeded: _asInt(json['exp_needed']),
      expProgress: (json['exp_progress'] as num?)?.toDouble(),
      isMaxLevel: json['is_max_level'] as bool?,
      levelInfo: levelInfoRaw is Map
          ? UserLevelInfo.fromJson(Map<String, dynamic>.from(levelInfoRaw))
          : null,
      followCount: _asInt(json['follow_count']) ?? _asInt(json['following_count']),
      favoriteCount: _asInt(json['favorite_count']) ?? _asInt(json['collect_count']) ?? _asInt(json['favorites_count']),
      isGuest: json['is_guest'] == null
          ? null
          : (json['is_guest'] == true || json['is_guest']?.toString() == '1'),
      accountLabel: json['account_label']?.toString(),
      formalAt: json['formal_at']?.toString(),
      trialRemainingSeconds: _asInt(json['trial_remaining_seconds']) ??
          _asInt(json['video_trial_remaining_seconds']),
      videoTrialRemainingSeconds: _asInt(json['video_trial_remaining_seconds']) ??
          _asInt(json['trial_remaining_seconds']),
      liveTrialRemainingSeconds: _asInt(json['live_trial_remaining_seconds']),
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

/// 登录响应（对应原生 LoginResponse）
class LoginResponse {
  final String token;
  final UserInfo user;
  final bool? autoLogin;

  LoginResponse({
    required this.token,
    required this.user,
    this.autoLogin,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String? ?? '',
      user: UserInfo.fromJson(json['user'] as Map<String, dynamic>),
      autoLogin: json['auto_login'] as bool?,
    );
  }
}
