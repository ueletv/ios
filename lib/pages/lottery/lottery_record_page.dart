import 'package:flutter/material.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';

import 'package:videoweb_flutter/api/api_parse.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';

/// 开奖记录（对应原生 LotteryRecordActivity.kt）
class LotteryRecordPage extends StatefulWidget {
  final int? caipiaoId;
  final String? biaoshi;

  const LotteryRecordPage({
    super.key,
    this.caipiaoId,
    this.biaoshi,
  });

  @override
  State<LotteryRecordPage> createState() => _LotteryRecordPageState();
}

class _LotteryRecordPageState extends State<LotteryRecordPage> {
  final ApiService _api = ApiService();
  List<_LotteryRecordRow> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCaipiaoHistory(
        caipiaoId: widget.caipiaoId,
        biaoshi: widget.biaoshi,
        page: 1,
        pageSize: 20,
      );
      final rows = <_LotteryRecordRow>[];
      if (ApiResult.isSuccess(res)) {
        final list = ApiParse.extractList(res.data['data']);
        for (final item in list) {
          final opencode =
              item['opencode']?.toString() ?? item['open_code']?.toString() ?? '';
          rows.add(_LotteryRecordRow(
            nameZh: item['name_zh']?.toString() ?? item['name']?.toString() ?? '未知',
            expect: item['expect']?.toString() ?? '',
            numbers: opencode.split(',').where((e) => e.trim().isNotEmpty).toList(),
            opentime: item['opentime']?.toString() ?? '',
          ));
        }
      }
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) {
        AppToast.show('加载失败: $e', context: context);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text('开奖记录')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? Center(
                  child: Text('暂无开奖记录', style: TextStyle(color: Colors.grey[600])),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _LotteryRecordCard(row: _rows[index]),
                  ),
                ),
    );
  }
}

class _LotteryRecordRow {
  final String nameZh;
  final String expect;
  final List<String> numbers;
  final String opentime;

  const _LotteryRecordRow({
    required this.nameZh,
    required this.expect,
    required this.numbers,
    required this.opentime,
  });
}

class _LotteryRecordCard extends StatelessWidget {
  final _LotteryRecordRow row;

  const _LotteryRecordCard({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.nameZh, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('第 ${row.expect} 期', style: TextStyle(color: Colors.grey.shade700)),
          if (row.opentime.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(row.opentime, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
          if (row.numbers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: row.numbers
                  .map(
                    (n) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        n.trim(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
