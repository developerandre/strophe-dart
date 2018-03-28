import 'dart:async';

import 'package:flutter/services.dart';

class MD5 {
  static MethodChannel _methodChannel =
      new MethodChannel("flutter.channel/sasl");
  //static const mask32 = 0xFFFFFFFF;
  static Future<int> safe_add(int x, int y) async {
    /* var lsw = (0xFFFF & x) + (0xFFFF & y);
    var msw = (x >> 16) + (y >> 16) + (lsw >> 16);
    return (msw << 16) | (lsw & 0xFFFF); */
    return await _methodChannel.invokeMethod("md5_safe_add", [x, y]);
  }

  static Future<int> bit_rol(int nber, int cnt) async {
    // Dans strophe.js (nber << cnt) | (nber >>> (32 - cnt))
    // l'operateur >>> n'existe pas dans dart
    //return (nber << cnt) | _zeroFillRightShift(nber, (32 - cnt));
    return await _methodChannel.invokeMethod("bit_rol", [nber, cnt]);
  }

  static Future<List<int>> str2binl(String str) async {
    /* List bin = [];
    for (int i = 0; i < str.length * 8; i += 8) {
      if (bin.length <= (i >> 5)) {
        var length = bin.length;
        bin.length = (i >> 5) + 1;
        bin.fillRange(length, (i >> 5) + 1, 0);
      }
      bin[i >> 5] |= (str.codeUnitAt((i / 8).round()) & 255) << (i % 32);
    }
    return bin; */
    return await _methodChannel.invokeMethod("str2binl", [str]);
  }

  /*
     * Convert an array of little-endian words to a string
     */
  static Future<String> binl2str(List<int> bin) async {
    /* String str = "";
    for (int i = 0; i < bin.length * 32; i += 8) {
      //str += new String.fromCharCode((bin[i >> 5] >>> (i % 32)) & 255);
      str += new String.fromCharCode(
          _zeroFillRightShift(bin[i >> 5], (i % 32)) & 255);
    }
    return str; */
    return await _methodChannel.invokeMethod("binl2str", [bin]);
  }

  static Future<String> binl2hex(List binarray) async {
    /*  const String hex_tab = "0123456789abcdef";
    String str = "";
    for (int i = 0; i < binarray.length * 4; i++) {
      str += hex_tab
              .split('')
              .elementAt((binarray[i >> 2] >> ((i % 4) * 8 + 4)) & 0xF) +
          hex_tab
        ..split('').elementAt((binarray[i >> 2] >> ((i % 4) * 8)) & 0xF);
    }
    return str; */
    return await _methodChannel.invokeMethod("binl2hex", [binarray]);
  }

  /*  static int _zeroFillRightShift(int n, int amount) {
    //return (n & 0xffffffff) >> amount;
    // return ((n & mask32) >> (32 - (amount & 31)));
    return 0;
  } */

  static Future<int> md5_cmn(int q, int a, int b, int x, int s, int t) async {
    /* return safe_add(bit_rol(safe_add(safe_add(a, q), safe_add(x, t)), s), b); */
    return await _methodChannel.invokeMethod("md5_cmn", [q, a, b, x, s, t]);
  }

  static Future<int> md5_ff(
      int a, int b, int c, int d, int x, int s, int t) async {
    //return md5_cmn((b & c) | ((~b) & d), a, b, x, s, t);
    return await _methodChannel.invokeMethod("md5_ff", [a, b, c, d, x, s, t]);
  }

  static Future<int> md5_gg(
      int a, int b, int c, int d, int x, int s, int t) async {
    //return md5_cmn((b & d) | (c & (~d)), a, b, x, s, t);
    return await _methodChannel.invokeMethod("md5_gg", [a, b, c, d, x, s, t]);
  }

  static Future<int> md5_hh(
      int a, int b, int c, int d, int x, int s, int t) async {
    //return md5_cmn(b ^ c ^ d, a, b, x, s, t);
    return await _methodChannel.invokeMethod("md5_hh", [a, b, c, d, x, s, t]);
  }

  static Future<int> md5_ii(
      int a, int b, int c, int d, int x, int s, int t) async {
    //return md5_cmn(c ^ (b | (~d)), a, b, x, s, t);
    return await _methodChannel.invokeMethod("md5_ii", [a, b, c, d, x, s, t]);
  }

  static Future<List<int>> core_md5(List<int> x, int len) async {
    return await _methodChannel.invokeMethod("core_md5", [x, len]);
    /* append padding */
    /*  x[len >> 5] |= 0x80 << ((len) % 32);
    int length = x.length;
    //x.length = (((len + 64) >>> 9) << 4) + 14;
    x.length = (_zeroFillRightShift((len + 64), 9) << 4) + 14;
    if (length < x.length) {
      x.fillRange(
          length - 1, (_zeroFillRightShift((len + 64), 9) << 4) + 14, 0);
      x.add(len);
      x.add(0);
    }
    //x[(((len + 64) >> 9) << 4) + 14] = len;

    var a = 1732584193;
    var b = -271733879;
    var c = -1732584194;
    var d = 271733878;

    var olda, oldb, oldc, oldd;
    for (var i = 0; i < x.length; i += 16) {
      olda = a;
      oldb = b;
      oldc = c;
      oldd = d;

      a = md5_ff(a, b, c, d, x[i + 0], 7, -680876936);
      d = md5_ff(d, a, b, c, x[i + 1], 12, -389564586);
      c = md5_ff(c, d, a, b, x[i + 2], 17, 606105819);
      b = md5_ff(b, c, d, a, x[i + 3], 22, -1044525330);
      a = md5_ff(a, b, c, d, x[i + 4], 7, -176418897);
      d = md5_ff(d, a, b, c, x[i + 5], 12, 1200080426);
      c = md5_ff(c, d, a, b, x[i + 6], 17, -1473231341);
      b = md5_ff(b, c, d, a, x[i + 7], 22, -45705983);
      a = md5_ff(a, b, c, d, x[i + 8], 7, 1770035416);
      d = md5_ff(d, a, b, c, x[i + 9], 12, -1958414417);
      c = md5_ff(c, d, a, b, x[i + 10], 17, -42063);
      b = md5_ff(b, c, d, a, x[i + 11], 22, -1990404162);
      a = md5_ff(a, b, c, d, x[i + 12], 7, 1804603682);
      d = md5_ff(d, a, b, c, x[i + 13], 12, -40341101);
      c = md5_ff(c, d, a, b, x[i + 14], 17, -1502002290);
      b = md5_ff(b, c, d, a, x[i + 15], 22, 1236535329);

      a = md5_gg(a, b, c, d, x[i + 1], 5, -165796510);
      d = md5_gg(d, a, b, c, x[i + 6], 9, -1069501632);
      c = md5_gg(c, d, a, b, x[i + 11], 14, 643717713);
      b = md5_gg(b, c, d, a, x[i + 0], 20, -373897302);
      a = md5_gg(a, b, c, d, x[i + 5], 5, -701558691);
      d = md5_gg(d, a, b, c, x[i + 10], 9, 38016083);
      c = md5_gg(c, d, a, b, x[i + 15], 14, -660478335);
      b = md5_gg(b, c, d, a, x[i + 4], 20, -405537848);
      a = md5_gg(a, b, c, d, x[i + 9], 5, 568446438);
      d = md5_gg(d, a, b, c, x[i + 14], 9, -1019803690);
      c = md5_gg(c, d, a, b, x[i + 3], 14, -187363961);
      b = md5_gg(b, c, d, a, x[i + 8], 20, 1163531501);
      a = md5_gg(a, b, c, d, x[i + 13], 5, -1444681467);
      d = md5_gg(d, a, b, c, x[i + 2], 9, -51403784);
      c = md5_gg(c, d, a, b, x[i + 7], 14, 1735328473);
      b = md5_gg(b, c, d, a, x[i + 12], 20, -1926607734);

      a = md5_hh(a, b, c, d, x[i + 5], 4, -378558);
      d = md5_hh(d, a, b, c, x[i + 8], 11, -2022574463);
      c = md5_hh(c, d, a, b, x[i + 11], 16, 1839030562);
      b = md5_hh(b, c, d, a, x[i + 14], 23, -35309556);
      a = md5_hh(a, b, c, d, x[i + 1], 4, -1530992060);
      d = md5_hh(d, a, b, c, x[i + 4], 11, 1272893353);
      c = md5_hh(c, d, a, b, x[i + 7], 16, -155497632);
      b = md5_hh(b, c, d, a, x[i + 10], 23, -1094730640);
      a = md5_hh(a, b, c, d, x[i + 13], 4, 681279174);
      d = md5_hh(d, a, b, c, x[i + 0], 11, -358537222);
      c = md5_hh(c, d, a, b, x[i + 3], 16, -722521979);
      b = md5_hh(b, c, d, a, x[i + 6], 23, 76029189);
      a = md5_hh(a, b, c, d, x[i + 9], 4, -640364487);
      d = md5_hh(d, a, b, c, x[i + 12], 11, -421815835);
      c = md5_hh(c, d, a, b, x[i + 15], 16, 530742520);
      b = md5_hh(b, c, d, a, x[i + 2], 23, -995338651);

      a = md5_ii(a, b, c, d, x[i + 0], 6, -198630844);
      d = md5_ii(d, a, b, c, x[i + 7], 10, 1126891415);
      c = md5_ii(c, d, a, b, x[i + 14], 15, -1416354905);
      b = md5_ii(b, c, d, a, x[i + 5], 21, -57434055);
      a = md5_ii(a, b, c, d, x[i + 12], 6, 1700485571);
      d = md5_ii(d, a, b, c, x[i + 3], 10, -1894986606);
      c = md5_ii(c, d, a, b, x[i + 10], 15, -1051523);
      b = md5_ii(b, c, d, a, x[i + 1], 21, -2054922799);
      a = md5_ii(a, b, c, d, x[i + 8], 6, 1873313359);
      d = md5_ii(d, a, b, c, x[i + 15], 10, -30611744);
      c = md5_ii(c, d, a, b, x[i + 6], 15, -1560198380);
      b = md5_ii(b, c, d, a, x[i + 13], 21, 1309151649);
      a = md5_ii(a, b, c, d, x[i + 4], 6, -145523070);
      d = md5_ii(d, a, b, c, x[i + 11], 10, -1120210379);
      c = md5_ii(c, d, a, b, x[i + 2], 15, 718787259);
      b = md5_ii(b, c, d, a, x[i + 9], 21, -343485551);

      a = safe_add(a, olda);
      b = safe_add(b, oldb);
      c = safe_add(c, oldc);
      d = safe_add(d, oldd);
    }
    return [a, b, c, d]; */
  }

  static Future<String> hexdigest(String s) async {
    //return binl2hex(core_md5(str2binl(s), s.length * 8));
    return await _methodChannel.invokeMethod("hexdigest", [s]);
  }

  static Future<String> hash(String s) async {
    //return binl2str(core_md5(str2binl(s), s.length * 8));
    return await _methodChannel.invokeMethod("hash", [s]);
  }
}
