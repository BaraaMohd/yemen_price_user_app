import 'dart:convert';
import 'package:dio/dio.dart';
import 'service_locator.dart';
import '../config.dart';
import '../models/exchange_rate.dart';
import 'offline_manager.dart';

class ExchangeRateService {
  static Future<List<ExchangeRateInfo>> fetchLatestRates() async {
    try {
      final resp = await locator<Dio>().get(AppConfig.exchangeRateMultiEndpoint);
      final data = resp.data;
      if (data is Map && data['rates'] is List) {
        final rates = (data['rates'] as List)
            .whereType<Map>()
            .map((e) => ExchangeRateInfo.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        await OfflineManager.cacheExchangeRates(
          (data['rates'] as List).map((e) => Map<String, dynamic>.from(e)).toList(),
        );
        return rates;
      }
    } catch (_) {
      // fall through to single-rate fallback
    }

    try {
      final resp = await locator<Dio>().get(AppConfig.exchangeRateEndpoint);
      if (resp.data is Map) {
        final list = [
          ExchangeRateInfo.fromJson(Map<String, dynamic>.from(resp.data as Map))
        ];
        await OfflineManager.cacheExchangeRates(
          [Map<String, dynamic>.from(resp.data as Map)],
        );
        return list;
      }
    } catch (_) {}

    final cached = OfflineManager.loadCachedExchangeRates();
    if (cached.isNotEmpty) {
      return cached
          .whereType<Map>()
          .map((e) => ExchangeRateInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  static Stream<ExchangeRateInfo> streamLatestRates() async* {
    final dio = Dio();
    try {
      final response = await dio.get<ResponseBody>(
        "${AppConfig.baseUrl}/stream/exchange_rate",
        options: Options(
          responseType: ResponseType.stream,
          headers: {"Accept": "text/event-stream", "Cache-Control": "no-cache"},
        ),
      );

      final stream = response.data?.stream;
      if (stream == null) return;
      
      String buffer = "";
      await for (final chunk in stream) {
        buffer += String.fromCharCodes(chunk);
        final lines = buffer.split("\n\n");
        
        for (int i = 0; i < lines.length - 1; i++) {
          final block = lines[i].trim();
          if (block.startsWith("data: ")) {
             final jsonStr = block.substring(6).trim();
             try {
               final data = json.decode(jsonStr) as Map<String, dynamic>;
               yield ExchangeRateInfo.fromJson(data);
             } catch (_) {}
          }
        }
        buffer = lines.last; // Keep incomplete chunk
      }
    } catch (_) {
      // Stream disconnect
    }
  }
}
