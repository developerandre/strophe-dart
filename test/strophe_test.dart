import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strophe/src/sha1.dart';
import 'package:strophe/strophe.dart';

void main() async {
  test('adds one to input values', () async {
    //var key = utf8.encode("p@ssw0rd");
    //var bytes = utf8.encode("foobar");

    //var hmacSha1 = new Hmac(sha1, key); // HMAC-SHA256
    //var digest = hmacSha1.convert(bytes);
    //String decode = utf8.decode(digest.bytes, allowMalformed: true);
    //print(" $decode");
    /* print(String.fromCharCodes(digest.bytes) == 'Í¡ÊSQâ9þ5RðAåÜhl');
  print("HMAC digest as bytes: ${digest.bytes}");
  print("HMAC digest as hex string: $digest");
  print("HMAC digest as base64 string: ${base64.encode(digest.bytes)}"); */
    StropheConnection _connection =
        Strophe.Connection("ws://127.0.0.1:5280/xmpp");
    _connection.xmlInput = (elem) {
      //print('input $elem');
    };
    _connection.xmlOutput = (elem) {
      //print('output $elem');
    };
    _connection.connect('11111@localhost', 'jesuis123',
        (int status, condition, ele) {
      print("$status $ele");
    });
    await Future.delayed(Duration(days: 1), () {
      print('kehhh');
    });
  });
}
