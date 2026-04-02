import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/config.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/services/offline_manager.dart';

import '../../../core/services/service_locator.dart';

class StoreDetailScreen extends StatefulWidget {
  final String storeName;
  const StoreDetailScreen({super.key, required this.storeName});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  final Dio _api = locator<Dio>();

  final TextEditingController _searchController = TextEditingController();
  final formatter = NumberFormat('#,###');
  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  bool _isLoading = true;
  bool _usingOfflineData = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _fetchStoreProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStoreProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
      _usingOfflineData = false;
    });

    final online = await OfflineManager.hasInternet();

    if (online) {
      try {
        final resp = await _api.get(
          AppConfig.storeProductsEndpoint(widget.storeName),
        );
        if (resp.statusCode != null && resp.statusCode! < 400) {
          final list = resp.data is List ? resp.data : [];
          await OfflineManager.cacheStoreProducts(widget.storeName, list);
          if (mounted) {
            setState(() {
              _products = list;
              _isLoading = false;
              _usingOfflineData = false;
            });
          }
          _applyFilter(_searchController.text);
          return;
        }
      } catch (_) {
        // fallback to offline
      }
    }

    final cached = OfflineManager.loadCachedStoreProducts(widget.storeName);
    if (mounted) {
      setState(() {
        _products = cached;
        _isLoading = false;
        _usingOfflineData = cached.isNotEmpty;
        _errorMessage = cached.isEmpty
            ? context.tr("تعذر الاتصال ولا توجد بيانات محفوظة لهذا المتجر")
            : "";
      });
    }
    _applyFilter(_searchController.text);
  }

  void _applyFilter(String value) {
    final query = value.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = List.from(_products);
      } else {
        _filteredProducts = _products.where((p) {
          final name = (p['product_name'] ?? '').toString().toLowerCase();
          final category = (p['category'] ?? '').toString().toLowerCase();
          return name.contains(query) || category.contains(query);
        }).toList();
      }
    });
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
              context.tr("عرض منتجات مخزنة دون اتصال"),
              style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: _applyFilter,
        decoration: InputDecoration(
          hintText: context.tr("ابحث داخل منتجات المتجر"),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilter("");
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final count = _products.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.store, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.storeName,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${context.tr("عدد المنتجات المتاحة")}: $count",
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(dynamic item) {
    final name = (item['product_name'] ?? '').toString();
    final category = (item['category'] ?? '').toString();
    final unit = (item['unit'] ?? '').toString();
    final priceRaw = item['price'];
    final price = priceRaw is num ? priceRaw.toDouble() : 0.0;
    final updatedAt = item['updated_at']?.toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inventory_2_outlined, color: Colors.teal.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? context.tr("منتج") : name,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${formatter.format(price)} ر.ي / $unit",
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (category.isNotEmpty)
                  Text(
                    category,
                    style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade500),
                  ),
                if (updatedAt != null)
                  Text(
                    "${context.tr("آخر تحديث")}: $updatedAt",
                    style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey.shade500),
                  ),
              ],
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
          widget.storeName,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _fetchStoreProducts,
            icon: const Icon(Icons.refresh),
            tooltip: context.tr("تحديث"),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStoreProducts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildHeader(),
            _buildSearchBox(),
            if (_usingOfflineData) _buildOfflineBanner(),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(fontSize: 14),
                ),
              )
            else if (_filteredProducts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr("لا توجد منتجات مطابقة"),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(color: Colors.grey.shade600),
                ),
              )
            else
              ..._filteredProducts.map(_buildProductCard),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
