import 'dart:convert';
import 'package:crypto/crypto.dart';

class MD5 {
  /*
     * Convert an array of little-endian words to a string
     */
  static String binl2str(List<int> bytes) {
    return String.fromCharCodes(bytes);
  }

  static String binl2hex(List binarray) {
    return md5.convert(binarray).toString();
  }

  static List<int> coreMd5(String s, int len) {
    var bytes = utf8.encode(s); // data being hashed
    Digest digest = md5.convert(bytes);
    return digest.bytes;
  }

  static String hexdigest(String s) {
    return binl2hex(coreMd5(s, s.length * 8));
  }

  static String hash(String s) {
    return binl2str(coreMd5(s, s.length * 8));
  }
}
