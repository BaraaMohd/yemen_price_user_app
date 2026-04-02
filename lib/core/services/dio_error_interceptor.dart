// #8 - Centralized Dio Error Interceptor
// Handles all HTTP and network errors in one place, mapping them to friendly Arabic messages.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../app_scaffold.dart';

class DioErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final messenger = appScaffoldMessengerKey.currentState;
    String message;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = '⏱️ انتهت مهلة الاتصال بالسيرفر';
        break;
      case DioExceptionType.connectionError:
        message = '📡 تعذر الاتصال. تحقق من الإنترنت';
        break;
      case DioExceptionType.badResponse:
        final code = err.response?.statusCode;
        if (code == 400) {
          message = '⚠️ طلب غير صحيح (400)';
        } else if (code == 401) {
          message = '🔒 غير مصرح لك بهذا الإجراء (401)';
        } else if (code == 403) {
          message = '🚫 الوصول محظور (403)';
        } else if (code == 404) {
          message = '🔍 المورد غير موجود (404)';
        } else if (code != null && code >= 500) {
          message = '🛠️ خطأ في السيرفر ($code). حاول لاحقاً';
        } else {
          message = '❌ خطأ في الشبكة ($code)';
        }
        break;
      default:
        message = '❌ حدث خطأ غير متوقع';
    }

    debugPrint('[DioError] ${err.requestOptions.uri} — $message');
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    handler.next(err);
  }
}
