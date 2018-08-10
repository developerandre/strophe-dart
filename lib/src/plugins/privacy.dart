import 'package:strophe/src/core.dart';
import 'package:strophe/src/enums.dart';
import 'package:strophe/src/plugins/plugins.dart';
import 'package:xml/xml.dart';

class PrivacyPlugin extends PluginClass {
  /** Variable: lists
   *  Available privacy lists
   */
  Map<String, PrivacyList> lists = {};
  /** PrivateVariable: _default
   *  Default privacy list
   */
  String _default = null;
  /** PrivateVariable: _active
   *  Active privacy list
   */
  String _active = null;
  /** PrivateVariable: _isInitialized
   *  If lists were pulled from the server, and plugin is ready to work with those.
   */
  bool _isInitialized = false;
  Function _listChangeCallback;
  init(StropheConnection conn) {
    this.connection = conn;
    this._listChangeCallback = null;
    Strophe.addNamespace('PRIVACY', "jabber:iq:privacy");
  }

  bool isInitialized() {
    return this._isInitialized;
  }

  /** Function: getListNames
   *  Initial call to get all list names.
   *
   *  This has to be called before any actions with lists. This is separated from init method, to be able to put
   *  callbacks on the success and fail events.
   *
   *  Params:
   *    (Function) successCallback - Called upon successful deletion.
   *    (Function) failCallback - Called upon fail deletion.
   *    (Function) listChangeCallback - Called upon list change.
   */
  getListNames(
      [Function successCallback,
      Function failCallback,
      Function listChangeCallback]) {
    this._listChangeCallback = listChangeCallback;
    this.connection.sendIQ(
        Strophe.$iq({
          'type': "get",
          'id': this.connection.getUniqueId("privacy")
        }).c("query", {'xmlns': Strophe.NS['PRIVACY']}).tree(),
        (XmlNode element) {
      XmlElement stanza;
      if (element is XmlDocument)
        stanza = element.rootElement;
      else
        stanza = element as XmlElement;
      Map<String, PrivacyList> _lists = this.lists;
      this.lists = {};
      List<XmlElement> listNames = stanza.findAllElements("list").toList();
      for (int i = 0; i < listNames.length; ++i) {
        String listName = listNames[i].getAttribute("name");
        if (_lists[listName] != null)
          this.lists[listName] = _lists[listName];
        else
          this.lists[listName] = new PrivacyList(listName, false);
        this.lists[listName]._isPulled = false;
      }
      List<XmlElement> activeNode = stanza.findAllElements("active").toList();
      if (activeNode.length == 1)
        this._active = activeNode[0].getAttribute("name");
      List<XmlElement> defaultNode = stanza.findAllElements("default").toList();
      if (defaultNode.length == 1)
        this._default = defaultNode[0].getAttribute("name");
      this._isInitialized = true;
      if (successCallback != null)
        try {
          successCallback();
        } catch (e) {
          Strophe.error(
              "Error while processing callback privacy list names pull.");
        }
    }, failCallback);
  }

  /** Function: newList
   *  Create new named list.
   *
   *  Params:
   *    (String) name - New List name.
   *
   *  Returns:
   *    New list, or existing list if it exists.
   */
  PrivacyList newList(String name) {
    if (this.lists[name] == null)
      this.lists[name] = new PrivacyList(name, true);
    return this.lists[name];
  }

  /** Function: newItem
   *  Create new item.
   *
   *  Params:
   *    (String) type - Type of item.
   *    (String) value - Value of item.
   *    (String) action - Action for the matching.
   *    (String) order - Order of rule.
   *    (String) blocked - Block list.
   *
   *  Returns:
   *    New list, or existing list if it exists.
   */
  PrivacyItem newItem(String type, String value, String action, int order,
      List<String> blocked) {
    PrivacyItem item = new PrivacyItem();
    item.type = type;
    item.value = value;
    item.action = action;
    item.order = order;
    item.blocked = blocked;
    return item;
  }

  /** Function: deleteList
   *  Delete list.
   *
   *  Params:
   *    (String) name - List name.
   *    (Function) successCallback - Called upon successful deletion.
   *    (Function) failCallback - Called upon fail deletion.
   */
  deleteList(String name, Function successCallback, Function failCallback) {
    name = name ?? '';
    this.connection.sendIQ(
        Strophe.$iq({
          'type': "set",
          'id': this.connection.getUniqueId("privacy")
        }).c("query", {'xmlns': Strophe.NS['PRIVACY']}).c(
            "list", {'name': name}).tree(), () {
      this.lists.remove(name);
      if (successCallback != null)
        try {
          successCallback();
        } catch (e) {
          Strophe.error("Exception while running callback after removing list");
        }
    }, failCallback);
  }

  /** Function: saveList
   *  Saves list.
   *
   *  Params:
   *    (String) name - List name.
   *    (Function) successCallback - Called upon successful setting.
   *    (Function) failCallback - Called upon fail setting.
   *
   *  Returns:
   *    True if list is ok, and is sent to server, false otherwise.
   */
  saveList(String name, [Function successCallback, Function failCallback]) {
    if (this.lists[name] == null) {
      Strophe.error("Trying to save uninitialized list");
      //throw {'error': "List not found"};
      this.newList(name);
    }
    PrivacyList listModel = this.lists[name];
    if (!listModel.validate()) return false;
    StanzaBuilder listIQ = Strophe
        .$iq({'type': "set", 'id': this.connection.getUniqueId("privacy")});
    StanzaBuilder list = listIQ
        .c("query", {'xmlns': Strophe.NS['PRIVACY']}).c("list", {'name': name});

    int count = listModel.items.length;
    for (int i = 0; i < count; ++i) {
      PrivacyItem item = listModel.items[i];
      StanzaBuilder itemNode = list
          .c("item", {'action': item.action, 'order': item.order.toString()});
      if (item.type != "")
        itemNode.attrs({'type': item.type, 'value': item.value});
      if (item.blocked != null && item.blocked.length > 0) {
        int blockCount = item.blocked.length;
        for (int j = 0; j < blockCount; ++j) itemNode.c(item.blocked[j]).up();
      }
      itemNode.up();
    }
    this.connection.sendIQ(listIQ.tree(), () {
      listModel._isPulled = true;
      if (successCallback != null)
        try {
          successCallback();
        } catch (e) {
          Strophe.error("Exception in callback when saving list " + name);
        }
    }, failCallback);
    return true;
  }

  /** Function: loadList
   *  Loads list from server
   *
   *  Params:
   *    (String) name - List name.
   *    (Function) successCallback - Called upon successful load.
   *    (Function) failCallback - Called upon fail load.
   */
  loadList(String name, [Function successCallback, Function failCallback]) {
    name = name ?? '';
    this.connection.sendIQ(
        Strophe.$iq({
          'type': "get",
          'id': this.connection.getUniqueId("privacy")
        }).c("query", {'xmlns': Strophe.NS['PRIVACY']}).c(
            "list", {'name': name}).tree(), (XmlNode element) {
      XmlElement stanza;
      if (element is XmlDocument)
        stanza = element.rootElement;
      else
        stanza = element as XmlElement;
      List<XmlElement> lists = stanza.findAllElements("list").toList();
      int listsSize = lists.length;
      for (int i = 0; i < listsSize; ++i) {
        XmlElement list = lists[i];
        PrivacyList listModel = this.newList(list.getAttribute("name"));
        listModel.items = [];
        List<XmlElement> items = list.findAllElements("item").toList();
        int itemsSize = items.length;
        for (int j = 0; j < itemsSize; ++j) {
          XmlElement item = items[j];
          List<String> blocks = [];
          List<XmlNode> blockNodes = item.children;
          int nodesSize = blockNodes.length;
          for (int k = 0; k < nodesSize; ++k)
            blocks.add((blockNodes[k] as XmlElement).name.qualified);
          listModel.items.add(this.newItem(
              item.getAttribute('type'),
              item.getAttribute('value'),
              item.getAttribute('action'),
              int.parse(item.getAttribute('order')) ?? 0,
              blocks));
        }
      }
      this.lists[name];
      if (successCallback != null)
        try {
          successCallback();
        } catch (e) {
          Strophe.error("Exception while running callback after loading list");
        }
    }, failCallback);
  }

  /** Function: setActive
   *  Sets given list as active.
   *
   *  Params:
   *    (String) name - List name.
   *    (Function) successCallback - Called upon successful setting.
   *    (Function) failCallback - Called upon fail setting.
   */
  setActive(String name, [Function successCallback, Function failCallback]) {
    StanzaBuilder iq = Strophe
        .$iq({'type': "set", 'id': this.connection.getUniqueId("privacy")}).c(
            "query", {'xmlns': Strophe.NS['PRIVACY']}).c("active");
    if (name != null && name.isNotEmpty) iq.attrs({'name': name});
    this.connection.sendIQ(iq.tree(), () {
      this._active = name;
      if (successCallback != null)
        try {
          successCallback();
        } catch (e) {
          Strophe.error(
              "Exception while running callback after setting active list");
        }
    }, failCallback);
  }

  /** Function: getActive
   *  Returns currently active list of null.
   */
  String getActive() {
    return this._active;
  }

  /** Function: setDefault
   *  Sets given list as default.
   *
   *  Params:
   *    (String) name - List name.
   *    (Function) successCallback - Called upon successful setting.
   *    (Function) failCallback - Called upon fail setting.
   */
  setDefault(String name, [Function successCallback, Function failCallback]) {
    StanzaBuilder iq = Strophe
        .$iq({'type': "set", 'id': this.connection.getUniqueId("privacy")}).c(
            "query", {'xmlns': Strophe.NS['PRIVACY']}).c("default");
    if (name != null && name.isNotEmpty) iq.attrs({'name': name});
    this.connection.sendIQ(iq.tree(), () {
      this._default = name;
      if (successCallback != null)
        try {
          successCallback();
        } catch (e) {
          Strophe.error(
              "Exception while running callback after setting default list");
        }
    }, failCallback);
  }

  /** Function: getDefault
   *  Returns currently default list of null.
   */
  String getDefault() {
    return this._default;
  }
}

/**
 * Class: PrivacyItem
 * Describes single rule.
 */
class PrivacyItem {
  /** Variable: type
   *  One of [jid, group, subscription].
   */
  String type;
  String value;
  /** Variable: action
   *  One of [allow, deny].
   *
   *  Not null. Action to be execute.
   */
  String action;
  /** Variable: order
   *  The order in which privacy list items are processed.
   *
   *  Unique, not-null, non-negative integer.
   */
  int order;
  /** Variable: blocked
   *  List of blocked stanzas.
   *
   *  One or more of [message, iq, presence-in, presence-out]. Empty set is equivalent to all.
   */
  List<String> blocked = [];
  /** Function: validate
 *  Checks if item is of valid structure
 */
  bool validate() {
    if (["jid", "group", "subscription", ""].indexOf(this.type) < 0)
      return false;
    if (this.type == "subscription") {
      if (["both", "to", "from", "none"].indexOf(this.value) < 0) return false;
    }
    if (["allow", "deny"].indexOf(this.action) < 0) return false;
    bool hasMatch = new RegExp(r"^\d+$").hasMatch(this.order.toString());
    if (this.order == 0 || !hasMatch) return false;
    if (this.blocked.length > 0) {
      //if(typeof(this.blocked) != "object") return false;
      List<String> possibleBlocks = [
        "message",
        "iq",
        "presence-in",
        "presence-out"
      ];
      int blockCount = this.blocked.length;
      for (int i = 0; i < blockCount; ++i) {
        if (possibleBlocks.indexOf(this.blocked[i]) < 0) return false;
        possibleBlocks.remove(this.blocked[i]);
      }
    }
    return true;
  }

/** Function: copy
 *  Copy one item into another.
 */
  copy(PrivacyItem item) {
    this.type = item.type;
    this.value = item.value;
    this.action = item.action;
    this.order = item.order;
    this.blocked = item.blocked.getRange(0, item.blocked.length).toList();
  }
}

/**
 * Class: List
 * Contains list of rules. There is no layering.
 */
class PrivacyList {
  PrivacyList(this._name, this._isPulled);
  /** PrivateVariable: _name
   *  List name.
   *
   *  Not changeable. Create new, copy this one, and delete, if you wish to rename.
   */
  String _name;
  /** PrivateVariable: _isPulled
   *  If list is pulled from server and up to date.
   *
   *  Is false upon first getting of list of lists, or after getting stanza about update
   */
  bool _isPulled;
  /** Variable: items
   *  Items of this list.
   */
  List<PrivacyItem> items = [];
  /** Function: getName
 *  Returns list name
 */
  String getName() {
    return this._name;
  }

/** Function: isPulled
 *  If list is pulled from server.
 *
 * This is false for list names just taken from server. you need to make loadList to see all the contents of the list.
 * Also this is possible when list was changed somewhere else, and you've got announcement about update. Same loadList
 * is your savior.
 */
  bool isPulled() {
    return this._isPulled;
  }

/** Function: validate
 *  Checks if list is of valid structure
 */
  bool validate() {
    List<int> orders = [];
    this.items = this.items.where((PrivacyItem item) {
      return item != null;
    }).toList();
    int itemCount = this.items.length;
    for (int i = 0; i < itemCount; ++i) {
      if (this.items[i] == null || !this.items[i].validate()) return false;
      if (orders.indexOf(this.items[i].order) >= 0) return false;
      orders.add(this.items[i].order);
    }
    return true;
  }

/** Function: copy
 *  Copy all items of one list into another.
 *
 *  Params:
 *    (List) list - list to copy items from.
 */
  copy(PrivacyList list) {
    this.items = [];
    int l = list.items.length;
    for (int i = 0; i < l; ++i) {
      this.items[i] = new PrivacyItem();
      this.items[i].copy(list.items[i]);
    }
  }
}
