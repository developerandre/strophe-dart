import 'package:strophe/src/core.dart';
import 'package:strophe/src/enums.dart';
import 'package:strophe/src/plugins/plugins.dart';
import 'package:strophe/src/plugins/pubsub.dart';
import 'package:xml/xml/nodes/node.dart';

class PepPlugin extends PluginClass {
  init(StropheConnection c) {
    this.connection = c;
    if (this.connection.caps == null) {
      throw {'error': "caps plugin required!"};
    }
    if (this.connection.pubsub == null) {
      throw {'error': "pubsub plugin required!"};
    }
  }

  subscribe(String node, Function handler) {
    this.connection.caps.addFeature(node);
    this.connection.caps.addFeature("" + node + "+notify");
    if (handler != null) {
      this.connection.addHandler(
          handler, Strophe.NS['PUBSUB_EVENT'], "message", null, null, null);
    }
    return this.connection.caps.sendPres();
  }

  unsubscribe(String node) {
    this.connection.caps.removeFeature(node);
    this.connection.caps.removeFeature("" + node + "+notify");
    return this.connection.caps.sendPres();
  }

  String publish(String node, items, Function callback) {
    String iqid = this.connection.getUniqueId("pubsubpublishnode");
    if (node == null || node.isEmpty) node = 'myPep';
    if (items is List<Map<String, dynamic>> || items is XmlNode) {
      if (callback != null)
        this.connection.addHandler(callback, null, 'iq', null, iqid, null);
      PubsubBuilder c = new PubsubBuilder(
              'iq', {'from': this.connection.jid, 'type': 'set', 'id': iqid})
          .c('pubsub', {'xmlns': Strophe.NS['PUBSUB']}).c(
              'publish', {'node': node, 'jid': this.connection.jid});
      if (items is List<Map<String, dynamic>>) {
        Map<String, dynamic> last = items.last;
        if (last != null) last['attrs'].addAll({'id': 'current'});
        this.connection.send(c.list('item', items).tree());
      } else if (items is XmlNode)
        this
            .connection
            .send(c.c('item', {'id': 'current'}).cnode(items).tree());
      return iqid;
    }
    return '';
  }
}
