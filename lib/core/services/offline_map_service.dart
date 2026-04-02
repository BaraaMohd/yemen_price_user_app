import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:dio/dio.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';
import 'service_locator.dart';
import 'offline_manager.dart';

class OfflineMapLayerConfig {
  final MbTilesTileProvider? rasterProvider;
  final MbTilesVectorTileProvider? vectorProvider;
  final Theme? vectorTheme;

  const OfflineMapLayerConfig.raster(this.rasterProvider) : vectorProvider = null, vectorTheme = null;
  const OfflineMapLayerConfig.vector(this.vectorProvider, this.vectorTheme) : rasterProvider = null;
  bool get isVector => vectorProvider != null && vectorTheme != null;
}

class OfflineMapService {
  OfflineMapService._();
  static const String _kMbtilesPath = 'offline_mbtiles_path';
  static const String _kLastAutoDownloadAt = 'offline_map_last_auto_download_at';
  static const String _bundledAsset = 'assets/tiles/yemen.mbtiles';
  static const String _fileName = 'yemen.mbtiles';
  static const String _vectorStyleAsset = 'assets/map_styles/osm_bright.json';

  static Future<MbTilesTileProvider?>? _providerFuture;
  static MbTilesTileProvider? _provider;
  static Future<OfflineMapLayerConfig?>? _offlineLayerFuture;
  static MbTiles? _vectorMbtiles;
  static MbTilesVectorTileProvider? _vectorProvider;
  static Theme? _vectorTheme;
  static StreamSubscription<InternetConnectionStatus>? _autoDownloadSub;
  static bool _downloadInProgress = false;
  static final ValueNotifier<double?> downloadProgress = ValueNotifier<double?>(null);
  static final ValueNotifier<String?> downloadErrorKey = ValueNotifier<String?>(null);

  static Future<MbTilesTileProvider?> getProvider() {
    if (kIsWeb) return Future.value(null);
    _providerFuture ??= _loadProvider();
    return _providerFuture!;
  }

  static Future<OfflineMapLayerConfig?> getOfflineLayerConfig() {
    if (kIsWeb) return Future.value(null);
    _offlineLayerFuture ??= _loadOfflineLayer();
    return _offlineLayerFuture!;
  }

  static Future<String?> getActiveMbtilesPath() async {
    if (kIsWeb) return null;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kMbtilesPath);
    if (stored != null && await File(stored).exists()) return stored;
    final fallback = await _defaultPathIfExists();
    if (fallback != null) await prefs.setString(_kMbtilesPath, fallback);
    return fallback;
  }

  static Future<String?> importFromFile(String sourcePath) async {
    if (kIsWeb) return null;
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final targetPath = await _defaultPath(create: true);
    if (targetPath == null) return null;
    await source.copy(targetPath);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMbtilesPath, targetPath);
    await _resetProvider();
    return targetPath;
  }

  static Future<String?> downloadFromUrl(String url, {void Function(int received, int total)? onProgress}) async {
    if (kIsWeb) return null;
    final targetPath = await _defaultPath(create: true);
    if (targetPath == null) return null;
    final tempPath = '$targetPath.download';
    try {
      downloadErrorKey.value = null;
      downloadProgress.value = 0.0;
      await locator<Dio>().download(url, tempPath, onReceiveProgress: (received, total) {
        if (total > 0) downloadProgress.value = received / total;
        onProgress?.call(received, total);
      }, options: Options(receiveTimeout: const Duration(minutes: 10)));
      final targetFile = File(targetPath);
      if (await targetFile.exists()) await targetFile.delete();
      await File(tempPath).rename(targetPath);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kMbtilesPath, targetPath);
      await _resetProvider();
      downloadProgress.value = null;
      return targetPath;
    } catch (err) {
      downloadProgress.value = null;
      downloadErrorKey.value = "فشل تنزيل خريطة أوفلاين";
      return null;
    }
  }

  static Future<void> clearOfflineMap() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kMbtilesPath);
    if (stored != null) {
      try {
        final file = File(stored);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    await prefs.remove(_kMbtilesPath);
    await _resetProvider();
  }

  static Future<OfflineMapLayerConfig?> _loadOfflineLayer() async {
    final path = await getActiveMbtilesPath();
    if (path == null) return null;
    MbTiles? mbtiles;
    try {
      mbtiles = MbTiles(mbtilesPath: path);
      final meta = mbtiles.getMetadata();
      if ((meta.format).toLowerCase().contains('pbf')) {
        _vectorMbtiles = mbtiles;
        _vectorProvider = MbTilesVectorTileProvider(mbtiles: mbtiles);
        _vectorTheme ??= await _loadVectorTheme();
        return _vectorTheme == null ? null : OfflineMapLayerConfig.vector(_vectorProvider!, _vectorTheme!);
      }
    } catch (_) { try { mbtiles?.dispose(); } catch (_) {} }
    final rasterProvider = await getProvider();
    return rasterProvider == null ? null : OfflineMapLayerConfig.raster(rasterProvider);
  }

  static Future<Theme?> _loadVectorTheme() async {
    try {
      final jsonStr = await rootBundle.loadString(_vectorStyleAsset);
      return ThemeReader().read(jsonDecode(jsonStr));
    } catch (_) { return null; }
  }

  static Future<MbTilesTileProvider?> _loadProvider() async {
    final path = await _resolvePath();
    if (path == null) return null;
    try {
      final provider = MbTilesTileProvider.fromPath(path: path);
      _provider = provider;
      return provider;
    } catch (_) { return null; }
  }

  static Future<String?> _resolvePath() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kMbtilesPath);
    if (stored != null && await File(stored).exists()) return stored;
    final fallback = await _defaultPathIfExists();
    if (fallback != null) {
      await prefs.setString(_kMbtilesPath, fallback);
      return fallback;
    }
    try {
      final data = await rootBundle.load(_bundledAsset);
      final targetPath = await _defaultPath(create: true);
      if (targetPath == null) return null;
      await File(targetPath).writeAsBytes(data.buffer.asUint8List());
      await prefs.setString(_kMbtilesPath, targetPath);
      return targetPath;
    } catch (_) { return null; }
  }

  static Future<String?> _defaultPath({bool create = false}) async {
    final dir = await getApplicationDocumentsDirectory();
    final tilesDir = Directory('${dir.path}/offline_tiles');
    if (create && !await tilesDir.exists()) await tilesDir.create(recursive: true);
    return '${tilesDir.path}/$_fileName';
  }

  static Future<String?> _defaultPathIfExists() async {
    final path = await _defaultPath();
    if (path == null) return null;
    return await File(path).exists() ? path : null;
  }

  static Future<void> _resetProvider() async {
    try { _provider?.dispose(); } catch (_) {}
    _provider = null;
    _providerFuture = null;
    _offlineLayerFuture = null;
    _vectorProvider = null;
    _vectorTheme = null;
    try { _vectorMbtiles?.dispose(); } catch (_) {}
    _vectorMbtiles = null;
  }

  static Future<bool> ensureOfflineMapDownloaded(String url, {Duration minInterval = const Duration(hours: 12), void Function(String path)? onDownloaded}) async {
    if (_downloadInProgress || downloadProgress.value != null) return false;
    final existing = await getActiveMbtilesPath();
    if (existing != null) return true;
    final prefs = await SharedPreferences.getInstance();
    final lastAttemptMs = prefs.getInt(_kLastAutoDownloadAt);
    if (lastAttemptMs != null) {
      final lastAttempt = DateTime.fromMillisecondsSinceEpoch(lastAttemptMs);
      if (DateTime.now().difference(lastAttempt) < minInterval) return false;
    }
    final connected = await OfflineManager.hasInternet();
    if (!connected) return false;
    _downloadInProgress = true;
    try {
      await prefs.setInt(
        _kLastAutoDownloadAt,
        DateTime.now().millisecondsSinceEpoch,
      );
      final saved = await downloadFromUrl(url);
      if (saved != null) { onDownloaded?.call(saved); return true; }
      return false;
    } finally { _downloadInProgress = false; }
  }

  static void startAutoDownload(
    String url, {
    Duration minInterval = const Duration(hours: 12),
    void Function(String path)? onDownloaded,
  }) {
    if (kIsWeb) return;

    Future<void> attemptDownload() async {
      final existing = await getActiveMbtilesPath();
      if (existing != null) return;

      await ensureOfflineMapDownloaded(
        url,
        minInterval: minInterval,
        onDownloaded: onDownloaded,
      );
    }

    unawaited(attemptDownload());
    _autoDownloadSub ??= InternetConnectionChecker().onStatusChange.listen((
      status,
    ) {
      if (status != InternetConnectionStatus.connected) return;
      unawaited(attemptDownload());
    });
  }
}
