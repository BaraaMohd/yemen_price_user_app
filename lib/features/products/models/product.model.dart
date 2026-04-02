class Product {
  final int id;
  final String name;
  final String category;
  final double officialPrice;
  final double? fairPrice;
  final double? exchangeRate;
  final String? exchangeCurrency;
  final String unit;
  final bool isStable;

  // Store info (for sorting)
  final String storeName;
  final double lat;
  final double lng;
  final double rating;

  // Trend
  final String? trend;
  final double? trendPercent;
  final String? trendAdvice;

  double? distanceFromUser;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.officialPrice,
    required this.unit,
    required this.storeName,
    required this.lat,
    required this.lng,
    required this.rating,
    this.fairPrice,
    this.exchangeRate,
    this.exchangeCurrency,
    this.trend,
    this.trendPercent,
    this.trendAdvice,
    this.isStable = true,
    this.distanceFromUser,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final trend = json['trend'] as Map<String, dynamic>?;
    return Product(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      category: json['category'] ?? 'عام',
      officialPrice: (json['official_price'] ?? 0).toDouble(),
      fairPrice: json['fair_price'] != null
          ? (json['fair_price'] as num).toDouble()
          : null,
      exchangeRate: json['exchange_rate'] != null
          ? (json['exchange_rate'] as num).toDouble()
          : null,
      exchangeCurrency: json['exchange_currency'],
      unit: json['unit'] ?? 'وحدة',
      isStable: json['is_stable'] ?? true,
      storeName: json['store_name'] ?? 'متجر غير معروف',
      lat: (json['lat'] ?? 0.0).toDouble(),
      lng: (json['lng'] ?? 0.0).toDouble(),
      rating: (json['rating'] ?? 0.0).toDouble(),
      trend: trend?['trend'],
      trendPercent: trend?['percent'] != null
          ? (trend?['percent'] as num).toDouble()
          : null,
      trendAdvice: trend?['advice'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'official_price': officialPrice,
      'fair_price': fairPrice,
      'exchange_rate': exchangeRate,
      'exchange_currency': exchangeCurrency,
      'unit': unit,
      'is_stable': isStable,
      'store_name': storeName,
      'lat': lat,
      'lng': lng,
      'rating': rating,
      'trend': trend,
      'trend_percent': trendPercent,
      'trend_advice': trendAdvice,
    };
  }
}
