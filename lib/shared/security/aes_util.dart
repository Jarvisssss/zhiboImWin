// 来源：study_app/lib/utils/aes_util.dart（与 Java 服务端 AESUtil 兼容的 AES-GCM 实现）。
// 平移时的改动：去掉对未知异常信息的透传（避免把密钥/明文拼进异常文案），其余算法与输出格式保持不变。
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// AES/GCM 加解密工具，用于生成云校园接口要求的 `userToken`。
///
/// 输出格式：`Base64( IV(12 字节) ‖ 密文 ‖ GCM 认证标签(16 字节) )`，与服务端约定一致。
abstract final class AesUtil {
  /// GCM 推荐的 12 字节 IV。
  static const int _gcmIvLength = 12;

  /// 128 位认证标签。
  static const int _gcmTagLengthBits = 128;

  /// 密钥长度（字节）。服务端使用 AES-256。
  static const int keyLength = 32;

  /// 安全随机数源，仅用于生成 IV。
  static final Random _random = Random.secure();

  /// 判断 [secretKey] 是否可用于 [encryptUserId]（UTF-8 编码后恰为 32 字节）。
  static bool isValidKey(String secretKey) => utf8.encode(secretKey).length == keyLength;

  /// 使用 AES-GCM 加密用户 ID，得到 `userToken`。
  ///
  /// [userId] 待加密的用户 ID；[secretKey] 必须为 32 字节；[iv] 仅用于测试注入固定 IV。
  /// 失败时抛出 [AesException]，其 message 不包含密钥或明文。
  static String encryptUserId(String userId, String secretKey, {Uint8List? iv}) {
    final keyBytes = Uint8List.fromList(utf8.encode(secretKey));
    if (keyBytes.length != keyLength) {
      throw const AesException('AES 密钥必须是 32 字节');
    }
    final nonce = iv ?? _randomIv();
    if (nonce.length != _gcmIvLength) {
      throw const AesException('GCM IV 必须是 12 字节');
    }
    try {
      final cipher = GCMBlockCipher(AESEngine())
        ..init(true, AEADParameters(KeyParameter(keyBytes), _gcmTagLengthBits, nonce, Uint8List(0)));
      final encrypted = cipher.process(Uint8List.fromList(utf8.encode(userId)));
      final result = Uint8List(_gcmIvLength + encrypted.length)
        ..setAll(0, nonce)
        ..setAll(_gcmIvLength, encrypted);
      return base64.encode(result);
    } catch (_) {
      throw const AesException('AES-GCM 加密失败');
    }
  }

  /// 解密 [encryptUserId] 生成的 Base64 密文，主要用于自测与问题排查。
  static String decryptGcm(String base64Encrypted, String secretKey) {
    try {
      final full = base64.decode(base64Encrypted);
      if (full.length <= _gcmIvLength) {
        throw const AesException('密文长度不合法');
      }
      final nonce = Uint8List.fromList(full.sublist(0, _gcmIvLength));
      final cipherBytes = Uint8List.fromList(full.sublist(_gcmIvLength));
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(
            KeyParameter(Uint8List.fromList(utf8.encode(secretKey))),
            _gcmTagLengthBits,
            nonce,
            Uint8List(0),
          ),
        );
      return utf8.decode(cipher.process(cipherBytes));
    } on AesException {
      rethrow;
    } catch (_) {
      throw const AesException('AES-GCM 解密失败');
    }
  }

  static Uint8List _randomIv() {
    final iv = Uint8List(_gcmIvLength);
    for (var i = 0; i < iv.length; i++) {
      iv[i] = _random.nextInt(256);
    }
    return iv;
  }
}

/// AES 加解密异常（message 保证不含密钥与明文）。
class AesException implements Exception {
  /// 创建异常。
  const AesException(this.message);

  /// 可展示/可记录的错误描述。
  final String message;

  @override
  String toString() => 'AesException: $message';
}
