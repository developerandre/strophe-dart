import 'dart:convert';

import 'package:crypto/crypto.dart';

class SHA1 {
  static List<int> coreSha1(String s, int len) {
    var bytes = utf8.encode(s); // data being hashed
    Digest digest = sha1.convert(bytes);
    return digest.bytes;
  }

  /*
 * Perform the appropriate triplet combination function for the current
 * iteration

 * Calculate the HMAC-SHA1 of a key and some data
 */
  static List<int> coreHmacSha1(String cle, String data) {
    List<int> key = utf8.encode(cle);
    List<int> bytes = utf8.encode(data);

    Hmac hmacSha1 = new Hmac(sha1, key); // HMAC-SHA1
    Digest digest = hmacSha1.convert(bytes);
    return digest.bytes;
  }

/*
 * Convert an array of big-endian words to a string
 */
  static String binb2str(List<int> bytes) {
    return String.fromCharCodes(bytes);
  }

/*
 * Convert an array of big-endian words to a base-64 string
 */
  static String binb2b64(List<int> binarray) {
    return base64.encode(binarray);
  }

  static String b64HmacSha1(String key, String data) {
    return binb2b64(coreHmacSha1(key, data));
  }

  static String b64Sha1(String s) {
    return binb2b64(coreSha1(s, s.length * 8));
  }

  static String strHmacSha1(String key, String data) {
    return binb2str(coreHmacSha1(key, data));
  }

  static String strSha1(String s) {
    return binb2str(coreSha1(s, s.length * 8));
  }
}
