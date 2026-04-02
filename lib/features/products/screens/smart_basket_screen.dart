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
    });

    try {
      final Map<String, dynamic> payload = {
        "product_ids": widget.allProducts.map((p) => p.id).toList(),
      };
      if (_useBudget && _budgetCap > 0) {
        payload["budget_cap"] = _budgetCap;
      }

      final response = await locator<Dio>().post(
        AppConfig.smartBasketEndpoint,
        data: payload,
      );

      if (mounted) {
        setState(() {
          _recommendations = response.data['recommendations'] ?? [];
          _totalCost = (response.data['total_cost'] as num).toDouble();
          _savings = (response.data['savings_vs_official'] as num).toDouble();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = context.tr("فشل تحليل السلة الذكية. تأكد من الاتصال بالإنترنت.");
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr("السلة العائلية الذكية"), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
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
                    Text(context.tr("أفضل أماكن الشراء المقترحة:"), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    ..._recommendations.map((rec) => _buildRecommendationCard(rec)),
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
                Text(context.tr("التكلفة الإجمالية:"), style: GoogleFonts.cairo(fontSize: 16)),
                Text("${_totalCost.toStringAsFixed(0)} ر.ي", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.tr("التوفير المحقق:"), style: GoogleFonts.cairo(fontSize: 14, color: Colors.green)),
                Text("${_savings.toStringAsFixed(0)} ر.ي", style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(dynamic rec) {
    final storeName = rec['store_name'];
    final items = rec['items'] as List;
    final lat = (rec['lat'] as num).toDouble();
    final lng = (rec['lng'] as num).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.store)),
            title: Text(storeName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            subtitle: Text("${items.length} ${context.tr("أصناف مقترحة")}", style: GoogleFonts.cairo(fontSize: 12)),
          ),
          Container(
            height: 150,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            clipBehavior: Clip.antiAlias,
            child: FlutterMap(
              options: MapOptions(initialCenter: ll.LatLng(lat, lng), initialZoom: 14),
              children: [
                if (_offlineMapLayer?.isVector ?? false)
                  VectorTileLayer(
                    theme: _offlineMapLayer!.vectorTheme!,
                    tileProviders: TileProviders({'openmaptiles': _offlineMapLayer!.vectorProvider!}),
                  )
                else
                  TileLayer(
                    urlTemplate: _offlineMapLayer?.rasterProvider != null ? 'mbtiles://{z}/{x}/{y}' : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    tileProvider: _offlineMapLayer?.rasterProvider,
                  ),
                MarkerLayer(markers: [Marker(point: ll.LatLng(lat, lng), width: 40, height: 40, child: const NumberedMarker(number: 1))]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.map<Widget>((item) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item['product_name'] ?? "", style: GoogleFonts.cairo(fontSize: 13)),
                  Text("${item['price']} ر.ي", style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
