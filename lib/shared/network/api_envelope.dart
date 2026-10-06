import 'dart:convert';

import 'api_exception.dart';

/// 响应信封风格。两套后端的成功判定规则不同，必须由调用方显式声明。
enum EnvelopeStyle {
  /// 云校园 IM 服务：`{code, message, result, success, timestamp}`，成功 = `success==true` 或 `code ∈ {0,200}`。
  eip,

  /// 主业务 API：`{code, message, data}`，成功 = `code==1`；`code==0` 表示 token 过期（与 App 一致）。
  main,
}

/// 解析后的响应信封。
class ApiEnvelope {
  /// 创建信封。
  const ApiEnvelope({
    required this.success,
    required this.message,
    required this.data,
    this.code,
    this.status,
  });

  /// 是否成功。
  final bool success;

  /// 服务端返回的提示信息。
  final String message;

  /// 业务数据（eip 为 `result`，main 为 `data`）。
  final Object? data;

  /// 信封 code。
  final int? code;

  /// 信封内的 status 字段（小程序约定：`status==500` 且 message 含 TOKEN 表示登录失效）。
  final int? status;

  /// 业务数据中的 `failCode`（登录接口使用）。
  int? get failCode {
    final value = data;
    if (value is Map) return _asInt(value['failCode']);
    return null;
  }

  /// 是否表示登录态失效。
  bool isAuthExpired(EnvelopeStyle style, int? httpStatus) {
    switch (style) {
      case EnvelopeStyle.eip:
        final upper = message.toUpperCase();
        final serverError = status == 500 || httpStatus == 500 || code == 500;
        return !success && serverError && upper.contains('TOKEN');
      case EnvelopeStyle.main:
        return code == 0 && !success;
    }
  }

  /// 把 HTTP 响应体（字符串或已解码对象）解析为信封。
  ///
  /// 无法解析为 JSON 对象时抛出 [ApiException]（kind=http 或 parse）。
  static ApiEnvelope parse(Object? body, EnvelopeStyle style, {int? httpStatus}) {
    Object? decoded = body;
    if (body is String) {
      if (body.trim().isEmpty) {
        throw ApiException(kind: ApiErrorKind.http, message: '服务返回空响应（HTTP ${httpStatus ?? '-'}）', httpStatus: httpStatus);
      }
      try {
        decoded = jsonDecode(body);
      } on FormatException {
        throw ApiException(kind: ApiErrorKind.http, message: '服务返回了非 JSON 内容（HTTP ${httpStatus ?? '-'}）', httpStatus: httpStatus);
      }
    }
    if (decoded is! Map) {
      throw ApiException(kind: ApiErrorKind.parse, message: '响应结构异常', httpStatus: httpStatus);
    }
    final map = decoded;
    final code = _asInt(map['code']);
    final message = '${map['message'] ?? map['msg'] ?? ''}';
    final status = _asInt(map['status']);
    switch (style) {
      case EnvelopeStyle.eip:
        final success = map['success'] is bool ? map['success'] as bool : (code == 0 || code == 200);
        return ApiEnvelope(success: success, message: message, data: map['result'], code: code, status: status);
      case EnvelopeStyle.main:
        final data = map.containsKey('data') ? map['data'] : map['result'];
        return ApiEnvelope(success: code == 1, message: message, data: data, code: code, status: status);
    }
  }

  static int? _asInt(Object? value) => value is num ? value.toInt() : int.tryParse('${value ?? ''}');
}
