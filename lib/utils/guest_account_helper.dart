import 'package:videoweb_flutter/api/models/user.dart';

/// 游客 / 正式用户判断（优先读后端 is_guest、account_label）
class GuestAccountHelper {
  static final RegExp _mobilePhone = RegExp(r'^1[3-9]\d{9}$');

  static bool hasBoundPhone(UserInfo? user) {
    final phone = user?.phone?.trim() ?? '';
    return _mobilePhone.hasMatch(phone);
  }

  static bool hasFormalized(UserInfo? user) {
    final at = user?.formalAt?.trim() ?? '';
    return at.isNotEmpty;
  }

  static bool isGuestAccount(UserInfo? user) {
    if (user == null) return false;
    if (hasBoundPhone(user)) return false;
    if (hasFormalized(user)) return false;
    if (user.isGuest == true) return true;
    if (user.isGuest == false) {
      // 旧服务端 is_guest 默认为 0；未转正时仍按游客
      return true;
    }
    final label = user.accountLabel?.trim() ?? '';
    if (label.startsWith('游客')) return true;
    final nick = user.nickname?.trim() ?? '';
    if (nick.startsWith('游客')) return true;
    return true;
  }

  static bool isFormalAccount(UserInfo? user) => user != null && !isGuestAccount(user);

  /// 展示用：游客1422 / {昵称前缀}1422（前缀由后台 user_nickname_prefix 配置）
  static String accountDisplayLabel(UserInfo? user) {
    final label = user?.accountLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    final nick = user?.nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    final u = user?.username?.trim() ?? '';
    if (u.isEmpty) return '--';
    return isFormalAccount(user) ? '用户$u' : '游客$u';
  }

  /// 登录账号（纯数字账号，用于复制）
  static String loginAccount(UserInfo? user) {
    return user?.username?.trim() ?? user?.id?.toString() ?? '';
  }

  /// 个人中心复制行：账号:1422
  static String accountCopyLine(UserInfo? user) {
    final u = loginAccount(user);
    if (u.isEmpty) return '';
    return '账号:$u';
  }

  static bool isGuestPhone(String? phone) {
    return !_mobilePhone.hasMatch(phone?.trim() ?? '');
  }
}
