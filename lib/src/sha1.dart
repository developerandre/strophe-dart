import 'dart:async';

import 'package:flutter/services.dart';

class SHA1 {
  static const mask32 = 0xFFFFFFFF;
  static MethodChannel _methodChannel =
      new MethodChannel("flutter.channel/sasl");
  static Future<List<int>> core_sha1(List<int> x, int len) async {
    return await _methodChannel.invokeMethod("core_sha1", [x, len]);
    /* append padding */
    /* if ((x.length <= (len >> 5))) {
      x.length = (len >> 5) + 1;
      x[len >> 5] = 0x80 << (24 - len % 32);
    } else
      x[len >> 5] |= 0x80 << (24 - len % 32);
    int length = x.length;
    x.length = ((((len + 64) >> 9) << 4) + 14) + 1;
    x.fillRange(length, ((((len + 64) >> 9) << 4) + 14) + 1, 0);
    x.add(len);
    //x.add(0);
    //x[((len + 64 >> 9) << 4) + 15] = len;

    List w = new List(80);
    int a = 1732584193;
    int b = -271733879;
    int c = -1732584194;
    int d = 271733878;
    int e = -1009589776;

    int j, t, olda, oldb, oldc, oldd, olde;
    for (int i = 0; i < x.length; i += 16) {
      olda = a;
      oldb = b;
      oldc = c;
      oldd = d;
      olde = e;

      for (j = 0; j < 80; j++) {
        if (j < 16) {
          w[j] = x[i + j];
        } else {
          w[j] = rol(w[j - 3] ^ w[j - 8] ^ w[j - 14] ^ w[j - 16], 1);
        }
        t = safe_add(safe_add(rol(a, 5), sha1_ft(j, b, c, d)),
            safe_add(safe_add(e, w[j]), sha1_kt(j)));
        e = d;
        d = c;
        c = rol(b, 30);
        b = a;
        a = t;
      }

      a = safe_add(a, olda);
      b = safe_add(b, oldb);
      c = safe_add(c, oldc);
      d = safe_add(d, oldd);
      e = safe_add(e, olde);
    }
    return [a, b, c, d, e]; */
  }

/*
 * Perform the appropriate triplet combination function for the current
 * iteration
 */
  static int sha1_ft(int t, int b, int c, int d) {
    if (t < 20) {
      return (b & c) | ((~b) & d);
    }
    if (t < 40) {
      return b ^ c ^ d;
    }
    if (t < 60) {
      return (b & c) | (b & d) | (c & d);
    }
    return b ^ c ^ d;
  }

/*
 * Determine the appropriate additive constant for the current iteration
 */
  static int sha1_kt(num t) {
    return (t < 20)
        ? 1518500249
        : (t < 40) ? 1859775393 : (t < 60) ? -1894007588 : -899497514;
  }

/*
 * Calculate the HMAC-SHA1 of a key and some data
 */
  static Future<List<int>> core_hmac_sha1(String key, String data) async {
    return await _methodChannel.invokeMethod("core_hmac_sha1", [key, data]);
    /*  List<int> bkey = str2binb(key);
    if (bkey.length > 16) {
      bkey = core_sha1(bkey, key.length * 8);
    }

    List ipad = new List(16), opad = new List(16);
    int value;
    for (int i = 0; i < 16; i++) {
      value = i < bkey.length ? bkey[i] : 0;
      ipad[i] = value ^ 0x36363636;
      opad[i] = value ^ 0x5C5C5C5C;
    }
    List hash = core_sha1(
        new List.from(ipad)..addAll(str2binb(data)), 512 + data.length * 8);
    return core_sha1(new List.from(opad)..addAll(hash), 512 + 160);
   */
  }

/*
 * Add integers, wrapping at 2^32. This uses 16-bit operations internally
 * to work around bugs in some JS interpreters.
 */
  static Future<int> safe_add(int x, int y) async {
    /* var lsw = (x & 0xFFFF) + (y & 0xFFFF);
    var msw = (x >> 16) + (y >> 16) + (lsw >> 16);
    return (msw << 16) | (lsw & 0xFFFF); */
    return await _methodChannel.invokeMethod("safe_add", [x, y]);
  }

/*
 * Bitwise rotate a 32-bit number to the left.
 */
  static Future<int> rol(int nber, int cnt) async {
    //return (nber << cnt) | (nber >>> (32 - cnt));
    //return (nber << cnt) | _zeroFillRightShift(nber, (32 - cnt));
    /*  int modShift = cnt & 31;
    return ((nber << modShift) & mask32) | ((nber & mask32) >> (32 - modShift)); */
    return await _methodChannel.invokeMethod("safe_add", [nber, cnt]);
  }

/*
 * Convert an 8-bit or 16-bit string to an array of big-endian words
 * In 8-bit function, characters >255 have their hi-byte silently ignored.
 */
  static Future<List<int>> str2binb(String str) async {
    return await _methodChannel.invokeMethod("str2binb", [str]);
    /*  List<int> bin = [];
    int mask = 255;
    int index;
    for (int i = 0; i < str.length * 8; i += 8) {
      index = i >> 5;
      if (bin.length + 1 < index) {
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
    return bin; */
  }

/*
 * Convert an array of big-endian words to a string
 */
  static Future<String> binb2str(List<int> bin) async {
    /* String str = "";
    int mask = 255;
    for (int i = 0; i < bin.length * 32; i += 8) {
      //str += new String.fromCharCode((bin[i >> 5] >>> (24 - i % 32)) & mask);
      str += new String.fromCharCode(
          _zeroFillRightShift(bin[i >> 5], (24 - i % 32)) & mask);
    }
    return str; */
    return await _methodChannel.invokeMethod("binb2str", [bin]);
  }

/*
 * Convert an array of big-endian words to a base-64 string
 */
  static Future<String> binb2b64(List<int> binarray) async {
    return await _methodChannel.invokeMethod("binb2b64", [binarray]);
    /* String tab =
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
    return str; */
  }

  static Future<String> b64_hmac_sha1(String key, String data) async {
    //return binb2b64(core_hmac_sha1(key, data));
    return await _methodChannel.invokeMethod("b64_hmac_sha1", [key, data]);
  }

  static Future<String> b64_sha1(String s) async {
    //return binb2b64(core_sha1(str2binb(s), s.length * 8));
    return await _methodChannel.invokeMethod("b64_sha1", [s]);
  }

  static Future<String> str_hmac_sha1(String key, String data) async {
    //return binb2str(core_hmac_sha1(key, data));
    return await _methodChannel.invokeMethod("str_hmac_sha1", [key, data]);
  }

  static Future<String> str_sha1(String s) async {
    //return binb2str(core_sha1(str2binb(s), s.length * 8));
    return await _methodChannel.invokeMethod("str_sha1", [s]);
  }

  static Future<List<int>> forEachBinaryXor(
      List<int> tab1, List<int> tab2, int length) async {
    //return binb2str(core_sha1(str2binb(s), s.length * 8));
    return await _methodChannel
        .invokeMethod("forEachBinaryXor", [tab1, tab2, length]);
  }
}
