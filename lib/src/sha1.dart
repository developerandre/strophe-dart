import 'dart:async';

import 'package:strophe/src/utils.dart';

class SHA1 {
  static const mask32 = 0xFFFFFFFF;
  static Future<List<int>> core_sha1(List<int> chunk, int len) async {
    List<int> digest = List<int>(5);
    digest[0] = 0x67452301;
    digest[1] = 0xEFCDAB89;
    digest[2] = 0x98BADCFE;
    digest[3] = 0x10325476;
    digest[4] = 0xC3D2E1F0;

    int a = digest[0];
    int b = digest[1];
    int c = digest[2];
    int d = digest[3];
    int e = digest[4];

    List<int> _extended = List<int>(80);
    int y;
    for (int i = 0; i < 80; i++) {
      if (i < 16) {
        if (chunk.length > i) {
          y = chunk[i];
        } else {
          y = 0;
        }
        _extended[i] = y;
      } else {
        _extended[i] = rotl32(
            _extended[i - 3] ^
                _extended[i - 8] ^
                _extended[i - 14] ^
                _extended[i - 16],
            1);
      }

      var newA = add32(add32(rotl32(a, 5), e), _extended[i]);
      if (i < 20) {
        newA = add32(add32(newA, (b & c) | (~b & d)), 0x5A827999);
      } else if (i < 40) {
        newA = add32(add32(newA, (b ^ c ^ d)), 0x6ED9EBA1);
      } else if (i < 60) {
        newA = add32(add32(newA, (b & c) | (b & d) | (c & d)), 0x8F1BBCDC);
      } else {
        newA = add32(add32(newA, b ^ c ^ d), 0xCA62C1D6);
      }

      e = d;
      d = c;
      c = rotl32(b, 30);
      b = a;
      a = newA & mask32;
    }

    digest[0] = add32(a, digest[0]);
    digest[1] = add32(b, digest[1]);
    digest[2] = add32(c, digest[2]);
    digest[3] = add32(d, digest[3]);
    digest[4] = add32(e, digest[4]);
    return digest;
  }

/*
 * Perform the appropriate triplet combination function for the current
 * iteration

 * Calculate the HMAC-SHA1 of a key and some data
 */
  static Future<List<int>> core_hmac_sha1(String key, String data) async {
    List<int> bkey = await str2binb(key);
    if (bkey.length > 16) {
      bkey = await core_sha1(bkey, key.length * 8);
    }

    List<int> ipad = new List<int>(16), opad = new List<int>(16);
    int value;
    for (int i = 0; i < 16; i++) {
      value = i < bkey.length ? bkey[i] : 0;
      ipad[i] = value ^ 0x36363636;
      opad[i] = value ^ 0x5C5C5C5C;
    }
    List<int> pad = new List<int>.from(ipad);
    pad.addAll(await str2binb(data));
    List<int> hash = await core_sha1(pad, 512 + data.length * 8);
    List<int> pod = new List.from(opad);
    pod.addAll(hash);
    return core_sha1(pod, 512 + 160);
  }

  static int _zeroFillRightShift(int n, int amount) {
    //return (n & 0xffffffff) >> amount;
    return ((n & mask32) >> (32 - (amount & 31)));
  }

/*
 * Bitwise rotate a 32-bit number to the left.
 */

  static Future<int> rol(int nber, int cnt) async {
    //return (nber << cnt) | (nber >>> (32 - cnt));
    //return (nber << cnt) | _zeroFillRightShift(nber, (32 - cnt));
    int modShift = cnt & 31;
    return ((nber << modShift) & mask32) | ((nber & mask32) >> (32 - modShift));
  }

/*
 * Convert an 8-bit or 16-bit string to an array of big-endian words
 * In 8-bit function, characters >255 have their hi-byte silently ignored.
 */
  static Future<List<int>> str2binb(String str) async {
    List<int> bin = [];
    int mask = 255;
    int index;
    for (int i = 0; i < str.length * 8; i += 8) {
      index = i >> 5;
      if (bin.length < index + 1) {
        bin.length = index + 1;
        bin.fillRange(bin.length, index + 1, 0);
      }
      if (bin[i >> 5] == null) {
        bin[i >> 5] = (str.codeUnitAt((i / 8).round()) & mask) << (24 - i % 32);
      } else {
        bin[i >> 5] |=
            (str.codeUnitAt((i / 8).round()) & mask) << (24 - i % 32);
      }
    }
    return bin;
  }

/*
 * Convert an array of big-endian words to a string
 */
  static Future<String> binb2str(List<int> bin) async {
    String str = "";
    int mask = 255;
    for (int i = 0; i < bin.length * 32; i += 8) {
      //str += new String.fromCharCode((bin[i >> 5] >>> (24 - i % 32)) & mask);
      str += new String.fromCharCode(
          _zeroFillRightShift(bin[i >> 5], (24 - i % 32)) & mask);
    }
    return str;
  }

/*
 * Convert an array of big-endian words to a base-64 string
 */
  static Future<String> binb2b64(List<int> binarray) async {
    String tab =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    String str = "";
    int triplet;
    int bin, bin2, bin3;
    for (int i = 0; i < binarray.length * 4; i += 3) {
      bin = (i >> 2) < binarray.length ? binarray[i >> 2] : 0;
      bin2 = (i + 1 >> 2) < binarray.length ? binarray[i + 1 >> 2] : 0;
      bin3 = (i + 2 >> 2) < binarray.length ? binarray[i + 2 >> 2] : 0;
      triplet = (((bin >> 8 * (3 - i % 4)) & 0xFF) << 16) |
          (((bin2 >> 8 * (3 - (i + 1) % 4)) & 0xFF) << 8) |
          ((bin3 >> 8 * (3 - (i + 2) % 4)) & 0xFF);
      for (int j = 0; j < 4; j++) {
        if (i * 8 + j * 6 > binarray.length * 32) {
          str += "=";
        } else {
          str += tab.split('').elementAt((triplet >> 6 * (3 - j)) & 0x3F);
        }
      }
    }
    return str;
  }

  static Future<String> b64_hmac_sha1(String key, String data) async {
    return binb2b64(await core_hmac_sha1(key, data));
  }

  static Future<String> b64_sha1(String s) async {
    return binb2b64(await core_sha1(await str2binb(s), s.length * 8));
  }

  static Future<String> str_hmac_sha1(String key, String data) async {
    return binb2str(await core_hmac_sha1(key, data));
  }

  static Future<String> str_sha1(String s) async {
    return binb2str(await core_sha1(await str2binb(s), s.length * 8));
  }
}
