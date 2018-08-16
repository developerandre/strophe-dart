import 'dart:async';
import 'utils.dart';

class MD5 {
  static Future<List<int>> str2binl(String str) async {
    List<int> bin = [];
    for (int i = 0; i < str.length * 8; i += 8) {
      if (bin.length <= (i >> 5)) {
        var length = bin.length;
        bin.length = (i >> 5) + 1;
        bin.fillRange(length, (i >> 5) + 1, 0);
      }
      bin[i >> 5] |= (str.codeUnitAt((i / 8).floor()) & 255) << (i % 32);
    }
    return bin;
  }

  /*
     * Convert an array of little-endian words to a string
     */
  static Future<String> binl2str(List<int> bin) async {
    String str = "";
    for (int i = 0; i < bin.length * 32; i += 8) {
      //str += new String.fromCharCode((bin[i >> 5] >>> (i % 32)) & 255);
      str +=
          String.fromCharCode(_zeroFillRightShift(bin[i >> 5], (i % 32)) & 255);
    }
    return str;
  }

  static Future<String> binl2hex(List binarray) async {
    const String hex_tab = "0123456789abcdef";
    String str = "";
    for (int i = 0; i < binarray.length * 4; i++) {
      str += hex_tab
              .split('')
              .elementAt((binarray[i >> 2] >> ((i % 4) * 8 + 4)) & 0xF) +
          hex_tab
              .split('')
              .elementAt((binarray[i >> 2] >> ((i % 4) * 8)) & 0xF);
    }
    return str;
  }

  static int _zeroFillRightShift(int n, int amount) {
    //return (n & 0xffffffff) >> amount;
    return ((n & mask32) >> (32 - (amount & 31)));
  }

  static Future<List<int>> core_md5(List<int> chunk, int len) async {
    const _noise = const [
      0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, //
      0xa8304613, 0xfd469501, 0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
      0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821, 0xf61e2562, 0xc040b340,
      0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
      0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8,
      0x676f02d9, 0x8d2a4c8a, 0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
      0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70, 0x289b7ec6, 0xeaa127fa,
      0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
      0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92,
      0xffeff47d, 0x85845dd1, 0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
      0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
    ];

    /// Per-round shift amounts.
    const _shiftAmounts = const [
      07, 12, 17, 22, 07, 12, 17, 22, 07, 12, 17, 22, 07, 12, 17, 22, 05, 09,
      14, //
      20, 05, 09, 14, 20, 05, 09, 14, 20, 05, 09, 14, 20, 04, 11, 16, 23, 04,
      11,
      16, 23, 04, 11, 16, 23, 04, 11, 16, 23, 06, 10, 15, 21, 06, 10, 15, 21,
      06,
      10, 15, 21, 06, 10, 15, 21
    ];
    List<int> digest = List<int>(4);
    digest[0] = 0x67452301;
    digest[1] = 0xefcdab89;
    digest[2] = 0x98badcfe;
    digest[3] = 0x10325476;
    int a = digest[0];
    int b = digest[1];
    int c = digest[2];
    int d = digest[3];

    int e;
    int f;

    for (int i = 0; i < 64; i++) {
      if (i < 16) {
        e = (b & c) | ((~b & mask32) & d);
        f = i;
      } else if (i < 32) {
        e = (d & b) | ((~d & mask32) & c);
        f = ((5 * i) + 1) % 16;
      } else if (i < 48) {
        e = b ^ c ^ d;
        f = ((3 * i) + 5) % 16;
      } else {
        e = c ^ (b | (~d & mask32));
        f = (7 * i) % 16;
      }

      int temp = d;
      d = c;
      c = b;
      int y;
      if (chunk.length > f) {
        y = chunk[f];
      } else {
        y = 0;
      }
      b = add32(
          b, rotl32(add32(add32(a, e), add32(_noise[i], y)), _shiftAmounts[i]));
      a = temp;
    }

    digest[0] = add32(a, digest[0]);
    digest[1] = add32(b, digest[1]);
    digest[2] = add32(c, digest[2]);
    digest[3] = add32(d, digest[3]);
    return digest;
  }

  static Future<String> hexdigest(String s) async {
    return binl2hex(await core_md5(await str2binl(s), s.length * 8));
  }

  static Future<String> hash(String s) async {
    return binl2str(await core_md5(await str2binl(s), s.length * 8));
  }
}
