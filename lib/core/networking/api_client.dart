import 'package:dio/dio.dart';

import '../services/connectivity_service.dart';

class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? Dio(_baseOptions()) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          ConnectivityService.instance.beginRequest();
          handler.next(options);
        },
        onResponse: (Response<dynamic> response, ResponseInterceptorHandler handler) {
          ConnectivityService.instance.endRequest();
          handler.next(response);
        },
        onError: (DioException err, ErrorInterceptorHandler handler) {
          ConnectivityService.instance.endRequest();
          handler.next(err);
        },
      ),
    );
  }

  final Dio _dio;

  static BaseOptions _baseOptions() {
    return BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: const {
        'Content-Type': 'application/json',
      },
    );
  }

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query}) {
    return _dio.get<dynamic>(path, queryParameters: query);
  }

  Future<Response<dynamic>> post(String path, {Object? body}) {
    return _dio.post<dynamic>(path, data: body);
  }

  Future<Response<dynamic>> patch(String path, {Object? body}) {
    return _dio.patch<dynamic>(path, data: body);
  }

  Future<Response<dynamic>> delete(String path, {Object? body}) {
    return _dio.delete<dynamic>(path, data: body);
  }
}
