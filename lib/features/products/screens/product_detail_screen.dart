import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:vector_map_tiles/vector_map_tiles.dart';
import '../../../core/widgets/numbered_marker.dart';

import '../../../core/config.dart';
import '../../../core/services/offline_manager.dart';
import '../../../core/services/offline_map_service.dart';
import '../../../core/services/service_locator.dart';
import '../models/product.model.dart';
import '../../../core/l10n/app_localizations.dart';
import 'store_detail_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final formatter = NumberFormat('#,###');
  final ScrollController _scrollController = ScrollController();
  final MapController _mapController = MapController();

  List<dynamic> _storeOffers = [];
  bool _isLoading = true;
  bool _usingOfflineData = false;
  bool _isOnline = true;
  bool _showOfficialFallback = false;
  Position? _userPosition;

  ll.LatLng? _selectedMarkerLocation;
  String? _selectedStoreName;
  List<ll.LatLng> _routePoints = [];
  double? _routeDistanceKm;
  int? _routeDurationMin;
  OfflineMapLayerConfig? _offlineMapLayer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _loadOfflineTiles();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOfflineTiles() async {
    final layer = await OfflineMapService.getOfflineLayerConfig();
    if (!mounted) return;
    setState(() {
      _offlineMapLayer = layer;
    });
  }

  Future<void> _fetchData() async {
    bool online = await OfflineManager.hasInternet();
    if (!mounted) return;
    setState(() {
      _isOnline = online;
      _isLoading = true;
    });

    try {
      _userPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      _userPosition = null;
    }

    if (!online) {
      final cached = OfflineManager.loadCachedProductOffers(widget.product.id);
      if (mounted) {
        final hasCached = cached.isNotEmpty;
        List<dynamic> fallback = cached;
        bool showFallback = false;
        if (!hasCached) {
          final name = widget.product.storeName.trim();
          if (name.isNotEmpty) {
            fallback = [
              {
                'store_name': name,
                'price': widget.product.officialPrice,
                'lat': widget.product.lat,
                'lng': widget.product.lng,
                'rating': widget.product.rating,
              },
            ];
            showFallback = true;
          }
        }
        setState(() {
          _storeOffers = fallback;
          _usingOfflineData = hasCached || showFallback;
          _showOfficialFallback = showFallback;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final response = await locator<Dio>().get(
        AppConfig.productStoresEndpoint(widget.product.id),
      );

      if (mounted) {
        List<dynamic> rawOffers = response.data;

        rawOffers.sort((a, b) {
          double priceA = (a['price'] as num).toDouble();
          double priceB = (b['price'] as num).toDouble();
          int priceCompare = priceA.compareTo(priceB);
          if (priceCompare != 0) return priceCompare;

          if (_userPosition != null) {
            double distA = Geolocator.distanceBetween(
              _userPosition!.latitude,
              _userPosition!.longitude,
              (a['lat'] as num).toDouble(),
              (a['lng'] as num).toDouble(),
            );
            double distB = Geolocator.distanceBetween(
              _userPosition!.latitude,
              _userPosition!.longitude,
              (b['lat'] as num).toDouble(),
              (b['lng'] as num).toDouble(),
            );
            return distA.compareTo(distB);
          }

          double ratingA = (a['rating'] ?? 0).toDouble();
          double ratingB = (b['rating'] ?? 0).toDouble();
          return ratingB.compareTo(ratingA);
        });

        OfflineManager.cacheProductOffers(widget.product.id, rawOffers);

        setState(() {
          _storeOffers = rawOffers;
          _usingOfflineData = false;
          _showOfficialFallback = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      final cached = OfflineManager.loadCachedProductOffers(widget.product.id);
      if (mounted) {
        final hasCached = cached.isNotEmpty;
        List<dynamic> fallback = cached;
        bool showFallback = false;
        if (!hasCached) {
          final name = widget.product.storeName.trim();
          if (name.isNotEmpty) {
            fallback = [
              {
                'store_name': name,
                'price': widget.product.officialPrice,
                'lat': widget.product.lat,
                'lng': widget.product.lng,
                'rating': widget.product.rating,
              },
            ];
            showFallback = true;
          }
        }
        setState(() {
          _storeOffers = fallback;
          _usingOfflineData = hasCached || showFallback;
          _showOfficialFallback = showFallback;
          _isLoading = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.cairo())),
    );
  }

  Future<void> _getRouteToStore(ll.LatLng dest) async {
    if (!_isOnline) {
      _showSnack(context.tr("لا يوجد اتصال بالإنترنت لعرض المسار"));
      return;
    }
    if (_userPosition == null) return;
    setState(() {
      _routePoints = [];
      _routeDistanceKm = null;
      _routeDurationMin = null;
    });

    try {
      final start = "${_userPosition!.longitude},${_userPosition!.latitude}";
      final end = "${dest.longitude},${dest.latitude}";
      final url =
          "http://router.project-osrm.org/route/v1/driving/$start;$end?geometries=geojson";

      final response = await locator<Dio>().get(url);

      if (response.statusCode == 200) {
        final List coordinates =
            response.data['routes'][0]['geometry']['coordinates'];
        final List<ll.LatLng> points = coordinates
            .map((p) => ll.LatLng(p[1].toDouble(), p[0].toDouble()))
            .toList();

        final double distanceMeters = (response.data['routes'][0]['distance'] as num).toDouble();
        final double durationSeconds = (response.data['routes'][0]['duration'] as num).toDouble();

        if (mounted) {
          setState(() {
            _routePoints = points;
            _routeDistanceKm = distanceMeters / 1000.0;
            _routeDurationMin = (durationSeconds / 60).round();
          });
        }
      }
    } catch (_) {}
  }

  void _focusStoreOnMap(double lat, double lng, String storeName) {
    ll.LatLng target = ll.LatLng(lat, lng);
    setState(() {
      _selectedMarkerLocation = target;
      _selectedStoreName = storeName;
    });

    _getRouteToStore(target);

    Future.delayed(const Duration(milliseconds: 200), () {
      _mapController.move(target, 14.0);
    });

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );
  }

  Widget _buildTopHeader() {
    bool isMapActive = _selectedMarkerLocation != null;

    final bool showOfflineMapWarning = !_isOnline && _offlineMapLayer == null;

    if (isMapActive && showOfflineMapWarning) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
        ),
        child: Center(
          child: Text(
            context.tr("الخريطة غير متاحة دون اتصال"),
            style: GoogleFonts.cairo(fontSize: 12),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: isMapActive ? 300 : 130,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: isMapActive
          ? Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedMarkerLocation!,
                    initialZoom: 14.0,
                  ),
                  children: [
                    if (_offlineMapLayer?.isVector ?? false)
                      VectorTileLayer(
                        theme: _offlineMapLayer!.vectorTheme!,
                        tileProviders: TileProviders({
                          'openmaptiles': _offlineMapLayer!.vectorProvider!,
                        }),
                        maximumZoom: 18,
                      )
                    else
                      TileLayer(
                        urlTemplate: _offlineMapLayer?.rasterProvider != null
                            ? 'mbtiles://{z}/{x}/{y}'
                            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        tileProvider: _offlineMapLayer?.rasterProvider,
                        userAgentPackageName: 'com.yemen.price.system',
                      ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 5.0,
                            color: Colors.blue.shade700,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedMarkerLocation!,
                          width: 50,
                          height: 50,
                          child: const NumberedMarker(number: 1),
                        ),
                        if (_userPosition != null)
                          Marker(
                            point: ll.LatLng(
                              _userPosition!.latitude,
                              _userPosition!.longitude,
                            ),
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 30,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: () => setState(() {
                        _selectedMarkerLocation = null;
                        _routePoints = [];
                        _routeDistanceKm = null;
                        _routeDurationMin = null;
                      }),
                    ),
                  ),
                ),
                if (_routeDistanceKm != null && _routeDurationMin != null)
                  Positioned(
                    left: 10,
                    top: 58,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).shadowColor.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        "${context.tr("المسافة:")} ${_routeDistanceKm!.toStringAsFixed(1)} ${context.tr("كم")} • ${context.tr("الزمن:")} $_routeDurationMin ${context.tr("دقيقة")}",
                        style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                if (_selectedStoreName != null)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedStoreName!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 50,
                  color: Colors.blue.shade300,
                ),
                const SizedBox(height: 5),
                Text(
                  widget.product.category,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  context.tr("اضغط 📌 لعرض موقع المتجر ومسار الطريق"),
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: Colors.blue.shade400,
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.tr("دليل الأسعار والمواقع"),
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  _buildTopHeader(),

                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          widget.product.name,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "${context.tr("السعر الرسمي:")} ${formatter.format(widget.product.officialPrice)} ر.ي",
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(thickness: 8, color: Color(0xFFF7F7F7)),

                  if (_usingOfflineData)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.wifi_off,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.tr("عرض بيانات مخزنة دون اتصال"),
                                style: GoogleFonts.cairo(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_showOfficialFallback)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.tr(
                                  "لا توجد عروض محفوظة، يتم عرض السعر الرسمي فقط",
                                ),
                                style: GoogleFonts.cairo(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr("ترتيب العروض:"),
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            context.tr("الأرخص أولاً ثم الأقرب ⬇️"),
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _storeOffers.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text(
                            context.tr("لا توجد بيانات متاجر لهذا الصنف حالياً"),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _storeOffers.length,
                          itemBuilder: (context, index) {
                            final store = _storeOffers[index];
                            final double sPrice = (store['price'] as num).toDouble();
                            final double sLat = (store['lat'] ?? 0.0).toDouble();
                            final double sLng = (store['lng'] ?? 0.0).toDouble();
                            final bool isFirst = index == 0;

                            double? dist;
                            if (_userPosition != null) {
                              dist = Geolocator.distanceBetween(
                                    _userPosition!.latitude,
                                    _userPosition!.longitude,
                                    sLat,
                                    sLng,
                                  ) /
                                  1000;
                            }

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isFirst
                                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                                      : Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: isFirst
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).dividerColor,
                                    width: isFirst ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Column(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: isFirst
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                                          child: Icon(
                                            Icons.store,
                                            color: isFirst
                                                ? Theme.of(context).colorScheme.onPrimary
                                                : Theme.of(context).colorScheme.primary,
                                            size: 20,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            size: 12,
                                            color: Colors.amber,
                                          ),
                                          Text(
                                            " ${store['rating'] ?? 4.5}",
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (isFirst)
                                          Text(
                                            context.tr("🥇 الصفقة الرابحة"),
                                            style: GoogleFonts.cairo(
                                              fontSize: 10,
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        Text(
                                          store['store_name'] ??
                                              context.tr("متجر"),
                                          style: GoogleFonts.cairo(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (dist != null)
                                          Text(
                                            "${context.tr("📍 يبعد")} ${dist.toStringAsFixed(1)} ${context.tr("كم")}",
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "${formatter.format(sPrice)} ر.ي",
                                        style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: sPrice <=
                                                  widget.product.officialPrice
                                              ? Colors.green.shade700
                                              : Colors.red,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.location_searching,
                                              size: 20,
                                              color: Colors.blue,
                                            ),
                                            onPressed: () => _focusStoreOnMap(
                                              sLat,
                                              sLng,
                                              store['store_name'],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.storefront_outlined,
                                              size: 20,
                                              color: Colors.teal,
                                            ),
                                            onPressed: () {
                                              final name = (store['store_name'] ?? '').toString();
                                              if (name.isEmpty) return;
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (c) => StoreDetailScreen(storeName: name),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
