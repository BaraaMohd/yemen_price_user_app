import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart' as ll; 
import 'package:vector_map_tiles/vector_map_tiles.dart';
import '../../../core/config.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/offline_manager.dart';
import '../../../core/services/offline_map_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/l10n/app_localizations.dart';

class MerchantSignupScreen extends StatefulWidget {
  const MerchantSignupScreen({super.key});

  @override
  State<MerchantSignupScreen> createState() => _MerchantSignupScreenState();
}

class _MerchantSignupScreenState extends State<MerchantSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passController = TextEditingController();
  final MapController _mapController = MapController();
  OfflineMapLayerConfig? _offlineMapLayer;

  ll.LatLng _selectedLocation = ll.LatLng(15.3534, 44.2057);
  bool _isLoading = false;
  bool _isGettingGps = false;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _loadOfflineTiles();
    _refreshConnectivity();
  }

  Future<void> _loadOfflineTiles() async {
    final layer = await OfflineMapService.getOfflineLayerConfig();
    if (!mounted) return;
    setState(() {
      _offlineMapLayer = layer;
    });
  }

  Future<void> _refreshConnectivity() async {
    final online = await OfflineManager.hasInternet();
    if (!mounted) return;
    setState(() {
      _isOnline = online;
    });
  }

  Future<void> _moveMapToCurrentLocation() async {
    setState(() => _isGettingGps = true);
    final pos = await LocationService.getCurrentLocation();
    if (pos != null) {
      final newPos = ll.LatLng(pos.latitude, pos.longitude);
      setState(() {
        _selectedLocation = newPos;
        _isGettingGps = false;
      });
      _mapController.move(newPos, 16.0);
    } else {
      setState(() => _isGettingGps = false);
      if (!mounted) return;
      _showSnack(context.tr("يرجى تفعيل نظام الـ GPS في الهاتف"), Colors.orange);
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final online = await OfflineManager.hasInternet();
    if (!mounted) return;
    if (!online) {
      _showSnack(context.tr("لا يوجد اتصال بالإنترنت لإتمام التسجيل"), Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await locator<Dio>().post(
        AppConfig.signupEndpoint,
        data: FormData.fromMap({
          "store_name": _nameController.text.trim(),
          "phone": _phoneController.text.trim(),
          "password": _passController.text.trim(),
          "lat": _selectedLocation.latitude,
          "lng": _selectedLocation.longitude,
          "owner_name": "رسمي",
        }),
      );

      if (!mounted) return;
      if (response.data['status'] == 'success') {
        _showSnack(context.tr("تم تسجيل متجرك بنجاح ✅"), Colors.green);
        Navigator.pop(context);
      } else {
        _showSnack(response.data['message'] ?? context.tr("حدث خطأ في التسجيل"), Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        context.tr("حدث خطأ في التسجيل: رقم الهاتف مسجل مسبقاً أو تعذر الاتصال"),
        Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.tr("انضمام متجر جديد")),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr("بيانات المنشأة التجارية"),
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              _buildField(_nameController, context.tr("اسم المتجر (المول / البقالة)"), Icons.store),
              const SizedBox(height: 15),
              _buildField(_phoneController, context.tr("رقم هاتف المتجر"), Icons.phone, isPhone: true),
              const SizedBox(height: 15),
              _buildField(_passController, context.tr("تعيين كلمة المرور"), Icons.lock_open, isPass: true),
              const SizedBox(height: 25),
              Text(
                context.tr("📍 حدد موقع متجرك الجغرافي على الخريطة:"),
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Theme.of(context).dividerColor, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    (!_isOnline && _offlineMapLayer == null)
                        ? Center(child: Text(context.tr("الخريطة غير متاحة دون اتصال"), style: GoogleFonts.cairo(fontSize: 12)))
                        : FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _selectedLocation,
                              initialZoom: 13.5,
                              onTap: (tapPosition, point) => setState(() => _selectedLocation = point),
                            ),
                            children: [
                              if (_offlineMapLayer?.isVector ?? false)
                                VectorTileLayer(
                                  theme: _offlineMapLayer!.vectorTheme!,
                                  tileProviders: TileProviders({'openmaptiles': _offlineMapLayer!.vectorProvider!}),
                                  maximumZoom: 18,
                                )
                              else
                                TileLayer(
                                  urlTemplate: _offlineMapLayer?.rasterProvider != null ? 'mbtiles://{z}/{x}/{y}' : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  tileProvider: _offlineMapLayer?.rasterProvider,
                                ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _selectedLocation,
                                    width: 50,
                                    height: 50,
                                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                                  ),
                                ],
                              ),
                            ],
                          ),
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: FloatingActionButton.small(
                        heroTag: "gps_btn",
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        onPressed: _moveMapToCurrentLocation,
                        child: _isGettingGps ? const CircularProgressIndicator(strokeWidth: 2) : Icon(Icons.my_location, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(context.tr("تأكيد تسجيل المتجر والموقع"), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String lbl, IconData icon, {bool isPass = false, bool isPhone = false}) {
    return TextFormField(
      controller: ctrl,
      obscureText: isPass,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: lbl,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: (v) => (v == null || v.isEmpty) ? context.tr("حقل مطلوب") : null,
    );
  }
}
