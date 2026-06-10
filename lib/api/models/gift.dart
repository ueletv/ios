/// 礼物模型（对应原生 Gift.kt）
class Gift {
  final dynamic id;
  final String? name;
  final int? price;
  final String? icon;
  final String? image;
  final int? type;
  final int? displayDuration;

  Gift({
    this.id,
    this.name,
    this.price,
    this.icon,
    this.image,
    this.type,
    this.displayDuration,
  });

  factory Gift.fromJson(Map<String, dynamic> json) {
    return Gift(
      id: json['id'],
      name: json['name'] as String?,
      price: json['price'] as int?,
      icon: json['icon'] as String?,
      image: json['image'] as String?,
      type: json['type'] as int?,
      displayDuration: json['display_duration'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'icon': icon,
      'image': image,
      'type': type,
      'display_duration': displayDuration,
    };
  }
}
