import 'package:strophe/src/core.dart';
import 'package:strophe/src/enums.dart';
import 'package:strophe/src/plugins/plugins.dart';
import 'package:xml/xml/nodes/node.dart';

/** File: strophe.pubsub.js
 *  A Strophe plugin for XMPP Publish-Subscribe.
 *
 *  Provides Strophe.Connection.pubsub object,
 *  parially implementing XEP 0060.
 *
 *  Strophe.Builder.prototype methods should probably move to strophe.js
 */

class PubsubBuilder extends StanzaBuilder {
  PubsubBuilder(String name, [Map<String, dynamic> attrs]) : super(name, attrs);
  /** Function: Strophe.Builder.form
 *  Add an options form child element.
 *
 *  Does not change the current element.
 *
 *  Parameters:
 *    (String) ns - form namespace.
 *    (Object) options - form properties.
 *
 *  Returns:
 *    The Strophe.Builder object.
 */
  form(String ns, Map<String, dynamic> options) {
    XmlNode xmlElement = Strophe
        .xmlElement('x', attrs: {"xmlns": "jabber:x:data", "type": "submit"});
    PubsubBuilder aX = this.cnode(xmlElement);
    aX
        .cnode(Strophe
            .xmlElement('field', attrs: {"var": "FORM_TYPE", "type": "hidden"}))
        .cnode(Strophe.xmlElement('value'))
        .t(ns)
        .up()
        .up();
    options.forEach((String key, value) {
      aX
          .cnode(Strophe.xmlElement('field', attrs: {"var": key}))
          .cnode(Strophe.xmlElement('value'))
          .t(options[key].toString())
          .up()
          .up();
    });
    return this;
  }

/** Function: Strophe.Builder.list
 *  Add many child elements.
 *
 *  Does not change the current element.
 *
 *  Parameters:
 *    (String) tag - tag name for children.
 *    (Array) array - list of objects with format:
 *          { attrs: { [string]:[string], ... } // attributes of each tag element
 *             data: [string | XML_element] }    // contents of each tag element
 *
 *  Returns:
 *    The Strophe.Builder object.
 */
  list(String tag, List<Map<String, dynamic>> array) {
    if (array == null) return this;
    for (int i = 0; i < array.length; ++i) {
      this.c(tag, array[i]['attrs']);
      if (array[i]['data'] == null) continue;
      if (array[i]['data'] is String) {
        this.cnode(Strophe.xmlElement('data',
            attrs: array[i]['attrs'], text: array[i]['data']));
      } else {
        var stanza = array[i]['data'];
        if (array[i]['data'] is StanzaBuilder) stanza = array[i]['data'].tree();
        this.cnode(Strophe.copyElement(stanza as XmlNode));
      }
      this.up();
    }
    return this;
  }

  @override
  PubsubBuilder c(String name, [Map<String, dynamic> attrs, dynamic text]) {
    return super.c(name, attrs, text) as PubsubBuilder;
  }

  children(Map object) {
    object.forEach((key, value) {
      if (value is List) {
        this.list(key, value);
      } else if (value is String) {
        this.c(key, {}, value);
      } else if (value is num) {
        this.c(key, {}, value.toString());
      } else if (value is Map) {
        this.c(key).children(value).up();
      } else {
        this.c(key).up();
      }
    });
    return this;
  }
}

class PubsubPlugin extends PluginClass {
  PubsubPlugin() {
    // Called by Strophe on connection event
    statusChanged = (status, condition) {
      if (this._autoService && status == Strophe.Status['CONNECTED']) {
        this.service =
            'pubsub.' + Strophe.getDomainFromJid(this.connection.jid);
        this.jid = this.connection.jid;
      }
    };
  }

// TODO Ideas Adding possible conf values?
/* Extend Strophe.Connection to have member 'pubsub'.
 */
/*
Extend connection object to have plugin name 'pubsub'.
*/
  bool _autoService = true;
  String service;
  String jid;
  Map<String, List<StanzaHandler>> handler = {};

  //The plugin must have the init function.
  init(StropheConnection conn) {
    this.connection = conn;

    /*
        Function used to setup plugin.
        */

    /* extend name space
        *  NS['PUBSUB'] - XMPP Publish Subscribe namespace
        *              from XEP 60.
        *
        *  NS.PUBSUB_SUBSCRIBE_OPTIONS - XMPP pubsub
        *                                options namespace from XEP 60.
        */
    Strophe.addNamespace('PUBSUB', "http://jabber.org/protocol/pubsub");
    Strophe.addNamespace('PUBSUB_SUBSCRIBE_OPTIONS',
        Strophe.NS['PUBSUB'] + "#subscribe_options");
    Strophe.addNamespace('PUBSUB_ERRORS', Strophe.NS['PUBSUB'] + "#errors");
    Strophe.addNamespace('PUBSUB_EVENT', Strophe.NS['PUBSUB'] + "#event");
    Strophe.addNamespace('PUBSUB_OWNER', Strophe.NS['PUBSUB'] + "#owner");
    Strophe.addNamespace(
        'PUBSUB_AUTO_CREATE', Strophe.NS['PUBSUB'] + "#auto-create");
    Strophe.addNamespace(
        'PUBSUB_PUBLISH_OPTIONS', Strophe.NS['PUBSUB'] + "#publish-options");
    Strophe.addNamespace(
        'PUBSUB_NODE_CONFIG', Strophe.NS['PUBSUB'] + "#node_config");
    Strophe.addNamespace('PUBSUB_CREATE_AND_CONFIGURE',
        Strophe.NS['PUBSUB'] + "#create-and-configure");
    Strophe.addNamespace('PUBSUB_SUBSCRIBE_AUTHORIZATION',
        Strophe.NS['PUBSUB'] + "#subscribe_authorization");
    Strophe.addNamespace(
        'PUBSUB_GET_PENDING', Strophe.NS['PUBSUB'] + "#get-pending");
    Strophe.addNamespace('PUBSUB_MANAGE_SUBSCRIPTIONS',
        Strophe.NS['PUBSUB'] + "#manage-subscriptions");
    Strophe.addNamespace(
        'PUBSUB_META_DATA', Strophe.NS['PUBSUB'] + "#meta-data");
    Strophe.addNamespace('ATOM', "http://www.w3.org/2005/Atom");

    if (conn.disco != null) conn.disco.addFeature(Strophe.NS['PUBSUB']);
  }

  /***Function
    Parameters:
    (String) jid - The node owner's jid.
    (String) service - The name of the pubsub service.
    */
  connect(String jid, [String service]) {
    if (service == null) {
      service = jid;
      jid = null;
    }
    this.jid = jid ?? this.connection.jid;
    this.service = service ?? null;
    this._autoService = false;
  }

  /***Function
     Parameters:
     (String) node - The name of node
     (String) handler - reference to registered strophe handler
     */
  storeHandler(String node, StanzaHandler handler) {
    if (this.handler[node] == null) {
      this.handler[node] = [];
    }
    this.handler[node].add(handler);
  }

  /***Function
     Parameters:
     (String) node - The name of node
     */
  removeHandler(String node) {
    List<StanzaHandler> toberemoved = this.handler[node];
    this.handler[node] = [];

    // remove handler
    if (toberemoved != null && toberemoved.length > 0) {
      for (int i = 0, l = toberemoved.length; i < l; i++) {
        this.connection.deleteHandler(toberemoved[i]);
      }
    }
  }

  /***Function
    Create a pubsub node on the given service with the given node
    name.
    Parameters:
    (String) node -  The name of the pubsub node.
    (Dictionary) options -  The configuration options for the  node.
    (Function) call_back - Used to determine if node
    creation was sucessful.
    Returns:
    Iq id used to send subscription.
    */
  createNode(String node,
      [String service, Map<String, dynamic> options, Function callback]) {
    String iqid = this.connection.getUniqueId("pubsubcreatenode");
    service = service != null && service.isNotEmpty ? service : this.service;
    PubsubBuilder iq = new PubsubBuilder('iq', {
      'from': Strophe.getBareJidFromJid(this.jid),
      'to': service,
      'type': 'set',
      'id': iqid
    }).c('pubsub', {'xmlns': Strophe.NS['PUBSUB']}).c(
        'create', node != null ? {'node': node} : null);
    if (options != null) {
      iq = iq.up().c('configure');
      iq.form(Strophe.NS['PUBSUB_NODE_CONFIG'], options);
    }
    if (callback != null)
      this.connection.addHandler(callback, null, 'iq', null, iqid, null);
    this.connection.send(iq.tree());
    return iqid;
  }

  /** Function: deleteNode
     *  Delete a pubsub node.
     *
     *  Parameters:
     *    (String) node -  The name of the pubsub node.
     *    (Function) call_back - Called on server response.
     *
     *  Returns:
     *    Iq id
     */
  deleteNode(String node, [Function callback]) {
    String iqid = this.connection.getUniqueId("pubsubdeletenode");

    StanzaBuilder iq = Strophe.$iq({
      'from': this.jid,
      'to': this.service,
      'type': 'set',
      'id': iqid
    }).c('pubsub', {'xmlns': Strophe.NS['PUBSUB_OWNER']}).c(
        'delete', {'node': node});

    this.connection.addHandler(callback, null, 'iq', null, iqid, null);
    this.connection.send(iq.tree());

    return iqid;
  }

  /** Function
     *
     * Get all nodes this.connection currently exist.
     *
     * Parameters:
     *   (Function) success - Used to determine if node creation was sucessful.
     *   (Function) error - Used to determine if node
     * creation had errors.
     */
  discoverNodes(
      [String service, Function success, Function error, int timeout]) {
    //ask for all nodes
    service = service != null && service.isNotEmpty ? service : this.service;
    StanzaBuilder iq = Strophe
        .$iq({'from': this.jid, 'to': service, 'type': 'get'}).c(
            'query', {'xmlns': Strophe.NS['DISCO_ITEMS']});

    return this.connection.sendIQ(iq.tree(), success, error, timeout);
  }

  /** Function: getConfig
     *  Get node configuration form.
     *
     *  Parameters:
     *    (String) node -  The name of the pubsub node.
     *    (Function) call_back - Receives config form.
     *
     *  Returns:
     *    Iq id
     */
  getConfig(String node, Function callback) {
    String iqid = this.connection.getUniqueId("pubsubconfigurenode");

    StanzaBuilder iq = Strophe.$iq({
      'from': this.jid,
      'to': this.service,
      'type': 'get',
      'id': iqid
    }).c('pubsub', {'xmlns': Strophe.NS['PUBSUB_OWNER']}).c(
        'configure', {'node': node});

    this.connection.addHandler(callback, null, 'iq', null, iqid, null);
    this.connection.send(iq.tree());

    return iqid;
  }

  /**
     *  Parameters:
     *    (Function) call_back - Receives subscriptions.
     *
     *  http://xmpp.org/extensions/tmp/xep-0060-1.13.html
     *  8.3 Request Default Node Configuration Options
     *
     *  Returns:
     *    Iq id
     */
  String getDefaultNodeConfig(Function callback) {
    String iqid = this.connection.getUniqueId("pubsubdefaultnodeconfig");

    StanzaBuilder iq = Strophe.$iq({
      'from': this.jid,
      'to': this.service,
      'type': 'get',
      'id': iqid
    }).c('pubsub', {'xmlns': Strophe.NS['PUBSUB_OWNER']}).c('default');

    this.connection.addHandler(callback, null, 'iq', null, iqid, null);
    this.connection.send(iq.tree());

    return iqid;
  }

  /***Function
        Subscribe to a node in order to receive event items.
        Parameters:
        (String) node         - The name of the pubsub node.
        (Array) options       - The configuration options for the  node.
        (Function) event_cb   - Used to recieve subscription events.
        (Function) success    - callback function for successful node creation.
        (Function) error      - error callback function.
        (Boolean) barejid     - use barejid creation was sucessful.
        Returns:
        Iq id used to send subscription.
    */
  subscribe(String node,
      [String service,
      Map<String, dynamic> options,
      Function eventcb,
      Function success,
      Function error,
      bool barejid = true]) {
    String iqid = this.connection.getUniqueId("subscribenode");

    String jid = this.jid;
    if (barejid) jid = Strophe.getBareJidFromJid(jid);
    service = service != null && service.isNotEmpty ? service : this.service;
    PubsubBuilder iq = new PubsubBuilder(
            'iq', {'from': this.jid, 'to': service, 'type': 'set', 'id': iqid})
        .c('pubsub', {'xmlns': Strophe.NS['PUBSUB']}).c(
            'subscribe', {'node': node, 'jid': jid});
    if (options != null) {
      PubsubBuilder c = iq.up().c('options');

      c.form(Strophe.NS['PUBSUB_SUBSCRIBE_OPTIONS'], options);
    }

    //add the event handler to receive items
    StanzaHandler hand =
        this.connection.addHandler(eventcb, null, 'message', null, null, null);
    this.storeHandler(node, hand);
    this.connection.sendIQ(iq.tree(), success, error);
    return iqid;
  }

  /***Function
        Unsubscribe from a node.
        Parameters:
        (String) node       - The name of the pubsub node.
        (Function) success  - callback function for successful node creation.
        (Function) error    - error callback function.
    */
  unsubscribe(String node, String jid,
      [String service, String subid, Function success, Function error]) {
    String iqid = this.connection.getUniqueId("pubsubunsubscribenode");
    service = service != null && service.isNotEmpty ? service : this.service;
    StanzaBuilder iq = Strophe
        .$iq({'from': this.jid, 'to': service, 'type': 'set', 'id': iqid}).c(
            'pubsub', {'xmlns': Strophe.NS['PUBSUB']}).c('unsubscribe', {
      'node': node,
      'jid': jid ?? Strophe.getBareJidFromJid(connection.jid)
    });
    if (subid != null && subid.isNotEmpty) iq.attrs({'subid': subid});

    this.connection.sendIQ(iq.tree(), success, error);
    this.removeHandler(node);
    return iqid;
  }

  /***Function
    Publish and item to the given pubsub node.
    Parameters:
    (String) node -  The name of the pubsub node.
    (Array) items -  The list of items to be published.
    (Function) call_back - Used to determine if node
    creation was sucessful.
    */
  String publish(
      String node, List<Map<String, dynamic>> items, Function callback) {
    String iqid = this.connection.getUniqueId("pubsubpublishnode");

    PubsubBuilder iq = new PubsubBuilder('iq', {
      'from': this.jid,
      'to': this.service,
      'type': 'set',
      'id': iqid
    }).c('pubsub', {'xmlns': Strophe.NS['PUBSUB']}).c(
        'publish', {'node': node, 'jid': this.jid});
    iq.list('item', items);

    this.connection.addHandler(callback, null, 'iq', null, iqid, null);
    this.connection.send(iq.tree());

    return iqid;
  }

  /*Function: items
    Used to retrieve the persistent items from the pubsub node.
    */
  String items(String node, [Function success, Function error, int timeout]) {
    //ask for all items
    StanzaBuilder iq = Strophe
        .$iq({'from': this.jid, 'to': this.service, 'type': 'get'}).c('pubsub',
            {'xmlns': Strophe.NS['PUBSUB']}).c('items', {'node': node});

    return this.connection.sendIQ(iq.tree(), success, error, timeout);
  }

  /** Function: getSubscriptions
     *  Get subscriptions of a JID.
     *
     *  Parameters:
     *    (Function) call_back - Receives subscriptions.
     *
     *  http://xmpp.org/extensions/tmp/xep-0060-1.13.html
     *  5.6 Retrieve Subscriptions
     *
     *  Returns:
     *    Iq id
     */
  getSubscriptions(Function callback) {
    String iqid = this.connection.getUniqueId("pubsubsubscriptions");

    StanzaBuilder iq = Strophe.$iq({
      'from': this.jid,
      'to': this.service,
      'type': 'get',
      'id': iqid
    }).c('pubsub', {'xmlns': Strophe.NS['PUBSUB']}).c('subscriptions');

    this.connection.addHandler(callback, null, 'iq', null, iqid, null);
    this.connection.send(iq.tree());

    return iqid;
  }

  /** Function: getNodeSubscriptions
     *  Get node subscriptions of a JID.
     *
     *  Parameters:
     *    (Function) call_back - Receives subscriptions.
     *
     *  http://xmpp.org/extensions/tmp/xep-0060-1.13.html
     *  5.6 Retrieve Subscriptions
     *
     *  Returns:
     *    Iq id
     */
  getNodeSubscriptions(String node, Function callback) {
    String iqid = this.connection.getUniqueId("pubsubsubscriptions");

    StanzaBuilder iq = Strophe.$iq({
      'from': this.jid,
      'to': this.service,
      'type': 'get',
      'id': iqid
    }).c('pubsub', {'xmlns': Strophe.NS['PUBSUB_OWNER']}).c(
        'subscriptions', {'node': node});

    this.connection.addHandler(callback, null, 'iq', null, iqid, null);
    this.connection.send(iq.tree());

    return iqid;
  }

  /** Function: getSubOptions
     *  Get subscription options form.
     *
     *  Parameters:
     *    (String) node -  The name of the pubsub node.
     *    (String) subid - The subscription id (optional).
     *    (Function) call_back - Receives options form.
     *
     *  Returns:
     *    Iq id
     */
  getSubOptions(String node, String subid, Function callback) {
    String iqid = this.connection.getUniqueId("pubsubsuboptions");

    StanzaBuilder iq = Strophe.$iq({
      'from': this.jid,
      'to': this.service,
      'type': 'get',
      'id': iqid
    }).c('pubsub', {'xmlns': Strophe.NS['PUBSUB']}).c(
        'options', {'node': node, 'jid': this.jid});
    if (subid != null && subid.isNotEmpty) iq.attrs({'subid': subid});

    this.connection.addHandler(callback, null, 'iq', null, iqid, null);
    this.connection.send(iq.tree());

    return iqid;
  }

  /**
     *  Parameters:
     *    (String) node -  The name of the pubsub node.
     *    (Function) call_back - Receives subscriptions.
     *
     *  http://xmpp.org/extensions/tmp/xep-0060-1.13.html
     *  8.9 Manage Affiliations - 8.9.1.1 Request
     *
     *  Returns:
     *    Iq id
     */
  getAffiliations(String node, Function callback) {
    String iqid = this.connection.getUniqueId("pubsubaffiliations");

    Map<String, String> attrs = {}, xmlns = {'xmlns': Strophe.NS['PUBSUB']};
    if (node != null && node.isNotEmpty) {
      attrs['node'] = node;
      xmlns = {'xmlns': Strophe.NS['PUBSUB_OWNER']};
    }

    StanzaBuilder iq = Strophe
        .$iq({'from': this.jid, 'to': this.service, 'type': 'get', 'id': iqid})
        .c('pubsub', xmlns)
        .c('affiliations', attrs);

    this.connection.addHandler(callback, null, 'iq', null, iqid, null);
    this.connection.send(iq.tree());

    return iqid;
  }

  /**
     *  Parameters:
     *    (String) node -  The name of the pubsub node.
     *    (Function) call_back - Receives subscriptions.
     *
     *  http://xmpp.org/extensions/tmp/xep-0060-1.13.html
     *  8.9.2 Modify Affiliation - 8.9.2.1 Request
     *
     *  Returns:
     *    Iq id
     */
  setAffiliation(
      String node, String jid, String affiliation, Function callback) {
    String iqid = this.connection.getUniqueId("pubsubaffiliations");

    StanzaBuilder iq = Strophe.$iq({
      'from': this.jid,
      'to': this.service,
      'type': 'set',
      'id': iqid
    }).c('pubsub', {'xmlns': Strophe.NS['PUBSUB_OWNER']}).c('affiliations', {
      'node': node
    }).c('affiliation', {'jid': jid, 'affiliation': affiliation});

    this.connection.addHandler(callback, null, 'iq', null, iqid, null);
    this.connection.send(iq.tree());

    return iqid;
  }

  /** Function: publishAtom
     */
  publishAtom(String node, List atoms, Function callback) {
    Map<String, dynamic> atom;
    List<Map<String, dynamic>> entries = [];
    for (int i = 0; i < atoms.length; i++) {
      atom = atoms[i];

      atom['updated'] = atom['updated'] ?? new DateTime.now().toIso8601String();
      if (atom['published'] && atom['published'].toIso8601String())
        atom['published'] = atom['published'].toIso8601String();
      PubsubBuilder data =
          Strophe.$build("entry", {'xmlns': Strophe.NS['ATOM']});
      entries.add({
        'data': data.children(atom).tree(),
        'attrs': atom['id'] ? {'id': atom['id']} : {},
      });
    }
    return this.publish(node, entries, callback);
  }
}
