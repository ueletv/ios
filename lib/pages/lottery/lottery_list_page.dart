import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/lottery.dart';
import 'package:videoweb_flutter/pages/lottery/lottery_detail_page.dart';
import 'package:videoweb_flutter/utils/image_url.dart';

/// 彩票列表页面（对应原生 LotteryListActivity.kt）
class LotteryListPage extends StatefulWidget {
  const LotteryListPage({super.key});

  @override
  State<LotteryListPage> createState() => _LotteryListPageState();
}

class _LotteryListPageState extends State<LotteryListPage> {
  final ApiService _api = ApiService();
  List<LotteryItem> _lotteryList = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getCaipiaoList();
      if (ApiResult.isSuccess(res)) {
        final data = res.data['data'];
        if (data is List) {
          setState(() {
            _lotteryList = data
                .map((e) => LotteryItem.fromJson(e as Map<String, dynamic>))
                .toList();
            _loading = false;
          });
          return;
        }
      }
      setState(() {
        _loading = false;
        _error = '加载失败';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _openDetail(LotteryItem item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LotteryDetailPage(lotteryItem: item),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D2B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D2B),
        elevation: 0,
        title: const Text(
          '彩票列表',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.amber));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_lotteryList.isEmpty) {
      return const Center(
        child: Text('暂无彩票', style: TextStyle(color: Colors.white54, fontSize: 16)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: _lotteryList.length,
          itemBuilder: (context, index) {
            final item = _lotteryList[index];
            return _LotteryListItem(
              item: item,
              onTap: () => _openDetail(item),
            );
          },
        ),
      ),
    );
  }
}

/// 彩票列表项卡片
class _LotteryListItem extends StatelessWidget {
  final LotteryItem item;
  final VoidCallback onTap;

  const _LotteryListItem({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1E4A), Color(0xFF2A2A5E)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (item.icon?.isNotEmpty == true)
              CachedNetworkImage(
                imageUrl: ImageUrl.getImageUrl(item.icon),
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                placeholder: (_, __) =>
                    Container(width: 44, height: 44, color: Colors.transparent),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.sports_esports,
                  color: Colors.amber,
                  size: 36,
                ),
              )
            else
              const Icon(Icons.sports_esports, color: Colors.amber, size: 36),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.nameZh,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            if (item.expects?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                '第${item.expects}期',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
