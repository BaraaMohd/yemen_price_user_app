import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:vector_map_tiles/vector_map_tiles.dart';
import '../../../core/widgets/numbered_marker.dart';

import '../../../core/config.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/offline_manager.dart';
import '../../../core/services/offline_map_service.dart';
import '../../../core/services/service_locator.dart';
import '../models/product.model.dart';
import '../../auth/login_screen.dart';
import '../../../core/l10n/app_localizations.dart';

class MerchantStoreScreen extends StatefulWidget {
  const MerchantStoreScreen({super.key});

  @override
  State<MerchantStoreScreen> createState() => _MerchantStoreScreenState();
}

class _MerchantStoreScreenState extends State<MerchantStoreScreen> {
  List<Product> _allOfficialProducts = [];
  bool _isLoading = true;
  bool _isOnline = true;
  bool _usingOfflineData = false;
  String _storeName = "";
  String _phone = "";
  double _myRating = 5.0;
  double _storeLat = 0.0;
  double _storeLng = 0.0;
  final Map<int, bool> _availability = {};
  OfflineMapLayerConfig? _offlineMapLayer;

  @override
  void initState() {
    super.initState();
    _loadMerchantData();
    _loadOfflineTiles();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadMerchantData() async {
    final session = await AuthSession.load();
    final role = (session['role'] ?? '').toString().toLowerCase();
    final storeName = (session['store_name'] ?? '').toString();
    final phone = (session['phone'] ?? '').toString();

    if (role != AuthSession.roleMerchant ||
        storeName.isEmpty ||
        phone.isEmpty) {
      if (!mounted) return;
      _showSnack(context.tr("يرجى تسجيل الدخول"), isError: true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    setState(() {
      _storeName = storeName;
      _phone = phone;
      _storeLat = (session['lat'] as num?)?.toDouble() ?? 0.0;
      _storeLng = (session['lng'] as num?)?.toDouble() ?? 0.0;
      _myRating = (session['rating'] as num?)?.toDouble() ?? 5.0;
    });

    final online = await OfflineManager.hasInternet();
    if (mounted) setState(() => _isOnline = online);

    if (!online) {
      final local = OfflineManager.loadCachedMerchantCatalog(
        maxAge: const Duration(days: 7),
      );
      if (mounted) {
        setState(() {
          _allOfficialProducts = local;
          _usingOfflineData = local.isNotEmpty;
          _rebuildAvailability(local);
          _isLoading = false;
        });
      }
      return;
    }

    await OfflineManager.syncPendingMerchantActions();

    try {
      final hashResponse = await locator<Dio>().get(
        AppConfig.merchantCatalogHashEndpoint,
        queryParameters: {"phone": _phone},
      );
      final serverHash = hashResponse.data is Map
          ? hashResponse.data['hash']?.toString()
          : null;
      final cachedHash = OfflineManager.loadMerchantCatalogHash();
      if (serverHash != null && serverHash == cachedHash) {
        final cached = OfflineManager.loadCachedMerchantCatalog(
          maxAge: const Duration(hours: 24),
        );
        if (cached.isNotEmpty && mounted) {
          setState(() {
            _allOfficialProducts = cached;
            _usingOfflineData = false;
            _rebuildAvailability(cached);
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {
      // Continue to live catalog fetch.
    }

    try {
      final response = await locator<Dio>().get(
        AppConfig.merchantCatalogEndpoint,
        queryParameters: {"phone": _phone},
      );
      final products = _extractMerchantCatalog(response.data);
      await OfflineManager.cacheMerchantCatalog(products);

      try {
        final hashResponse = await locator<Dio>().get(
          AppConfig.merchantCatalogHashEndpoint,
          queryParameters: {"phone": _phone},
        );
        final serverHash = hashResponse.data is Map
            ? hashResponse.data['hash']?.toString()
            : null;
        if (serverHash != null && serverHash.isNotEmpty) {
          await OfflineManager.saveMerchantCatalogHash(serverHash);
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _allOfficialProducts = products;
          _usingOfflineData = false;
          _rebuildAvailability(products);
          _isLoading = false;
        });
      }
    } catch (_) {
      final local = OfflineManager.loadCachedMerchantCatalog(
        maxAge: const Duration(days: 7),
      );
      if (mounted) {
        setState(() {
          _allOfficialProducts = local;
          _usingOfflineData = local.isNotEmpty;
          _rebuildAvailability(local);
          _isLoading = false;
        });
      }
    }
  }

  List<Product> _extractMerchantCatalog(dynamic payload) {
    final raw = payload is Map && payload['items'] is List
        ? payload['items'] as List
        : (payload is List ? payload : <dynamic>[]);
    return raw.whereType<Map>().map((entry) {
      return Product.fromJson(Map<String, dynamic>.from(entry));
    }).toList();
  }

  void _rebuildAvailability(List<Product> products) {
    final ids = products.map((p) => p.id).toSet();
    _availability.removeWhere((id, _) => !ids.contains(id));
    for (final p in products) {
      _availability.putIfAbsent(p.id, () => true);
    }
  }

  Future<void> _loadOfflineTiles() async {
    final layer = await OfflineMapService.getOfflineLayerConfig();
    if (!mounted) return;
    setState(() => _offlineMapLayer = layer);
  }

  void _updatePrice(Product p, String inputPrice) async {
    if (inputPrice.isEmpty) return;
    double? newPrice = double.tryParse(inputPrice);
    if (newPrice == null) return;

    final online = await OfflineManager.hasInternet();
    if (!online) {
      await OfflineManager.queueMerchantPriceUpdate(
        phone: _phone,
        productId: p.id,
        price: newPrice,
        lat: _storeLat,
        lng: _storeLng,
      );
      if (!mounted) return;
      _showSnack(context.tr("تم حفظ التحديث وسيتم المزامنة عند الاتصال"));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await locator<Dio>().post(
        AppConfig.updatePriceEndpoint,
        data: {
          "phone": _phone,
          "product_id": p.id,
          "price": newPrice,
          "lat": _storeLat,
          "lng": _storeLng,
        },
      );

      if (mounted) {
        final serverOfficial = response.data is Map
            ? (response.data['official_price'] as num?)?.toDouble()
            : null;
        final effectiveOfficial = serverOfficial ?? p.officialPrice;
        final isNonCompliant = newPrice > effectiveOfficial;

        final ratingVal = response.data is Map ? response.data['rating'] : null;
        if (ratingVal is num) {
          _myRating = ratingVal.toDouble();
          await AuthSession.updateRating(_myRating);
        }
        await _loadMerchantData();
        if (!mounted) return;
        _showSnack(
          (response.data is Map && response.data['message'] != null)
              ? response.data['message'].toString()
              : context.tr("تم التحديث"),
          isError: isNonCompliant,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        context.tr("⚠️ فشل الاتصال بالسيرفر، تأكد من البايثون"),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setAvailability(int productId, bool available) async {
    final online = await OfflineManager.hasInternet();
    if (!online) {
      await OfflineManager.queueMerchantAvailabilityUpdate(
        phone: _phone,
        productId: productId,
        available: available,
      );
      if (!mounted) return;
      _showSnack(context.tr("تم حفظ التغيير وسيتم المزامنة عند الاتصال"));
      return;
    }
    try {
      final response = await locator<Dio>().post(
        AppConfig.availabilityEndpoint,
        data: {
          "phone": _phone,
          "product_id": productId,
          "available": available,
        },
      );
      final ok = response.data is Map && response.data['status'] == 'success';
      if (!ok && mounted) {
        setState(() => _availability[productId] = !available);
        _showSnack(context.tr("فشل حفظ البيانات"), isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _availability[productId] = !available);
        _showSnack(context.tr("فشل حفظ البيانات"), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.tr("بوابة التاجر - السمعة الإلكترونية"),
          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.primaryColor,
        foregroundColor: scheme.onPrimary,
        actions: [
          IconButton(
            tooltip: context.tr("تسجيل الخروج"),
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await AuthSession.clearAuthOnly();
              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  if (!_isOnline || _usingOfflineData)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.wifi_off,
                              color: Colors.orange.shade800,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.tr(
                                  "وضع عدم الاتصال: سيتم حفظ التحديثات للمزامنة",
                                ),
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.primaryColor,
                          theme.primaryColor.withValues(alpha: 0.72),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withValues(alpha: 0.28),
                          blurRadius: 20,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _storeName,
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 21,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr("تقييم الالتزام بالتسعيرة:"),
                                style: GoogleFonts.cairo(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: List.generate(
                                  5,
                                  (index) => Icon(
                                    index < _myRating.round()
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: Colors.amberAccent,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.show_chart,
                                color: Colors.white70,
                                size: 16,
                              ),
                              Text(
                                _myRating.toStringAsFixed(1),
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(
                      height: 180,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowColor.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (_storeLat == 0.0 && _storeLng == 0.0)
                          ? Center(
                              child: Text(
                                context.tr("لم يتم تحديد موقع المتجر بعد"),
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            )
                          : (!_isOnline && _offlineMapLayer == null)
                          ? Center(
                              child: Text(
                                context.tr("الخريطة غير متاحة دون اتصال"),
                                style: GoogleFonts.cairo(fontSize: 12),
                              ),
                            )
                          : FlutterMap(
                              options: MapOptions(
                                initialCenter: ll.LatLng(_storeLat, _storeLng),
                                initialZoom: 14.0,
                                interactionOptions: const InteractionOptions(
                                  flags:
                                      InteractiveFlag.pinchZoom |
                                      InteractiveFlag.drag,
                                ),
                              ),
                              children: [
                                if (_offlineMapLayer?.isVector ?? false)
                                  VectorTileLayer(
                                    theme: _offlineMapLayer!.vectorTheme!,
                                    tileProviders: TileProviders({
                                      'openmaptiles':
                                          _offlineMapLayer!.vectorProvider!,
                                    }),
                                    maximumZoom: 18,
                                  )
                                else
                                  TileLayer(
                                    urlTemplate:
                                        _offlineMapLayer?.rasterProvider != null
                                        ? 'mbtiles://{z}/{x}/{y}'
                                        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    tileProvider:
                                        _offlineMapLayer?.rasterProvider,
                                    userAgentPackageName:
                                        'com.yemen.price.system',
                                  ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: ll.LatLng(_storeLat, _storeLng),
                                      width: 46,
                                      height: 46,
                                      child: const NumberedMarker(
                                        number: 1,
                                        size: 36,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit_note, color: theme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            context.tr("قائمة أسعار الرف المعتمدة لليوم:"),
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                      itemCount: _allOfficialProducts.length,
                      itemBuilder: (context, index) {
                        final p = _allOfficialProducts[index];
                        final priceInput = TextEditingController();

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.25),
                            ),
                          ),
                          color: scheme.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 21,
                                      backgroundColor: theme.primaryColor
                                          .withValues(alpha: 0.1),
                                      child: Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 20,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  "${context.tr("الرسمي:")} ${p.officialPrice} ر.ي",
                                                  style: GoogleFonts.cairo(
                                                    color:
                                                        Colors.green.shade700,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              if (p.fairPrice != null)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.teal.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    "${context.tr("السعر العادل")}: ${p.fairPrice} ر.ي",
                                                    style: GoogleFonts.cairo(
                                                      color:
                                                          Colors.teal.shade700,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: priceInput,
                                        decoration: InputDecoration(
                                          hintText: context.tr(
                                            "أدخل السعر في متجرك حالياً",
                                          ),
                                          hintStyle: GoogleFonts.cairo(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 12,
                                              ),
                                          filled: true,
                                          fillColor: scheme.surface.withValues(
                                            alpha: 0.8,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: theme.dividerColor
                                                  .withValues(alpha: 0.35),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: theme.dividerColor
                                                  .withValues(alpha: 0.35),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: theme.primaryColor,
                                              width: 1.4,
                                            ),
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.primaryColor,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _updatePrice(p, priceInput.text),
                                      child: Text(
                                        context.tr("تحديث"),
                                        style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Switch(
                                      value: _availability[p.id] ?? true,
                                      activeThumbColor: Colors.white,
                                      activeTrackColor: Colors.green.shade500,
                                      onChanged: (value) {
                                        setState(
                                          () => _availability[p.id] = value,
                                        );
                                        _setAvailability(p.id, value);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
