import 'dart:io';

import 'package:strophe/src/enums.dart';
import 'package:xml/xml/nodes/element.dart';

// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A bitmask that limits an integer to 32 bits.
const mask32 = 0xFFFFFFFF;

/// The number of bits in a byte.
const bitsPerByte = 8;

/// The number of bytes in a 32-bit word.
const bytesPerWord = 4;

/// Adds [x] and [y] with 32-bit overflow semantics.
int add32(int x, int y) => (x + y) & mask32;

/// Bitwise rotates [val] to the left by [shift], obeying 32-bit overflow
/// semantics.
int rotl32(int val, int shift) {
  var modShift = shift & 31;
  return ((val << modShift) & mask32) | ((val & mask32) >> (32 - modShift));
}

class Utils {
  static String utf16to8(String str) {
    int c;
    String out = "";
    int len = str.length;
    for (int i = 0; i < len; i++) {
      c = str.codeUnitAt(i);
      if ((c >= 0x0000) && (c <= 0x007F)) {
        out += new String.fromCharCode(str.codeUnitAt(i));
      } else if (c > 0x07FF) {
        out += new String.fromCharCode(0xE0 | ((c >> 12) & 0x0F));
        out += new String.fromCharCode(0x80 | ((c >> 6) & 0x3F));
        out += new String.fromCharCode(0x80 | ((c >> 0) & 0x3F));
      } else {
        out += new String.fromCharCode(0xC0 | ((c >> 6) & 0x1F));
        out += new String.fromCharCode(0x80 | ((c >> 0) & 0x3F));
      }
    }
    return out;
  }

  static List<Cookie> addCookies(Map<String, dynamic> cookies) {
    String cookieName;
    dynamic cookieObj;
    bool isObj;
    String cookieValue;
    DateTime expires;
    String domain;
    String path;
    List<Cookie> allCookies = [];
    cookies = cookies ?? {};
    cookies.forEach((String key, dynamic value) {
      expires = null;
      domain = '';
      path = '';
      cookieObj = value;
      isObj = cookieObj is String ? false : true;
      cookieValue = Uri.encodeFull(isObj ? cookieObj.value : cookieObj);
      if (isObj) {
        expires = cookieObj.expires ?? null;
        domain = cookieObj.domain ?? '';
        path = cookieObj.path ?? '';
      }
      Cookie cookie = new Cookie(cookieName, cookieValue);
      cookie.domain = domain;
      cookie.expires = expires;
      cookie.path = path;
      allCookies.add(cookie);
    });
    return allCookies;
  }
}

typedef void ConnectCallBack(int status, dynamic condition, dynamic elem);
typedef void XmlInputCallback(XmlElement elem);
typedef void RawInputCallback(String elem);
typedef void ConnexionCallback(req, Function _callback, String raw);
typedef void AuthenticateCallback(List<StropheSASLMechanism> matched);
