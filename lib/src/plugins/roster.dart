import 'package:strophe/src/core.dart';
import 'package:strophe/src/enums.dart';
import 'package:strophe/src/plugins/plugins.dart';
import 'package:xml/xml.dart' as xml;
import 'package:xml/xml/nodes/element.dart';

class RosterPlugin extends PluginClass {
  List<Function> _callbacks;

  List<Function> _callbacksRequest;

  List<RosterItem> items;

  String ver;

  init(StropheConnection conn) {
    this.connection = conn;
    this._callbacks = [];
    this._callbacksRequest = [];

    /** Property: items
         * Roster items
         * [
         *    {
         *        name         : "",
         *        jid          : "",
         *        subscription : "",
         *        ask          : "",
         *        groups       : ["", ""],
         *        resources    : {
         *            myresource : {
         *                show   : "",
         *                status : "",
         *                priority : ""
         *            }
         *        }
         *    }
         * ]
         */

    /** Property: ver
         * current roster revision
         * always null if server doesn't support xep 237
         */

    // Override the connect and attach methods to always add presence and roster handlers.
    // They are removed when the connection disconnects, so must be added on connection.
    Function oldCallback;
    Function _connect = conn.connect;
    Function _attach = conn.attach;
    Function newCallback = (int status, condition, ele) {
      if (status == Strophe.Status['ATTACHED'] ||
          status == Strophe.Status['CONNECTED']) {
        try {
          // Presence subscription
          conn.addHandler(
              this._onReceivePresence, null, 'presence', null, null, null);
          conn.addHandler(
              this._onReceiveIQ, Strophe.NS['ROSTER'], 'iq', "set", null, null);
        } catch (e) {
          Strophe.error(e);
        }
      }
      if (oldCallback != null && oldCallback is Function) {
        oldCallback(status, condition, ele);
      }
    };
    conn.connect = (String jid, String pass, Function callback,
        [int wait, int hold, String route, String authcid]) {
      oldCallback = callback;
      callback = newCallback;
      _connect(jid, pass, callback, wait, hold, route, authcid);
    };
    conn.attach = (String jid, String sid, int rid, Function callback, int wait,
        int hold, int wind) {
      oldCallback = callback;
      callback = newCallback;
      _attach(jid, sid, rid, callback, wait, hold, wind);
    };

    Strophe.addNamespace('ROSTER_VER', 'urn:xmpp:features:rosterver');
    Strophe.addNamespace('NICK', 'http://jabber.org/protocol/nick');
  }

  /** Function: supportVersioning
     * return true if roster versioning is enabled on server
     */
  bool supportVersioning() {
    return (this.connection.features != null &&
        this.connection.features.findAllElements('ver').length > 0);
  }

  /** Function: get
     * Get Roster on server
     *
     * Parameters:
     *   (Function) userCallback - callback on roster result
     *   (String) ver - current rev of roster
     *      (only used if roster versioning is enabled)
     *   (Array) items - initial items of ver
     *      (only used if roster versioning is enabled)
     *     In browser context you can use sessionStorage
     *     to store your roster in json (JSON.stringify())
     */
  get(Function userCallback, [String ver, List items]) {
    Map<String, String> attrs = {'xmlns': Strophe.NS['ROSTER']};
    this.items = [];
    if (this.supportVersioning()) {
      // empty rev because i want an rev attribute in the result
      attrs['ver'] = ver ?? '';
      this.items = items ?? [];
    }
    StanzaBuilder iq = Strophe
        .$iq({'type': 'get', 'id': this.connection.getUniqueId('roster')}).c(
            'query', attrs);
    return this.connection.sendIQ(iq.tree(), (XmlElement stanza) {
      this._onReceiveRosterSuccess(userCallback, stanza);
    }, (XmlElement stanza) {
      this._onReceiveRosterError(userCallback, stanza);
    });
  }

  /** Function: registerCallback
     * register callback on roster (presence and iq)
     *
     * Parameters:
     *   (Function) callback
     */
  registerCallback(Function callback) {
    if (callback != null) this._callbacks.add(callback);
  }

  registerRequestCallback(Function callback) {
    if (callback != null) this._callbacksRequest.add(callback);
  }

  /** Function: findItem
     * Find item by JID
     *
     * Parameters:
     *     (String) jid
     */
  RosterItem findItem(String jid) {
    if (this.items != null) {
      for (int i = 0; i < this.items.length; i++) {
        if (this.items[i] != null && this.items[i].jid == jid) {
          return this.items[i];
        }
      }
    }
    return null;
  }

  /** Function: removeItem
     * Remove item by JID
     *
     * Parameters:
     *     (String) jid
     */
  bool removeItem(String jid) {
    for (int i = 0; i < this.items.length; i++) {
      if (this.items[i] != null && this.items[i].jid == jid) {
        this.items.remove(i);
        return true;
      }
    }
    return false;
  }

  /** Function: subscribe
     * Subscribe presence
     *
     * Parameters:
     *     (String) jid
     *     (String) message (optional)
     *     (String) nick  (optional)
     */
  subscribe(String jid, [String message, String nick]) {
    StanzaBuilder pres = Strophe.$pres({'to': jid, 'type': "subscribe"});
    if (message != null && message != "") {
      pres.c("status").t(message).up();
    }
    if (nick != null && nick != "") {
      pres.c('nick', {'xmlns': Strophe.NS['NICK']}).t(nick).up();
    }
    this.connection.send(pres);
  }

  /** Function: unsubscribe
     * Unsubscribe presence
     *
     * Parameters:
     *     (String) jid
     *     (String) message
     */
  unsubscribe(String jid, [String message]) {
    StanzaBuilder pres = Strophe.$pres({'to': jid, 'type': "unsubscribe"});
    if (message != null && message != "") pres.c("status").t(message);
    this.connection.send(pres);
  }

  /** Function: authorize
     * Authorize presence subscription
     *
     * Parameters:
     *     (String) jid
     *     (String) message
     */
  authorize(String jid, [String message]) {
    StanzaBuilder pres = Strophe.$pres({'to': jid, 'type': "subscribed"});
    if (message != null && message != "") pres.c("status").t(message);
    this.connection.send(pres);
  }

  /** Function: unauthorize
     * Unauthorize presence subscription
     *
     * Parameters:
     *     (String) jid
     *     (String) message
     */
  unauthorize(String jid, [String message]) {
    StanzaBuilder pres = Strophe.$pres({'to': jid, 'type': "unsubscribed"});
    if (message != null && message != "") pres.c("status").t(message);
    this.connection.send(pres);
  }

  /** Function: add
     * Add roster item
     *
     * Parameters:
     *   (String) jid - item jid
     *   (String) name - name
     *   (Array) groups
     *   (Function) callback
     */
  add(String jid, String name, [List<String> groups, Function callback]) {
    StanzaBuilder iq = Strophe
        .$iq({'type': 'set'}).c('query', {'xmlns': Strophe.NS['ROSTER']}).c(
            'item', {'jid': jid, 'name': name});
    if (groups != null) {
      for (int i = 0; i < groups.length; i++) {
        iq.c('group').t(groups[i]).up();
      }
    }
    this.connection.sendIQ(iq.tree(), callback, callback);
  }

  /** Function: update
     * Update roster item
     *
     * Parameters:
     *   (String) jid - item jid
     *   (String) name - name
     *   (Array) groups
     *   (Function) callback
     */
  update(String jid, String name, [List groups, Function callback]) {
    RosterItem item = this.findItem(jid);
    if (item == null) {
      throw "item not found";
    }
    String newName = name ?? item.name;
    List newGroups = groups ?? item.groups;
    StanzaBuilder iq = Strophe
        .$iq({'type': 'set'}).c('query', {'xmlns': Strophe.NS['ROSTER']}).c(
            'item', {'jid': item.jid, 'name': newName});
    for (int i = 0; i < newGroups.length; i++) {
      iq.c('group').t(newGroups[i]).up();
    }
    return this.connection.sendIQ(iq.tree(), callback, callback);
  }

  /** Function: remove
     * Remove roster item
     *
     * Parameters:
     *   (String) jid - item jid
     *   (Function) callback
     */
  remove(String jid, [Function callback]) {
    RosterItem item = this.findItem(jid);
    if (item == null) {
      throw "item not found";
    }
    StanzaBuilder iq = Strophe
        .$iq({'type': 'set'}).c('query', {'xmlns': Strophe.NS['ROSTER']}).c(
            'item', {'jid': item.jid, 'subscription': "remove"});
    this.connection.sendIQ(iq.tree(), callback, callback);
  }

  /** PrivateFunction: _onReceiveRosterSuccess
     *
     */
  _onReceiveRosterSuccess(Function userCallback, XmlElement stanza) {
    this._updateItems(stanza);
    this._call_backs(this.items);
    if (userCallback != null) {
      userCallback(this.items);
    }
  }

  /** PrivateFunction: _onReceiveRosterError
     *
     */
  _onReceiveRosterError(Function userCallback, XmlElement stanza) {
    userCallback(this.items);
  }

  /** PrivateFunction: _onReceivePresence
     * Handle presence
     */
  _onReceivePresence(xml.XmlElement presence) {
    // TODO: from is optional
    String jid = presence.getAttribute('from');
    String from = Strophe.getBareJidFromJid(jid);
    RosterItem item = this.findItem(from);
    String type = presence.getAttribute('type');
    // not in roster
    if (item == null) {
      // if 'friend request' presence
      if (type == 'subscribe') {
        this._call_backs_request(from);
      }
      return true;
    }
    if (type == 'unavailable') {
      item.resources.remove(Strophe.getResourceFromJid(jid));
    } else if (type == null || type == '') {
      // TODO: add timestamp
      item.resources[Strophe.getResourceFromJid(jid)] = {
        'show': (presence.findAllElements('show').length > 0)
            ? Strophe.getText(presence.findAllElements('show').toList()[0])
            : "",
        'status': (presence.findAllElements('status').length > 0)
            ? Strophe.getText(presence.findAllElements('status').toList()[0])
            : "",
        'priority': (presence.findAllElements('priority').length > 0)
            ? Strophe.getText(presence.findAllElements('priority').toList()[0])
            : ""
      };
    } else {
      // Stanza is not a presence notification. (It's probably a subscription type stanza.)
      return true;
    }
    this._call_backs(this.items, item);
    return true;
  }

  /** PrivateFunction: _call_backs_request
     * call all the callbacks waiting for 'friend request' presences
     */
  _call_backs_request(String from) {
    for (int i = 0; i < this._callbacksRequest.length; i++) {
      this._callbacksRequest[i](from);
    }
  }

  /** PrivateFunction: _call_backs
     * first parameter is the full roster
     * second is optional, newly added or updated item
     * third is otional, in case of update, send the previous state of the
     *  update item
     */
  _call_backs(List<RosterItem> items, [item, previousItem]) {
    for (int i = 0; i < this._callbacks.length; i++) // [].forEach my love ...
    {
      this._callbacks[i](items, item, previousItem);
    }
  }

  /** PrivateFunction: _onReceiveIQ
     * Handle roster push.
     */
  _onReceiveIQ(xml.XmlElement iq) {
    String id = iq.getAttribute('id');
    String from = iq.getAttribute('from');
    // Receiving client MUST ignore stanza unless it has no from or from = user's JID.
    if (from != null &&
        from != "" &&
        from != this.connection.jid &&
        from != Strophe.getBareJidFromJid(this.connection.jid)) return true;
    StanzaBuilder iqresult =
        Strophe.$iq({'type': 'result', 'id': id, 'from': this.connection.jid});
    this.connection.send(iqresult);
    this._updateItems(iq);
    return true;
  }

  /** PrivateFunction: _updateItems
     * Update items from iq
     */
  _updateItems(xml.XmlElement iq) {
    List<xml.XmlElement> queries = iq.findAllElements('query').toList();
    if (queries.length != 0) {
      xml.XmlElement query = queries[0];
      if (query == null) return;
      List<xml.XmlElement> listItem = query.findAllElements('item').toList();
      if (listItem.length > 0) {
        xml.XmlElement item = listItem[0];
        this.ver = item.getAttribute('ver');
      }
      Strophe.forEachChild(query, 'item', (rosterItem) {
        this._updateItem(rosterItem);
      });
    }
  }

  /** PrivateFunction: _updateItem
     * Update internal representation of roster item
     */
  _updateItem(xml.XmlElement itemTag) {
    if (itemTag == null) return;
    String jid = itemTag.getAttribute("jid");
    String name = itemTag.getAttribute("name");
    String subscription = itemTag.getAttribute("subscription");
    String ask = itemTag.getAttribute("ask");
    List<String> groups = [];

    Strophe.forEachChild(itemTag, 'group', (group) {
      groups.add(Strophe.getText(group));
    });

    if (subscription == "remove") {
      bool hashBeenRemoved = this.removeItem(jid);
      if (hashBeenRemoved) {
        this._call_backs(this.items, {'jid': jid, 'subscription': 'remove'});
      }
      return;
    }

    RosterItem item = this.findItem(jid);
    RosterItem previousItem;
    if (item == null) {
      item = new RosterItem.fromMap({
        'name': name,
        'jid': jid,
        'subscription': subscription,
        'ask': ask,
        'groups': groups,
        'resources': {}
      });
      if (this.items != null) {
        this.items.add(item);
      }
    } else {
      previousItem = new RosterItem.fromMap({
        'name': item.name,
        'subscription': item.subscription,
        'ask': item.ask,
        'groups': item.groups
      });
      item.name = name;
      item.subscription = subscription;
      item.ask = ask;
      item.groups = groups;
    }
    this._call_backs(this.items, item, previousItem);
  }
}

class RosterItem {
  String name;
  String jid;
  String subscription;
  String ask;
  List<String> groups;
  Map<dynamic, dynamic> resources;
  RosterItem.fromMap(Map map) {
    this.name = map['name'] ?? '';
    this.jid = map['jid'] ?? '';
    this.subscription = map['subscription'] ?? '';
    this.ask = map['ask'] ?? '';
    this.groups = map['groups'] ?? [];
    this.resources = map['resources'] ?? {};
  }
  /*  {
        myresource : {
            show   : "",
            status : "",
            priority : ""
        }
  } */
}
