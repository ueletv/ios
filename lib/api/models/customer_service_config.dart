import 'dart:convert';

class CustomerServiceConfig {
  final String intro;
  final List<CustomerServiceFaq> faq;
  final List<CustomerServiceContact> contacts;
  final CustomerServiceOnline online;

  const CustomerServiceConfig({
    required this.intro,
    required this.faq,
    required this.contacts,
    required this.online,
  });

  factory CustomerServiceConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CustomerServiceConfig.defaults();
    final faqRaw = json['faq'];
    final contactsRaw = json['contacts'];
    return CustomerServiceConfig(
      intro: json['intro']?.toString().trim().isNotEmpty == true
          ? json['intro'].toString().trim()
          : CustomerServiceConfig.defaults().intro,
      faq: faqRaw is List
          ? faqRaw
              .whereType<Map>()
              .map((e) => CustomerServiceFaq.fromJson(Map<String, dynamic>.from(e)))
              .where((e) => e.question.isNotEmpty || e.answer.isNotEmpty)
              .toList()
          : const [],
      contacts: contactsRaw is List
          ? contactsRaw
              .whereType<Map>()
              .map((e) => CustomerServiceContact.fromJson(Map<String, dynamic>.from(e)))
              .where((e) => e.label.isNotEmpty || e.value.isNotEmpty)
              .toList()
          : const [],
      online: json['online'] is Map
          ? CustomerServiceOnline.fromJson(Map<String, dynamic>.from(json['online'] as Map))
          : const CustomerServiceOnline(),
    );
  }

  /// 从 /config 整包解析：优先 `customer_service` 对象，否则读顶层平铺键
  factory CustomerServiceConfig.fromAppConfigMap(Map<String, dynamic>? data) {
    if (data == null) return CustomerServiceConfig.defaults();
    final nested = data['customer_service'];
    if (nested is Map) {
      return CustomerServiceConfig.fromJson(Map<String, dynamic>.from(nested));
    }
    return CustomerServiceConfig._fromFlatKeys(data);
  }

  factory CustomerServiceConfig._fromFlatKeys(Map<String, dynamic> data) {
    final intro = data['customer_service_intro']?.toString().trim() ?? '';
    final faq = _parseFaqJson(data['customer_service_faq']?.toString());
    var contacts = _parseContactsJson(data['customer_service_contacts']?.toString());
    if (contacts.isEmpty) {
      contacts = _contactsFromSimpleKeys(data);
    }
    final onlineEnabled = data['customer_service_online_enabled']?.toString() == '1';
    final onlineUrl = data['customer_service_online_url']?.toString().trim() ?? '';
    final onlineLabel = data['customer_service_online_label']?.toString().trim() ?? '';
    return CustomerServiceConfig(
      intro: intro.isNotEmpty ? intro : CustomerServiceConfig.defaults().intro,
      faq: faq,
      contacts: contacts,
      online: CustomerServiceOnline(
        enabled: onlineEnabled && onlineUrl.isNotEmpty,
        url: onlineUrl,
        label: onlineLabel.isNotEmpty ? onlineLabel : '在线客服',
      ),
    );
  }

  static List<CustomerServiceFaq> _parseFaqJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => CustomerServiceFaq.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.question.isNotEmpty || e.answer.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<CustomerServiceContact> _parseContactsJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final out = <CustomerServiceContact>[];
      for (final item in decoded.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        final enabled = map['enabled'];
        if (enabled == false || enabled?.toString() == '0' || enabled?.toString() == 'false') {
          continue;
        }
        final contact = CustomerServiceContact.fromJson(map);
        if (contact.label.isNotEmpty || contact.value.isNotEmpty) {
          out.add(contact);
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static List<CustomerServiceContact> _contactsFromSimpleKeys(Map<String, dynamic> data) {
    final out = <CustomerServiceContact>[];
    void add(String type, String label, String? value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return;
      out.add(CustomerServiceContact(type: type, label: label, value: v, iconUrl: ''));
    }

    add('telegram', 'Telegram', data['customer_service_telegram']?.toString());
    add('email', '邮箱', data['customer_service_email']?.toString());
    add('phone', '电话', data['customer_service_phone']?.toString());
    return out;
  }

  factory CustomerServiceConfig.defaults() {
    return const CustomerServiceConfig(
      intro: '优先查看常见问题，也可以直接联系我们。',
      faq: [
        CustomerServiceFaq(question: '如何充值？', answer: '在个人中心点击「直播充值」，选择合适的充值方案即可完成充值。'),
        CustomerServiceFaq(question: '如何开通VIP？', answer: '在个人中心点击「VIP会员」，选择合适的套餐进行购买。'),
      ],
      contacts: [],
      online: CustomerServiceOnline(),
    );
  }
}

class CustomerServiceFaq {
  final String question;
  final String answer;

  const CustomerServiceFaq({required this.question, required this.answer});

  factory CustomerServiceFaq.fromJson(Map<String, dynamic> json) {
    return CustomerServiceFaq(
      question: json['question']?.toString().trim() ?? '',
      answer: json['answer']?.toString().trim() ?? '',
    );
  }
}

class CustomerServiceContact {
  final String type;
  final String label;
  final String value;
  final String iconUrl;

  const CustomerServiceContact({
    required this.type,
    required this.label,
    required this.value,
    required this.iconUrl,
  });

  factory CustomerServiceContact.fromJson(Map<String, dynamic> json) {
    return CustomerServiceContact(
      type: json['type']?.toString().trim().isNotEmpty == true ? json['type'].toString().trim() : 'custom',
      label: json['label']?.toString().trim() ?? '',
      value: json['value']?.toString().trim() ?? '',
      iconUrl: json['icon_url']?.toString().trim() ?? '',
    );
  }
}

class CustomerServiceOnline {
  final bool enabled;
  final String url;
  final String label;

  const CustomerServiceOnline({
    this.enabled = false,
    this.url = '',
    this.label = '在线客服',
  });

  factory CustomerServiceOnline.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'] == true || json['enabled']?.toString() == '1';
    final url = json['url']?.toString().trim() ?? '';
    final label = json['label']?.toString().trim() ?? '';
    return CustomerServiceOnline(
      enabled: enabled && url.isNotEmpty,
      url: url,
      label: label.isNotEmpty ? label : '在线客服',
    );
  }
}
