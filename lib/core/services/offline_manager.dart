import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:dio/dio.dart';

import '../../core/config.dart';
import '../../core/services/service_locator.dart';
import '../../features/products/models/product.model.dart';

class OfflineManager {
  static const String boxProducts = "cached_products_box";
  static const String boxReports = "pending_reports_queue";
  static const String boxProductOffers = "cached_product_offers_box";
  static const String boxStoresIndex = "cached_stores_index_box";
  static const String boxStoreProducts = "cached_store_products_box";
  static const String boxExchangeRates = "cached_exchange_rates_box";
  static const String boxNews = "cached_news_box";
  static const String boxAdminReports = "cached_admin_reports_box";
  static const String boxMerchantCatalog = "cached_merchant_catalog_box";
  static const String boxMerchantQueue = "pending_merchant_actions_box";
  static const String boxAdminQueue = "pending_admin_actions_box";

  static StreamSubscription<InternetConnectionStatus>? _connectionSub;
  static bool _isSyncing = false;
  static DateTime? _lastSyncAt;

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(boxProducts);
    await Hive.openBox(boxReports);
    await Hive.openBox(boxProductOffers);
    await Hive.openBox(boxStoresIndex);
    await Hive.openBox(boxStoreProducts);
    await Hive.openBox(boxExchangeRates);
    await Hive.openBox(boxNews);
    await Hive.openBox(boxAdminReports);
    await Hive.openBox(boxMerchantCatalog);
    await Hive.openBox(boxMerchantQueue);
    await Hive.openBox(boxAdminQueue);
  }

  /// Checks connectivity by pinging the backend's lightweight health endpoint.
  /// This avoids downloading heavy data (like /products) just to check reachability.
  static Future<bool> hasInternet() async {
    try {
      final response = await locator<Dio>().get(
        AppConfig.healthEndpoint,
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 25),
          validateStatus: (status) => status != null,
        ),
      );
      // Any HTTP response means the backend is reachable
      return (response.statusCode ?? 0) < 600;
    } on DioException catch (e) {
      // Connection refused / no route / timeout → truly offline
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        return false;
      }
      // For other Dio errors (e.g. 4xx/5xx), backend is still reachable
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cacheProducts(List<Product> products) async {
    var box = Hive.box(boxProducts);
    List<Map<String, dynamic>> jsonList = products
        .map((p) => p.toJson())
        .toList();
    await box.put('products_list', jsonEncode(jsonList));
    await box.put('products_cached_at', DateTime.now().toIso8601String());
  }

  static Future<void> saveCachedHash(String hash) async {
    var box = Hive.box(boxProducts);
    await box.put('products_hash', hash);
  }

  static String? loadCachedHash() {
    var box = Hive.box(boxProducts);
    return box.get('products_hash');
  }

  static List<Product> loadCachedProducts({
    Duration maxAge = const Duration(minutes: 10),
  }) {
    var box = Hive.box(boxProducts);
    String? jsonString = box.get('products_list');
    if (jsonString != null) {
      String? cachedAtStr = box.get('products_cached_at');
      if (cachedAtStr != null) {
        try {
          DateTime cachedAt = DateTime.parse(cachedAtStr);
          if (DateTime.now().difference(cachedAt) > maxAge) {
            return [];
          }
        } catch (_) {}
      }
      List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((json) => Product.fromJson(json)).toList();
    }
    return [];
  }

  static Future<void> clearCachedProducts() async {
    var box = Hive.box(boxProducts);
    await box.delete('products_list');
    await box.delete('products_cached_at');
    await box.delete('products_hash');
  }

  static Future<void> cacheMerchantCatalog(List<Product> products) async {
    var box = Hive.box(boxMerchantCatalog);
    List<Map<String, dynamic>> jsonList = products
        .map((p) => p.toJson())
        .toList();
    await box.put('merchant_products_list', jsonEncode(jsonList));
    await box.put(
      'merchant_products_cached_at',
      DateTime.now().toIso8601String(),
    );
  }

  static List<Product> loadCachedMerchantCatalog({
    Duration maxAge = const Duration(minutes: 20),
  }) {
    var box = Hive.box(boxMerchantCatalog);
    String? jsonString = box.get('merchant_products_list');
    if (jsonString != null) {
      String? cachedAtStr = box.get('merchant_products_cached_at');
      if (cachedAtStr != null) {
        try {
          DateTime cachedAt = DateTime.parse(cachedAtStr);
          if (DateTime.now().difference(cachedAt) > maxAge) {
            return [];
          }
        } catch (_) {}
      }
      List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((json) => Product.fromJson(json)).toList();
    }
    return [];
  }

  static Future<void> saveMerchantCatalogHash(String hash) async {
    var box = Hive.box(boxMerchantCatalog);
    await box.put('merchant_products_hash', hash);
  }

  static String? loadMerchantCatalogHash() {
    var box = Hive.box(boxMerchantCatalog);
    return box.get('merchant_products_hash');
  }

  static Future<void> clearCachedMerchantCatalog() async {
    var box = Hive.box(boxMerchantCatalog);
    await box.delete('merchant_products_list');
    await box.delete('merchant_products_cached_at');
    await box.delete('merchant_products_hash');
  }

  static Future<void> cacheProductOffers(
    int productId,
    List<dynamic> offers,
  ) async {
    var box = Hive.box(boxProductOffers);
    await box.put('product_offers_$productId', jsonEncode(offers));
  }

  static List<dynamic> loadCachedProductOffers(int productId) {
    var box = Hive.box(boxProductOffers);
    String? jsonString = box.get('product_offers_$productId');
    return jsonString != null ? jsonDecode(jsonString) as List<dynamic> : [];
  }

  static bool hasCachedProductOffers(int productId) {
    var box = Hive.box(boxProductOffers);
    return box.containsKey('product_offers_$productId');
  }

  static Future<void> cacheStoresIndex(List<dynamic> stores) async {
    var box = Hive.box(boxStoresIndex);
    await box.put('stores_index', jsonEncode(stores));
  }

  static List<dynamic> loadCachedStoresIndex() {
    var box = Hive.box(boxStoresIndex);
    String? jsonString = box.get('stores_index');
    return jsonString != null ? jsonDecode(jsonString) as List<dynamic> : [];
  }

  static String _normalizeStoreKey(String name) => name.trim().toLowerCase();

  static Future<void> cacheStoreProducts(
    String storeName,
    List<dynamic> products,
  ) async {
    var box = Hive.box(boxStoreProducts);
    await box.put(
      'store_products_${_normalizeStoreKey(storeName)}',
      jsonEncode(products),
    );
  }

  static List<dynamic> loadCachedStoreProducts(String storeName) {
    var box = Hive.box(boxStoreProducts);
    String? jsonString = box.get(
      'store_products_${_normalizeStoreKey(storeName)}',
    );
    return jsonString != null ? jsonDecode(jsonString) as List<dynamic> : [];
  }

  static bool hasCachedStoreProducts(String storeName) {
    var box = Hive.box(boxStoreProducts);
    return box.containsKey('store_products_${_normalizeStoreKey(storeName)}');
  }

  static Future<void> queueReport(Map<String, dynamic> reportData) async {
    var box = Hive.box(boxReports);
    await box.add(jsonEncode(reportData));
  }

  static Future<int> syncPendingReports() async {
    if (!await hasInternet()) return 0;
    var box = Hive.box(boxReports);
    if (box.isEmpty) return 0;
    int successCount = 0;
    var keys = box.keys.toList();
    for (var key in keys) {
      try {
        var data = jsonDecode(box.get(key));
        FormData formData = FormData.fromMap({
          "store_name": data['store_name'],
          "product_name": data['product_name'],
          "price_seen": data['price_seen'],
          "lat": data['lat'],
          "lng": data['lng'],
          "notes": "${data['notes']} (Synced)",
        });
        if (data['image_path'] != null) {
          File imgFile = File(data['image_path']);
          if (await imgFile.exists()) {
            formData.files.add(
              MapEntry(
                "image",
                await MultipartFile.fromFile(
                  data['image_path'],
                  filename: "offline_proof.jpg",
                ),
              ),
            );
          }
        }
        var response = await locator<Dio>().post(
          AppConfig.submitReportEndpoint,
          data: formData,
        );
        if (response.statusCode == 200) {
          await box.delete(key);
          successCount++;
        }
      } catch (e) {
        log("❌ Sync Error: $e");
      }
    }
    return successCount;
  }

  static Future<void> cacheExchangeRates(List<dynamic> rates) async {
    var box = Hive.box(boxExchangeRates);
    await box.put('exchange_rates', jsonEncode(rates));
  }

  static List<dynamic> loadCachedExchangeRates() {
    var box = Hive.box(boxExchangeRates);
    String? jsonString = box.get('exchange_rates');
    return jsonString != null ? jsonDecode(jsonString) as List<dynamic> : [];
  }

  static Future<void> cacheNews(List<dynamic> news) async {
    var box = Hive.box(boxNews);
    await box.put('news_list', jsonEncode(news));
  }

  static List<dynamic> loadCachedNews() {
    var box = Hive.box(boxNews);
    String? jsonString = box.get('news_list');
    return jsonString != null ? jsonDecode(jsonString) as List<dynamic> : [];
  }

  static Future<void> cacheAdminReports(List<dynamic> reports) async {
    var box = Hive.box(boxAdminReports);
    await box.put('admin_reports_list', jsonEncode(reports));
  }

  static List<dynamic> loadCachedAdminReports() {
    var box = Hive.box(boxAdminReports);
    String? jsonString = box.get('admin_reports_list');
    return jsonString != null ? jsonDecode(jsonString) as List<dynamic> : [];
  }

  static Future<void> queueMerchantPriceUpdate({
    required String phone,
    required int productId,
    required double price,
    required double lat,
    required double lng,
  }) async {
    var box = Hive.box(boxMerchantQueue);
    await box.put(
      'merchant_price_$productId',
      jsonEncode({
        "type": "price",
        "phone": phone,
        "product_id": productId,
        "price": price,
        "lat": lat,
        "lng": lng,
        "created_at": DateTime.now().toIso8601String(),
      }),
    );
  }

  static Future<void> queueMerchantAvailabilityUpdate({
    required String phone,
    required int productId,
    required bool available,
  }) async {
    var box = Hive.box(boxMerchantQueue);
    await box.put(
      'merchant_availability_$productId',
      jsonEncode({
        "type": "availability",
        "phone": phone,
        "product_id": productId,
        "available": available,
        "created_at": DateTime.now().toIso8601String(),
      }),
    );
  }

  static Future<int> syncPendingMerchantActions() async {
    if (!await hasInternet()) return 0;
    var box = Hive.box(boxMerchantQueue);
    if (box.isEmpty) return 0;
    int successCount = 0;
    final keys = box.keys.toList();
    for (final key in keys) {
      try {
        final data = jsonDecode(box.get(key));
        Response response;
        if (data['type'] == 'price') {
          response = await locator<Dio>().post(
            AppConfig.updatePriceEndpoint,
            data: {
              "phone": data['phone'],
              "product_id": data['product_id'],
              "price": data['price'],
              "lat": data['lat'],
              "lng": data['lng'],
            },
          );
        } else {
          response = await locator<Dio>().post(
            AppConfig.availabilityEndpoint,
            data: {
              "phone": data['phone'],
              "product_id": data['product_id'],
              "available": data['available'],
            },
          );
        }
        if (response.statusCode != null && response.statusCode! < 300) {
          await box.delete(key);
          successCount++;
        }
      } catch (e) {
        log("❌ Merchant Sync Error: $e");
      }
    }
    return successCount;
  }

  static Future<void> queueAdminReportStatusUpdate({
    required int reportId,
    required String newStatus,
  }) async {
    var box = Hive.box(boxAdminQueue);
    await box.put(
      'admin_report_status_$reportId',
      jsonEncode({
        "type": "report_status",
        "report_id": reportId,
        "new_status": newStatus,
        "created_at": DateTime.now().toIso8601String(),
      }),
    );
  }

  static Future<void> queueAdminOfficialPriceUpdate({
    required int productId,
    required double newPrice,
  }) async {
    var box = Hive.box(boxAdminQueue);
    await box.put(
      'admin_official_price_$productId',
      jsonEncode({
        "type": "official_price",
        "product_id": productId,
        "new_price": newPrice,
        "created_at": DateTime.now().toIso8601String(),
      }),
    );
  }

  static Future<int> syncPendingAdminActions() async {
    if (!await hasInternet()) return 0;
    var box = Hive.box(boxAdminQueue);
    if (box.isEmpty) return 0;
    int successCount = 0;
    for (final key in box.keys.toList()) {
      try {
        final data = jsonDecode(box.get(key));
        Response response;
        if (data['type'] == 'report_status') {
          response = await locator<Dio>().post(
            AppConfig.updateStatusEndpoint,
            data: {
              "report_id": data['report_id'],
              "new_status": data['new_status'],
            },
          );
        } else {
          response = await locator<Dio>().post(
            AppConfig.updateOfficialPriceEndpoint,
            data: {
              "product_id": data['product_id'],
              "new_price": data['new_price'],
            },
          );
        }
        if (response.statusCode != null && response.statusCode! < 300) {
          await box.delete(key);
          successCount++;
        }
      } catch (e) {
        log("❌ Admin Sync Error: $e");
      }
    }
    return successCount;
  }

  static Future<int> syncAllPending() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    try {
      int count = 0;
      count += await syncPendingReports();
      count += await syncPendingMerchantActions();
      count += await syncPendingAdminActions();
      _lastSyncAt = DateTime.now();
      return count;
    } finally {
      _isSyncing = false;
    }
  }

  static void startConnectivitySync({
    Duration minInterval = const Duration(seconds: 20),
    void Function(int count)? onSynced,
  }) {
    _connectionSub ??= InternetConnectionChecker().onStatusChange.listen((
      status,
    ) async {
      if (status != InternetConnectionStatus.connected) return;
      if (_lastSyncAt != null &&
          DateTime.now().difference(_lastSyncAt!) < minInterval) {
        return;
      }
      final count = await syncAllPending();
      if (count > 0) onSynced?.call(count);
    });
  }

  static Future<void> stopConnectivitySync() async {
    await _connectionSub?.cancel();
    _connectionSub = null;
  }
}
