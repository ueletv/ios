/// 统一解析后端 data / pagination 结构
class ApiParse {
  static int? asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static List<Map<String, dynamic>> extractList(dynamic root) {
    if (root is List) {
      return root
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (root is Map) {
      final list = root['list'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return const [];
  }

  static int extractTotalPages(Map<String, dynamic> responseData, {int fallback = 1}) {
    final pagination = responseData['pagination'];
    if (pagination is Map) {
      final totalPages = asInt(pagination['total_pages']);
      if (totalPages != null && totalPages > 0) return totalPages;
    }
    final data = responseData['data'];
    if (data is Map) {
      final totalPages = asInt(data['total_pages']);
      if (totalPages != null && totalPages > 0) return totalPages;
    }
    return fallback;
  }
}
