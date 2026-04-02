// lib/core/config.dart
import 'package:flutter/foundation.dart';

class AppConfig {
  // Runtime switch via --dart-define.
  // Examples:
  // flutter run --dart-define=API_ENV=dev
  // flutter run --dart-define=API_ENV=device --dart-define=API_DEVICE_URL=http://192.168.1.4:8000
  // flutter run --dart-define=API_BASE_URL=http://192.168.1.4:8000
  // flutter run --dart-define=API_BASE_URL=https://reel-api-ggcs.onrender.com
  static const String _env = String.fromEnvironment(
    'API_ENV',
    defaultValue: 'prod',
  );
  static const String _overrideBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _productionBaseUrl = String.fromEnvironment(
    'API_PROD_URL',
    defaultValue: 'https://reel-api-ggcs.onrender.com',
  );
  static const String _deviceBaseUrl = String.fromEnvironment(
    'API_DEVICE_URL',
    defaultValue: 'https://reel-api-ggcs.onrender.com',
  );
  static const String _devBaseUrl = String.fromEnvironment(
    'API_DEV_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:8000';

  static String get baseUrl {
    if (_overrideBaseUrl.isNotEmpty) return _overrideBaseUrl;
    if (_env == 'dev') {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        return _androidEmulatorBaseUrl;
      }
      return _devBaseUrl;
    }
    if (_env == 'device') return _deviceBaseUrl;
    return _productionBaseUrl;
  }

  // Endpoints
  static String get productsEndpoint => "$baseUrl/products";
  static String get productsHashEndpoint => "$baseUrl/products/hash";
  static String get merchantCatalogEndpoint => "$baseUrl/merchant/catalog";
  static String get merchantCatalogHashEndpoint =>
      "$baseUrl/merchant/catalog/hash";
  static String get uploadEndpoint => "$baseUrl/upload";
  static String get submitReportEndpoint => "$baseUrl/submit_report";
  static String get reportsEndpoint => submitReportEndpoint;
  static String get loginEndpoint => "$baseUrl/auth/login";
  static String get signupEndpoint => "$baseUrl/auth/signup";
  static String get updatePriceEndpoint => "$baseUrl/merchant/update_price";
  static String get availabilityEndpoint => "$baseUrl/merchant/availability";
  static String get updateStatusEndpoint =>
      "$baseUrl/admin/reports/update_status";
  static String get updateOfficialPriceEndpoint =>
      "$baseUrl/admin/products/update_official";
  static String get importProductsEndpoint =>
      "$baseUrl/minister/import_products";
  static String get importProductsPreviewEndpoint =>
      "$baseUrl/minister/import_products/preview";
  static String get importProductsConfirmEndpoint =>
      "$baseUrl/minister/import_products/confirm";
  static String get exchangeRateEndpoint => "$baseUrl/exchange_rate/latest";
  static String get exchangeRateMultiEndpoint =>
      "$baseUrl/exchange_rate/latest_multi";
  static String get alertsEndpoint => "$baseUrl/alerts";
  static String get newsEndpoint => "$baseUrl/news";
  static String get storesEndpoint => "$baseUrl/stores";
  static String storeProductsEndpoint(String storeName) =>
      "$baseUrl/store/${Uri.encodeComponent(storeName)}/products";
  static String get offlineMapUrl => String.fromEnvironment(
    'OFFLINE_MAP_URL',
    defaultValue: "$baseUrl/offline_maps/yemen.mbtiles",
  );
  static String get healthEndpoint => "$baseUrl/admin/health";
  static String get healthCheckEndpoint => healthEndpoint;
  static String get smartBasketEndpoint => "$baseUrl/basket/analyze";
  static String productOffersEndpoint(int productId) =>
      "$baseUrl/product/$productId/stores";
  static String productStoresEndpoint(int productId) =>
      productOffersEndpoint(productId);
}
