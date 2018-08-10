import 'dart:async';

import 'package:strophe/src/core.dart';
import 'package:strophe/src/enums.dart';
import 'package:strophe/src/plugins/plugins.dart';
import 'package:strophe/src/sha1.dart';

class CapsPlugin extends PluginClass {
  String _hash = 'sha-1';
  String _node = 'http://strophe.im/strophejs/';
  init(StropheConnection c) {
    this.connection = c;
    Strophe.addNamespace('CAPS', "http://jabber.org/protocol/caps");
    if (this.connection.disco == null) {
      throw {'error': "disco plugin required!"};
    }
    this.connection.disco.addFeature(Strophe.NS['CAPS']);
    this.connection.disco.addFeature(Strophe.NS['DISCO_INFO']);
    if (this.connection.disco.identities.length == 0) {
      return this.connection.disco.addIdentity("client", "pc", "strophejs", "");
    }
  }

  addFeature(String feature) {
    return this.connection.disco.addFeature(feature);
  }

  removeFeature(String feature) {
    return this.connection.disco.removeFeature(feature);
  }

  sendPres() {
    createCapsNode().then((StanzaBuilder caps) {
      return this.connection.send(Strophe.$pres().cnode(caps.tree()));
    });
  }

  Future<StanzaBuilder> createCapsNode() async {
    String node;
    if (this.connection.disco.identities.length > 0) {
      node = this.connection.disco.identities[0]['name'] ?? "";
    } else {
      node = this._node;
    }
    return Strophe.$build("c", {
      'xmlns': Strophe.NS['CAPS'],
      'hash': this._hash,
      'node': node,
      'ver': await generateVerificationString()
    });
  }

  propertySort(List<Map<String, String>> array, String property) {
    return array.sort((a, b) {
      return a[property].compareTo(b[property]);
    });
  }

  generateVerificationString() async {
    String ns;
    List<String> _ref1;
    List<Map<String, String>> ids = [];
    List<Map<String, String>> _ref = this.connection.disco.identities;
    for (int _i = 0, _len = _ref.length; _i < _len; _i++) {
      ids.add(_ref[_i]);
    }
    List<String> features = [];
    _ref1 = this.connection.disco.features;
    for (int _j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      features.add(_ref1[_j]);
    }
    String S = "";
    propertySort(ids, "category");
    propertySort(ids, "type");
    propertySort(ids, "lang");
    ids.forEach((Map<String, String> id) {
      S += "" +
          id['category'] +
          "/" +
          id['type'] +
          "/" +
          id['lang'] +
          "/" +
          id['name'] +
          "<";
    });
    features.sort();
    for (int _k = 0, _len2 = features.length; _k < _len2; _k++) {
      ns = features[_k];
      S += "" + ns + "<";
    }
    return "" + (await SHA1.b64_sha1(S)) + "=";
  }
}
