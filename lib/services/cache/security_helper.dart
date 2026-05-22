import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class SecurityHelper {
  static const _secureStorage = FlutterSecureStorage();
  static const _keyAlias = 'local_vyapari_aes_key';
  static encrypt.Key? _cachedKey;

  static Future<encrypt.Key> _getEncryptionKey() async {
    if (_cachedKey != null) return _cachedKey!;

    String? base64Key = await _secureStorage.read(key: _keyAlias);
    if (base64Key == null) {
      // Generate a random 32-byte key (256-bit AES)
      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
      base64Key = base64UrlEncode(keyBytes);
      await _secureStorage.write(key: _keyAlias, value: base64Key);
    }

    final keyBytes = base64Url.decode(base64Key);
    _cachedKey = encrypt.Key(Uint8List.fromList(keyBytes));
    return _cachedKey!;
  }

  static Future<String> encryptData(String plainText) async {
    final key = await _getEncryptionKey();
    // IV is 16 bytes for AES. We use a random IV for every encryption to ensure uniqueness.
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    
    // Combine IV and cipherText in a single string for storage
    return '${base64.encode(iv.bytes)}:${encrypted.base64}';
  }

  static Future<String> decryptData(String encryptedData) async {
    try {
      final parts = encryptedData.split(':');
      if (parts.length != 2) {
        throw const FormatException('Invalid encrypted data format');
      }

      final ivBytes = base64.decode(parts[0]);
      final cipherText = parts[1];

      final key = await _getEncryptionKey();
      final iv = encrypt.IV(Uint8List.fromList(ivBytes));
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      
      final decrypted = encrypter.decrypt64(cipherText, iv: iv);
      return decrypted;
    } catch (e) {
      // Fallback/Error propagation: if decryption fails (e.g. data tampered), it propagates up to clear cache
      rethrow;
    }
  }

  /// Wipe the security keys. Helpful if performing a complete security reset.
  static Future<void> resetSecurityKeys() async {
    await _secureStorage.delete(key: _keyAlias);
    _cachedKey = null;
  }
}
