import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/config.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/offline_manager.dart';
import '../../../core/services/service_locator.dart';
import '../../auth/login_screen.dart';
import '../../products/models/product.model.dart';
import '../widgets/violation_card.dart';
import 'health_check_screen.dart';

class MinistryDashboardScreen extends StatefulWidget {
  const MinistryDashboardScreen({super.key});

  @override
  State<MinistryDashboardScreen> createState() =>
      _MinistryDashboardScreenState();
}

class _MinistryDashboardScreenState extends State<MinistryDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Dio _api = locator<Dio>();
  bool _isLoading = false;
  bool _isInitialLoading = true;
  String _initialError = "";
  bool _isOnline = true;
  bool _usingOfflineData = false;

  // Data Lists
  List<dynamic> _reports = [];
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _productSearchQuery = "";
  String _reportStatusFilter = "الكل";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _guardAndLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshConnectivity() async {
    final online = await OfflineManager.hasInternet();
    if (!mounted) return;
    setState(() {
      _isOnline = online;
    });
  }

  Future<void> _guardAndLoad() async {
    final role = await AuthSession.role();
    if (!mounted) return;
    if (role != AuthSession.roleMinistry) {
      _showSnack(context.tr("يرجى تسجيل الدخول"), isError: true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    await _loadDashboardData();
  }

  Future<void> _loadDashboardData({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() {
        _isInitialLoading = true;
        _initialError = "";
      });
    }
    await _refreshConnectivity();
    if (_isOnline) {
      await OfflineManager.syncPendingAdminActions();
    }
    try {
      await Future.wait([
        _fetchReports(silentError: true),
        _fetchProducts(silentError: true),
      ]);
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          if (!_isOnline && _reports.isEmpty && _products.isEmpty) {
            _initialError = context.tr("لا توجد بيانات محفوظة دون اتصال");
          } else {
            _initialError = "";
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _initialError = context.tr("تعذر الاتصال بالخادم");
        });
      }
    }
  }

  // --- API Calls ---

  Future<void> _fetchReports({bool silentError = false}) async {
    if (!_isOnline) {
      if (mounted) {
        setState(() {
          _reports = OfflineManager.loadCachedAdminReports();
          _usingOfflineData = _reports.isNotEmpty;
        });
      }
      return;
    }
    try {
      final response = await _api.get('${AppConfig.baseUrl}/admin/reports');
      if (response.statusCode == null || response.statusCode! >= 400) {
        throw Exception("HTTP ${response.statusCode}");
      }
      if (response.data is List) {
        await OfflineManager.cacheAdminReports(response.data as List);
      }
      if (mounted) {
        setState(() {
          _reports = response.data is List ? response.data : [];
          _usingOfflineData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reports = OfflineManager.loadCachedAdminReports();
          _usingOfflineData = _reports.isNotEmpty;
        });
      }
      if (!silentError) {
        if (!mounted) return;
        _showSnack(context.tr("تعذر الاتصال بالخادم"), isError: true);
      }
      if (!silentError) rethrow;
    }
  }

  Future<void> _fetchProducts({bool silentError = false}) async {
    if (!_isOnline) {
      if (mounted) {
        final cached = OfflineManager.loadCachedProducts();
        setState(() {
          _products = cached;
          _filteredProducts = _applyProductFilter(cached, _productSearchQuery);
          _usingOfflineData = _products.isNotEmpty;
        });
      }
      return;
    }
    try {
      final response = await _api.get(AppConfig.productsEndpoint);
      if (response.statusCode == null || response.statusCode! >= 400) {
        throw Exception("HTTP ${response.statusCode}");
      }
      final raw = response.data is List ? response.data as List : <dynamic>[];
      final List<Product> loaded = raw.map((e) => Product.fromJson(e)).toList();
      await OfflineManager.cacheProducts(loaded);
      if (mounted) {
        setState(() {
          _products = loaded;
          _filteredProducts = _applyProductFilter(loaded, _productSearchQuery);
          _usingOfflineData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final cached = OfflineManager.loadCachedProducts();
        setState(() {
          _products = cached;
          _filteredProducts = _applyProductFilter(cached, _productSearchQuery);
          _usingOfflineData = _products.isNotEmpty;
        });
      }
      if (!silentError) {
        if (!mounted) return;
        _showSnack(context.tr("تعذر الاتصال بالخادم"), isError: true);
      }
      if (!silentError) rethrow;
    }
  }

  Future<void> _updateReportStatus(int id, String newStatus) async {
    final online = await OfflineManager.hasInternet();
    if (!online) {
      await OfflineManager.queueAdminReportStatusUpdate(
        reportId: id,
        newStatus: newStatus,
      );
      if (!mounted) return;
      setState(() {
        for (final r in _reports) {
          if (r['id'] == id) {
            r['status'] = newStatus;
          }
        }
        _usingOfflineData = true;
      });
      await OfflineManager.cacheAdminReports(_reports);
      if (!mounted) return;
      _showSnack(
        context.tr("تم حفظ التحديث وسيتم المزامنة عند الاتصال"),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await _api.post(
        '${AppConfig.baseUrl}/admin/reports/update_status',
        data: {"report_id": id, "new_status": newStatus},
      );
      if (response.statusCode == null || response.statusCode! >= 400) {
        throw Exception("HTTP ${response.statusCode}");
      }
      if (!mounted) return;
      _showSnack(context.tr("تم تحديث الحالة"));
      await _fetchReports(silentError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(context.tr("فشل تحديث الحالة"), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOfficialPrice(Product product, double newPrice) async {
    final online = await OfflineManager.hasInternet();
    if (!online) {
      await OfflineManager.queueAdminOfficialPriceUpdate(
        productId: product.id,
        newPrice: newPrice,
      );
      if (!mounted) return;
      setState(() {
        final idx = _products.indexWhere((p) => p.id == product.id);
        if (idx != -1) {
          _products[idx] = Product(
            id: _products[idx].id,
            name: _products[idx].name,
            category: _products[idx].category,
            officialPrice: newPrice,
            unit: _products[idx].unit,
            storeName: _products[idx].storeName,
            lat: _products[idx].lat,
            lng: _products[idx].lng,
            rating: _products[idx].rating,
            fairPrice: _products[idx].fairPrice,
            exchangeRate: _products[idx].exchangeRate,
            exchangeCurrency: _products[idx].exchangeCurrency,
            trend: _products[idx].trend,
            trendPercent: _products[idx].trendPercent,
            trendAdvice: _products[idx].trendAdvice,
            isStable: _products[idx].isStable,
          );
          _filteredProducts =
              _applyProductFilter(_products, _productSearchQuery);
        }
        _usingOfflineData = true;
      });
      await OfflineManager.cacheProducts(_products);
      if (!mounted) return;
      _showSnack(
        context.tr("تم حفظ التحديث وسيتم المزامنة عند الاتصال"),
      );
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Fix: Ensure ID is int
      int pId = int.tryParse(product.id.toString()) ?? 0;
      final response = await _api.post(
        '${AppConfig.baseUrl}/admin/products/update_official',
        data: {"product_id": pId, "new_price": newPrice},
      );
      if (response.statusCode == null || response.statusCode! >= 400) {
        throw Exception("HTTP ${response.statusCode}");
      }
      if (!mounted) return;
      _showSnack(context.tr("تم تحديث السعر الرسمي"));
      await _fetchProducts(silentError: true);
      if (mounted) Navigator.pop(context); // Close dialog
    } catch (e) {
      if (!mounted) return;
      _showSnack(context.tr("فشل تحديث السعر"), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Import Logic (Existing) ---
  Future<void> _importProductsFile() async {
    final online = await OfflineManager.hasInternet();
    if (!mounted) return;
    if (!online) {
      _showSnack(context.tr("لا يوجد اتصال لرفع الملف"), isError: true);
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        if (!mounted) return;
        _showSnack(context.tr("تعذر قراءة الملف"), isError: true);
        return;
      }

      setState(() => _isLoading = true);

      final formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        ),
      });

      final previewResponse = await _api.post(
        AppConfig.importProductsPreviewEndpoint,
        data: formData,
        options: Options(
          headers: {"Content-Type": "multipart/form-data"},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      final data = previewResponse.data;
      final importId = data is Map ? data['import_id']?.toString() : null;
      final previewRows = _extractPreviewRows(data);

      await _showPreviewDialog(
        rows: previewRows,
        importId: importId,
        originalFile: file,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack(context.tr("فشل رفع الملف"), isError: true);
      }
    }
  }

  List<Map<String, dynamic>> _extractPreviewRows(dynamic data) {
    if (data is Map) {
      final rows = data['rows'] ?? data['preview'] ?? data['data'];
      if (rows is List) {
        return rows
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }

  bool _rowHasError(Map<String, dynamic> row) {
    final err = row['error'] ?? row['errors'] ?? row['validation_error'];
    if (err == null) return false;
    if (err is String) return err.trim().isNotEmpty;
    if (err is List) return err.isNotEmpty;
    return true;
  }

  String _rowErrorText(Map<String, dynamic> row) {
    final err = row['error'] ?? row['errors'] ?? row['validation_error'];
    if (err == null) return '';
    if (err is String) return err;
    if (err is List) return err.join(', ');
    return err.toString();
  }

  Future<void> _confirmImport({
    required String? importId,
    required PlatformFile originalFile,
    bool fixErrorsOnly = false,
  }) async {
    try {
      setState(() => _isLoading = true);

      dynamic responseData;
      if (importId != null && importId.isNotEmpty) {
        final resp = await _api.post(
          AppConfig.importProductsConfirmEndpoint,
          data: {
            "import_id": importId,
            "mode": fixErrorsOnly ? "fix_errors_only" : "all",
          },
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        responseData = resp.data;
      } else {
        final formData = FormData.fromMap({
          "file": MultipartFile.fromBytes(
            originalFile.bytes!,
            filename: originalFile.name,
          ),
          "mode": fixErrorsOnly ? "fix_errors_only" : "all",
        });
        final resp = await _api.post(
          AppConfig.importProductsConfirmEndpoint,
          data: formData,
          options: Options(
            headers: {"Content-Type": "multipart/form-data"},
            validateStatus: (s) => s != null && s < 500,
          ),
        );
        responseData = resp.data;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      final msg = (responseData is Map && responseData['message'] != null)
          ? responseData['message'].toString()
          : context.tr("تم حفظ البيانات");
      _showSnack(msg);
      await _fetchProducts(silentError: true);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack(context.tr("فشل حفظ البيانات"), isError: true);
      }
    }
  }

  String _escapeCsv(String value) {
    final needsQuotes = value.contains(',') ||
        value.contains('\n') ||
        value.contains('\r') ||
        value.contains('"');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  Future<void> _exportErrorRowsCsv(List<Map<String, dynamic>> rows) async {
    final errorRows = rows.where(_rowHasError).toList();
    if (errorRows.isEmpty) {
      _showSnack(context.tr("لا توجد أخطاء للتصدير"));
      return;
    }

    final allKeys = <String>{};
    for (final r in errorRows) {
      allKeys.addAll(r.keys);
    }
    final columns = allKeys
        .where((k) => k != 'error' && k != 'errors' && k != 'validation_error')
        .toList();

    final buffer = StringBuffer();
    buffer.writeln(
      [...columns, 'error'].map((c) => _escapeCsv(c)).join(','),
    );
    for (final row in errorRows) {
      final cells = <String>[];
      for (final c in columns) {
        cells.add(_escapeCsv(row[c]?.toString() ?? ''));
      }
      cells.add(_escapeCsv(_rowErrorText(row)));
      buffer.writeln(cells.join(','));
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: context.tr("حفظ تقرير الأخطاء"),
      fileName: "import_errors.csv",
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (path == null) return;

    final file = File(path);
    await file.writeAsString(buffer.toString());
    if (!mounted) return;
    _showSnack(context.tr("تم حفظ التقرير"));
  }

  Future<void> _showPreviewDialog({
    required List<Map<String, dynamic>> rows,
    required String? importId,
    required PlatformFile originalFile,
  }) async {
    if (!mounted) return;

    final previewRows = rows.take(50).toList();
    final allKeys = <String>{};
    for (final r in previewRows) {
      allKeys.addAll(r.keys);
    }

    final columns = allKeys
        .where((k) => k != 'error' && k != 'errors' && k != 'validation_error')
        .toList();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            context.tr("معاينة الاستيراد"),
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (previewRows.isEmpty)
                  Text(
                    context.tr("لا توجد صفوف للعرض"),
                    style: GoogleFonts.cairo(),
                  )
                else
                  SizedBox(
                    height: 320,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: [
                            for (final c in columns)
                              DataColumn(
                                label: Text(
                                  c,
                                  style: GoogleFonts.cairo(fontSize: 11),
                                ),
                              ),
                            DataColumn(label: Text(context.tr("خطأ"))),
                          ],
                          rows: previewRows.map((row) {
                            final hasError = _rowHasError(row);
                            final errorText = _rowErrorText(row);
                            return DataRow(
                              color: hasError
                                  ? WidgetStateProperty.all(
                                      Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.25),
                                    )
                                  : null,
                              cells: [
                                for (final c in columns)
                                  DataCell(
                                    Text(
                                      row[c]?.toString() ?? '',
                                      style: GoogleFonts.cairo(fontSize: 11),
                                    ),
                                  ),
                                DataCell(
                                  Text(
                                    errorText,
                                    style: GoogleFonts.cairo(
                                      fontSize: 10,
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  context.tr("يتم عرض أول 50 صف فقط"),
                  style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr("إلغاء"), style: GoogleFonts.cairo()),
            ),
            OutlinedButton(
              onPressed: previewRows.isEmpty
                  ? null
                  : () => _exportErrorRowsCsv(rows),
              child:
                  Text(context.tr("تصدير الأخطاء CSV"), style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: previewRows.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _confirmImport(
                        importId: importId,
                        originalFile: originalFile,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child:
                  Text(context.tr("تأكيد الاستيراد"), style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: previewRows.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _confirmImport(
                        importId: importId,
                        originalFile: originalFile,
                        fixErrorsOnly: true,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                foregroundColor: Theme.of(context).colorScheme.onTertiary,
              ),
              child: Text(
                context.tr("استيراد الصفوف السليمة فقط"),
                style: GoogleFonts.cairo(),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.cairo()),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _logout() async {
    await AuthSession.clearAuthOnly();
    if (!mounted) return;
    Navigator.pop(context);
  }

  // --- UI Builders ---

  List<Product> _applyProductFilter(List<Product> source, String query) {
    final lowered = query.toLowerCase();
    return source.where((p) {
      return lowered.isEmpty || p.name.toLowerCase().contains(lowered);
    }).toList();
  }

  void _filterProducts() {
    setState(() {
      _filteredProducts = _applyProductFilter(_products, _productSearchQuery);
    });
  }

  Widget _buildOfflineBanner() {
    if (_isOnline && !_usingOfflineData) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
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
                context.tr("وضع عدم الاتصال: بعض الإجراءات ستؤجل للمزامنة"),
                style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViolationsTab() {
    final visibleReports = _reports.where((r) {
      if (_reportStatusFilter == "الكل") return true;
      return (r['status'] ?? 'جديد') == _reportStatusFilter;
    }).toList();

    int countByStatus(String status) {
      return _reports.where((r) => (r['status'] ?? 'جديد') == status).length;
    }

    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildOfflineBanner(),
            const SizedBox(height: 24),
            Icon(Icons.check_circle_outline,
                size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            Text(
              context.tr("لا توجد بلاغات مرصودة حالياً"),
              style: GoogleFonts.cairo(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildOfflineBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusPill(context.tr("الكل"), _reports.length, "الكل"),
              _buildStatusPill(context.tr("جديد"), countByStatus("جديد"), "جديد"),
              _buildStatusPill(
                context.tr("قيد المراجعة"),
                countByStatus("قيد المراجعة"),
                "قيد المراجعة",
              ),
              _buildStatusPill(
                context.tr("تم الضبط"),
                countByStatus("تم الضبط"),
                "تم الضبط",
              ),
            ],
          ),
        ),
        Expanded(
          child: visibleReports.isEmpty
              ? Center(
                  child: Text(
                    context.tr("لا توجد بلاغات مرصودة حالياً"),
                    style: GoogleFonts.cairo(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: visibleReports.length,
                  itemBuilder: (context, index) {
                    final r = visibleReports[index];
                    return ViolationCard(
                      report: r,
                      isUpdating: _isLoading,
                      onStatusChanged: (newStatus) {
                        _updateReportStatus(r['id'], newStatus);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatusPill(String label, int count, String value) {
    final selected = _reportStatusFilter == value;
    return ChoiceChip(
      label: Text(
        "$label ($count)",
        style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      selected: selected,
      onSelected: (_) {
        setState(() => _reportStatusFilter = value);
      },
    );
  }

  Widget _buildPricesTab() {
    return Column(
      children: [
        _buildOfflineBanner(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) {
              _productSearchQuery = v;
              _filterProducts();
            },
            decoration: InputDecoration(
              hintText: context.tr('ابحث عن منتج...'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _filteredProducts.length,
            separatorBuilder: (c, i) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final p = _filteredProducts[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  title: Text(
                    p.name,
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    "${context.tr("السعر الرسمي:")} ${p.officialPrice} ر.ي",
                    style: GoogleFonts.cairo(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.edit, color: Theme.of(context).primaryColor),
                    onPressed: () => _showEditPriceDialog(p),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditPriceDialog(Product p) {
    final controller =
        TextEditingController(text: p.officialPrice.toInt().toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("تعديل السعر الرسمي"),
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name, style: GoogleFonts.cairo(fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr("السعر الجديد"),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr("إلغاء"), style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                _updateOfficialPrice(p, val);
              }
            },
            child: Text(context.tr("حفظ"), style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.tr("غرفة العمليات المركزية"),
          style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: context.tr("تحديث البيانات"),
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadDashboardData(showSpinner: false),
          ),
          IconButton(
            tooltip: context.tr("تسجيل الخروج"),
            icon: const Icon(Icons.exit_to_app),
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          unselectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600),
          indicatorColor: scheme.primary,
          indicatorWeight: 3,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.65),
          tabs: [
            Tab(text: context.tr("البلاغات")),
            Tab(text: context.tr("التسعيرة")),
            Tab(text: context.tr("الاستيراد")),
            Tab(text: context.tr("السيرفر")),
          ],
        ),
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : _initialError.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off,
                          size: 56,
                          color: scheme.error.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _initialError,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _loadDashboardData(),
                          icon: const Icon(Icons.refresh),
                          label: Text(context.tr("إعادة المحاولة")),
                        ),
                      ],
                    ),
                  ),
                )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildViolationsTab(),
                _buildPricesTab(),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (!_isOnline || _usingOfflineData) _buildOfflineBanner(),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr("استيراد منتجات الوزارة"),
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr(
                              "ارفع ملف Excel أو CSV ليتم تحليله قبل الاستيراد النهائي.",
                            ),
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _isOnline ? _importProductsFile : null,
                              icon: const Icon(Icons.file_upload),
                              label: Text(
                                context.tr("رفع ملف"),
                                style: GoogleFonts.cairo(),
                              ),
                            ),
                          ),
                          if (!_isOnline)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                context.tr("يتطلب رفع الملف اتصالاً بالإنترنت"),
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                // #9 – Health Check tab
                const HealthCheckScreen(),
              ],
            ),
    );
  }
}
