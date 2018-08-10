import 'package:strophe/src/core.dart';
import 'package:strophe/src/enums.dart';
import 'package:strophe/src/plugins/plugins.dart';
import 'package:xml/xml/nodes/element.dart';

class DiscoPlugin extends PluginClass {
  List<Map<String, String>> _identities = [];
  List<String> _features = [];
  List<Map<String, dynamic>> _items = [];

  /** Function: init
     * Plugin init
     *
     * Parameters:
     *   (Strophe.Connection) conn - Strophe connection
     */
  List<Map<String, String>> get identities {
    return _identities;
  }

  List<String> get features {
    return _features;
  }

  init(StropheConnection conn) {
    this.connection = conn;
    this._identities = [];
    this._features = [];
    this._items = [];
    // disco info
    conn.addHandler(
        this._onDiscoInfo, Strophe.NS['DISCO_INFO'], 'iq', 'get', null, null);
    // disco items
    conn.addHandler(
        this._onDiscoItems, Strophe.NS['DISCO_ITEMS'], 'iq', 'get', null, null);
  }

  /** Function: addIdentity
     * See http://xmpp.org/registrar/disco-categories.html
     * Parameters:
     *   (String) category - category of identity (like client, automation, etc ...)
     *   (String) type - type of identity (like pc, web, bot , etc ...)
     *   (String) name - name of identity in natural language
     *   (String) lang - lang of name parameter
     *
     * Returns:
     *   Boolean
     */
  bool addIdentity(String category, String type,
      [String name = '', String lang = '']) {
    for (int i = 0; i < this._identities.length; i++) {
      if (this._identities[i]['category'] == category &&
          this._identities[i]['type'] == type &&
          this._identities[i]['name'] == name &&
          this._identities[i]['lang'] == lang) {
        return false;
      }
    }
    this
        ._identities
        .add({'category': category, 'type': type, 'name': name, 'lang': lang});
    return true;
  }

  /** Function: addFeature
     *
     * Parameters:
     *   (String) var_name - feature name (like jabber:iq:version)
     *
     * Returns:
     *   boolean
     */
  bool addFeature(String varName) {
    for (int i = 0; i < this._features.length; i++) {
      if (this._features[i] == varName) return false;
    }
    this._features.add(varName);
    return true;
  }

  /** Function: removeFeature
     *
     * Parameters:
     *   (String) var_name - feature name (like jabber:iq:version)
     *
     * Returns:
     *   boolean
     */
  bool removeFeature(String varName) {
    for (int i = 0; i < this._features.length; i++) {
      if (this._features[i] == varName) {
        this._features.removeAt(i);
        return true;
      }
    }
    return false;
  }

  /** Function: addItem
     *
     * Parameters:
     *   (String) jid
     *   (String) name
     *   (String) node
     *   (Function) call_back
     *
     * Returns:
     *   boolean
     */
  addItem(String jid, String name, String node, [Function callback]) {
    if (node != null && node.isNotEmpty && callback == null) return false;
    this
        ._items
        .add({'jid': jid, 'name': name, 'node': node, 'call_back': callback});
    return true;
  }

  /** Function: info
     * Info query
     *
     * Parameters:
     *   (Function) call_back
     *   (String) jid
     *   (String) node
     */
  info(String jid,
      [String node, Function success, Function error, int timeout]) {
    Map<String, String> attrs = {'xmlns': Strophe.NS['DISCO_INFO']};
    if (node != null && node.isNotEmpty) attrs['node'] = node;

    StanzaBuilder info = Strophe
        .$iq({'from': this.connection.jid, 'to': jid, 'type': 'get'}).c(
            'query', attrs);
    this.connection.sendIQ(info.tree(), success, error, timeout);
  }

  /** Function: items
     * Items query
     *
     * Parameters:
     *   (Function) call_back
     *   (String) jid
     *   (String) node
     */
  items(String jid,
      [String node, Function success, Function error, int timeout]) {
    Map<String, String> attrs = {'xmlns': Strophe.NS['DISCO_ITEMS']};
    if (node != null && node.isNotEmpty) attrs['node'] = node;

    StanzaBuilder items = Strophe
        .$iq({'from': this.connection.jid, 'to': jid, 'type': 'get'}).c(
            'query', attrs);
    this.connection.sendIQ(items.tree(), success, error, timeout);
  }

  /** PrivateFunction: _buildIQResult
     */
  StanzaBuilder _buildIQResult(
      XmlElement stanza, Map<String, String> queryAttrs) {
    String id = stanza.getAttribute('id');
    String from = stanza.getAttribute('from');
    StanzaBuilder iqresult = Strophe.$iq({'type': 'result', id: id});

    if (from != null) {
      iqresult.attrs({'to': from});
    }

    return iqresult.c('query', queryAttrs);
  }

  /** PrivateFunction: _onDiscoInfo
     * Called when receive info request
     */
  _onDiscoInfo(XmlElement stanza) {
    String node =
        stanza.findAllElements('query').toList()[0].getAttribute('node');
    Map<String, String> attrs = {'xmlns': Strophe.NS['DISCO_INFO']};
    if (node != null && node.isNotEmpty) {
      attrs['node'] = node;
    }
    StanzaBuilder iqresult = this._buildIQResult(stanza, attrs);
    for (int i = 0; i < this._identities.length; i++) {
      attrs = {
        'category': this._identities[i]['category'],
        'type': this._identities[i]['type']
      };
      if (this._identities[i]['name'] != null)
        attrs['name'] = this._identities[i]['name'];
      if (this._identities[i]['lang'] != null)
        attrs['xml:lang'] = this._identities[i]['lang'];
      iqresult.c('identity', attrs).up();
    }
    for (int i = 0; i < this._features.length; i++) {
      iqresult.c('feature', {'var': this._features[i]}).up();
    }
    this.connection.send(iqresult.tree());
    return true;
  }

  /** PrivateFunction: _onDiscoItems
     * Called when receive items request
     */
  bool _onDiscoItems(XmlElement stanza) {
    Map<String, String> queryAttrs = {'xmlns': Strophe.NS['DISCO_ITEMS']};
    String node =
        stanza.findAllElements('query').toList()[0].getAttribute('node');
    List items;
    if (node != null && node.isNotEmpty) {
      queryAttrs['node'] = node;
      items = [];
      for (int i = 0; i < this._items.length; i++) {
        if (this._items[i]['node'] == node) {
          items = this._items[i]['call_back'](stanza);
          break;
        }
      }
    } else {
      items = this._items;
    }
    StanzaBuilder iqresult = this._buildIQResult(stanza, queryAttrs);
    for (int i = 0; i < items.length; i++) {
      Map<String, dynamic> attrs = {'jid': items[i].jid};
      if (items[i]['name'] != null) attrs['name'] = items[i].name;
      if (items[i].node) attrs['node'] = items[i].node;
      iqresult.c('item', attrs).up();
    }
    this.connection.send(iqresult.tree());
    return true;
  }
}
