class ExchangeRateInfo {
  final String currency;
  final double? rate;
  final String? date;
  final String? source;
  final String? sourceType;

  ExchangeRateInfo({
    required this.currency,
    required this.rate,
    required this.date,
    this.source,
    this.sourceType,
  });

  factory ExchangeRateInfo.fromJson(Map<String, dynamic> json) {
    final rateValue = json['rate'];
    return ExchangeRateInfo(
      currency: (json['currency'] ?? '').toString(),
      rate: rateValue == null ? null : (rateValue as num).toDouble(),
      date: json['date']?.toString(),
      source: json['source']?.toString(),
      sourceType: json['source_type']?.toString(),
    );
  }
}
