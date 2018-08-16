import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:strophe/src/bosh.dart';
import 'package:strophe/src/core.dart';
import 'package:strophe/src/md5.dart';
import 'package:strophe/src/plugins/administration.dart';
import 'package:strophe/src/plugins/bookmark.dart';
import 'package:strophe/src/plugins/caps.dart';
import 'package:strophe/src/plugins/chat-notifications.dart';
import 'package:strophe/src/plugins/disco.dart';
import 'package:strophe/src/plugins/last-activity.dart';
import 'package:strophe/src/plugins/muc.dart';
import 'package:strophe/src/plugins/pep.dart';
import 'package:strophe/src/plugins/plugins.dart';
import 'package:strophe/src/plugins/privacy.dart';
import 'package:strophe/src/plugins/private-storage.dart';
import 'package:strophe/src/plugins/pubsub.dart';
import 'package:strophe/src/plugins/register.dart';
import 'package:strophe/src/plugins/roster.dart';
import 'package:strophe/src/plugins/vcard-temp.dart';
import 'package:strophe/src/sessionstorage.dart';
import 'package:strophe/src/sha1.dart';
import 'package:strophe/src/utils.dart';
import 'package:xml/xml.dart' as xml;

Map<String, int> ConnexionStatus = {
  'ERROR': 0,
  'CONNECTING': 1,
  'CONNFAIL': 2,
  "AUTHENTICATING": 3,
  "AUTHFAIL": 4,
  "CONNECTED": 5,
  "DISCONNECTED": 6,
  "DISCONNECTING": 7,
  "ATTACHED": 8,
  "REDIRECT": 9,
  "CONNTIMEOUT": 10
};
Map<String, String> NAMESPACE = {
  'HTTPBIND': "http://jabber.org/protocol/httpbind",
  'BOSH': "urn:xmpp:xbosh",
  'CLIENT': "jabber:client",
  'AUTH': "jabber:iq:auth",
  'ROSTER': "jabber:iq:roster",
  'PROFILE': "jabber:iq:profile",
  'DISCO_INFO': "http://jabber.org/protocol/disco#info",
  'DISCO_ITEMS': "http://jabber.org/protocol/disco#items",
  'MUC': "http://jabber.org/protocol/muc",
  'SASL': "urn:ietf:params:xml:ns:xmpp-sasl",
  'STREAM': "http://etherx.jabber.org/streams",
  'FRAMING': "urn:ietf:params:xml:ns:xmpp-framing",
  'BIND': "urn:ietf:params:xml:ns:xmpp-bind",
  'SESSION': "urn:ietf:params:xml:ns:xmpp-session",
  'VERSION': "jabber:iq:version",
  'STANZAS': "urn:ietf:params:xml:ns:xmpp-stanzas",
  'XHTML_IM': "http://jabber.org/protocol/xhtml-im",
  'XHTML': "http://www.w3.org/1999/xhtml"
};
const Map<String, String> ERRORSCONDITIONS = const {
  'BAD_FORMAT': "bad-format",
  'CONFLICT': "conflict",
  'MISSING_JID_NODE': "x-strophe-bad-non-anon-jid",
  'NO_AUTH_MECH': "no-auth-mech",
  'UNKNOWN_REASON': "unknown",
};
const Map<String, int> LOGLEVEL = const {
  'DEBUG': 0,
  'INFO': 1,
  'WARN': 2,
  'ERROR': 3,
  'FATAL': 4
};
const Map<String, int> ELEMENTTYPE = const {
  'NORMAL': 1,
  'TEXT': 3,
  'CDATA': 4,
  'FRAGMENT': 11
};

class StanzaBuilder {
  List<int> node = [];
  xml.XmlNode nodeTree;
  StanzaBuilder(String name, [Map<String, dynamic> attrs]) {
    // Set correct namespace for jabber:client elements
    if (name == "presence" || name == "message" || name == "iq") {
      if (attrs != null && attrs['xmlns'] == null) {
        attrs['xmlns'] = Strophe.NS['CLIENT'];
      } else if (attrs == null) {
        attrs = {'xmlns': Strophe.NS['CLIENT']};
      }
    }

    // Holds the tree being built.
    this.nodeTree = Strophe.xmlElement(name, attrs: attrs);

    // Points to the current operation node.
    this.node = [0];
  }

  /** Function: tree
     *  Return the DOM tree.
     *
     *  This function returns the current DOM tree as an element object.  This
     *  is suitable for passing to functions like Strophe.Connection.send().
     *
     *  Returns:
     *    The DOM tree as a element object.
     */
  xml.XmlElement tree() {
    if (this.nodeTree is xml.XmlDocument) {
      xml.XmlDocument doc = this.nodeTree as xml.XmlDocument;
      return doc.rootElement;
    }
    return this.nodeTree;
  }

  xml.XmlElement get currentNode {
    xml.XmlNode _currentNode = this.nodeTree.children[0];
    for (int i = 1; i < this.node.length; i++) {
      _currentNode = _currentNode.children[this.node[i]];
    }
    return _currentNode is xml.XmlDocument
        ? _currentNode.rootElement
        : _currentNode as xml.XmlElement;
  }

  /** Function: toString
     *  Serialize the DOM tree to a String.
     *
     *  This function returns a string serialization of the current DOM
     *  tree.  It is often used internally to pass data to a
     *  Strophe.Request object.
     *
     *  Returns:
     *    The serialized DOM tree in a String.
     */
  String toString() {
    return Strophe.serialize(this.nodeTree);
  }

  /** Function: up
     *  Make the current parent element the new current element.
     *
     *  This function is often used after c() to traverse back up the tree.
     *  For example, to add two children to the same element
     *  > builder.c('child1', {}).up().c('child2', {});
     *
     *  Returns:
     *    The Stophe.Builder object.
     */
  StanzaBuilder up() {
    if (this.node.length > 0) this.node.removeLast();
    return this;
  }

  /** Function: root
     *  Make the root element the new current element.
     *
     *  When at a deeply nested element in the tree, this function can be used
     *  to jump back to the root of the tree, instead of having to repeatedly
     *  call up().
     *
     *  Returns:
     *    The Stophe.Builder object.
     */
  StanzaBuilder root() {
    this.node = [];
    this.nodeTree = this.nodeTree.root;
    return this;
  }

  /** Function: attrs
     *  Add or modify attributes of the current element.
     *
     *  The attributes should be passed in object notation.  This function
     *  does not move the current element pointer.
     *
     *  Parameters:
     *    (Object) moreattrs - The attributes to add/modify in object notation.
     *
     *  Returns:
     *    The Strophe.Builder object.
     */
  StanzaBuilder attrs(Map<String, dynamic> moreattrs) {
    moreattrs.forEach((String key, dynamic value) {
      if (value == null || value.isEmpty) {
        this
            .nodeTree
            .firstChild
            .attributes
            .removeWhere((xml.XmlAttribute attr) {
          return attr.name.qualified == key;
        });
      } else {
        this
            .nodeTree
            .firstChild
            .attributes
            .add(new xml.XmlAttribute(new xml.XmlName.fromString(key), value));
      }
    });
    return this;
  }

  /** Function: c
     *  Add a child to the current element and make it the new current
     *  element.
     *
     *  This function moves the current element pointer to the child,
     *  unless text is provided.  If you need to add another child, it
     *  is necessary to use up() to go back to the parent in the tree.
     *
     *  Parameters:
     *    (String) name - The name of the child.
     *    (Object) attrs - The attributes of the child in object notation.
     *    (String) text - The text to add to the child.
     *
     *  Returns:
     *    The Strophe.Builder object.
     */
  StanzaBuilder c(String name, [Map<String, dynamic> attrs, dynamic text]) {
    xml.XmlNode child = Strophe.xmlElement(name, attrs: attrs, text: text);
    xml.XmlElement xmlElement = child is xml.XmlDocument
        ? child.rootElement
        : (child as xml.XmlElement);

    xml.XmlNode currentNode = this.nodeTree.children[0];
    for (int i = 1; i < this.node.length; i++) {
      currentNode = currentNode.children[this.node[i]];
    }
    currentNode.children.add(Strophe.copyElement(xmlElement));
    this.node.add(currentNode.children.length - 1);
    return this;
  }

  /** Function: cnode
     *  Add a child to the current element and make it the new current
     *  element.
     *
     *  This function is the same as c() except this instead of using a
     *  name and an attributes object to create the child it uses an
     *  existing DOM element object.
     *
     *  Parameters:
     *    (XMLElement) elem - A DOM element.
     *
     *  Returns:
     *    The Strophe.Builder object.
     */
  StanzaBuilder cnode(xml.XmlNode elem) {
    xml.XmlNode newElem = Strophe.copyElement(elem);
    xml.XmlNode currentNode = this.nodeTree.children[0];
    for (int i = 1; i < this.node.length; i++) {
      currentNode = currentNode.children[this.node[i]];
    }
    if (newElem != null) currentNode.children.add(Strophe.copyElement(newElem));
    this.node.add(currentNode.children.length - 1);
    return this;
  }

  /** Function: t
     *  Add a child text element.
     *
     *  This *does not* make the child the new current element since there
     *  are no children of text elements.
     *
     *  Parameters:
     *    (String) text - The text data to append to the current element.
     *
     *  Returns:
     *    The Strophe.Builder object.
     */
  StanzaBuilder t(String text) {
    xml.XmlNode currentNode = this.nodeTree.children[0];
    for (int i = 1; i < this.node.length; i++) {
      currentNode = currentNode.children[this.node[i]];
    }
    currentNode.children.add(Strophe.copyElement(new xml.XmlText(text ?? '')));
    return this;
  }

  /** Function: h
     *  Replace current element contents with the HTML passed in.
     *
     *  This *does not* make the child the new current element
     *
     *  Parameters:
     *    (String) html - The html to insert as contents of current element.
     *
     *  Returns:
     *    The Strophe.Builder object.
     */
  StanzaBuilder h(String html) {
    xml.XmlNode fragment = Strophe.xmlElement('body');

    // force the browser to try and fix any invalid HTML tags
    fragment.children.add(Strophe.xmlTextNode(html));

    // copy cleaned html into an xml dom
    xml.XmlNode xhtml = Strophe.createHtml(fragment);
    xml.XmlNode currentNode = this.nodeTree.children[0];
    for (int i = 1; i < this.node.length; i++) {
      currentNode = currentNode.children[this.node[i]];
    }
    currentNode.children.add(Strophe.copyElement(xhtml));
    return this;
  }
}

class StanzaHandler {
  String from;
  // whether the handler is a user handler or a system handler
  bool user;
  Function handler;
  String ns;
  String name;
  List<String> type; // String or List
  String id;
  Map options;
  StanzaHandler(
      this.handler, this.ns, this.name, ptype, this.id, this.options) {
    this.type = ptype is List ? ptype : [ptype];
  }

/** PrivateFunction: getNamespace
     *  Returns the XML namespace attribute on an element.
     *  If `ignoreNamespaceFragment` was passed in for this handler, then the
     *  URL fragment will be stripped.
     *
     *  Parameters:
     *    (XMLElement) elem - The XML element with the namespace.
     *
     *  Returns:
     *    The namespace, with optionally the fragment stripped.
     */

  String getNamespace(xml.XmlNode node) {
    xml.XmlElement elem =
        node is xml.XmlDocument ? node.rootElement : node as xml.XmlElement;
    String elNamespace = elem.getAttribute("xmlns") ?? '';
    if (elNamespace != null &&
        elNamespace.isNotEmpty &&
        this.options['ignoreNamespaceFragment']) {
      elNamespace = elNamespace.split('#')[0];
    }
    return elNamespace;
  }

  /** PrivateFunction: namespaceMatch
     *  Tests if a stanza matches the namespace set for this Strophe.Handler.
     *
     *  Parameters:
     *    (XMLElement) elem - The XML element to test.
     *
     *  Returns:
     *    true if the stanza matches and false otherwise.
     */
  bool namespaceMatch(xml.XmlNode elem) {
    bool nsMatch = false;
    if (this.ns == null || this.ns.isEmpty) {
      return true;
    } else {
      Strophe.forEachChild(elem, null, (child) {
        if (this.getNamespace(child) == this.ns) {
          nsMatch = true;
        }
      });
      nsMatch = nsMatch || this.getNamespace(elem) == this.ns;
    }
    return nsMatch;
  }

  /** PrivateFunction: isMatch
     *  Tests if a stanza matches the Strophe.Handler.
     *
     *  Parameters:
     *    (XMLElement) elem - The XML element to test.
     *
     *  Returns:
     *    true if the stanza matches and false otherwise.
     */
  bool isMatch(xml.XmlNode node) {
    xml.XmlElement elem =
        node is xml.XmlDocument ? node.rootElement : node as xml.XmlElement;
    String from = elem.getAttribute("from");
    if (this.options['matchBareFromJid']) {
      from = Strophe.getBareJidFromJid(from);
    }
    bool withId = false;

    String id = elem.getAttribute("id");
    if (this.options['endsWithId'] == true) {
      withId = (id ?? '').endsWith(this.id);
    }
    if (this.options['startsWithId'] == true) {
      withId = (id ?? '').startsWith(this.id);
    }

    String elemType = elem.getAttribute("type");
    bool statement = this.type.indexOf(elemType) != -1;
    if (this.namespaceMatch(elem) &&
        (this.name == null || Strophe.isTagEqual(elem, this.name)) &&
        (this.type == null || this.type.contains(null) || statement) &&
        (this.id == null || id == this.id || withId) &&
        (this.from == null || from == this.from)) {
      return true;
    }
    return false;
  }

  /** PrivateFunction: run
     *  Run the callback on a matching stanza.
     *
     *  Parameters:
     *    (XMLElement) elem - The DOM element this triggered the
     *      Strophe.Handler.
     *
     *  Returns:
     *    A boolean indicating if the handler should remain active.
     */
  bool run(xml.XmlNode elem) {
    bool result = false;
    if (this.handler == null) return false;
    try {
      var handResult = this.handler(elem);
      if (handResult == null || handResult == true) result = true;
    } catch (e) {
      Strophe.handleError(e);
      throw e;
    }
    return result;
  }

  /** PrivateFunction: toString
     *  Get a String representation of the Strophe.Handler object.
     *
     *  Returns:
     *    A String.
     */
  String toString() {
    return "{Handler: " +
        this.handler.toString() +
        "(" +
        this.name +
        "," +
        this.id +
        "," +
        this.ns +
        ")}";
  }
}

class StanzaTimedHandler {
  bool user = true;
  int lastCalled;
  int period;
  Function handler;

  StanzaTimedHandler(int period, Function handler) {
    this.period = period;
    this.handler = handler;
    this.lastCalled = new DateTime.now().millisecondsSinceEpoch;
  }
  /** PrivateFunction: run
     *  Run the callback for the Strophe.TimedHandler.
     *
     *  Returns:
     *    true if the Strophe.TimedHandler should be called again, and false
     *      otherwise.
     */
  bool run() {
    this.lastCalled = new DateTime.now().millisecondsSinceEpoch;
    return this.handler();
  }

  /** PrivateFunction: reset
     *  Reset the last called time for the Strophe.TimedHandler.
     */
  void reset() {
    this.lastCalled = new DateTime.now().millisecondsSinceEpoch;
  }

  /** PrivateFunction: toString
     *  Get a string representation of the Strophe.TimedHandler object.
     *
     *  Returns:
     *    The string representation.
     */
  String toString() {
    return "{TimedHandler: " +
        this.handler.toString() +
        "(" +
        this.period.toString() +
        ")}";
  }
}

class StropheConnection {
  String service;
  String pass;
  String authcid;
  String authzid;
  String servtype;
  Map<String, dynamic> options;

  String jid;

  ServiceType _proto;

  String domain;

  xml.XmlElement features;

  Map<String, dynamic> _saslData;

  bool doSession = false;

  bool doBind = false;

  Function _startConnection;

  Function _attachConnection;
  RegisterPlugin get register {
    return Strophe.connectionPlugins['register'];
  }

  DiscoPlugin get disco {
    return Strophe.connectionPlugins['disco'];
  }

  RosterPlugin get roster {
    return Strophe.connectionPlugins['roster'];
  }

  AdministrationPlugin get admin {
    return Strophe.connectionPlugins['admin'];
  }

  CapsPlugin get caps {
    return Strophe.connectionPlugins['caps'];
  }

  MucPlugin get muc {
    return Strophe.connectionPlugins['muc'];
  }

  BookMarkPlugin get bookmarks {
    return Strophe.connectionPlugins['bookmarks'];
  }

  LastActivity get lastactivity {
    return Strophe.connectionPlugins['lastactivity'];
  }

  PepPlugin get pep {
    return Strophe.connectionPlugins['pep'];
  }

  PrivacyPlugin get privacy {
    return Strophe.connectionPlugins['privacy'];
  }

  PubsubPlugin get pubsub {
    return Strophe.connectionPlugins['pubsub'];
  }

  PrivateStorage get private {
    return Strophe.connectionPlugins['private'];
  }

  VCardTemp get vcard {
    return Strophe.connectionPlugins['vcard'];
  }

  ChatStatesNotificationPlugin get chatstates {
    return Strophe.connectionPlugins['chatstates'];
  }

  List<StanzaTimedHandler> timedHandlers;

  List<StanzaHandler> handlers;

  List<StanzaTimedHandler> removeTimeds;

  List<StanzaHandler> removeHandlers;

  List<StanzaTimedHandler> addTimeds;

  Map<String, Map<int, Function>> protocolErrorHandlers;

  List<StanzaHandler> addHandlers;

  Timer _idleTimeout;

  StanzaTimedHandler _disconnectTimeout;

  bool authenticated = false;

  bool connected = false;

  bool disconnecting = false;

  bool doAuthentication = false;

  bool paused = false;

  bool restored = false;

  List<dynamic> _data;

  int _uniqueId;

  StanzaHandler _saslSuccessHandler;

  StanzaHandler _saslFailureHandler;

  StanzaHandler _saslChallengeHandler;

  int maxRetries;

  List<Cookie> cookies;

  List<StropheRequest> _requests;

  ConnectCallBack connectCallback;

  StropheSASLMechanism _saslMechanism;

  XmlInputCallback _xmlInputCallback = (xml.XmlElement elem) => {};

  XmlInputCallback _xmlOutputCallback = (xml.XmlElement elem) => {};

  RawInputCallback _rawInputCallback = (String elem) => {};
  RawInputCallback _connexionErrorInputCallback = (String error) => {};

  RawInputCallback _rawOutputCallback = (String elem) => {};

  // The service URL
  int get uniqueId {
    return this._uniqueId;
  }

  List get requests {
    return this._requests;
  }

  Function _reset;
  ConnexionCallback _connectCb;
  AuthenticateCallback _authenticate;
  StropheConnection(String service, [Map options]) {
    this.service = service;
    // Configuration options
    this.options = options ?? {};
    String proto = this.options['protocol'] ?? "";

    // Select protocal based on service or options
    if (service.indexOf("ws:") == 0 ||
        service.indexOf("wss:") == 0 ||
        proto.indexOf("ws") == 0) {
      this._proto = Strophe.Websocket(this);
    } else {
      this._proto = Strophe.Bosh(this);
    }
    /* The connected JID. */
    this.jid = "";
    /* the JIDs domain */
    this.domain = null;
    /* stream:features */
    this.features = null;

    // SASL
    this._saslData = {};
    this.doSession = false;
    this.doBind = false;

    // handler lists
    this.timedHandlers = [];
    this.handlers = [];
    this.removeTimeds = [];
    this.removeHandlers = [];
    this.addTimeds = [];
    this.addHandlers = [];
    this.protocolErrorHandlers = {'HTTP': {}, 'websocket': {}};
    this._idleTimeout = null;
    this._disconnectTimeout = null;

    this.authenticated = false;
    this.connected = false;
    this.disconnecting = false;
    this.doAuthentication = true;
    this.paused = false;
    this.restored = false;

    this._data = [];
    this._uniqueId = 0;

    this._saslSuccessHandler = null;
    this._saslFailureHandler = null;
    this._saslChallengeHandler = null;

    // Max retries before disconnecting
    this.maxRetries = 5;
    // Call onIdle callback every 1/10th of a second
    // XXX: setTimeout should be called only with function expressions (23974bc1)
    this._idleTimeout = new Timer(new Duration(milliseconds: 100), () {
      this._onIdle();
    });

    this.cookies = Utils.addCookies(this.options['cookies']);
    this.registerSASLMechanisms(this.options['mechanisms']);

    this.initializeFunction();
    this._startConnection = this._connect;
    this._attachConnection = this._attach;
    // initialize plugins
    Strophe.connectionPlugins.forEach((String key, PluginClass value) {
      Strophe.connectionPlugins[key].init(this);
    });
  }
  initializeFunction() {
    this._reset = () {
      this._proto.reset();

      // SASL
      this.doSession = false;
      this.doBind = false;

      // handler lists
      this.timedHandlers = [];
      this.handlers = [];
      this.removeTimeds = [];
      this.removeHandlers = [];
      this.addTimeds = [];
      this.addHandlers = [];

      this.authenticated = false;
      this.connected = false;
      this.disconnecting = false;
      this.restored = false;

      this._data = [];
      this._requests = [];
      this._uniqueId = 0;
    };
    this._connectCb = (req, Function _callback, String raw) {
      this.connected = true;

      xml.XmlElement bodyWrap;
      try {
        bodyWrap = this._proto.reqToData(req);
      } catch (e) {
        if (e.toString() != "badformat") {
          throw e;
        }
        this._changeConnectStatus(
            Strophe.Status['CONNFAIL'], Strophe.ErrorCondition['BAD_FORMAT']);
        this._doDisconnect(Strophe.ErrorCondition['BAD_FORMAT']);
      }
      if (bodyWrap == null) {
        return;
      }

      //if (this.xmlInput != Strophe.Connection.xmlInput) {
      if (bodyWrap.name.qualified == this._proto.strip &&
          bodyWrap.children.length > 0) {
        this.xmlInput(bodyWrap.firstChild);
      } else {
        this.xmlInput(bodyWrap);
      }
      //}
      //if (this.rawInput != Strophe.Connection.rawInput) {
      if (raw != null) {
        this.rawInput(raw);
      } else {
        this.rawInput(Strophe.serialize(bodyWrap));
      }
      //}

      int conncheck = this._proto.connectCb(bodyWrap);
      if (conncheck == Strophe.Status['CONNFAIL']) {
        return;
      }

      // Check for the stream:features tag
      bool hasFeatures;
      if (bodyWrap.getAttribute('xmlns') == Strophe.NS['STREAM']) {
        hasFeatures = bodyWrap.findAllElements("features").length > 0 ??
            bodyWrap.findAllElements("stream:features").length > 0;
      } else {
        hasFeatures = bodyWrap.findAllElements("stream:features").length > 0 ??
            bodyWrap.findAllElements("features").length > 0;
      }
      if (!hasFeatures) {
        this._noAuthReceived(_callback);
        return;
      }

      List<StropheSASLMechanism> matched = [];

      String mech;
      List<xml.XmlElement> mechanisms =
          bodyWrap.findAllElements("mechanism").toList();
      if (mechanisms.length > 0) {
        for (int i = 0; i < mechanisms.length; i++) {
          mech = Strophe.getText(mechanisms.elementAt(i));
          if (this.mechanisms[mech] != null) matched.add(this.mechanisms[mech]);
        }
      }
      if (matched.length == 0) {
        if (bodyWrap.findAllElements("auth").length == 0) {
          // There are no matching SASL mechanisms and also no legacy
          // auth available.
          this._noAuthReceived(_callback);
          return;
        }
      }
      if (this.doAuthentication != false) {
        this.authenticate(matched);
      }
    };
    this._authenticate = (List<StropheSASLMechanism> matched) {
      this._attemptSASLAuth(matched).then((bool result) {
        if (result != true) this._attemptLegacyAuth();
      });
    };
  }

  addConnectionPlugin(String name, PluginClass ptype) {
    Strophe.addConnectionPlugin(name, ptype);
  }

  ServiceType get proto {
    return this._proto;
  }

  set proto(ServiceType pro) {
    this._proto = pro;
  }

  List<dynamic> get data {
    return this._data;
  }

  set data(data) {
    this._data = data;
  }

  Timer get idleTimeout {
    return this._idleTimeout;
  }

  set idleTimeout(Timer newTimeout) {
    this._idleTimeout = newTimeout;
  }

  /** Function: reset
     *  Reset the connection.
     *
     *  This function should be called after a connection is disconnected
     *  before this connection is reused.
     */
  set reset(Function callback) {
    this._reset = callback;
  }

  Function get reset {
    if (_reset == null) initializeFunction();
    return this._reset;
  }

  /** Function: pause
     *  Pause the request manager.
     *
     *  This will prevent Strophe from sending any more requests to the
     *  server.  This is very useful for temporarily pausing
     *  BOSH-Connections while a lot of send() calls are happening quickly.
     *  This causes Strophe to send the data in a single request, saving
     *  many request trips.
     */
  pause() {
    this.paused = true;
  }

  /** Function: resume
     *  Resume the request manager.
     *
     *  This resumes after pause() has been called.
     */
  resume() {
    this.paused = false;
  }
  /** Function: getUniqueId
     *  Generate a unique ID for use in <iq/> elements.
     *
     *  All <iq/> stanzas are required to have unique id attributes.  This
     *  function makes creating these easy.  Each connection instance has
     *  a counter which starts from zero, and the value of this counter
     *  plus a colon followed by the suffix becomes the unique id. If no
     *  suffix is supplied, the counter is used as the unique id.
     *
     *  Suffixes are used to make debugging easier when reading the stream
     *  data, and their use is recommended.  The counter resets to 0 for
     *  every new connection for the same reason.  For connections to the
     *  same server this authenticate the same way, all the ids should be
     *  the same, which makes it easy to see changes.  This is useful for
     *  automated testing as well.
     *
     *  Parameters:
     *    (String) suffix - A optional suffix to append to the id.
     *
     *  Returns:
     *    A unique string to be used for the id attribute.
     */

  String getUniqueId([String suffix]) {
    String uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
        .replaceAllMapped(new RegExp(r"[xy]"), (Match c) {
      int r = new Random().nextInt(16) | 0;
      int v = c.group(0) == 'x' ? r : r & 0x3 | 0x8;
      return v.toRadixString(16);
    });
    if (suffix != null) {
      return uuid + ":" + suffix;
    } else {
      return uuid + "";
    }
  }

  /** Function: addProtocolErrorHandler
     *  Register a handler function for when a protocol (websocker or HTTP)
     *  error occurs.
     *
     *  NOTE: Currently only HTTP errors for BOSH requests are handled.
     *  Patches this handle websocket errors would be very welcome.
     *
     *  Parameters:
     *    (String) protocol - 'HTTP' or 'websocket'
     *    (Integer) status_code - Error status code (e.g 500, 400 or 404)
     *    (Function) callback - Function this will fire on Http error
     *
     *  Example:
     *  function onError(err_code){
     *    //do stuff
     *  }
     *
     *  var conn = Strophe.connect('http://example.com/http-bind');
     *  conn.addProtocolErrorHandler('HTTP', 500, onError);
     *  // Triggers HTTP 500 error and onError handler will be called
     *  conn.connect('user_jid@incorrect_jabber_host', 'secret', onConnect);
     */
  addProtocolErrorHandler(String protocol, int statusCode, Function callback) {
    this.protocolErrorHandlers[protocol][statusCode] = callback;
  }

  /** Function: connect
     *  Starts the connection process.
     *
     *  As the connection process proceeds, the user supplied callback will
     *  be triggered multiple times with status updates.  The callback
     *  should take two arguments - the status code and the error condition.
     *
     *  The status code will be one of the values in the Strophe.Status
     *  constants.  The error condition will be one of the conditions
     *  defined in RFC 3920 or the condition 'strophe-parsererror'.
     *
     *  The Parameters _wait_, _hold_ and _route_ are optional and only relevant
     *  for BOSH connections. Please see XEP 124 for a more detailed explanation
     *  of the optional parameters.
     *
     *  Parameters:
     *    (String) jid - The user's JID.  This may be a bare JID,
     *      or a full JID.  If a node is not supplied, SASL OAUTHBEARER or
     *      SASL ANONYMOUS authentication will be attempted (OAUTHBEARER will
     *      process the provided password value as an access token).
     *    (String) pass - The user's password.
     *    (Function) callback - The connect callback function.
     *    (Integer) wait - The optional HTTPBIND wait value.  This is the
     *      time the server will wait before returning an empty result for
     *      a request.  The default setting of 60 seconds is recommended.
     *    (Integer) hold - The optional HTTPBIND hold value.  This is the
     *      number of connections the server will hold at one time.  This
     *      should almost always be set to 1 (the default).
     *    (String) route - The optional route value.
     *    (String) authcid - The optional alternative authentication identity
     *      (username) if intending to impersonate another user.
     *      When using the SASL-EXTERNAL authentication mechanism, for example
     *      with client certificates, then the authcid value is used to
     *      determine whether an authorization JID (authzid) should be sent to
     *      the server. The authzid should not be sent to the server if the
     *      authzid and authcid are the same. So to prevent it from being sent
     *      (for example when the JID is already contained in the client
     *      certificate), set authcid to this same JID. See XEP-178 for more
     *      details.
     */
  Function get connect {
    return this._startConnection ?? _connect;
  }

  set connect(Function value) {
    this._startConnection = value;
  }

  _connect(String jid, String pass, ConnectCallBack callback,
      [int wait, int hold, String route, String authcid]) {
    this.jid = jid;
    /** Variable: authzid
         *  Authorization identity.
         */
    this.authzid = Strophe.getBareJidFromJid(this.jid);

    /** Variable: authcid
         *  Authentication identity (User name).
         */
    this.authcid = authcid ?? Strophe.getNodeFromJid(this.jid);

    /** Variable: pass
         *  Authentication identity (User password).
         */

    this.pass = pass;

    /** Variable: servtype
         *  Digest MD5 compatibility.
         */

    this.servtype = "xmpp";

    this.connectCallback = callback;
    this.disconnecting = false;
    this.connected = false;
    this.authenticated = false;
    this.restored = false;

    // parse jid for domain
    this.domain = Strophe.getDomainFromJid(this.jid);

    this._changeConnectStatus(Strophe.Status['CONNECTING'], null);

    this._proto.connect(wait, hold, route);
  }

  /** Function: attach
     *  Attach to an already created and authenticated BOSH session.
     *
     *  This function is provided to allow Strophe to attach to BOSH
     *  sessions which have been created externally, perhaps by a Web
     *  application.  This is often used to support auto-login type features
     *  without putting user credentials into the page.
     *
     *  Parameters:
     *    (String) jid - The full JID this is bound by the session.
     *    (String) sid - The SID of the BOSH session.
     *    (String) rid - The current RID of the BOSH session.  This RID
     *      will be used by the next request.
     *    (Function) callback The connect callback function.
     *    (Integer) wait - The optional HTTPBIND wait value.  This is the
     *      time the server will wait before returning an empty result for
     *      a request.  The default setting of 60 seconds is recommended.
     *      Other settings will require tweaks to the Strophe.TIMEOUT value.
     *    (Integer) hold - The optional HTTPBIND hold value.  This is the
     *      number of connections the server will hold at one time.  This
     *      should almost always be set to 1 (the default).
     *    (Integer) wind - The optional HTTBIND window value.  This is the
     *      allowed range of request ids this are valid.  The default is 5.
     */
  Function get attach {
    return this._attachConnection ?? _attach;
  }

  set attach(Function value) {
    this._attachConnection = value;
  }

  _attach(String jid, String sid, int rid, Function callback, int wait,
      int hold, int wind) {
    if (this._proto is StropheBosh) {
      this._proto.attach(jid, sid, rid, callback, wait, hold, wind);
    } else {
      throw {
        'name': 'StropheSessionError',
        'message':
            'The "attach" method can only be used with a BOSH connection.'
      };
    }
  }

  /** Function: restore
                 *  Attempt to restore a cached BOSH session.
                 *
                 *  This function is only useful in conjunction with providing the
                 *  "keepalive":true option when instantiating a new Strophe.Connection.
                 *
                 *  When "keepalive" is set to true, Strophe will cache the BOSH tokens
                 *  RID (Request ID) and SID (Session ID) and then when this function is
                 *  called, it will attempt to restore the session from those cached
                 *  tokens.
                 *
                 *  This function must therefore be called instead of connect or attach.
                 *
                 *  For an example on how to use it, please see examples/restore.js
                 *
                 *  Parameters:
                 *    (String) jid - The user's JID.  This may be a bare JID or a full JID.
                 *    (Function) callback - The connect callback function.
                 *    (Integer) wait - The optional HTTPBIND wait value.  This is the
                 *      time the server will wait before returning an empty result for
                 *      a request.  The default setting of 60 seconds is recommended.
                 *    (Integer) hold - The optional HTTPBIND hold value.  This is the
                 *      number of connections the server will hold at one time.  This
                 *      should almost always be set to 1 (the default).
                 *    (Integer) wind - The optional HTTBIND window value.  This is the
                 *      allowed range of request ids this are valid.  The default is 5.
                 */
  restore(String jid, Function callback, int wait, int hold, int wind) {
    if (this._sessionCachingSupported()) {
      this._proto.restore(jid, callback, wait, hold, wind);
    } else {
      throw {
        'name': 'StropheSessionError',
        'message':
            'The "restore" method can only be used with a BOSH connection.'
      };
    }
  }

  /** PrivateFunction: _sessionCachingSupported
                                         * Checks whether sessionStorage and JSON are supported and whether we're
                                         * using BOSH.
                                         */
  bool sessionCachingSupported() {
    return this._sessionCachingSupported();
  }

  bool _sessionCachingSupported() {
    if (this._proto is StropheBosh) {
      try {
        SessionStorage.setItem('_strophe_', '_strophe_');
        SessionStorage.removeItem('_strophe_');
      } catch (e) {
        return false;
      }
      return true;
    }
    return false;
  }

  /** Function: xmlInput
                                         *  User overrideable function this receives XML data coming into the
                                         *  connection.
                                         *
                                         *  The default function does nothing.  User code can override this with
                                         *  > Strophe.Connection.xmlInput = function (elem) {
                                         *  >   (user code)
                                         *  > };
                                         *
                                         *  Due to limitations of current Browsers' XML-Parsers the opening and closing
                                         *  <stream> tag for WebSocket-Connoctions will be passed as selfclosing here.
                                         *
                                         *  BOSH-Connections will have all stanzas wrapped in a <body> tag. See
                                         *  <Strophe.Bosh.strip> if you want to strip this tag.
                                         *
                                         *  Parameters:
                                         *    (XMLElement) elem - The XML data received by the connection.
                                         */
  /* jshint unused:false */

  set xmlInput(XmlInputCallback callback) {
    this._xmlInputCallback = callback;
  }

  XmlInputCallback get xmlInput {
    return this._xmlInputCallback;
  }

  set connexionError(RawInputCallback callback) {
    this._connexionErrorInputCallback = callback;
  }

  RawInputCallback get connexionError {
    return this._connexionErrorInputCallback;
  }

  /* jshint unused:true */

  /** Function: xmlOutput
                                         *  User overrideable function this receives XML data sent to the
                                         *  connection.
                                         *
                                         *  The default function does nothing.  User code can override this with
                                         *  > Strophe.Connection.xmlOutput = function (elem) {
                                         *  >   (user code)
                                         *  > };
                                         *
                                         *  Due to limitations of current Browsers' XML-Parsers the opening and closing
                                         *  <stream> tag for WebSocket-Connoctions will be passed as selfclosing here.
                                         *
                                         *  BOSH-Connections will have all stanzas wrapped in a <body> tag. See
                                         *  <Strophe.Bosh.strip> if you want to strip this tag.
                                         *
                                         *  Parameters:
                                         *    (XMLElement) elem - The XMLdata sent by the connection.
                                         */
  /* jshint unused:false */
  set xmlOutput(XmlInputCallback callback) {
    this._xmlOutputCallback = callback;
  }

  XmlInputCallback get xmlOutput {
    return this._xmlOutputCallback;
  }
  /* jshint unused:true */

  /** Function: rawInput
                                         *  User overrideable function this receives raw data coming into the
                                         *  connection.
                                         *
                                         *  The default function does nothing.  User code can override this with
                                         *  > Strophe.Connection.rawInput = function (data) {
                                         *  >   (user code)
                                         *  > };
                                         *
                                         *  Parameters:
                                         *    (String) data - The data received by the connection.
                                         */
  /* jshint unused:false */
  set rawInput(RawInputCallback callback) {
    this._rawInputCallback = callback;
  }

  RawInputCallback get rawInput {
    return this._rawInputCallback;
  }
  /* jshint unused:true */

  /** Function: rawOutput
                                         *  User overrideable function this receives raw data sent to the
                                         *  connection.
                                         *
                                         *  The default function does nothing.  User code can override this with
                                         *  > Strophe.Connection.rawOutput = function (data) {
                                         *  >   (user code)
                                         *  > };
                                         *
                                         *  Parameters:
                                         *    (String) data - The data sent by the connection.
                                         */
  /* jshint unused:false */
  set rawOutput(RawInputCallback callback) {
    this._rawOutputCallback = callback;
  }

  RawInputCallback get rawOutput {
    return this._rawOutputCallback;
  }
  /* jshint unused:true */

  /** Function: nextValidRid
                                         *  User overrideable function this receives the new valid rid.
                                         *
                                         *  The default function does nothing. User code can override this with
                                         *  > Strophe.Connection.nextValidRid = function (rid) {
                                         *  >    (user code)
                                         *  > };
                                         *
                                         *  Parameters:
                                         *    (Number) rid - The next valid rid
                                         */
  /* jshint unused:false */
  nextValidRid(int rid) {
    return;
  }
  /* jshint unused:true */

  /** Function: send
                                         *  Send a stanza.
                                         *
                                         *  This function is called to add data onto the send queue to
                                         *  go out over the wire.  Whenever a request is sent to the BOSH
                                         *  server, all pending data is sent and the queue is flushed.
                                         *
                                         *  Parameters:
                                         *    (XMLElement |
                                         *     [XMLElement] |
                                         *     Strophe.Builder) elem - The stanza to send.
                                         */
  send(dynamic elem) {
    if (elem == null) {
      return;
    }
    if (elem is List) {
      for (int i = 0; i < elem.length; i++) {
        if (elem[i] is xml.XmlNode) {
          this._queueData(elem[i]);
        } else if (elem[i] is StanzaBuilder) {
          this._queueData(elem[i].tree());
        }
      }
    } else {
      if (elem is xml.XmlNode) {
        this._queueData(elem);
      } else if (elem is StanzaBuilder) {
        this._queueData(elem.tree());
      }
    }
    this._proto.send();
  }

  /** Function: flush
                                                                                     *  Immediately send any pending outgoing data.
                                                                                     *
                                                                                     *  Normally send() queues outgoing data until the next idle period
                                                                                     *  (100ms), which optimizes network use in the common cases when
                                                                                     *  several send()s are called in succession. flush() can be used to
                                                                                     *  immediately send all pending data.
                                                                                     */
  flush() {
    // cancel the pending idle period and run the idle function
    // immediately
    if (this._idleTimeout != null) this._idleTimeout.cancel();
    this._onIdle();
  }

  /** Function: sendPresence
                                                                                     *  Helper function to send presence stanzas. The main benefit is for
                                                                                     *  sending presence stanzas for which you expect a responding presence
                                                                                     *  stanza with the same id (for example when leaving a chat room).
                                                                                     *
                                                                                     *  Parameters:
                                                                                     *    (XMLElement) elem - The stanza to send.
                                                                                     *    (Function) callback - The callback function for a successful request.
                                                                                     *    (Function) errback - The callback function for a failed or timed
                                                                                     *      out request.  On timeout, the stanza will be null.
                                                                                     *    (Integer) timeout - The time specified in milliseconds for a
                                                                                     *      timeout to occur.
                                                                                     *
                                                                                     *  Returns:
                                                                                     *    The id used to send the presence.
                                                                                     */
  String sendPresence(xml.XmlNode element,
      [Function callback, Function errback, int timeout]) {
    StanzaTimedHandler timeoutHandler;
    xml.XmlElement elem = element is xml.XmlDocument
        ? element.rootElement
        : (element as xml.XmlElement);
    String id = elem.getAttribute("id");
    if (id == null || id.isEmpty) {
      // inject id if not found
      id = this.getUniqueId("sendPresence");
      elem.attributes
          .add(new xml.XmlAttribute(new xml.XmlName.fromString('id'), id));
    }

    if (callback == null || errback == null) {
      StanzaHandler handler = this.addHandler((stanza) {
        // remove timeout handler if there is one
        if (timeoutHandler != null) {
          this.deleteTimedHandler(timeoutHandler);
        }
        String type = elem.getAttribute("type");
        if (type == 'error') {
          if (errback != null) {
            errback(stanza);
          }
        } else if (callback != null) {
          callback(stanza);
        }
      }, null, 'presence', null, id);

      // if timeout specified, set up a timeout handler.
      if (timeout != null && timeout > 0) {
        timeoutHandler = this.addTimedHandler(timeout, () {
          // get rid of normal handler
          this.deleteHandler(handler);
          // call errback on timeout with null stanza
          if (errback != null) {
            errback(null);
          }
          return false;
        });
      }
    }
    this.send(elem);
    return id;
  }

  /** Function: sendIQ
                                                                                     *  Helper function to send IQ stanzas.
                                                                                     *
                                                                                     *  Parameters:
                                                                                     *    (XMLElement) elem - The stanza to send.
                                                                                     *    (Function) callback - The callback function for a successful request.
                                                                                     *    (Function) errback - The callback function for a failed or timed
                                                                                     *      out request.  On timeout, the stanza will be null.
                                                                                     *    (Integer) timeout - The time specified in milliseconds for a
                                                                                     *      timeout to occur.
                                                                                     *
                                                                                     *  Returns:
                                                                                     *    The id used to send the IQ.
                                                                                    */
  String sendIQ(xml.XmlNode el,
      [Function callback, Function errback, int timeout]) {
    StanzaTimedHandler timeoutHandler;
    xml.XmlElement elem = el;
    if (el is xml.XmlDocument)
      elem = el.rootElement;
    else if (el is xml.XmlElement) elem = el;
    String id = elem.getAttribute("id");
    if (id == null) {
      // inject id if not found
      id = this.getUniqueId("sendIQ");
      elem.attributes
          .add(new xml.XmlAttribute(new xml.XmlName.fromString('id'), id));
    }

    if (callback != null || errback != null) {
      StanzaHandler handler = this.addHandler((stanza) {
        // remove timeout handler if there is one
        if (timeoutHandler != null) {
          this.deleteTimedHandler(timeoutHandler);
        }
        if (stanza is xml.XmlDocument) stanza = stanza.rootElement;
        String iqtype = stanza.getAttribute("type");
        if (iqtype == 'result') {
          if (callback != null) {
            callback(stanza);
          }
        } else if (iqtype == 'error') {
          if (errback != null) {
            errback(stanza);
          }
        } else {
          throw {
            'name': "StropheError",
            'message': "Got bad IQ type of " + iqtype
          };
        }
      }, null, 'iq', ['error', 'result'], id);
      // if timeout specified, set up a timeout handler.
      if (timeout != null && timeout > 0) {
        timeoutHandler = this.addTimedHandler(timeout, () {
          // get rid of normal handler
          this.deleteHandler(handler);
          // call errback on timeout with null stanza
          if (errback != null) {
            errback(null);
          }
          return false;
        });
      }
    }
    this.send(elem);
    return id;
  }

  /** PrivateFunction: _queueData
                                                                                     *  Queue outgoing data for later sending.  Also ensures this the data
                                                                                     *  is a DOMElement.
                                                                                     */
  _queueData(xml.XmlNode element) {
    xml.XmlElement elem = element is xml.XmlDocument
        ? element.rootElement
        : (element as xml.XmlElement);

    if (elem == null || elem.name == null) {
      throw {'name': "StropheError", 'message': "Cannot queue non-DOMElement."};
    }
    this._data.add(elem);
  }

  /** PrivateFunction: _sendRestart
                                                                                     *  Send an xmpp:restart stanza.
                                                                                     */
  _sendRestart() {
    this._data.add("restart");
    this._proto.sendRestart();
    // XXX: setTimeout should be called only with function expressions (23974bc1)
    this._idleTimeout = new Timer(new Duration(milliseconds: 100), () {
      this._onIdle();
    });
  }

  /** Function: addTimedHandler
                                                                                                                                                                             *  Add a timed handler to the connection.
                                                                                                                                                                             *
                                                                                                                                                                             *  This function adds a timed handler.  The provided handler will
                                                                                                                                                                             *  be called every period milliseconds until it returns false,
                                                                                                                                                                             *  the connection is terminated, or the handler is removed.  Handlers
                                                                                                                                                                             *  this wish to continue being invoked should return true.
                                                                                                                                                                             *
                                                                                                                                                                             *  Because of method binding it is necessary to save the result of
                                                                                                                                                                             *  this function if you wish to remove a handler with
                                                                                                                                                                             *  deleteTimedHandler().
                                                                                                                                                                             *
                                                                                                                                                                             *  Note this user handlers are not active until authentication is
                                                                                                                                                                             *  successful.
                                                                                                                                                                             *
                                                                                                                                                                             *  Parameters:
                                                                                                                                                                             *    (Integer) period - The period of the handler.
                                                                                                                                                                             *    (Function) handler - The callback function.
                                                                                                                                                                             *
                                                                                                                                                                             *  Returns:
                                                                                                                                                                             *    A reference to the handler this can be used to remove it.
                                                                                                                                                                             */
  StanzaTimedHandler addTimedHandler(int period, Function handler) {
    StanzaTimedHandler thand = Strophe.TimedHandler(period, handler);
    this.addTimeds.add(thand);
    return thand;
  }

  /** Function: deleteTimedHandler
                                                                                                                                                                             *  Delete a timed handler for a connection.
                                                                                                                                                                             *
                                                                                                                                                                             *  This function removes a timed handler from the connection.  The
                                                                                                                                                                             *  handRef parameter is *not* the function passed to addTimedHandler(),
                                                                                                                                                                             *  but is the reference returned from addTimedHandler().
                                                                                                                                                                             *
                                                                                                                                                                             *  Parameters:
                                                                                                                                                                             *    (Strophe.TimedHandler) handRef - The handler reference.
                                                                                                                                                                             */
  deleteTimedHandler(StanzaTimedHandler handRef) {
    // this must be done in the Idle loop so this we don't change
    // the handlers during iteration
    this.removeTimeds.add(handRef);
  }

  /** Function: addHandler
                                                                                                                                                                             *  Add a stanza handler for the connection.
                                                                                                                                                                             *
                                                                                                                                                                             *  This function adds a stanza handler to the connection.  The
                                                                                                                                                                             *  handler callback will be called for any stanza this matches
                                                                                                                                                                             *  the parameters.  Note this if multiple parameters are supplied,
                                                                                                                                                                             *  they must all match for the handler to be invoked.
                                                                                                                                                                             *
                                                                                                                                                                             *  The handler will receive the stanza this triggered it as its argument.
                                                                                                                                                                             *  *The handler should return true if it is to be invoked again;
                                                                                                                                                                             *  returning false will remove the handler after it returns.*
                                                                                                                                                                             *
                                                                                                                                                                             *  As a convenience, the ns parameters applies to the top level element
                                                                                                                                                                             *  and also any of its immediate children.  This is primarily to make
                                                                                                                                                                             *  matching /iq/query elements easy.
                                                                                                                                                                             *
                                                                                                                                                                             *  Options
                                                                                                                                                                             *  ~~~~~~~
                                                                                                                                                                             *  With the options argument, you can specify boolean flags this affect how
                                                                                                                                                                             *  matches are being done.
                                                                                                                                                                             *
                                                                                                                                                                             *  Currently two flags exist:
                                                                                                                                                                             *
                                                                                                                                                                             *  - matchBareFromJid:
                                                                                                                                                                             *      When set to true, the from parameter and the
                                                                                                                                                                             *      from attribute on the stanza will be matched as bare JIDs instead
                                                                                                                                                                             *      of full JIDs. To use this, pass {matchBareFromJid: true} as the
                                                                                                                                                                             *      value of options. The default value for matchBareFromJid is false.
                                                                                                                                                                             *
                                                                                                                                                                             *  - ignoreNamespaceFragment:
                                                                                                                                                                             *      When set to true, a fragment specified on the stanza's namespace
                                                                                                                                                                             *      URL will be ignored when it's matched with the one configured for
                                                                                                                                                                             *      the handler.
                                                                                                                                                                             *
                                                                                                                                                                             *      This means this if you register like this:
                                                                                                                                                                             *      >   connection.addHandler(
                                                                                                                                                                             *      >       handler,
                                                                                                                                                                             *      >       'http://jabber.org/protocol/muc',
                                                                                                                                                                             *      >       null, null, null, null,
                                                                                                                                                                             *      >       {'ignoreNamespaceFragment': true}
                                                                                                                                                                             *      >   );
                                                                                                                                                                             *
                                                                                                                                                                             *      Then a stanza with XML namespace of
                                                                                                                                                                             *      'http://jabber.org/protocol/muc#user' will also be matched. If
                                                                                                                                                                             *      'ignoreNamespaceFragment' is false, then only stanzas with
                                                                                                                                                                             *      'http://jabber.org/protocol/muc' will be matched.
                                                                                                                                                                             *
                                                                                                                                                                             *  Deleting the handler
                                                                                                                                                                             *  ~~~~~~~~~~~~~~~~~~~~
                                                                                                                                                                             *  The return value should be saved if you wish to remove the handler
                                                                                                                                                                             *  with deleteHandler().
                                                                                                                                                                             *
                                                                                                                                                                             *  Parameters:
                                                                                                                                                                             *    (Function) handler - The user callback.
                                                                                                                                                                             *    (String) ns - The namespace to match.
                                                                                                                                                                             *    (String) name - The stanza name to match.
                                                                                                                                                                             *    (String|Array) type - The stanza type (or types if an array) to match.
                                                                                                                                                                             *    (String) id - The stanza id attribute to match.
                                                                                                                                                                             *    (String) from - The stanza from attribute to match.
                                                                                                                                                                             *    (String) options - The handler options
                                                                                                                                                                             *
                                                                                                                                                                             *  Returns:
                                                                                                                                                                             *    A reference to the handler this can be used to remove it.
                                                                                                                                                                             */
  StanzaHandler addHandler(Function handler, String ns, String name,
      [type, String id, String from, options]) {
    StanzaHandler hand =
        Strophe.Handler(handler, ns, name, type, id, from, options);
    this.addHandlers.add(hand);
    return hand;
  }

  /** Function: deleteHandler
                                                                                                                                                                             *  Delete a stanza handler for a connection.
                                                                                                                                                                             *
                                                                                                                                                                             *  This function removes a stanza handler from the connection.  The
                                                                                                                                                                             *  handRef parameter is *not* the function passed to addHandler(),
                                                                                                                                                                             *  but is the reference returned from addHandler().
                                                                                                                                                                             *
                                                                                                                                                                             *  Parameters:
                                                                                                                                                                             *    (Strophe.Handler) handRef - The handler reference.
                                                                                                                                                                             */
  deleteHandler(StanzaHandler handRef) {
    // this must be done in the Idle loop so this we don't change
    // the handlers during iteration
    this.removeHandlers.add(handRef);
    // If a handler is being deleted while it is being added,
    // prevent it from getting added
    int i = this.addHandlers.indexOf(handRef);
    if (i >= 0) {
      this.addHandlers.removeAt(i);
    }
  }

  /** Function: registerSASLMechanisms
                                                                                                                                                                             *
                                                                                                                                                                             * Register the SASL mechanisms which will be supported by this instance of
                                                                                                                                                                             * Strophe.Connection (i.e. which this XMPP client will support).
                                                                                                                                                                             *
                                                                                                                                                                             *  Parameters:
                                                                                                                                                                             *    (Array) mechanisms - Array of objects with Strophe.SASLMechanism prototypes
                                                                                                                                                                             *
                                                                                                                                                                             */
  registerSASLMechanisms(mechanisms) {
    this.mechanisms = {};
    mechanisms = mechanisms ??
        [
          Strophe.SASLAnonymous,
          Strophe.SASLExternal,
          Strophe.SASLMD5,
          Strophe.SASLOAuthBearer,
          Strophe.SASLXOAuth2,
          Strophe.SASLPlain,
          Strophe.SASLSHA1
        ];
    mechanisms.forEach(this.registerSASLMechanism);
  }

  /** Function: registerSASLMechanism
                                                                                                                                                                             *
                                                                                                                                                                             * Register a single SASL mechanism, to be supported by this client.
                                                                                                                                                                             *
                                                                                                                                                                             *  Parameters:
                                                                                                                                                                             *    (Object) mechanism - Object with a Strophe.SASLMechanism prototype
                                                                                                                                                                             *
                                                                                                                                                                             */
  registerSASLMechanism(StropheSASLMechanism mechanism) {
    this.mechanisms[mechanism.name] = mechanism;
  }

  /** Function: disconnect
                                                                                                                                                                             *  Start the graceful disconnection process.
                                                                                                                                                                             *
                                                                                                                                                                             *  This function starts the disconnection process.  This process starts
                                                                                                                                                                             *  by sending unavailable presence and sending BOSH body of type
                                                                                                                                                                             *  terminate.  A timeout handler makes sure this disconnection happens
                                                                                                                                                                             *  even if the BOSH server does not respond.
                                                                                                                                                                             *  If the Connection object isn't connected, at least tries to abort all pending requests
                                                                                                                                                                             *  so the connection object won't generate successful requests (which were already opened).
                                                                                                                                                                             *
                                                                                                                                                                             *  The user supplied connection callback will be notified of the
                                                                                                                                                                             *  progress as this process happens.
                                                                                                                                                                             *
                                                                                                                                                                             *  Parameters:
                                                                                                                                                                             *    (String) reason - The reason the disconnect is occuring.
                                                                                                                                                                             */
  disconnect([String reason = ""]) {
    this._changeConnectStatus(Strophe.Status['DISCONNECTING'], reason);

    Strophe.info("Disconnect was called because: " + reason);
    if (this.connected) {
      StanzaBuilder pres;
      this.disconnecting = true;
      if (this.authenticated) {
        pres = Strophe
            .$pres({'xmlns': Strophe.NS['CLIENT'], 'type': 'unavailable'});
      }
      // setup timeout handler
      this._disconnectTimeout =
          this._addSysTimedHandler(3000, this._onDisconnectTimeout);
      this._proto.disconnect(pres?.tree());
    } else {
      Strophe
          .info("Disconnect was called before Strophe connected to the server");
      this._proto.abortAllRequests();
      this._doDisconnect();
    }
  }

  /** PrivateFunction: _changeConnectStatus
                                                                                                                                                                                                                                                                                                                                                                       *  _Private_ helper function this makes sure plugins and the user's
                                                                                                                                                                                                                                                                                                                                                                       *  callback are notified of connection status changes.
                                                                                                                                                                                                                                                                                                                                                                       *
                                                                                                                                                                                                                                                                                                                                                                       *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                       *    (Integer) status - the new connection status, one of the values
                                                                                                                                                                                                                                                                                                                                                                       *      in Strophe.Status
                                                                                                                                                                                                                                                                                                                                                                       *    (String) condition - the error condition or null
                                                                                                                                                                                                                                                                                                                                                                       *    (XMLElement) elem - The triggering stanza.
                                                                                                                                                                                                                                                                                                                                                                       */
  changeConnectStatus(int status, String condition, [xml.XmlNode elem]) {
    this._changeConnectStatus(status, condition, elem);
  }

  _changeConnectStatus(int status, [String condition, xml.XmlNode elem]) {
    // notify all plugins listening for status changes
    Strophe.connectionPlugins.forEach((String key, PluginClass plugin) {
      if (plugin.statusChanged != null) {
        try {
          plugin.statusChanged(status, condition);
        } catch (err) {
          Strophe.error("" +
              key +
              " plugin caused an exception " +
              "changing status: " +
              err);
        }
      }
    });
    // notify the user's callback
    if (this.connectCallback != null) {
      try {
        if (connectCallback != null)
          this.connectCallback(status, condition, elem);
      } catch (e) {
        if (e is Error) Strophe.handleError(e);
        Strophe.error("User connection callback caused an " +
            "exception: " +
            e.toString());
      }
    }
  }

  /** PrivateFunction: _doDisconnect
                                                                                                                                                                                                                                                                                                                                                                       *  _Private_ function to disconnect.
                                                                                                                                                                                                                                                                                                                                                                       *
                                                                                                                                                                                                                                                                                                                                                                       *  This is the last piece of the disconnection logic.  This resets the
                                                                                                                                                                                                                                                                                                                                                                       *  connection and alerts the user's connection callback.
                                                                                                                                                                                                                                                                                                                                                                       */
  doDisconnect([condition]) {
    return this._doDisconnect(condition);
  }

  _doDisconnect([condition]) {
    if (this._idleTimeout != null) {
      this._idleTimeout.cancel();
    }

    // Cancel Disconnect Timeout
    if (this._disconnectTimeout != null) {
      this.deleteTimedHandler(this._disconnectTimeout);
      this._disconnectTimeout = null;
    }
    this._proto.doDisconnect();

    this.authenticated = false;
    this.disconnecting = false;
    this.restored = false;

    // delete handlers
    this.handlers = [];
    this.timedHandlers = [];
    this.removeTimeds = [];
    this.removeHandlers = [];
    this.addTimeds = [];
    this.addHandlers = [];

    // tell the parent we disconnected
    this._changeConnectStatus(Strophe.Status['DISCONNECTED'], condition);
    this.connected = false;
  }

  /** PrivateFunction: _dataRecv
                                                                                                                                                                                                                                                                                                                                                                                 *  _Private_ handler to processes incoming data from the the connection.
                                                                                                                                                                                                                                                                                                                                                                                 *
                                                                                                                                                                                                                                                                                                                                                                                 *  Except for _connect_cb handling the initial connection request,
                                                                                                                                                                                                                                                                                                                                                                                 *  this function handles the incoming data for all requests.  This
                                                                                                                                                                                                                                                                                                                                                                                 *  function also fires stanza handlers this match each incoming
                                                                                                                                                                                                                                                                                                                                                                                 *  stanza.
                                                                                                                                                                                                                                                                                                                                                                                 *
                                                                                                                                                                                                                                                                                                                                                                                 *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                 *    (Strophe.Request) req - The request this has data ready.
                                                                                                                                                                                                                                                                                                                                                                                 *    (string) req - The stanza a raw string (optiona).
                                                                                                                                                                                                                                                                                                                                                                                 */
  dataRecv(req, [String raw]) {
    this._dataRecv(req, raw);
  }

  _dataRecv(req, [String raw]) {
    xml.XmlElement elem = this._proto.reqToData(req);
    if (elem == null) {
      return;
    }
    //if (this.xmlInput != Strophe.Connection.xmlInput) {
    if (elem.name.qualified == this._proto.strip && elem.children.length > 0) {
      this.xmlInput(elem.firstChild);
    } else {
      this.xmlInput(elem);
    }
    //}
    //if (this.rawInput != Strophe.Connection.rawInput) {
    if (raw != null) {
      this.rawInput(raw);
    } else {
      this.rawInput(Strophe.serialize(elem));
    }
    //}

    // remove handlers scheduled for deletion
    int i;
    StanzaHandler hand;
    while (this.removeHandlers.length > 0) {
      hand = this.removeHandlers.removeLast();
      i = this.handlers.indexOf(hand);
      if (i >= 0) {
        this.handlers.removeAt(i);
      }
    }
    // add handlers scheduled for addition
    while (this.addHandlers.length > 0) {
      this.handlers.add(this.addHandlers.removeLast());
    }
    // handle graceful disconnect
    if (this.disconnecting && this._proto.emptyQueue()) {
      this._doDisconnect();
      return;
    }
    xml.XmlElement stanza;
    if (elem.name.qualified == this._proto.strip)
      stanza = elem.firstChild as xml.XmlElement;
    else
      stanza = elem;
    String type = stanza.getAttribute('type');
    if (type == null) {
      try {
        type = (elem.firstChild as xml.XmlElement).getAttribute('type');
      } catch (e) {}
    }
    String cond;
    Iterable<xml.XmlElement> conflict;
    if (type != null && type == "terminate") {
      // Don't process stanzas this come in after disconnect
      if (this.disconnecting) {
        return;
      }

      // an error occurred

      cond = elem.getAttribute('condition');
      conflict = elem.document.findAllElements("conflict");
      if (cond != null) {
        if (cond == "remote-stream-error" && conflict.length > 0) {
          cond = "conflict";
        }
        this._changeConnectStatus(Strophe.Status['CONNFAIL'], cond);
      } else {
        this._changeConnectStatus(Strophe.Status['CONNFAIL'],
            Strophe.ErrorCondition['UNKOWN_REASON']);
      }
      this._doDisconnect(cond);
      return;
    }
    // send each incoming stanza through the handler chain
    Strophe.forEachChild(elem, null, (child) {
      // process handlers
      List<StanzaHandler> newList = this.handlers;
      this.handlers = [];

      for (int i = 0; i < newList.length; i++) {
        StanzaHandler hand = newList.elementAt(i);
        // encapsulate 'handler.run' not to lose the whole handler list if
        // one of the handlers throws an exception
        try {
          if (hand.isMatch(child) && (this.authenticated || !hand.user)) {
            if (hand.run(child)) {
              this.handlers.add(hand);
            }
          } else {
            this.handlers.add(hand);
          }
        } catch (e) {
          // if the handler throws an exception, we consider it as false
          Strophe.warn('Removing Strophe handlers due to uncaught exception: ' +
              e.toString());
        }
      }
    });
  }

  /** Attribute: mechanisms
                                                                                                                                                                                                                                                                                                                                                                                                         *  SASL Mechanisms available for Connection.
                                                                                                                                                                                                                                                                                                                                                                                                         */
  Map<String, StropheSASLMechanism> mechanisms = {};

  /** PrivateFunction: _no_auth_received
                                                                                                                                                                                                                                                                                                                                                                                                         *
                                                                                                                                                                                                                                                                                                                                                                                                         * Called on stream start/restart when no stream:features
                                                                                                                                                                                                                                                                                                                                                                                                         * has been received or when no viable authentication mechanism is offered.
                                                                                                                                                                                                                                                                                                                                                                                                         *
                                                                                                                                                                                                                                                                                                                                                                                                         * Sends a blank poll request.
                                                                                                                                                                                                                                                                                                                                                                                                         */
  Function get noAuthReceived {
    return _noAuthReceived;
  }

  _noAuthReceived([Function _callback]) {
    String errorMsg =
        "Server did not offer a supported authentication mechanism";
    Strophe.error(errorMsg);
    this._changeConnectStatus(
        Strophe.Status['CONNFAIL'], Strophe.ErrorCondition['NO_AUTH_MECH']);
    if (_callback != null) {
      _callback();
    }
    this._doDisconnect();
  }

  /** PrivateFunction: _connect_cb
                                                                                                                                                                                                                                                                                                                                                                                                         *  _Private_ handler for initial connection request.
                                                                                                                                                                                                                                                                                                                                                                                                         *
                                                                                                                                                                                                                                                                                                                                                                                                         *  This handler is used to process the initial connection request
                                                                                                                                                                                                                                                                                                                                                                                                         *  response from the BOSH server. It is used to set up authentication
                                                                                                                                                                                                                                                                                                                                                                                                         *  handlers and start the authentication process.
                                                                                                                                                                                                                                                                                                                                                                                                         *
                                                                                                                                                                                                                                                                                                                                                                                                         *  SASL authentication will be attempted if available, otherwise
                                                                                                                                                                                                                                                                                                                                                                                                         *  the code will fall back to legacy authentication.
                                                                                                                                                                                                                                                                                                                                                                                                         *
                                                                                                                                                                                                                                                                                                                                                                                                         *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                                         *    (Strophe.Request) req - The current request.
                                                                                                                                                                                                                                                                                                                                                                                                         *    (Function) _callback - low level (xmpp) connect callback function.
                                                                                                                                                                                                                                                                                                                                                                                                         *      Useful for plugins with their own xmpp connect callback (when they
                                                                                                                                                                                                                                                                                                                                                                                                         *      want to do something special).
                                                                                                                                                                                                                                                                                                                                                                                                         */

  set connectCb(ConnexionCallback param) {
    this._connectCb = param;
  }

  ConnexionCallback get connectCb {
    if (_reset == null) initializeFunction();
    return this._connectCb;
  }
/* set connectCb(){

} */

  /** Function: sortMechanismsByPriority
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Sorts an array of objects with prototype SASLMechanism according to
                                                                                                                                                                                                                                                                                                                                                                                                             *  their priorities.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                                             *    (Array) mechanisms - Array of SASL mechanisms.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             */
  List<StropheSASLMechanism> sortMechanismsByPriority(
      List<StropheSASLMechanism> mechanisms) {
    // Sorting mechanisms according to priority.
    int higher;
    StropheSASLMechanism swap;
    for (int i = 0; i < mechanisms.length - 1; ++i) {
      higher = i;
      for (int j = i + 1; j < mechanisms.length; ++j) {
        if (mechanisms[j].priority > mechanisms[higher].priority) {
          higher = j;
        }
      }
      if (higher != i) {
        swap = mechanisms[i];
        mechanisms[i] = mechanisms[higher];
        mechanisms[higher] = swap;
      }
    }
    return mechanisms;
  }

  /** PrivateFunction: _attemptSASLAuth
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Iterate through an array of SASL mechanisms and attempt authentication
                                                                                                                                                                                                                                                                                                                                                                                                             *  with the highest priority (enabled) mechanism.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                                             *    (Array) mechanisms - Array of SASL mechanisms.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Returns:
                                                                                                                                                                                                                                                                                                                                                                                                             *    (Boolean) mechanism_found - true or false, depending on whether a
                                                                                                                                                                                                                                                                                                                                                                                                             *          valid SASL mechanism was found with which authentication could be
                                                                                                                                                                                                                                                                                                                                                                                                             *          started.
                                                                                                                                                                                                                                                                                                                                                                                                             */
  Future<bool> _attemptSASLAuth(List<StropheSASLMechanism> mechanisms) async {
    mechanisms = this.sortMechanismsByPriority(mechanisms ?? []);

    bool mechanismFound = false;
    for (int i = 0; i < mechanisms.length; ++i) {
      if (!mechanisms[i].test(this)) {
        continue;
      }
      this._saslSuccessHandler =
          this._addSysHandler(this._saslSuccessCb, null, "success", null, null);
      this._saslFailureHandler =
          this._addSysHandler(this._saslFailureCb, null, "failure", null, null);
      this._saslChallengeHandler = this
          ._addSysHandler(this._saslChallengeCb, null, "challenge", null, null);

      this._saslMechanism = mechanisms[i];
      this._saslMechanism.onStart(this);

      StanzaBuilder requestAuthExchange = Strophe.$build("auth",
          {'xmlns': Strophe.NS['SASL'], 'mechanism': this._saslMechanism.name});
      if (this._saslMechanism.isClientFirst) {
        String response = await this._saslMechanism.onChallenge(this, null);
        requestAuthExchange.t(base64.encode(response.runes.toList()));
      }
      this.send(requestAuthExchange.tree());
      mechanismFound = true;
      break;
    }
    return mechanismFound;
  }

  /** PrivateFunction: _attemptLegacyAuth
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Attempt legacy (i.e. non-SASL) authentication.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             */
  _attemptLegacyAuth() {
    if (Strophe.getNodeFromJid(this.jid) == null) {
      // we don't have a node, which is required for non-anonymous
      // client connections
      this._changeConnectStatus(Strophe.Status['CONNFAIL'],
          Strophe.ErrorCondition['MISSING_JID_NODE']);
      this.disconnect(Strophe.ErrorCondition['MISSING_JID_NODE']);
    } else {
      // Fall back to legacy authentication
      this._changeConnectStatus(Strophe.Status['AUTHENTICATING'], null);
      this._addSysHandler(this._auth1Cb, null, null, null, "_auth_1");
      this.send(Strophe
          .$iq({'type': "get", 'to': this.domain, 'id': "_auth_1"})
          .c("query", {'xmlns': Strophe.NS['AUTH']})
          .c("username", {})
          .t(Strophe.getNodeFromJid(this.jid))
          .tree());
    }
  }

  /** Function: authenticate
                                                                                                                                                                                                                                                                                                                                                                                                             * Set up authentication
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Continues the initial connection request by setting up authentication
                                                                                                                                                                                                                                                                                                                                                                                                             *  handlers and starting the authentication process.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  SASL authentication will be attempted if available, otherwise
                                                                                                                                                                                                                                                                                                                                                                                                             *  the code will fall back to legacy authentication.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                                             *    (Array) matched - Array of SASL mechanisms supported.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             */

  set authenticate(AuthenticateCallback callback) {
    this._authenticate = callback;
  }

  AuthenticateCallback get authenticate {
    if (_authenticate == null) initializeFunction();
    return this._authenticate;
  }

  /** PrivateFunction: _saslChallengeCb
                                                                                                                                                                                                                                                                                                                                                                                                             *  _Private_ handler for the SASL challenge
                                                                                                                                                                                                                                                                                                                                                                                                             *authenticate
                                                                                                                                                                                                                                                                                                                                                                                                             */
  Future<bool> _saslChallengeCb(elem) async {
    String challenge =
        new String.fromCharCodes(base64.decode(Strophe.getText(elem)));
    String response = await this._saslMechanism.onChallenge(this, challenge);
    StanzaBuilder stanza =
        Strophe.$build('response', {'xmlns': Strophe.NS['SASL']});
    if (response != "") {
      stanza.t(base64.encode(response.runes.toList()));
    }
    this.send(stanza.tree());
    return true;
  }

  /** PrivateFunction: _auth1Cb
                                                                                                                         authenticate                                                                                                                                                                                                                                                                                    *  _Private_ handler for legacy authentication.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  This handler is called in response to the initial <iq type='get'/>
                                                                                                                                                                                                                                                                                                                                                                                                             *  for legacy authentication.  It builds an authentication <iq/> and
                                                                                                                                                                                                                                                                                                                                                                                                             *  sends it, creating a handler (calling back to _auth2Cb()) to
                                                                                                                                                                                                                                                                                                                                                                                                             *  handle the result
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                                             *    (XMLElement) elem - The stanza this triggered the callback.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Returns:
                                                                                                                                                                                                                                                                                                                                                                                                             *    false to remove the handler.
                                                                                                                                                                                                                                                                                                                                                                                                             */
  /* jshint unused:false */
  _auth1Cb(elem) {
    // build plaintext auth iq
    StanzaBuilder iq = Strophe
        .$iq({'type': "set", 'id': "_auth_2"})
        .c('query', {'xmlns': Strophe.NS['AUTH']})
        .c('username', {})
        .t(Strophe.getNodeFromJid(this.jid))
        .up()
        .c('password')
        .t(this.pass);

    if (Strophe.getResourceFromJid(this.jid) == null ||
        Strophe.getResourceFromJid(this.jid).isEmpty) {
      // since the user has not supplied a resource, we pick
      // a default one here.  unlike other auth methods, the server
      // cannot do this for us.
      this.jid = Strophe.getBareJidFromJid(this.jid) + '/strophe';
    }
    iq.up().c('resource', {}).t(Strophe.getResourceFromJid(this.jid));

    this._addSysHandler(this._auth2Cb, null, null, null, "_auth_2");
    this.send(iq.tree());
    return false;
  }
  /* jshint unused:true */

  /** PrivateFunction: _saslSuccessCb
                                                                                                                                                                                                                                                                                                                                                                                                             *  _Private_ handler for succesful SASL authentication.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                                             *    (XMLElement) elem - The matching stanza.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Returns:
                                                                                                                                                                                                                                                                                                                                                                                                             *    false to remove the handler.
                                                                                                                                                                                                                                                                                                                                                                                                             */
  bool _saslSuccessCb(elem) {
    String saslData = this._saslData["server-signature"];
    if (saslData != null && saslData.isNotEmpty) {
      String serverSignature;
      String success =
          new String.fromCharCodes(base64.decode(Strophe.getText(elem)));
      RegExp attribMatch = new RegExp(r"([a-z]+)=([^,]+)(,|$)");
      Match matches = attribMatch.firstMatch(success);
      if (matches.group(1) == "v") {
        serverSignature = matches.group(2);
      }
      if (serverSignature != saslData) {
        // remove old handlers
        this.deleteHandler(this._saslFailureHandler);
        this._saslFailureHandler = null;
        if (this._saslChallengeHandler != null) {
          this.deleteHandler(this._saslChallengeHandler);
          this._saslChallengeHandler = null;
        }

        this._saslData = {};
        return this._saslFailureCb(null);
      }
    }
    Strophe.info("SASL authentication succeeded.");

    if (this._saslMechanism != null) {
      this._saslMechanism.onSuccess();
    }

    // remove old handlers
    this.deleteHandler(this._saslFailureHandler);
    this._saslFailureHandler = null;
    if (this._saslChallengeHandler != null) {
      this.deleteHandler(this._saslChallengeHandler);
      this._saslChallengeHandler = null;
    }

    List<StanzaHandler> streamFeatureHandlers = [];
    streamFeatureHandlers.add(this._addSysHandler((elem) {
      return this.wrapper(streamFeatureHandlers, elem);
    }, null, "stream:features", null, null));
    streamFeatureHandlers.add(this._addSysHandler((elem) {
      return this.wrapper(streamFeatureHandlers, elem);
    }, Strophe.NS['STREAM'], "features", null, null));

    // we must send an xmpp:restart now
    this._sendRestart();

    return false;
  }

  bool wrapper(List<StanzaHandler> handlers, elem) {
    while (handlers.length > 0) {
      this.deleteHandler(handlers.removeLast());
    }
    this._saslAuth1Cb(elem);
    return false;
  }

  /** PrivateFunction: _saslAuth1Cb
                                                                                                                                                                                                                                                                                                                                                                                                             *  _Private_ handler to start stream binding.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                                             *    (XMLElement) elem - The matching stanza.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Returns:
                                                                                                                                                                                                                                                                                                                                                                                                             *    false to remove the handler.
                                                                                                                                                                                                                                                                                                                                                                                                             */
  bool _saslAuth1Cb(element) {
    // save stream:features for future usage
    xml.XmlElement elem = element is xml.XmlDocument
        ? element.rootElement
        : (element as xml.XmlElement);
    this.features = elem;
    xml.XmlElement child;
    for (int i = 0; i < elem.children.length; i++) {
      child = elem.children.elementAt(i) as xml.XmlElement;
      if (child.name.qualified == 'bind') {
        this.doBind = true;
      }

      if (child.name.qualified == 'session') {
        this.doSession = true;
      }
    }
    if (!this.doBind) {
      this._changeConnectStatus(Strophe.Status['AUTHFAIL'], null);
      return false;
    } else {
      this._addSysHandler(this._saslBindCb, null, null, null, "_bind_auth_2");

      String resource = Strophe.getResourceFromJid(this.jid);
      if (resource != null && resource.isNotEmpty) {
        this.send(Strophe
            .$iq({'type': "set", 'id': "_bind_auth_2"})
            .c('bind', {"xmlns": Strophe.NS['BIND']})
            .c('resource', {})
            .t(resource)
            .tree());
      } else {
        this.send(Strophe.$iq({'type': "set", 'id': "_bind_auth_2"}).c(
            'bind', {'xmlns': Strophe.NS['BIND']}).tree());
      }
    }
    return false;
  }

  /** PrivateFunction: _saslBindCb
                                                                                                                                                                                                                                                                                                                                                                                                             *  _Private_ handler for binding result and session start.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                                             *    (XMLElement) elem - The matching stanza.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Returns:
                                                                                                                                                                                                                                                                                                                                                                                                             *    false to remove the handler.
                                                                                                                                                                                                                                                                                                                                                                                                             */
  bool _saslBindCb(xml.XmlElement elem) {
    if (elem.getAttribute("type") == "error") {
      Strophe.info("SASL binding failed.");
      List<xml.XmlElement> conflict = elem.findAllElements("conflict");
      String condition;
      if (conflict.length > 0) {
        condition = Strophe.ErrorCondition['CONFLICT'];
      }
      this._changeConnectStatus(Strophe.Status['AUTHFAIL'], condition, elem);
      return false;
    }

    List<xml.XmlElement> bind = elem.findAllElements("bind").toList();
    List<xml.XmlElement> jidNode;
    if (bind.length > 0) {
      // Grab jid
      jidNode = bind[0].findAllElements("jid").toList();
      if (jidNode.length > 0) {
        this.jid = Strophe.getText(jidNode[0]);

        if (this.doSession) {
          this._addSysHandler(
              this._saslSessionCb, null, null, null, "_session_auth_2");
          this.send(Strophe.$iq({'type': "set", 'id': "_session_auth_2"}).c(
              'session', {'xmlns': Strophe.NS['SESSION']}).tree());
        } else {
          this.authenticated = true;
          this._changeConnectStatus(Strophe.Status['CONNECTED'], null);
        }
      }
      return false;
    } else {
      Strophe.info("SASL binding failed.");
      this._changeConnectStatus(Strophe.Status['AUTHFAIL'], null, elem);
      return false;
    }
  }

  /** PrivateFunction: _saslSessionCb
                                                                                                                                                                                                                                                                                                                                                                                                             *  _Private_ handler to finish successful SASL connection.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  This sets Connection.authenticated to true on success, which
                                                                                                                                                                                                                                                                                                                                                                                                             *  starts the processing of user handlers.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                                             *    (XMLElement) elem - The matching stanza.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Returns:
                                                                                                                                                                                                                                                                                                                                                                                                             *    false to remove the handler.
                                                                                                                                                                                                                                                                                                                                                                                                             */
  bool _saslSessionCb(xml.XmlElement elem) {
    if (elem.getAttribute("type") == "result") {
      this.authenticated = true;
      this._changeConnectStatus(Strophe.Status['CONNECTED'], null);
    } else if (elem.getAttribute("type") == "error") {
      Strophe.info("Session creation failed.");
      this._changeConnectStatus(Strophe.Status['AUTHFAIL'], null, elem);
      return false;
    }
    return false;
  }

  /** PrivateFunction: _saslFailureCb
                                                                                                                                                                                                                                                                                                                                                                                                             *  _Private_ handler for SASL authentication failure.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                                             *    (XMLElement) elem - The matching stanza.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Returns:
                                                                                                                                                                                                                                                                                                                                                                                                             *    false to remove the handler.
                                                                                                                                                                                                                                                                                                                                                                                                             */
  /* jshint unused:false */
  _saslFailureCb([xml.XmlElement elem]) {
    // delete unneeded handlers
    if (this._saslSuccessHandler != null) {
      this.deleteHandler(this._saslSuccessHandler);
      this._saslSuccessHandler = null;
    }
    if (this._saslChallengeHandler != null) {
      this.deleteHandler(this._saslChallengeHandler);
      this._saslChallengeHandler = null;
    }

    if (this._saslMechanism != null) this._saslMechanism.onFailure();
    this._changeConnectStatus(Strophe.Status['AUTHFAIL'], null, elem);
    return false;
  }
  /* jshint unused:true */

  /** PrivateFunction: _auth2Cb
                                                                                                                                                                                                                                                                                                                                                                                                             *  _Private_ handler to finish legacy authentication.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  This handler is called when the result from the jabber:iq:auth
                                                                                                                                                                                                                                                                                                                                                                                                             *  <iq/> stanza is returned.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                                             *    (XMLElement) elem - The stanza this triggered the callback.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Returns:
                                                                                                                                                                                                                                                                                                                                                                                                             *    false to remove the handler.
                                                                                                                                                                                                                                                                                                                                                                                                             */
  bool _auth2Cb(xml.XmlElement elem) {
    if (elem.getAttribute("type") == "result") {
      this.authenticated = true;
      this._changeConnectStatus(Strophe.Status['CONNECTED'], null);
    } else if (elem.getAttribute("type") == "error") {
      this._changeConnectStatus(Strophe.Status['AUTHFAIL'], null, elem);
      this.disconnect('authentication failed');
    }
    return false;
  }

  /** PrivateFunction: _addSysTimedHandler
                                                                                                                                                                                                                                                                                                                                                                                                             *  _Private_ function to add a system level timed handler.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  This function is used to add a Strophe.TimedHandler for the
                                                                                                                                                                                                                                                                                                                                                                                                             *  library code.  System timed handlers are allowed to run before
                                                                                                                                                                                                                                                                                                                                                                                                             *  authentication is complete.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                                             *    (Integer) period - The period of the handler.
                                                                                                                                                                                                                                                                                                                                                                                                             *    (Function) handler - The callback function.
                                                                                                                                                                                                                                                                                                                                                                                                             */
  StanzaTimedHandler _addSysTimedHandler(int period, Function handler) {
    StanzaTimedHandler thand = Strophe.TimedHandler(period, handler);
    thand.user = false;
    this.addTimeds.add(thand);
    return thand;
  }

  /** PrivateFunction: _addSysHandler
                                                                                                                                                                                                                                                                                                                                                                                                             *  _Private_ function to add a system level stanza handler.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  This function is used to add a Strophe.Handler for the
                                                                                                                                                                                                                                                                                                                                                                                                             *  library code.  System stanza handlers are allowed to run before
                                                                                                                                                                                                                                                                                                                                                                                                             *  authentication is complete.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                                             *    (Function) handler - The callback function.
                                                                                                                                                                                                                                                                                                                                                                                                             *    (String) ns - The namespace to match.
                                                                                                                                                                                                                                                                                                                                                                                                             *    (String) name - The stanza name to match.
                                                                                                                                                                                                                                                                                                                                                                                                             *    (String) type - The stanza type attribute to match.
                                                                                                                                                                                                                                                                                                                                                                                                             *    (String) id - The stanza id attribute to match.
                                                                                                                                                                                                                                                                                                                                                                                                             */
  StanzaHandler addSysHandler(
      Function handler, String ns, String name, String type, String id) {
    return _addSysHandler(handler, ns, name, type, id);
  }

  StanzaHandler _addSysHandler(
      Function handler, String ns, String name, String type, String id) {
    StanzaHandler hand = Strophe.Handler(handler, ns, name, type, id);
    hand.user = false;
    this.addHandlers.add(hand);
    return hand;
  }

  /** PrivateFunction: _onDisconnectTimeout
                                                                                                                                                                                                                                                                                                                                                                                                             *  _Private_ timeout handler for handling non-graceful disconnection.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  If the graceful disconnect process does not complete within the
                                                                                                                                                                                                                                                                                                                                                                                                             *  time allotted, this handler finishes the disconnect anyway.
                                                                                                                                                                                                                                                                                                                                                                                                             *
                                                                                                                                                                                                                                                                                                                                                                                                             *  Returns:
                                                                                                                                                                                                                                                                                                                                                                                                             *    false to remove the handler.
                                                                                                                                                                                                                                                                                                                                                                                                             */
  bool onDisconnectTimeout() {
    return _onDisconnectTimeout();
  }

  bool _onDisconnectTimeout() {
    this._changeConnectStatus(Strophe.Status['CONNTIMEOUT'], null);
    this._proto.onDisconnectTimeout();
    // actually disconnect
    this._doDisconnect();
    return false;
  }

  /** PrivateFunction: _onIdle
                                                                                                                                                                                                                                                                                                                                                                                                                     *  _Private_ handler to process events during idle cycle.
                                                                                                                                                                                                                                                                                                                                                                                                                     *
                                                                                                                                                                                                                                                                                                                                                                                                                     *  This handler is called every 100ms to fire timed handlers this
                                                                                                                                                                                                                                                                                                                                                                                                                     *  are ready and keep poll requests going.
                                                                                                                                                                                                                                                                                                                                                                                                                     */
  onIdle() {
    this._onIdle();
  }

  _onIdle() {
    int i;
    int since;
    List<StanzaTimedHandler> newList;
    StanzaTimedHandler thand;
    // add timed handlers scheduled for addition
    // NOTE: we add before remove in the case a timed handler is
    // added and then deleted before the next _onIdle() call.
    while (this.addTimeds.length > 0) {
      this.timedHandlers.add(this.addTimeds.removeLast());
    }

    // remove timed handlers this have been scheduled for deletion
    while (this.removeTimeds.length > 0) {
      thand = this.removeTimeds.removeLast();
      i = this.timedHandlers.indexOf(thand);
      if (i >= 0) {
        this.timedHandlers.removeAt(i);
      }
    }

    // call ready timed handlers
    int now = new DateTime.now().millisecondsSinceEpoch;
    newList = [];
    for (i = 0; i < this.timedHandlers.length; i++) {
      thand = this.timedHandlers[i];
      if (this.authenticated || !thand.user) {
        since = thand.lastCalled + thand.period;
        if (since - now <= 0) {
          if (thand.run()) {
            newList.add(thand);
          }
        } else {
          newList.add(thand);
        }
      }
    }
    this.timedHandlers = newList;

    this._idleTimeout.cancel();

    this._proto.onIdle();
    // reactivate the timer only if connected
    if (this.connected) {
      // XXX: setTimeout should be called only with function expressions (23974bc1)
      this._idleTimeout = new Timer(new Duration(milliseconds: 100), () {
        this._onIdle();
      });
    }
  }
}

/** Class: Strophe.SASLMechanism
                                                                                                                                                                                                                                                                                                                                                                                                                                 *
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  encapsulates SASL authentication mechanisms.
                                                                                                                                                                                                                                                                                                                                                                                                                                 *
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  User code may override the priority for each mechanism or disable it completely.
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  See <priority> for information about changing priority and <test> for informatian on
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  how to disable a mechanism.
                                                                                                                                                                                                                                                                                                                                                                                                                                 *
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  By default, all mechanisms are enabled and the priorities are
                                                                                                                                                                                                                                                                                                                                                                                                                                 *
                                                                                                                                                                                                                                                                                                                                                                                                                                 *      OAUTHBEARER - 60
                                                                                                                                                                                                                                                                                                                                                                                                                                 *      SCRAM-SHA1 - 50
                                                                                                                                                                                                                                                                                                                                                                                                                                 *      DIGEST-MD5 - 40
                                                                                                                                                                                                                                                                                                                                                                                                                                 *      PLAIN - 30
                                                                                                                                                                                                                                                                                                                                                                                                                                 *      ANONYMOUS - 20
                                                                                                                                                                                                                                                                                                                                                                                                                                 *      EXTERNAL - 10
                                                                                                                                                                                                                                                                                                                                                                                                                                 *
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  See: Strophe.Connection.addSupportedSASLMechanisms
                                                                                                                                                                                                                                                                                                                                                                                                                                 */

/**
                                                                                                                                                                                                                                                                                                                                                                                                                                 * PrivateConstructor: Strophe.SASLMechanism
                                                                                                                                                                                                                                                                                                                                                                                                                                 * SASL auth mechanism abstraction.
                                                                                                                                                                                                                                                                                                                                                                                                                                 *
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                                                                 *    (String) name - SASL Mechanism name.
                                                                                                                                                                                                                                                                                                                                                                                                                                 *    (Boolean) isClientFirst - If client should send response first without challenge.
                                                                                                                                                                                                                                                                                                                                                                                                                                 *    (Number) priority - Priority.
                                                                                                                                                                                                                                                                                                                                                                                                                                 *
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  Returns:
                                                                                                                                                                                                                                                                                                                                                                                                                                 *    A new Strophe.SASLMechanism object.
                                                                                                                                                                                                                                                                                                                                                                                                                                 */
class StropheSASLMechanism {
  String name;

  bool isClientFirst;

  num priority;

  StropheConnection _connection;

  StropheSASLMechanism(String name, bool isClientFirst, num priority) {
    /** PrivateVariable: name
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Mechanism name.
                                                                                                                                                                                                                                                                                                                                                                                                                                   */
    this.name = name;
    /** PrivateVariable: isClientFirst
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  If client sends response without initial server challenge.
                                                                                                                                                                                                                                                                                                                                                                                                                                   */
    this.isClientFirst = isClientFirst;
    /** Variable: priority
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Determines which <SASLMechanism> is chosen for authentication (Higher is better).
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Users may override this to prioritize mechanisms differently.
                                                                                                                                                                                                                                                                                                                                                                                                                                   *
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  In the default configuration the priorities are
                                                                                                                                                                                                                                                                                                                                                                                                                                   *
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  SCRAM-SHA1 - 40
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  DIGEST-MD5 - 30
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Plain - 20
                                                                                                                                                                                                                                                                                                                                                                                                                                   *
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Example: (This will cause Strophe to choose the mechanism this the server sent first)
                                                                                                                                                                                                                                                                                                                                                                                                                                   *
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  > Strophe.SASLMD5.priority = Strophe.SASLSHA1.priority;
                                                                                                                                                                                                                                                                                                                                                                                                                                   *
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  See <SASL mechanisms> for a list of available mechanisms.
                                                                                                                                                                                                                                                                                                                                                                                                                                   *
                                                                                                                                                                                                                                                                                                                                                                                                                                   */
    this.priority = priority;
  }
  bool test(StropheConnection connection) {
    return true;
  }
  /* jshint unused:true */

  /** PrivateFunction: onStart
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Called before starting mechanism on some connection.
                                                                                                                                                                                                                                                                                                                                                                                                                                   *
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                                                                   *    (Strophe.Connection) connection - Target Connection.
                                                                                                                                                                                                                                                                                                                                                                                                                                   */
  void onStart(StropheConnection connection) {
    this._connection = connection;
  }

  /** PrivateFunction: onChallenge
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Called by protocol implementation on incoming challenge. If client is
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  first (isClientFirst === true) challenge will be null on the first call.
                                                                                                                                                                                                                                                                                                                                                                                                                                   *
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Parameters:
                                                                                                                                                                                                                                                                                                                                                                                                                                   *    (Strophe.Connection) connection - Target Connection.
                                                                                                                                                                                                                                                                                                                                                                                                                                   *    (String) challenge - current challenge to handle.
                                                                                                                                                                                                                                                                                                                                                                                                                                   *
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Returns:
                                                                                                                                                                                                                                                                                                                                                                                                                                   *    (String) Mechanism response.
                                                                                                                                                                                                                                                                                                                                                                                                                                   */
  /* jshint unused:false */
  Future<String> onChallenge(StropheConnection connection,
      [String challenge, String testCnonce]) {
    throw {'message': "You should implement challenge handling!"};
  }
  /* jshint unused:true */

  /** PrivateFunction: onFailure
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Protocol informs mechanism implementation about SASL failure.
                                                                                                                                                                                                                                                                                                                                                                                                                                   */
  void onFailure() {
    this._connection = null;
  }

  /** PrivateFunction: onSuccess
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Protocol informs mechanism implementation about SASL success.
                                                                                                                                                                                                                                                                                                                                                                                                                                   */
  void onSuccess() {
    this._connection = null;
  }
}
/** Constants: SASL mechanisms
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Available authentication mechanisms
                                                                                                                                                                                                                                                                                                                                                                                                                                   *
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Strophe.SASLAnonymous - SASL ANONYMOUS authentication.
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Strophe.SASLPlain - SASL PLAIN authentication.
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Strophe.SASLMD5 - SASL DIGEST-MD5 authentication
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Strophe.SASLSHA1 - SASL SCRAM-SHA1 authentication
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Strophe.SASLOAuthBearer - SASL OAuth Bearer authentication
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Strophe.SASLExternal - SASL EXTERNAL authentication
                                                                                                                                                                                                                                                                                                                                                                                                                                   *  Strophe.SASLXOAuth2 - SASL X-OAuth2 authentication
                                                                                                                                                                                                                                                                                                                                                                                                                                   */

// Building SASL callbacks

/** PrivateConstructor: SASLAnonymous
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  SASL ANONYMOUS authentication.
                                                                                                                                                                                                                                                                                                                                                                                                                                 */
class StropheSASLAnonymous extends StropheSASLMechanism {
  StropheSASLAnonymous() : super("ANONYMOUS", false, 20);
  bool test(StropheConnection connection) {
    return connection.authcid == null;
  }
}
/** PrivateConstructor: SASLPlain
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  SASL PLAIN authentication.
                                                                                                                                                                                                                                                                                                                                                                                                                                 */

class StropheSASLPlain extends StropheSASLMechanism {
  //StropheSASLPlain() : super("PLAIN", true, 50);
  StropheSASLPlain() : super("PLAIN", true, 90);
  bool test(StropheConnection connection) {
    return connection.authcid != null;
  }

  Future<String> onChallenge(StropheConnection connection,
      [String challenge, dynamic testCnonce]) async {
    String authStr = connection.authzid;
    authStr = authStr + "\u0000";
    authStr = authStr + connection.authcid;
    authStr = authStr + "\u0000";
    authStr = authStr + connection.pass;
    return Utils.utf16to8(authStr);
  }
}

/** PrivateConstructor: SASLSHA1
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  SASL SCRAM SHA 1 authentication.
                                                                                                                                                                                                                                                                                                                                                                                                                                 */
class StropheSASLSHA1 extends StropheSASLMechanism {
  static bool first = false;
  StropheSASLSHA1() : super("SCRAM-SHA-1", true, 70);
  bool test(StropheConnection connection) {
    return connection.authcid != null;
  }

  Future<String> onChallenge(StropheConnection connection,
      [String challenge, String testCnonce]) async {
    if (first && challenge != null && challenge.isNotEmpty)
      return await this._onChallenge(connection, challenge);
    Random random = new Random();
    String cnonce = testCnonce ??
        await MD5.hexdigest((random.nextDouble() * 1234567890).toString());
    String authStr = "n=" + Utils.utf16to8(connection.authcid);
    authStr += ",r=";
    authStr += cnonce;
    connection._saslData['cnonce'] = cnonce;
    connection._saslData["client-first-message-bare"] = authStr;

    authStr = "n,," + authStr;

    first = true;
    return authStr;
  }

  Future<String> _onChallenge(
      StropheConnection connection, String challenge) async {
    String nonce, salt, iter;
    List<int> hi, U, uOld;
    String serverKey, pass;
    List clientKey, clientSignature;
    String responseText = "c=biws,";
    String authMessage = connection._saslData["client-first-message-bare"] +
        "," +
        challenge +
        ",";
    String cnonce = connection._saslData['cnonce'];
    RegExp attribMatch = new RegExp(r"([a-z]+)=([^,]+)(,|$)");
    while (attribMatch.hasMatch(challenge)) {
      Match match = attribMatch.firstMatch(challenge);
      challenge = challenge.replaceAll(match.group(0), "");
      switch (match.group(1)) {
        case "r":
          nonce = match.group(2);
          break;
        case "s":
          salt = match.group(2);
          break;
        case "i":
          iter = match.group(2);
          break;
      }
    }

    if (nonce.substring(0, cnonce.length) != cnonce) {
      connection._saslData = {};
      return connection._saslFailureCb();
    }

    responseText += "r=" + nonce;
    authMessage += responseText;
    salt = new String.fromCharCodes(base64.decode(salt));
    salt += "\x00\x00\x00\x01";
    pass = Utils.utf16to8(connection.pass);
    hi = await SHA1.core_hmac_sha1(pass, salt);
    uOld = hi;
    String s;
    int parseInt = int.parse(iter, radix: 10);
    for (int i = 1; i < parseInt; i++) {
      s = await SHA1.binb2str(uOld);
      U = await SHA1.core_hmac_sha1(pass, s);
      for (int k = 0; k < 5; k++) {
        hi[k] ^= U[k];
      }
      uOld = U;
    }

    String hiStr = await SHA1.binb2str(hi);
    clientKey = await SHA1.core_hmac_sha1(hiStr, "Client Key");
    serverKey = await SHA1.str_hmac_sha1(hiStr, "Server Key");
    clientSignature = await SHA1.core_hmac_sha1(
        await SHA1.str_sha1(await SHA1.binb2str(clientKey)), authMessage);
    connection._saslData["server-signature"] =
        await SHA1.b64_hmac_sha1(serverKey, authMessage);
    for (int k = 0; k < 5; k++) {
      clientKey[k] ^= clientSignature[k];
    }
    String binb2str = await SHA1.binb2str(clientKey);
    responseText += ",p=" + base64.encode(binb2str.runes.toList());
    return responseText;
  }
}

/** PrivateConstructor: SASLMD5
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  SASL DIGEST MD5 authentication.
                                                                                                                                                                                                                                                                                                                                                                                                                                 */
class StropheSASLMD5 extends StropheSASLMechanism {
  static bool first = false;
  StropheSASLMD5() : super("DIGEST-MD5", false, 60);
  //StropheSASLMD5() : super("DIGEST-MD5", false, 90);
  bool test(StropheConnection connection) {
    return connection.authcid != null;
  }

  String _quote(String str) {
    return '"' +
        str
            .replaceAll(new RegExp(r"\\"), "\\\\")
            .replaceAll(new RegExp(r'"'), '\\"') +
        '"';
  }

  Future<String> onChallenge(StropheConnection connection,
      [String challenge, String testCnonce]) async {
    if (first) return "";
    if (challenge == null) challenge = '';
    //if (testCnonce == null) testCnonce = '';
    RegExp attribMatch = new RegExp(r'([a-z]+)=("[^"]+"|[^,"]+)(?:,|$)');
    String cnonce = testCnonce ??
        await MD5
            .hexdigest((new Random().nextDouble() * 1234567890).toString());
    String realm = "";
    String host;
    String nonce = "";
    String qop = "";
    Match matches;
    while (attribMatch.hasMatch(challenge)) {
      matches = attribMatch.firstMatch(challenge);
      challenge = challenge.replaceAll(matches.group(0), "");
      switch (matches.group(1)) {
        case "realm":
          realm = matches.group(2);
          break;
        case "nonce":
          nonce = matches.group(2);
          break;
        case "qop":
          qop = matches.group(2);
          break;
        case "host":
          host = matches.group(2);
          break;
      }
    }
    String digestUri = connection.servtype + "/" + connection.domain;
    if (host != null) {
      digestUri = digestUri + "/" + host;
    }

    String cred = Utils.utf16to8(
        connection.authcid + ":" + realm + ":" + this._connection.pass);
    String a1 = await MD5.hash(cred) + ":" + nonce + ":" + cnonce;
    String a2 = 'AUTHENTICATE:' + digestUri;

    String responseText = "";
    responseText += 'charset=utf-8,';
    responseText +=
        'username=' + this._quote(Utils.utf16to8(connection.authcid)) + ',';
    responseText += 'realm=' + this._quote(realm) + ',';
    responseText += 'nonce=' + this._quote(nonce) + ',';
    responseText += 'nc=00000001,';
    responseText += 'cnonce=' + this._quote(cnonce) + ',';
    responseText += 'digest-uri=' + this._quote(digestUri) + ',';
    responseText += 'response=' +
        await MD5.hexdigest(await MD5.hexdigest(a1) +
            ":" +
            nonce +
            ":00000001:" +
            cnonce +
            ":auth:" +
            await MD5.hexdigest(a2)) +
        ",";
    responseText += 'qop=auth';
    print(responseText);
    first = true;
    return responseText;
  }
}

/** PrivateConstructor: SASLOAuthBearer
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  SASL OAuth Bearer authentication.
                                                                                                                                                                                                                                                                                                                                                                                                                                 */
class StropheSASLOAuthBearer extends StropheSASLMechanism {
  StropheSASLOAuthBearer() : super("OAUTHBEARER", true, 40);
  bool test(StropheConnection connection) {
    return connection.pass != null;
  }

  Future<String> onChallenge(StropheConnection connection,
      [String challenge, dynamic testCnonce]) async {
    String authStr = 'n,';
    if (connection.authcid != null) {
      authStr = authStr + 'a=' + connection.authzid;
    }
    authStr = authStr + ',';
    authStr = authStr + "\u0001";
    authStr = authStr + 'auth=Bearer ';
    authStr = authStr + connection.pass;
    authStr = authStr + "\u0001";
    authStr = authStr + "\u0001";

    return Utils.utf16to8(authStr);
  }
}

/** PrivateConstructor: SASLExternal
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  SASL EXTERNAL authentication.
                                                                                                                                                                                                                                                                                                                                                                                                                                 *
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  The EXTERNAL mechanism allows a client to request the server to use
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  credentials established by means external to the mechanism to
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  authenticate the client. The external means may be, for instance,
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  TLS services.
                                                                                                                                                                                                                                                                                                                                                                                                                                 */
class StropheSASLExternal extends StropheSASLMechanism {
  StropheSASLExternal() : super("EXTERNAL", true, 10);
  Future<String> onChallenge(StropheConnection connection,
      [String challenge, dynamic testCnonce]) async {
    /** According to XEP-178, an authzid SHOULD NOT be presented when the
                                                                                                                                                                                                                                                                                                                                                                                                                                     * authcid contained or implied in the client certificate is the JID (i.e.
                                                                                                                                                                                                                                                                                                                                                                                                                                     * authzid) with which the user wants to log in as.
                                                                                                                                                                                                                                                                                                                                                                                                                                     *
                                                                                                                                                                                                                                                                                                                                                                                                                                     * To NOT send the authzid, the user should therefore set the authcid equal
                                                                                                                                                                                                                                                                                                                                                                                                                                     * to the JID when instantiating a new Strophe.Connection object.
                                                                                                                                                                                                                                                                                                                                                                                                                                     */
    return connection.authcid == connection.authzid ? '' : connection.authzid;
  }
}

/** PrivateConstructor: SASLXOAuth2
                                                                                                                                                                                                                                                                                                                                                                                                                                 *  SASL X-OAuth2 authentication.
                                                                                                                                                                                                                                                                                                                                                                                                                                 */
class StropheSASLXOAuth2 extends StropheSASLMechanism {
  StropheSASLXOAuth2() : super("X-OAUTH2", true, 30);
  bool test(StropheConnection connection) {
    return connection.pass != null;
  }

  Future<String> onChallenge(StropheConnection connection,
      [String challenge, dynamic testCnonce]) async {
    String authStr = '\u0000';
    if (connection.authcid != null) {
      authStr = authStr + connection.authzid;
    }
    authStr = authStr + "\u0000";
    authStr = authStr + connection.pass;

    return Utils.utf16to8(authStr);
  }
}

abstract class ServiceType {
  StropheConnection _conn;
  StropheConnection get conn {
    return this._conn;
  }

  String strip;
  reset();
  connect([int wait, int hold, String route]);

  void attach(String jid, String sid, int rid, Function callback, int wait,
      int hold, int wind) {}

  void restore(String jid, Function callback, int wait, int hold, int wind) {}

  void send() {}

  void sendRestart() {}

  void disconnect(xml.XmlElement pres) {}

  void abortAllRequests() {}

  void doDisconnect() {}

  xml.XmlElement reqToData(dynamic req) {
    return null;
  }

  bool emptyQueue() {
    return true;
  }

  connectCb(xml.XmlElement bodyWrap) {}

  void onDisconnectTimeout() {}

  void onIdle() {}
}
