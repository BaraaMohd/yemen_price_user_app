import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:flutter_map/flutter_map.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import '../../../core/services/service_locator.dart';
import '../models/product.model.dart';
import '../../../core/config.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/services/offline_map_service.dart';
import '../../../core/widgets/numbered_marker.dart';

class SmartBasketScreen extends StatefulWidget {
  final List<Product> allProducts;
  const SmartBasketScreen({super.key, required this.allProducts});

  @override
  State<SmartBasketScreen> createState() => _SmartBasketScreenState();
}

class _SmartBasketScreenState extends State<SmartBasketScreen> {
  bool _isLoading = false;
  String? _error;
  String? _serverMessage;
  String _recommendationType = "";
  List<dynamic> _recommendations = [];
  double _totalCost = 0;
  double _savings = 0;
  final double _budgetCap = 0;
  final bool _useBudget = false;

  OfflineMapLayerConfig? _offlineMapLayer;

  @override
  void initState() {
    super.initState();
    _loadOfflineTiles();
    _analyzeBasket();
  }

  Future<void> _loadOfflineTiles() async {
    final layer = await OfflineMapService.getOfflineLayerConfig();
    if (!mounted) return;
    setState(() => _offlineMapLayer = layer);
  }

  Future<void> _analyzeBasket() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _serverMessage = null;
    });

    try {
      final uniqueProducts = <int, Product>{};
      for (final p in widget.allProducts) {
        uniqueProducts[p.id] = p;
      }

      final basketItems = uniqueProducts.values
          .map((p) => {"product_id": p.id, "quantity": 1})
          .toList();
      if (basketItems.isEmpty) {
        throw Exception("empty-basket");
      }

      final Map<String, dynamic> payload = {"items": basketItems};
      if (_useBudget && _budgetCap > 0) {
        payload["budget_cap"] = _budgetCap;
      }

      final response = await locator<Dio>().post(
        AppConfig.smartBasketEndpoint,
        data: payload,
      );

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (mounted) {
        setState(() {
          _recommendationType = (data['recommendation'] ?? "").toString();
          _recommendations = _extractRecommendations(data);
          _totalCost = _extractTotalCost(data);
          _savings = _asDouble(data['savings']);
          _serverMessage = data['message']?.toString();
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = _dioErrorToMessage(e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = context.tr(
            "فشل تحليل السلة الذكية. تأكد من الاتصال بالإنترنت.",
          );
        });
      }
    }
  }

  List<dynamic> _extractRecommendations(Map<String, dynamic> data) {
    final legacy = data['recommendations'];
    if (legacy is List) return legacy;

    final groupedByStore = <String, Map<String, dynamic>>{};
    final splitOption = data['split_option'];
    if (splitOption is Map<String, dynamic>) {
      final details = splitOption['details'];
      if (details is List) {
        for (final row in details) {
          if (row is! Map) continue;
          final item = Map<String, dynamic>.from(row.cast<String, dynamic>());
          final store = (item['store_name'] ?? context.tr("متجر")).toString();
          final entry = groupedByStore.putIfAbsent(store, () {
            return {
              'store_name': store,
              'items': <Map<String, dynamic>>[],
              'lat': item['lat'],
              'lng': item['lng'],
            };
          });
          (entry['items'] as List<Map<String, dynamic>>).add(item);
        }
      }
    }

    final singleOption = data['single_option'];
    if (singleOption is Map<String, dynamic>) {
      final store = (singleOption['store_name'] ?? context.tr("متجر"))
          .toString();
      groupedByStore.putIfAbsent(store, () {
        return {
          'store_name': store,
          'items': <Map<String, dynamic>>[],
          'lat': singleOption['lat'],
          'lng': singleOption['lng'],
        };
      });
    }

    return groupedByStore.values.toList();
  }

  double _extractTotalCost(Map<String, dynamic> data) {
    final recommendation = (data['recommendation'] ?? "").toString();
    final singleOption = data['single_option'];
    final splitOption = data['split_option'];

    if (recommendation == "SINGLE" &&
        singleOption is Map<String, dynamic> &&
        singleOption['total'] != null) {
      return _asDouble(singleOption['total']);
    }
    if (recommendation == "SPLIT" &&
        splitOption is Map<String, dynamic> &&
        splitOption['total_cost'] != null) {
      return _asDouble(splitOption['total_cost']);
    }

    if (data.containsKey('total_cost')) {
      return _asDouble(data['total_cost']);
    }
    if (splitOption is Map<String, dynamic> &&
        splitOption['total_cost'] != null) {
      return _asDouble(splitOption['total_cost']);
    }
    if (singleOption is Map<String, dynamic> && singleOption['total'] != null) {
      return _asDouble(singleOption['total']);
    }
    return 0;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }

  String _dioErrorToMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    if (data is String && data.isNotEmpty) return data;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return context.tr("انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى");
    }
    return context.tr("فشل تحليل السلة الذكية. تأكد من الاتصال بالإنترنت.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr("السلة العائلية الذكية"),
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, style: GoogleFonts.cairo()))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(),
                const SizedBox(height: 20),
                if (_serverMessage != null && _serverMessage!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _serverMessage!,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(
                  context.tr("أفضل أماكن الشراء المقترحة:"),
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                if (_recommendations.isEmpty)
                  Text(
                    context.tr("لا توجد نتائج متاحة حالياً"),
                    style: GoogleFonts.cairo(),
                  )
                else
                  ..._recommendations.map(
                    (rec) => _buildRecommendationCard(rec),
                  ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr("التكلفة الإجمالية:"),
                  style: GoogleFonts.cairo(fontSize: 16),
                ),
                Text(
                  "${_totalCost.toStringAsFixed(0)} ر.ي",
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            if (_recommendationType.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr("التوصية:"),
                    style: GoogleFonts.cairo(fontSize: 14),
                  ),
                  Text(
                    _recommendationType == "SPLIT"
                        ? context.tr("خيار التقسيم الذكي")
                        : _recommendationType == "SINGLE"
                        ? context.tr("خيار المتجر الواحد")
                        : _recommendationType,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _recommendationType == "SPLIT"
                          ? Colors.green
                          : Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr("التوفير المحقق:"),
                  style: GoogleFonts.cairo(fontSize: 14, color: Colors.green),
                ),
                Text(
                  "${_savings.toStringAsFixed(0)} ر.ي",
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(dynamic rec) {
    final storeName = rec['store_name'];
    final items = rec['items'] as List? ?? [];
    final lat = _asDouble(rec['lat']);
    final lng = _asDouble(rec['lng']);
    final hasMapLocation = lat != 0 && lng != 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.store)),
            title: Text(
              storeName,
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "${items.length} ${context.tr("أصناف مقترحة")}",
              style: GoogleFonts.cairo(fontSize: 12),
            ),
          ),
          if (hasMapLocation)
            Container(
              height: 150,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: ll.LatLng(lat, lng),
                  initialZoom: 14,
                ),
                children: [
                  if (_offlineMapLayer?.isVector ?? false)
                    VectorTileLayer(
                      theme: _offlineMapLayer!.vectorTheme!,
                      tileProviders: TileProviders({
                        'openmaptiles': _offlineMapLayer!.vectorProvider!,
                      }),
                    )
                  else
                    TileLayer(
                      urlTemplate: _offlineMapLayer?.rasterProvider != null
                          ? 'mbtiles://{z}/{x}/{y}'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      tileProvider: _offlineMapLayer?.rasterProvider,
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: ll.LatLng(lat, lng),
                        width: 40,
                        height: 40,
                        child: const NumberedMarker(number: 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items
                  .map<Widget>(
                    (item) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['product_name'] ?? "",
                            style: GoogleFonts.cairo(fontSize: 13),
                          ),
                        ),
                        Text(
                          "${_asDouble(item['subtotal'] ?? item['price'] ?? item['price_unit']).toStringAsFixed(0)} ر.ي",
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
