import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../../../../core/config.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/offline_manager.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/l10n/app_localizations.dart';

class ViolationReportScreen extends StatefulWidget {
  final String? initialProductName;
  const ViolationReportScreen({super.key, this.initialProductName});

  @override
  State<ViolationReportScreen> createState() => _ViolationReportScreenState();
}

class _ViolationReportScreenState extends State<ViolationReportScreen> {
  // المدخلات
  final TextEditingController _storeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _periodController = TextEditingController();
  late TextEditingController _productNameController;

  // حالة الواجهة
  bool _isLoading = false;
  bool _isCapturingGps = false;
  double? _lat;
  double? _long;

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _productNameController = TextEditingController(
      text: widget.initialProductName ?? "",
    );
  }

  @override
  void dispose() {
    _storeController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _productNameController.dispose();
    super.dispose();
  }

  // --- 1. التقاط الـ GPS ---
  Future<void> _handleGpsCapture() async {
    setState(() => _isCapturingGps = true);
    final position = await LocationService.getCurrentLocation();

    if (position != null) {
      setState(() {
        _lat = position.latitude;
        _long = position.longitude;
        _locationController.text = context.tr("موقعك الحالي (تم التحديد ✅)");
        _isCapturingGps = false;
      });
      if (!mounted) return;
      _showSnack(context.tr("تم التقاط الموقع بنجاح"), Colors.green);
    } else {
      setState(() => _isCapturingGps = false);
      if (!mounted) return;
      _showSnack(
        context.tr("تعذر الوصول للموقع، تأكد من تفعيل GPS"),
        Colors.orange,
      );
    }
  }

  // --- 2. التقاط الصورة ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(context.tr("فشل فتح الكاميرا"), Colors.red);
    }
  }

  // --- 3. وظيفة الحفظ عند انقطاع النت ---
  Future<void> _saveOffline(Map<String, dynamic> data) async {
    // إضافة مسار الصورة للقائمة المحفوظة (لكي يتمكن syncPendingReports من قراءتها لاحقا)
    if (_selectedImage != null) {
      data['image_path'] = _selectedImage!.path;
    }

    await OfflineManager.queueReport(data);

    if (!mounted) return;
    _showSnack(
      context.tr("لا يوجد إنترنت. تم حفظ البلاغ وسيرسل تلقائياً."),
      Colors.amber.shade700,
    );
    if (mounted) Navigator.pop(context);
  }

  // --- 4. المحرك الرئيسي: الإرسال الذكي ---
  void _submitReport() async {
    // التحقق من صحة المدخلات
    if (_storeController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _lat == null) {
      _showSnack(
        context.tr("يرجى تعبئة كافة الحقول والتقاط الموقع أولاً"),
        Colors.redAccent,
      );
      return;
    }

    setState(() => _isLoading = true);

    // تحضير البيانات الأساسية
    Map<String, dynamic> reportPayload = {
      "store_name": _storeController.text.trim(),
      "product_name": _productNameController.text.isEmpty
          ? context.tr("سلعة عامة")
          : _productNameController.text.trim(),
      "price_seen": _priceController.text.trim(),
      "lat": _lat,
      "lng": _long,
      "notes": "بلاغ تطبيق جوال",
      "period": _periodController.text.trim().isEmpty
          ? null
          : _periodController.text.trim(),
    };

    // فحص الاتصال الحقيقي بالشبكة
    bool online = await OfflineManager.hasInternet();

    if (online) {
      // --- أ) المحاولة أونلاين ---
      try {
        FormData formData = FormData.fromMap(reportPayload);

        if (_selectedImage != null) {
          formData.files.add(
            MapEntry(
              "image",
              await MultipartFile.fromFile(
                _selectedImage!.path,
                filename: "evidence.jpg",
              ),
            ),
          );
        }

        final response = await locator<Dio>().post(
          AppConfig.submitReportEndpoint,
          data: formData,
        );

        if (response.statusCode == 200 && mounted) {
          _showSnack(
            context.tr("تم إرسال البلاغ بنجاح! شكراً لك."),
            Colors.green,
          );
          Navigator.pop(context);
        }
      } catch (e) {
        // فشل رغم وجود النت (السيرفر مغلق مثلاً) -> حول للأوفلاين
        await _saveOffline(reportPayload);
      }
    } else {
      // --- ب) وضع الأوفلاين المباشر ---
      await _saveOffline(reportPayload);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // مساعد لعرض الرسائل
  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.tr("توثيق مخالفة"),
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr("تفاصيل الواقعة"),
              style: GoogleFonts.cairo(fontSize: 16, color: Colors.blueGrey),
            ),
            const SizedBox(height: 15),

            // الحقول النصية
            _inputField(
              _storeController,
              context.tr("اسم المحل / المتجر"),
              Icons.store,
            ),
            const SizedBox(height: 12),
            _inputField(
              _productNameController,
              context.tr("اسم الصنف"),
              Icons.shopping_basket,
            ),
            const SizedBox(height: 12),
            _inputField(
              _priceController,
              context.tr("السعر الذي شاهدته"),
              Icons.money,
              isNum: true,
            ),

            const SizedBox(height: 20),

            // حقل الموقع التلقائي
            TextField(
              controller: _locationController,
              readOnly: true,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                hintText: context.tr(
                  "موقع المتجر (يجب الضغط على الزر لتحديده)",
                ),
                suffixIcon: _isCapturingGps
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.gps_fixed, color: Colors.red),
                        onPressed: _handleGpsCapture,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // زر الصورة (كبير وواضح)
            InkWell(
              onTap: () => _pickImage(ImageSource.camera),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.grey.shade50,
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 50,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr("اضغط لإرفاق صورة الفاتورة أو المنتج"),
                            style: GoogleFonts.cairo(color: Colors.grey),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        context.tr("تأكيد الإرسال"),
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            if (_isLoading == false)
              Center(
                child: Text(
                  context.tr("سيتم الإرسال فور توفر الشبكة"),
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(
    TextEditingController c,
    String lbl,
    IconData ic, {
    bool isNum = false,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: lbl,
        prefixIcon: Icon(ic, color: Colors.blue.shade700),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }
}
