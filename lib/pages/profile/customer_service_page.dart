import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videoweb_flutter/api/models/customer_service_config.dart';
import 'package:videoweb_flutter/pages/profile/widgets/profile_subpage_scaffold.dart';
import 'package:videoweb_flutter/services/app_config_cache.dart';
import 'package:videoweb_flutter/services/theme_controller.dart';
import 'package:videoweb_flutter/theme/app_theme.dart';
import 'package:videoweb_flutter/utils/ad_link_helper.dart';
import 'package:videoweb_flutter/utils/app_toast.dart';
import 'package:videoweb_flutter/utils/image_url.dart';
import 'package:videoweb_flutter/widgets/telegram_icon.dart';

/// 客服页（配置来自后台站点配置 customer_service）
class CustomerServicePage extends StatefulWidget {
  const CustomerServicePage({super.key});

  @override
  State<CustomerServicePage> createState() => _CustomerServicePageState();
}

class _CustomerServicePageState extends State<CustomerServicePage> {
  CustomerServiceConfig _config = CustomerServiceConfig.defaults();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig(force: true);
  }

  Future<void> _loadConfig({bool force = false}) async {
    if (!_loading && force) {
      setState(() => _loading = true);
    }
    final data = await AppConfigCache.fetch(force: force);
    if (!mounted) return;
    setState(() {
      _config = CustomerServiceConfig.fromAppConfigMap(data);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final colors = context.appColors;
    return ProfileSubpageScaffold(
      title: '客服中心',
      body: _loading
          ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent))
          : RefreshIndicator(
              color: colors.accent,
              onRefresh: () => _loadConfig(force: true),
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                ProfileThemedCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('需要帮助？', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(_config.intro, style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.45)),
                    ],
                  ),
                ),
                if (_config.faq.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('常见问题', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colors.textPrimary)),
                  const SizedBox(height: 12),
                  ..._config.faq.map((item) => _buildFaqItem(context, colors, item)),
                ],
                if (_config.contacts.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('联系我们', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colors.textPrimary)),
                  const SizedBox(height: 12),
                  ..._config.contacts.map((item) => _buildContactItem(context, colors, item)),
                ],
                if (_config.online.enabled) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openOnlineService(context, _config.online.url),
                      icon: const Icon(Icons.headset_mic_rounded),
                      label: Text(_config.online.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ],
            ),
            ),
    );
  }

  Widget _buildFaqItem(BuildContext context, AppColors colors, CustomerServiceFaq item) {
    return ProfileThemedCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: colors.textSecondary,
          collapsedIconColor: colors.textSecondary,
          title: Text(item.question, style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(item.answer, style: TextStyle(color: colors.textSecondary, height: 1.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(BuildContext context, AppColors colors, CustomerServiceContact item) {
    final label = item.label.isNotEmpty ? item.label : _defaultLabel(item.type);
    return ProfileThemedCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: _buildContactIcon(colors, item),
        title: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary)),
        subtitle: Text(
          item.value.isNotEmpty ? item.value : '暂未配置',
          style: TextStyle(color: item.value.isNotEmpty ? colors.textSecondary : colors.textHint),
        ),
        trailing: Icon(Icons.chevron_right, color: colors.textHint),
        onTap: item.value.isEmpty ? null : () => _onContactTap(context, item),
      ),
    );
  }

  Widget _buildContactIcon(AppColors colors, CustomerServiceContact item) {
    final type = _normalizeContactType(item.type);
    if (type == 'telegram') {
      return const TelegramIcon(size: 28);
    }
    final iconUrl = ImageUrl.getImageUrl(item.iconUrl);
    if (iconUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: iconUrl,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Icon(_builtinIcon(type), color: colors.accent, size: 26),
        ),
      );
    }
    return Icon(_builtinIcon(type), color: colors.accent, size: 26);
  }

  String _normalizeContactType(String type) {
    switch (type) {
      case 'qq':
      case 'wechat':
        return 'telegram';
      default:
        return type;
    }
  }

  IconData _builtinIcon(String type) {
    switch (type) {
      case 'telegram':
        return Icons.send_rounded;
      case 'email':
        return Icons.email_outlined;
      case 'phone':
        return Icons.phone_outlined;
      case 'url':
        return Icons.link_rounded;
      default:
        return Icons.contact_support_outlined;
    }
  }

  String _defaultLabel(String type) {
    switch (_normalizeContactType(type)) {
      case 'telegram':
        return 'Telegram';
      case 'email':
        return '邮箱';
      case 'phone':
        return '电话';
      case 'url':
        return '链接';
      default:
        return '联系方式';
    }
  }

  String _telegramLaunchUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final username = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
    return 'https://t.me/$username';
  }

  Future<void> _onContactTap(BuildContext context, CustomerServiceContact item) async {
    final value = item.value.trim();
    if (value.isEmpty) return;
    switch (_normalizeContactType(item.type)) {
      case 'telegram':
        await AdLinkHelper.openLink(context, linkType: 'url', linkUrl: _telegramLaunchUrl(value));
        return;
      case 'email':
        final uri = Uri(scheme: 'mailto', path: value);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          await _copy(context, value);
        }
        return;
      case 'phone':
        final tel = value.replaceAll(RegExp(r'\s+'), '');
        final uri = Uri(scheme: 'tel', path: tel);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          await _copy(context, value);
        }
        return;
      case 'url':
        await AdLinkHelper.openLink(context, linkType: 'url', linkUrl: value);
        return;
      default:
        await _copy(context, value);
    }
  }

  Future<void> _openOnlineService(BuildContext context, String url) async {
    await AdLinkHelper.openLink(context, linkType: 'url', linkUrl: url);
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) AppToast.show('已复制', context: context);
  }
}
