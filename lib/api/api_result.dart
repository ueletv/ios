import 'package:dio/dio.dart';

/// 统一 API 异常处理（对应原生 ApiResult.kt）
class ApiResult {
  static bool isSuccess(Response response) {
    final data = response.data;
    if (data is Map) {
      final code = data['code'];
      return code == 200 || code == 1 || code == 0;
    }
    return response.statusCode == 200;
  }

  static String? getErrorMessage(Response response) {
    final data = response.data;
    if (data is Map) {
      final message = data['message'] as String?;
      if (message != null && message.isNotEmpty) return message;
    }
    return null;
  }

  static String? parseDioError(DioException e) {
    if (e.response?.data is Map) {
      final msg = (e.response!.data as Map)['message'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    }
    return e.message ?? '网络错误';
  }
}
