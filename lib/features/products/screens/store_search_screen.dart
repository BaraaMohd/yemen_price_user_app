import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/services/offline_manager.dart';
import 'store_detail_screen.dart';

import '../../../core/services/service_locator.dart';

class StoreSearchScreen extends StatefulWidget {
  const StoreSearchScreen({super.key});

  @override
  State<StoreSearchScreen> createState() => _StoreSearchScreenState();
}

class _StoreSearchScreenState extends State<StoreSearchScreen> {
  final Dio _api = locator<Dio>();

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _stores = [];
  List<dynamic> _filteredStores = [];
  bool _isLoading = true;
  bool _usingOfflineData = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _fetchStores();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStores() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
      _usingOfflineData = false;
    });

    final online = await OfflineManager.hasInternet();

    if (online) {
      try {
        final resp = await _api.get(AppConfig.storesEndpoint);
        if (resp.statusCode != null && resp.statusCode! < 400) {
          final list = resp.data is List ? resp.data : [];
          await OfflineManager.cacheStoresIndex(list);
          if (mounted) {
            setState(() {
              _stores = list;
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

    final cached = OfflineManager.loadCachedStoresIndex();
    if (mounted) {
      setState(() {
        _stores = cached;
        _isLoading = false;
        _usingOfflineData = cached.isNotEmpty;
        _errorMessage = cached.isEmpty
            ? context.tr("تعذر الاتصال ولا توجد متاجر محفوظة")
            : "";
      });
    }
    _applyFilter(_searchController.text);
  }

  void _applyFilter(String value) {
    final query = value.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredStores = List.from(_stores);
      } else {
        _filteredStores = _stores.where((s) {
          final name = (s['store_name'] ?? '').toString().toLowerCase();
          return name.contains(query);
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
              context.tr("عرض بيانات متاجر محفوظة دون اتصال"),
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
          hintText: context.tr("ابحث عن متجر بالاسم"),
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

  Widget _buildStoreCard(dynamic store) {
    final name = (store['store_name'] ?? '').toString();
    final rating = (store['rating'] ?? 0).toDouble();
    final offersCount = store['offers_count'] ?? 0;
    final updatedAt = store['updated_at']?.toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: name.isEmpty
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => StoreDetailScreen(storeName: name),
                  ),
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
                    name.isEmpty ? context.tr("متجر") : name,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.cairo(fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${context.tr("عدد العروض")}: $offersCount",
                        style: GoogleFonts.cairo(fontSize: 11),
                      ),
                    ],
                  ),
                  if (updatedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      "${context.tr("آخر تحديث")}: $updatedAt",
                      style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_left),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.tr("بحث عن متجر"),
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _fetchStores,
            icon: const Icon(Icons.refresh),
            tooltip: context.tr("تحديث"),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStores,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
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
            else if (_filteredStores.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr("لا توجد متاجر تطابق بحثك"),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(color: Colors.grey.shade600),
                ),
              )
            else
              ..._filteredStores.map(_buildStoreCard),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
