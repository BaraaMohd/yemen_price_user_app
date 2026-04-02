import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yemen_price_system2/features/products/screens/smart_basket_screen.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import '../../../core/app_settings.dart';
import '../../../core/l10n/app_localizations.dart';

import '../../../core/config.dart';
import '../../../core/models/exchange_rate.dart';
import '../../../core/services/exchange_rate_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/offline_manager.dart';
import '../../../core/services/offline_map_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/product_skeleton.dart';
import '../models/product.model.dart';
import '../widgets/product_card.dart';
import '../screens/store_search_screen.dart';
import '../reports/screens/violation_report_screen.dart';
import '../../notifications/screens/notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String _errorMessage = "";
  bool _isOnline = true;
  bool _usingOfflineProducts = false;
  bool _usingOfflineNews = false;

  Position? _currentPosition;
  String _selectedCategory = "الكل";
  String _searchText = "";
  final TextEditingController _searchController = TextEditingController();
  final Dio _api = locator<Dio>();

  double? _exchangeRate;
  String? _exchangeCurrency;
  String? _exchangeDate;
  List<ExchangeRateInfo> _exchangeRates = [];
  StreamSubscription? _sseSubscription;
  List<dynamic> _news = [];
  String? _offlineMapPath;
  bool _wasDownloading = false;

  final List<String> _categories = [
    "الكل",
    "حبوب",
    "ألبان",
    "طاقة",
    "مواد بناء",
    "مواد غذائية",
  ];

  void _openSettingsSheet() {
    final rootContext = context;
    showModalBottomSheet(
      context: rootContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickOfflineMap() async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['mbtiles'],
              );
              if (result == null || result.files.isEmpty) return;
              final path = result.files.first.path;
              if (path == null) return;
              final saved = await OfflineMapService.importFromFile(path);
              if (!mounted) return;
              setState(() {
                _offlineMapPath = saved;
              });
              setSheetState(() {
                _offlineMapPath = saved;
              });
              if (!rootContext.mounted) return;
              _showSnack(rootContext.tr("تم حفظ خريطة أوفلاين"));
            }

            Future<void> downloadOfflineMap() async {
              if (OfflineMapService.downloadProgress.value != null) return;
              final saved = await OfflineMapService.downloadFromUrl(
                AppConfig.offlineMapUrl,
              );
              if (!mounted) return;
              setState(() {
                _offlineMapPath = saved;
              });
              setSheetState(() {
                _offlineMapPath = saved;
              });
              final errorKey = OfflineMapService.downloadErrorKey.value;
              if (!rootContext.mounted) return;
              _showSnack(
                saved == null
                    ? rootContext.tr(errorKey ?? "فشل تنزيل خريطة أوفلاين")
                    : rootContext.tr("تم تنزيل خريطة أوفلاين"),
              );
            }

            Future<void> clearOfflineMap() async {
              await OfflineMapService.clearOfflineMap();
              if (!mounted) return;
              setState(() {
                _offlineMapPath = null;
              });
              setSheetState(() {
                _offlineMapPath = null;
              });
              if (!rootContext.mounted) return;
              _showSnack(rootContext.tr("تم حذف خريطة أوفلاين"));
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rootContext.tr("الإعدادات"),
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      rootContext.tr("الوضع الليلي"),
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: AppSettings.themeMode,
                      builder: (context, currentMode, _) =>
                          SegmentedButton<ThemeMode>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: ThemeMode.light,
                                label: Text(rootContext.tr("فاتح")),
                                icon: const Icon(Icons.light_mode_outlined),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                label: Text(rootContext.tr("داكن")),
                                icon: const Icon(Icons.dark_mode_outlined),
                              ),
                              ButtonSegment(
                                value: ThemeMode.system,
                                label: Text(rootContext.tr("النظام")),
                                icon: const Icon(Icons.phone_android_outlined),
                              ),
                            ],
                            selected: {currentMode},
                            onSelectionChanged: (selection) {
                              if (selection.isNotEmpty) {
                                AppSettings.setThemeMode(selection.first);
                              }
                            },
                          ),
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(rootContext.tr("اللغة")),
                      trailing: DropdownButton<Locale>(
                        value: AppSettings.locale.value,
                        items: [
                          DropdownMenuItem(
                            value: const Locale('ar'),
                            child: Text(rootContext.tr("العربية")),
                          ),
                          DropdownMenuItem(
                            value: const Locale('en'),
                            child: Text(rootContext.tr("الإنجليزية")),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) AppSettings.setLocale(v);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      rootContext.tr("خرائط أوفلاين"),
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _offlineMapPath == null
                          ? rootContext.tr("لم يتم تحميل خريطة أوفلاين بعد")
                          : rootContext.tr("خريطة أوفلاين جاهزة"),
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Theme.of(sheetContext).hintColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<double?>(
                      valueListenable: OfflineMapService.downloadProgress,
                      builder: (context, progress, _) {
                        final isDownloading = progress != null;
                        final percentText = progress == null
                            ? ''
                            : _formatPercent(progress);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: isDownloading
                                      ? null
                                      : downloadOfflineMap,
                                  icon: const Icon(
                                    Icons.cloud_download_outlined,
                                  ),
                                  label: Text(
                                    rootContext.tr("تنزيل خريطة أوفلاين"),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: isDownloading
                                      ? null
                                      : pickOfflineMap,
                                  icon: const Icon(Icons.folder_open_outlined),
                                  label: Text(rootContext.tr("استيراد من ملف")),
                                ),
                                OutlinedButton.icon(
                                  onPressed:
                                      isDownloading || _offlineMapPath == null
                                      ? null
                                      : clearOfflineMap,
                                  icon: const Icon(Icons.delete_outline),
                                  label: Text(
                                    rootContext.tr("مسح الخريطة الأوفلاين"),
                                  ),
                                ),
                              ],
                            ),
                            if (isDownloading) ...[
                              const SizedBox(height: 10),
                              LinearProgressIndicator(value: progress),
                              const SizedBox(height: 6),
                              Text(
                                '${rootContext.tr("جاري تنزيل خريطة أوفلاين")} $percentText',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: Theme.of(sheetContext).hintColor,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _initApp();
    _loadOfflineMapPath();
    OfflineMapService.downloadProgress.addListener(
      _handleOfflineMapDownloadProgress,
    );
  }

  @override
  void dispose() {
    OfflineMapService.downloadProgress.removeListener(
      _handleOfflineMapDownloadProgress,
    );
    _searchController.dispose();
    _sseSubscription?.cancel();
    super.dispose();
  }

  void _openSmartBasket() {
    final source = _filteredProducts.isNotEmpty
        ? _filteredProducts
        : _allProducts;
    if (source.isEmpty) {
      _showSnack(context.tr("لا توجد منتجات تطابق بحثك"));
      return;
    }

    final uniqueById = <int, Product>{};
    for (final product in source) {
      uniqueById.putIfAbsent(product.id, () => product);
    }

    // Keep payload bounded so basket analysis stays fast on mobile networks.
    final basketSeed = uniqueById.values.take(40).toList();
    if (basketSeed.isEmpty) {
      _showSnack(context.tr("السلة فارغة. يرجى إضافة منتجات أولاً"));
      return;
    }
    if (uniqueById.length > basketSeed.length) {
      _showSnack(
        context.tr(
          "تم استخدام أول 40 منتج لتحليل السلة. استخدم البحث لتقليل النتائج.",
        ),
      );
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => SmartBasketScreen(allProducts: basketSeed),
      ),
    );
  }

  void _openStoreSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (c) => const StoreSearchScreen()),
    );
  }

  Future<void> _handleRefresh() async {
    await _refreshConnectivity();
    await Future.wait([_fetchProducts(), _fetchExchangeRate(), _fetchNews()]);
  }

  void _updateSearch(String value) {
    _searchText = value;
    _applyFilters();
  }

  void _setCategory(String category) {
    _selectedCategory = category;
    _applyFilters();
  }

  Future<void> _initApp() async {
    try {
      _currentPosition = await LocationService.getCurrentLocation();
    } catch (_) {
      debugPrint("GPS signal issue or permission denied");
    }
    await _refreshConnectivity();
    await Future.wait([_fetchProducts(), _fetchExchangeRate(), _fetchNews()]);
  }

  Future<void> _loadOfflineMapPath() async {
    final path = await OfflineMapService.getActiveMbtilesPath();
    if (!mounted) return;
    setState(() {
      _offlineMapPath = path;
    });
  }

  void _handleOfflineMapDownloadProgress() {
    final progress = OfflineMapService.downloadProgress.value;
    if (progress != null) {
      _wasDownloading = true;
      return;
    }
    if (_wasDownloading) {
      _wasDownloading = false;
      _loadOfflineMapPath();
    }
  }

  Future<void> _refreshConnectivity() async {
    final online = await OfflineManager.hasInternet();
    if (!mounted) return;
    setState(() {
      _isOnline = online;
    });
  }

  Future<void> _fetchExchangeRate() async {
    _sseSubscription?.cancel();
    _sseSubscription = ExchangeRateService.streamLatestRates().listen((
      rateInfo,
    ) {
      if (!mounted) return;
      setState(() {
        _exchangeRate = rateInfo.rate;
        _exchangeCurrency = rateInfo.currency;
        _exchangeDate = rateInfo.date;

        final idx = _exchangeRates.indexWhere(
          (r) => r.currency == rateInfo.currency,
        );
        if (idx != -1) {
          _exchangeRates[idx] = rateInfo;
        } else {
          _exchangeRates.add(rateInfo);
        }
      });
    });

    try {
      final rates = await ExchangeRateService.fetchLatestRates();
      if (!mounted) return;
      setState(() {
        _exchangeRates = rates;
        ExchangeRateInfo? picked;
        for (final r in rates) {
          if (r.currency.toUpperCase() == "USD" &&
              (r.sourceType ?? "").toLowerCase() == "official" &&
              r.rate != null) {
            picked = r;
            break;
          }
        }
        picked ??= rates.firstWhere(
          (r) => r.currency.toUpperCase() == "USD" && r.rate != null,
          orElse: () => rates.isNotEmpty
              ? rates.first
              : ExchangeRateInfo(
                  currency: _exchangeCurrency ?? "USD",
                  rate: _exchangeRate,
                  date: _exchangeDate,
                ),
        );
        _exchangeRate = picked.rate ?? _exchangeRate;
        _exchangeCurrency = picked.currency.isNotEmpty
            ? picked.currency
            : _exchangeCurrency;
        _exchangeDate = picked.date ?? _exchangeDate;
      });
    } catch (_) {
      // silent
    }
  }

  Future<void> _fetchNews() async {
    if (!_isOnline) {
      if (!mounted) return;
      setState(() {
        _news = OfflineManager.loadCachedNews();
        _usingOfflineNews = _news.isNotEmpty;
      });
      return;
    }
    try {
      final resp = await _api.get(AppConfig.newsEndpoint);
      if (resp.statusCode != null && resp.statusCode! >= 400) {
        if (mounted) {
          setState(() {
            _news = [];
          });
        }
        return;
      }
      if (resp.data is List) {
        await OfflineManager.cacheNews(resp.data as List);
      }
      if (!mounted) return;
      setState(() {
        _news = resp.data is List ? resp.data : [];
        _usingOfflineNews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _news = OfflineManager.loadCachedNews();
        _usingOfflineNews = _news.isNotEmpty;
      });
    }
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    if (!_isOnline) {
      List<Product> localData = OfflineManager.loadCachedProducts();
      if (mounted) {
        setState(() {
          if (localData.isNotEmpty) {
            _allProducts = localData;
            _usingOfflineProducts = true;
          } else {
            _errorMessage = context.tr(
              "\u062a\u0639\u0630\u0631 \u0627\u0644\u0627\u062a\u0635\u0627\u0644 \u0648\u0644\u0627 \u062a\u0648\u062c\u062f \u0628\u064a\u0627\u0646\u0627\u062a \u0633\u0627\u0628\u0642\u0629 \u0645\u062d\u0641\u0648\u0638\u0629 \ud83d\udcf5",
            );
            _usingOfflineProducts = false;
          }
          _isLoading = false;
        });
      }
      _applyFilters();
      return;
    }

    try {
      final hashResponse = await _api.get(AppConfig.productsHashEndpoint);
      if (hashResponse.statusCode == 200 && hashResponse.data != null) {
        final serverHash = hashResponse.data['hash'] as String?;
        final cachedHash = OfflineManager.loadCachedHash();
        if (serverHash != null && serverHash == cachedHash) {
          final cached = OfflineManager.loadCachedProducts(
            maxAge: const Duration(hours: 24),
          );
          if (cached.isNotEmpty && mounted) {
            setState(() {
              _allProducts = cached;
              _isLoading = false;
              _usingOfflineProducts = false;
              if (cached.isNotEmpty) {
                _exchangeRate = cached.first.exchangeRate;
                _exchangeCurrency = cached.first.exchangeCurrency;
              }
            });
            _applyFilters();
            return;
          }
        }
      }
    } catch (_) {}

    try {
      final response = await _api.get(AppConfig.productsEndpoint);
      if (response.statusCode == null || response.statusCode! >= 400) {
        throw Exception("HTTP ${response.statusCode}");
      }
      if (response.data is! List) {
        throw Exception("Unexpected products payload");
      }

      List<Product> results = (response.data as List)
          .map((json) => Product.fromJson(json))
          .toList();

      await OfflineManager.cacheProducts(results);

      try {
        final hashResponse = await _api.get(AppConfig.productsHashEndpoint);
        if (hashResponse.statusCode == 200 && hashResponse.data != null) {
          final serverHash = hashResponse.data['hash'] as String?;
          if (serverHash != null) {
            await OfflineManager.saveCachedHash(serverHash);
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _allProducts = results;
          _isLoading = false;
          _usingOfflineProducts = false;
          if (results.isNotEmpty) {
            _exchangeRate = results.first.exchangeRate;
            _exchangeCurrency = results.first.exchangeCurrency;
          }
        });
      }
      unawaited(_prefetchProductOffers(results));
      unawaited(_prefetchStoresIndex());
    } catch (e) {
      debugPrint("Loading Offline Data...");
      List<Product> localData = OfflineManager.loadCachedProducts();

      if (mounted) {
        setState(() {
          if (localData.isNotEmpty) {
            _allProducts = localData;
            _usingOfflineProducts = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      context.tr(
                        "\u0648\u0636\u0639 \u0627\u0644\u062a\u0635\u0641\u062d \u062f\u0648\u0646 \u0627\u062a\u0635\u0627\u0644 (\u0628\u064a\u0627\u0646\u0627\u062a \u0645\u062d\u0641\u0648\u0638\u0629",
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          } else {
            _errorMessage = context.tr(
              "\u062a\u0639\u0630\u0631 \u0627\u0644\u0627\u062a\u0635\u0627\u0644 \u0648\u0644\u0627 \u062a\u0648\u062c\u062f \u0628\u064a\u0627\u0646\u0627\u062a \u0633\u0627\u0628\u0642\u0629 \u0645\u062d\u0641\u0648\u0638\u0629 \ud83d\udcf5",
            );
            _usingOfflineProducts = false;
          }
          _isLoading = false;
        });
      }
    }

    if (_exchangeRate == null && _exchangeRates.isEmpty) {
      await _fetchExchangeRate();
    }

    _applyFilters();
  }

  Future<void> _prefetchProductOffers(List<Product> products) async {
    if (!await OfflineManager.hasInternet()) return;
    final int max = products.length <= 50 ? products.length : 30;
    for (var i = 0; i < max; i++) {
      final p = products[i];
      if (OfflineManager.hasCachedProductOffers(p.id)) continue;
      try {
        final response = await _api.get(
          '${AppConfig.baseUrl}/product/${p.id}/stores',
        );
        if (response.statusCode != null && response.statusCode! < 400) {
          if (response.data is List) {
            await OfflineManager.cacheProductOffers(
              p.id,
              response.data as List,
            );
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _prefetchStoresIndex() async {
    if (!await OfflineManager.hasInternet()) return;
    try {
      final resp = await _api.get(AppConfig.storesEndpoint);
      if (resp.statusCode != null && resp.statusCode! < 400) {
        final list = resp.data is List ? resp.data as List : <dynamic>[];
        await OfflineManager.cacheStoresIndex(list);
        // Prefetch store products for a limited set
        final int max = list.length <= 50 ? list.length : 30;
        for (var i = 0; i < max; i++) {
          final name = (list[i]['store_name'] ?? '').toString();
          if (name.isEmpty) continue;
          if (OfflineManager.hasCachedStoreProducts(name)) continue;
          try {
            final productsResp = await _api.get(
              AppConfig.storeProductsEndpoint(name),
            );
            if (productsResp.statusCode != null &&
                productsResp.statusCode! < 400 &&
                productsResp.data is List) {
              await OfflineManager.cacheStoreProducts(
                name,
                productsResp.data as List,
              );
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  void _applyFilters() {
    List<Product> results = List.from(_allProducts);

    if (_selectedCategory != "الكل") {
      results = results.where((p) => p.category == _selectedCategory).toList();
    }

    if (_searchText.isNotEmpty) {
      final query = _searchText.toLowerCase();
      results = results
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
    }

    if (_currentPosition != null) {
      for (var product in results) {
        if (product.lat != 0.0) {
          double dist = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            product.lat,
            product.lng,
          );
          product.distanceFromUser = dist / 1000;
        } else {
          product.distanceFromUser = 999;
        }
      }

      results.sort((a, b) {
        double scoreA = (a.officialPrice * 0.4) + (a.distanceFromUser! * 50);
        double scoreB = (b.officialPrice * 0.4) + (b.distanceFromUser! * 50);
        return scoreA.compareTo(scoreB);
      });
    }

    setState(() {
      _filteredProducts = results;
    });
  }

  void _showFeatureInfo(String title, String body) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(body, style: GoogleFonts.cairo(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshLocation() async {
    try {
      final pos = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
      });
      _applyFilters();
      _showSnack(context.tr("تم تحديث موقعك بنجاح"));
    } catch (_) {
      _showSnack(context.tr("تعذر تحديد الموقع. تحقق من الأذونات"));
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.cairo())),
    );
  }

  String _formatPercent(double value) {
    final pct = (value * 100).clamp(0.0, 100.0);
    return '${pct.toStringAsFixed(0)}%';
  }

  Widget _buildOfflineBanner() {
    if (_isOnline && !_usingOfflineProducts && !_usingOfflineNews) {
      return const SizedBox();
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.orange.shade800, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr("وضع عدم الاتصال: قد يتم عرض بيانات محفوظة"),
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineMapDownloadBanner() {
    return ValueListenableBuilder<double?>(
      valueListenable: OfflineMapService.downloadProgress,
      builder: (context, progress, _) {
        if (progress == null) return const SizedBox();
        final percentText = _formatPercent(progress);
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_download_outlined,
                    color: Colors.blue.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr("جاري تنزيل خريطة أوفلاين"),
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                  Text(
                    percentText,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress),
            ],
          ),
        );
      },
    );
  }

  Color _withAlpha(Color color, double opacity) {
    final alpha = (opacity.clamp(0.0, 1.0) * 255).round();
    return color.withAlpha(alpha);
  }

  Widget _buildExchangeRateBanner() {
    final rates = _exchangeRates.isNotEmpty
        ? _exchangeRates
        : (_exchangeRate == null
              ? <ExchangeRateInfo>[]
              : [
                  ExchangeRateInfo(
                    currency: _exchangeCurrency ?? "USD",
                    rate: _exchangeRate,
                    date: _exchangeDate,
                  ),
                ]);
    if (rates.isEmpty) return const SizedBox();

    final hasOpenErApi = rates.any(
      (r) => (r.source ?? "").toLowerCase().contains("open_er_api"),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 110,
          margin: const EdgeInsets.symmetric(vertical: 12),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: rates.length,
            separatorBuilder: (c, i) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final r = rates[index];
              final rateText = r.rate == null
                  ? context.tr("غير متوفر")
                  : r.rate!.toStringAsFixed(2);
              final sourceLabel = _sourceLabel(context, r);

              return Container(
                width: 220,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      _withAlpha(Theme.of(context).primaryColor, 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _withAlpha(Theme.of(context).primaryColor, 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _withAlpha(Colors.white, 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.currency_exchange,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          r.currency,
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      rateText,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _withAlpha(Colors.white, 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            sourceLabel,
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (r.date != null)
                          Text(
                            r.date!,
                            style: GoogleFonts.cairo(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (hasOpenErApi)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.tr("مصدر سعر السوق: ExchangeRate-API (open.er-api.com)"),
              style: GoogleFonts.cairo(
                fontSize: 11,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
      ],
    );
  }

  String _sourceLabel(BuildContext context, ExchangeRateInfo r) {
    final type = (r.sourceType ?? "").toLowerCase();
    if (type == "official") return context.tr("رسمي");
    if (type == "market") return context.tr("سوق");
    if (type == "manual") return context.tr("يدوي");
    return (r.source ?? "").isNotEmpty ? r.source! : context.tr("غير متوفر");
  }

  Widget _buildNewsSection() {
    if (_news.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _withAlpha(Theme.of(context).dividerColor, 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: _withAlpha(Theme.of(context).shadowColor, 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.newspaper,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr("أحدث الأخبار"),
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._news
              .take(3)
              .map(
                (n) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.circle, size: 8, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${n["title"]} - ${n["date"]}",
                          style: GoogleFonts.cairo(fontSize: 13, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    final items = [
      _FeatureItem(
        icon: Icons.store_mall_directory_outlined,
        title: context.tr("المتاجر"),
        description: context.tr("ابحث عن متجر"),
        onTap: _openStoreSearch,
      ),
      _FeatureItem(
        icon: Icons.notifications_active_outlined,
        title: context.tr("تنبيهات"),
        description: context.tr("إدارة التنبيهات"),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => const NotificationsScreen()),
        ),
      ),
      _FeatureItem(
        icon: Icons.sell_outlined,
        title: context.tr("الرسمية"),
        description: context.tr("الأسعار الرسمية"),
        onTap: () => _showFeatureInfo(
          context.tr("الأسعار الرسمية"),
          context.tr("يمكنك مشاهدة الأسعار الرسمية في قائمة المنتجات أدناه."),
        ),
      ),
      _FeatureItem(
        icon: Icons.campaign_outlined,
        title: context.tr("بلاغات"),
        description: context.tr("بلغ عن مخالفة"),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => const ViolationReportScreen()),
        ),
      ),
      _FeatureItem(
        icon: Icons.my_location_outlined,
        title: context.tr("الموقع"),
        description: context.tr("تجديد الموقع"),
        onTap: _refreshLocation,
      ),
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (c, i) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _FeatureCard(item: items[index]),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: _updateSearch,
            decoration: InputDecoration(
              hintText: context.tr("ابحث عن منتج (مثل: سكر، أرز...)"),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchText.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _updateSearch("");
                      },
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _categories.map(_buildCategoryChip).toList()),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    final isSelected = _selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          context.tr(label),
          style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        selected: isSelected,
        onSelected: (_) => _setCategory(label),
        selectedColor: _withAlpha(Theme.of(context).primaryColor, 0.15),
        backgroundColor: Theme.of(context).colorScheme.surface,
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Theme.of(context).dividerColor,
        ),
      ),
    );
  }

  Widget _buildLocationBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _withAlpha(Theme.of(context).primaryColor, 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _withAlpha(Theme.of(context).primaryColor, 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.my_location,
            size: 18,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr("تم تحديد موقعك: ترتيب الأسعار حسب القرب"),
              style: GoogleFonts.cairo(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            _errorMessage.isEmpty
                ? context.tr("تعذر الاتصال بالخادم")
                : _errorMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 14),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _withAlpha(Theme.of(context).colorScheme.surface, 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _withAlpha(Theme.of(context).dividerColor, 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr("عنوان الخادم الحالي:"),
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  AppConfig.baseUrl,
                  style: GoogleFonts.cairo(fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    "تأكد أن هاتفك والكمبيوتر على نفس الشبكة وأن خادم API يعمل.",
                  ),
                  style: GoogleFonts.cairo(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _handleRefresh,
            child: Text(context.tr("إعادة المحاولة")),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            context.tr("لا توجد منتجات تطابق بحثك"),
            style: GoogleFonts.cairo(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSliver() {
    if (_isLoading) {
      // #4 – Shimmer skeleton loading instead of plain spinner
      return SliverToBoxAdapter(child: ProductListSkeleton(count: 6));
    }

    if (_errorMessage.isNotEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildErrorState(),
      );
    }

    if (_filteredProducts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final product = _filteredProducts[index];
        return ProductCard(product: product);
      }, childCount: _filteredProducts.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.tr("الأسعار اليومية"),
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: context.tr("السلة الذكية"),
            icon: const Icon(Icons.shopping_basket_outlined),
            onPressed: _openSmartBasket,
          ),
          IconButton(
            tooltip: context.tr("الإعدادات"),
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettingsSheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildSearchSection()),
            SliverToBoxAdapter(child: _buildOfflineBanner()),
            SliverToBoxAdapter(child: _buildOfflineMapDownloadBanner()),
            if (_currentPosition != null)
              SliverToBoxAdapter(child: _buildLocationBanner()),
            SliverToBoxAdapter(child: _buildExchangeRateBanner()),
            SliverToBoxAdapter(child: _buildFeaturesSection()),
            SliverToBoxAdapter(child: _buildNewsSection()),
            SliverToBoxAdapter(
              child: _buildSectionTitle(context.tr("دليل الأسعار والمواقع")),
            ),
            _buildProductsSliver(),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
  });
}

class _FeatureCard extends StatelessWidget {
  final _FeatureItem item;
  const _FeatureCard({required this.item});

  Color _withAlpha(Color color, double opacity) {
    final alpha = (opacity.clamp(0.0, 1.0) * 255).round();
    return color.withAlpha(alpha);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _withAlpha(Theme.of(context).shadowColor, 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: _withAlpha(Theme.of(context).dividerColor, 0.5),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: Theme.of(context).primaryColor, size: 28),
              const SizedBox(height: 8),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
