
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiInterceptor extends InterceptorsWrapper {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint("");
    debugPrint("--------------- request ---------------");
    debugPrint(options.uri.toString());
    debugPrint(options.headers.toString());
    debugPrint(jsonEncode(options.data));
    debugPrint("--------------- request end -------------");
    debugPrint("");
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint("");
    debugPrint("--------------- response ---------------");
    debugPrint(response.data.toString());
    debugPrint("------------- response end -------------");
    debugPrint("");
    super.onResponse(response, handler);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    debugPrint("");
    debugPrint("--------------- error ---------------");
    debugPrint(err.toString());
    debugPrint(err.response.toString());
    debugPrint("------------- error end ------------");
    debugPrint("");
    super.onError(err, handler);
  }
}