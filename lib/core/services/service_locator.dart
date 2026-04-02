// #7 - Service Locator (get_it)
// Registers all app-wide singletons and provides them via locator<T>().
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:path_provider/path_provider.dart';
import 'dio_error_interceptor.dart';

final GetIt locator = GetIt.instance;

bool _initialized = false;

Future<void> setupLocator() async {
  if (_initialized) return;
  _initialized = true;

  // Setup Cache Store
  final dir = await getApplicationDocumentsDirectory();
  final cacheStore = HiveCacheStore(
    dir.path,
    hiveBoxName: "yemen_price_api_cache",
  );
  
  final cacheOptions = CacheOptions(
    store: cacheStore,
    policy: CachePolicy.request, 
    hitCacheOnErrorExcept: [401, 403],
    maxStale: const Duration(minutes: 5),
    priority: CachePriority.normal,
    cipher: null,
    keyBuilder: CacheOptions.defaultCacheKeyBuilder,
    allowPostMethod: false,
  );

  // Dio — shared instance with error interceptor applied
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 40),
      validateStatus: (s) => s != null && s < 500,
    ),
  );
  
  dio.interceptors.add(DioCacheInterceptor(options: cacheOptions));
  dio.interceptors.add(DioErrorInterceptor());
  
  locator.registerSingleton<Dio>(dio);
}
