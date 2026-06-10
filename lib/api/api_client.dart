import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:videoweb_flutter/services/device_info_service.dart';
/// 网络请求客户端（对应原生 RetrofitClient.kt）
class ApiClient {
  static const String _defaultBaseUrl = 'https://app.16kkk.cc/';

  static String _baseUrl = _defaultBaseUrl;
  static String get baseUrl => _baseUrl;

  static Dio? _dio;
  static Function()? onUnauthorized;

  static String? Function()? _tokenProvider;

  static void setTokenProvider(String? Function() provider) {
    _tokenProvider = provider;
  }

  static void setBaseUrl(String url) {
    _baseUrl = url.trim().endsWith('/') ? url : '$url/';
    _dio = null;
  }

  static Dio get dio {
    if (_dio != null) return _dio!;
    _dio = _createDio();
    return _dio!;
  }

  static Dio _createDio() {
    final d = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // 请求拦截器：Token + 设备 User-Agent（后台识别安卓/iOS）
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = _tokenProvider?.call();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        try {
          options.headers['User-Agent'] = await DeviceInfoService.appUserAgent();
        } catch (_) {}
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));

    // 限制并发连接，避免 FD 耗尽（日志里 Too many open files）
    final adapter = IOHttpClientAdapter();
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.maxConnectionsPerHost = 6;
      return client;
    };
    d.httpClientAdapter = adapter;

    if (kDebugMode) {
      d.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: false,
        logPrint: (obj) => debugPrint('[API] $obj'),
      ));
    }

    return d;
  }
}
