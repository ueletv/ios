import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fijkplayer/fijkplayer.dart';
import 'package:provider/provider.dart';
import 'package:videoweb_flutter/api/api_client.dart';
import 'package:videoweb_flutter/api/api_parse.dart';
import 'package:videoweb_flutter/api/api_result.dart';
import 'package:videoweb_flutter/api/api_service.dart';
import 'package:videoweb_flutter/api/models/ad.dart';
import 'package:videoweb_flutter/pages/common/announcement_dialog.dart';
import 'package:videoweb_flutter/pages/common/splash_ad_view.dart';
import 'package:videoweb_flutter/pages/home/home_page.dart';
import 'package:videoweb_flutter/pages/hot/hot_page.dart';
import 'package:videoweb_flutter/pages/game/game_page.dart';
import 'package:videoweb_flutter/pages/live/live_list_page.dart';
import 'package:videoweb_flutter/pages/profile/profile_page.dart';
import 'package:videoweb_flutter/services/app_config_cache.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';
import 'package:videoweb_flutter/services/home_prefetch_cache.dart';
import 'package:videoweb_flutter/services/global_trial_service.dart';
import 'package:videoweb_flutter/services/guest_auth_helper.dart';
import 'package:videoweb_flutter/services/main_tab_controller.dart';
import 'package:videoweb_flutter/services/popup_ad_session.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';
import 'package:videoweb_flutter/utils/image_url.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 限制图片内存缓存，减轻长时间使用后的卡顿/OOM
  PaintingBinding.instance.imageCache
    ..maximumSize = 80
    ..maximumSizeBytes = 48 << 20;

  FijkLog.setLevel(FijkLogLevel.Error);

  // 初始化本地存储
  final prefs = AppPrefs();
  await prefs.init();

  // 初始化 API 客户端
  if (prefs.apiBaseUrl != null) {
    ApiClient.setBaseUrl(prefs.apiBaseUrl!);
  }
  ApiClient.setTokenProvider(() => prefs.token);
  ApiClient.onUnauthorized = () {
    prefs.clearToken();
  };

  // 设置图片基础 URL
  final baseForApi = prefs.apiBaseUrl ?? ApiClient.baseUrl;
  final imageBase = prefs.imageBaseUrl ?? baseForApi;
  ImageUrl.setBaseUrl(imageBase);

  runApp(VideoWebApp(prefs: prefs));
}

class VideoWebApp extends StatelessWidget {
  final AppPrefs prefs;

  const VideoWebApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppPrefs>.value(value: prefs),
        ChangeNotifierProvider(create: (_) => ThemeController(prefs)),
        ChangeNotifierProvider(create: (_) => MainTabController()),
        ChangeNotifierProvider(create: (_) => GlobalTrialService()),
      ],
      child: const _VideoWebRoot(),
    );
  }
}

class _VideoWebRoot extends StatelessWidget {
  const _VideoWebRoot();

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();
    return MaterialApp(
      navigatorKey: AppToast.navigatorKey,
      title: '视频直播',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeCtrl.materialThemeMode,
      home: const SplashPage(),
    );
  }
}

/// 启动页（对应原生 SplashActivity.kt）
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _loading = true;
  List<SplashAdItem> _splashAds = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = context.read<AppPrefs>();

    try {
      final data = await AppConfigCache.fetch(force: true);
      if (data != null) {
          final url = (data['api_base_url'] ?? data['platform_url'] ?? data['base_url'])
              ?.toString()
              .trim();
          if (url != null && url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
            final base = url.endsWith('/') ? url : '$url/';
            ApiClient.setBaseUrl(base);
            prefs.apiBaseUrl = base;
            final coverDomain = data['cover_domain']?.toString().trim() ?? '';
            final platformUrl = data['platform_url']?.toString().trim() ?? '';
            final rawImageBase = coverDomain.isNotEmpty
                ? coverDomain
                : (platformUrl.isNotEmpty
                    ? platformUrl
                    : base.replaceAll('/index.php', '').replaceAll(RegExp(r'/$'), ''));
            final imageBase = ImageUrl.normalizeImageBase(rawImageBase);
            if (imageBase.isNotEmpty) {
              prefs.imageBaseUrl = imageBase;
              ImageUrl.setBaseUrl(imageBase);
            }
            final defaultAvatar = data['default_avatar']?.toString().trim() ?? '';
            if (defaultAvatar.isNotEmpty) {
              prefs.defaultAvatarUrl = defaultAvatar;
            }
          }
      }
    } catch (_) {}

    if (!prefs.isLoggedIn && !prefs.autoGuestLoginPaused) {
      final ok = await GuestAuthHelper.ensureToken(prefs);
      if (!ok && GuestAuthHelper.lastError != null && mounted) {
        AppToast.show(GuestAuthHelper.lastError!, context: context);
      }
    }
    if (prefs.isLoggedIn && mounted) {
      await context.read<GlobalTrialService>().refreshFromServer();
    }

    // 登录就绪后预取首页分类+推荐内容（开屏广告展示期间并行加载）
    final homePrefetchFuture = HomePrefetchCache.prefetchAll();

    var ads = await _loadSplashAds(prefs);
    if (ads.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 300));
      ads = await _loadSplashAds(prefs);
    }

    if (!mounted) return;
    if (ads.isEmpty) {
      await homePrefetchFuture;
      if (!mounted) return;
      _goMain();
      return;
    }
    setState(() {
      _loading = false;
      _splashAds = ads;
    });
  }

  Future<List<SplashAdItem>> _loadSplashAds(AppPrefs prefs) async {
    try {
      final res = await ApiService().getSplashAds();
      if (!ApiResult.isSuccess(res)) return [];
      final rows = ApiParse.extractList(res.data['data']);
      final ads = <SplashAdItem>[];
      for (final row in rows) {
        try {
          final ad = SplashAdItem.fromJson(row);
          final cover = ad.coverImage?.trim() ?? '';
          if (cover.isEmpty) continue;
          if (ad.showOnce == 1 && prefs.hasSplashAdBeenShown(ad.id)) continue;
          ads.add(ad);
        } catch (_) {}
      }
      return ads
        ..sort((a, b) {
          final sort = b.sortOrder.compareTo(a.sortOrder);
          return sort != 0 ? sort : a.id.compareTo(b.id);
        });
    } catch (_) {
      return [];
    }
  }

  Future<void> _goMain() async {
    await HomePrefetchCache.prefetchAll();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _splashAds.isNotEmpty) {
      return SplashAdView(ads: _splashAds, onComplete: _goMain);
    }
    return Scaffold(
      body: Container(
        color: const Color(0xFFF6F7FB),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 18),
              Text(
                '正在加载...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF444444),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 主页面（对应原生 MainActivity.kt）
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  bool _popupShown = false;
  bool _popupDraining = false;
  final List<PopupAdItem> _popupQueue = [];

  final List<Widget> _pages = const [
    HomePage(),
    HotPage(),
    GamePage(),
    LiveListPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyInitialTab();
      // 等开屏页切换动画结束后再拉弹窗（对齐 Vue PopupAd 延迟展示）
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _fetchPopupAds();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<GlobalTrialService>().refreshFromServer();
    }
  }

  void _applyInitialTab() {
    final prefs = context.read<AppPrefs>();
    if (prefs.openLiveWithFollow) {
      prefs.openLiveWithFollow = false;
      context.read<MainTabController>().switchToLiveFollow();
    }
  }

  Future<void> _fetchPopupAds() async {
    if (_popupShown) return;
    try {
      final res = await ApiService().getPopupAds();
      if (!mounted) return;
      if (!ApiResult.isSuccess(res)) {
        if (kDebugMode) {
          debugPrint('[PopupAd] API failed: ${ApiResult.getErrorMessage(res)}');
        }
        return;
      }
      final rows = ApiParse.extractList(res.data['data']);
      if (kDebugMode) {
        debugPrint('[PopupAd] raw count=${rows.length}');
      }
      final list = <PopupAdItem>[];
      for (final row in rows) {
        try {
          final ad = PopupAdItem.fromJson(row);
          if (ad.id <= 0) {
            if (kDebugMode) debugPrint('[PopupAd] skip id<=0: $row');
            continue;
          }
          if (!ad.hasAnnouncementText) {
            if (kDebugMode) {
              debugPrint('[PopupAd] skip image-only ad id=${ad.id}');
            }
            continue;
          }
          if (!PopupAdSession.canShow(ad.id, ad.showOnce)) {
            if (kDebugMode) debugPrint('[PopupAd] skip shown-this-launch id=${ad.id}');
            continue;
          }
          list.add(ad);
        } catch (e) {
          if (kDebugMode) debugPrint('[PopupAd] parse skip: $e');
        }
      }
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (kDebugMode) {
        debugPrint(
          '[PopupAd] showable count=${list.length} ids=${list.map((e) => e.id).toList()}',
        );
      }
      if (list.isEmpty || !mounted) return;
      _popupShown = true;
      _popupQueue
        ..clear()
        ..addAll(list);
      await _drainPopupQueue();
    } catch (e) {
      if (kDebugMode) debugPrint('[PopupAd] fetch error: $e');
    }
  }

  Future<BuildContext?> _waitPopupDialogContext() async {
    for (var i = 0; i < 30; i++) {
      final root = AppToast.navigatorKey.currentContext;
      if (root != null && root.mounted) return root;
      if (mounted && context.mounted) return context;
      await Future.delayed(const Duration(milliseconds: 50));
    }
    return null;
  }

  Future<void> _drainPopupQueue() async {
    if (_popupDraining || !mounted || _popupQueue.isEmpty) return;
    _popupDraining = true;
    final pending = List<PopupAdItem>.from(_popupQueue);
    _popupQueue.clear();
    final total = pending.length;
    try {
      for (var i = 0; i < pending.length; i++) {
        if (!mounted) break;
        final ad = pending[i];
        final dialogContext = await _waitPopupDialogContext();
        if (dialogContext == null || !dialogContext.mounted) {
          if (kDebugMode) {
            debugPrint('[PopupAd] context unavailable at ${i + 1}/$total, retry queue later');
          }
          _popupQueue.addAll(pending.sublist(i));
          break;
        }
        if (kDebugMode) {
          debugPrint('[PopupAd] show ${i + 1}/$total id=${ad.id} title=${ad.title}');
        }
        await AnnouncementDialog.show(
          dialogContext,
          adItem: ad,
          index: i + 1,
          total: total,
        );
        PopupAdSession.markShown(ad.id, ad.showOnce);
        if (i < pending.length - 1) {
          await Future.delayed(const Duration(milliseconds: 320));
          await WidgetsBinding.instance.endOfFrame;
        }
      }
    } finally {
      _popupDraining = false;
      if (mounted && _popupQueue.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _drainPopupQueue());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = context.watch<MainTabController>().index;

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        sizing: StackFit.expand,
        children: List.generate(_pages.length, (i) {
          return TickerMode(
            enabled: currentIndex == i,
            child: _pages[i],
          );
        }),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.appColors.bottomNavTopLine)),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            context.read<MainTabController>().switchTo(index);
            if (index == MainTabController.tabHot || index == MainTabController.tabLive) {
              context.read<GlobalTrialService>().refreshFromServer();
            }
          },
          height: 68,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
            NavigationDestination(icon: Icon(Icons.local_fire_department_outlined), selectedIcon: Icon(Icons.local_fire_department), label: '热门'),
            NavigationDestination(icon: Icon(Icons.sports_esports_outlined), selectedIcon: Icon(Icons.sports_esports), label: '游戏'),
            NavigationDestination(icon: Icon(Icons.live_tv_outlined), selectedIcon: Icon(Icons.live_tv), label: '直播'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
          ],
        ),
      ),
    );
  }
}
