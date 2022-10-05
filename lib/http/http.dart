import 'dart:convert';
import 'package:aptos/http/interceptor.dart';
import 'package:dio/dio.dart';
import 'package:dio/native_imp.dart';
import 'package:flutter/foundation.dart';

final Http http = Http();

class Http extends DioForNative {
  static Http? instance;

  factory Http() {
      instance ??= Http._().._init();
    return instance!;
  }

  Http._();

  _init() {
    options.connectTimeout = 3000;
    options.receiveTimeout = 5000;

    options.headers["Content-Type"] = "application/json";

    (transformer as DefaultTransformer).jsonDecodeCallback = parseJson;
    interceptors.add(ApiInterceptor());
  }
}

_parseAndDecode(String response) {
  return jsonDecode(response);
}

parseJson(String text) {
  return compute(_parseAndDecode, text);
}