/// 通用 API 响应（对应原生 ApiResponse.kt）
class ApiResponse<T> {
  final int code;
  final String? message;
  final T? data;
  final Pagination? pagination;
  final int? total;

  ApiResponse({
    required this.code,
    this.message,
    this.data,
    this.pagination,
    this.total,
  });

  bool isSuccess() => code == 200 || code == 1 || code == 0;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T? Function(dynamic)? dataParser,
  ) {
    return ApiResponse(
      code: json['code'] as int? ?? 0,
      message: json['message'] as String?,
      data: json['data'] != null && dataParser != null
          ? dataParser(json['data'])
          : json['data'] as T?,
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
      total: json['total'] as int?,
    );
  }
}

class Pagination {
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  Pagination({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      totalPages: json['total_pages'] as int? ?? 1,
    );
  }
}
