import 'dart:convert' show Base64Decoder, JsonDecoder;

class AuthTokenUtil {
  /// 从 Authorization header 提取 Bearer Token
  static String extractToken(String? authHeader) {
    if (authHeader == null || authHeader.isEmpty) return '';
    var token = authHeader;
    while (token.isNotEmpty && (token[0] == ' ' || token[0] == '\t')) {
      token = token.substring(1);
    }
    if (token.length >= 7 &&
        (token.substring(0, 7).toLowerCase() == 'bearer ')) {
      token = token.substring(7);
    }
    return token.trim();
  }

  /// 解析 JWT Token 的 payload 部分（不校验签名）
  static Map<String, dynamic>? parseJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      final padded = normalized.padRight(
        normalized.length + (4 - normalized.length % 4) % 4,
        '=',
      );
      final decoded = String.fromCharCodes(
        const Base64Decoder().convert(padded),
      );
      return Map<String, dynamic>.from(
        const JsonDecoder().convert(decoded) as Map,
      );
    } catch (_) {
      return null;
    }
  }

  /// 从 Token 提取用户 ID
  static int? getUserIdFromToken(String token) {
    final payload = parseJwtPayload(token);
    if (payload == null) return null;
    final userId = payload['user_id'] ?? payload['id'] ?? payload['sub'];
    if (userId is int) return userId;
    if (userId is String) return int.tryParse(userId);
    return null;
  }
}
