import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import 'interceptor.dart';

class Http extends DioForNative {
  static Http? instance;

  factory Http() {
    instance ??= Http._().._init();

    return instance!;
  }

  Http._();

  _init() {
    options.connectTimeout = const Duration(seconds: 5);
    options.receiveTimeout = const Duration(seconds: 10);

    options.headers["Content-Type"] = "application/json";

    interceptors.add(ApiInterceptor());
  }
}
