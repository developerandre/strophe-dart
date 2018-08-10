import 'package:strophe/src/core.dart';
import 'package:strophe/src/enums.dart';
import 'package:strophe/src/plugins/plugins.dart';
import 'package:xml/xml.dart';

class MucPlugin extends PluginClass {
  /*
 *Plugin to implement the MUC extension.
   http://xmpp.org/extensions/xep-0045.html
 *Previous Author:
    Nathan Zorn <nathan.zorn@gmail.com>
 *Complete CoffeeScript rewrite:
    Andreas Guth <guth@dbis.rwth-aachen.de>
 */

  Map<String, XmppRoom> rooms = {};
  List<String> roomNames = [];
  StanzaHandler _mucHandler;
  MucPlugin _muc;
  /*Function
  Initialize the MUC plugin. Sets the correct connection object and
  extends the namesace.
   */
  MucPlugin get muc {
    return _muc;
  }

  init(StropheConnection conn) {
    this.connection = conn;
    this._mucHandler = null;
    Strophe.addNamespace('MUC_OWNER', Strophe.NS['MUC'] + "#owner");
    Strophe.addNamespace('MUC_ADMIN', Strophe.NS['MUC'] + "#admin");
    Strophe.addNamespace('MUC_USER', Strophe.NS['MUC'] + "#user");
    Strophe.addNamespace('MUC_ROOMCONF', Strophe.NS['MUC'] + "#roomconfig");
    return Strophe.addNamespace('MUC_REGISTER', "jabber:iq:register");
  }

  /*Function
  Join a multi-user chat room
  Parameters:
  (String) room - The multi-user chat room to join.
  (String) nick - The nickname to use in the chat room. Optional
  (Function) msgHandlerCb - The  call to handle messages from the
  specified chat room.
  (Function) presHandlerCb - The  call back to handle presence
  in the chat room.
  (Function) rosterCb - The  call to handle roster info in the chat room
  (String) password - The optional password to use. (password protected
  rooms only)
  (Object) history_attrs - Optional attributes for retrieving history
  (XML DOM Element) extended_presence - Optional XML for extending presence
   */
  join(String room, String nick,
      [Function msgHandlerCb,
      Function presHandlerCb,
      Function rosterCb,
      String password,
      Map<String, dynamic> historyAttrs,
      XmlNode extendedPresence]) {
    StanzaBuilder pres;
    String roomNick = this.testAppendNick(room, nick);
    pres = Strophe.$pres({'from': this.connection.jid, 'to': roomNick}).c(
        "x", {'xmlns': Strophe.NS['MUC']});
    if (historyAttrs != null) {
      pres = pres.c("history", historyAttrs).up();
    }
    if (password != null && password.isNotEmpty) {
      pres.cnode(Strophe.xmlElement("password", attrs: [], text: password));
    }
    if (extendedPresence != null) {
      pres.up().cnode(extendedPresence);
    }
    if (this._mucHandler == null) {
      this._mucHandler = this.connection.addHandler((XmlElement stanza) {
        String from = stanza.getAttribute('from');
        if (from == null || from.isEmpty) {
          return true;
        }
        String roomname = from.split("/")[0];
        if (this.rooms[roomname] != null) {
          return true;
        }
        XmppRoom roomAt = this.rooms[roomname];
        Map handlers = {};
        if (stanza.name.qualified == "message") {
          if (roomAt != null) handlers = roomAt._message_handlers;
        } else if (stanza.name.qualified == "presence") {
          List<XmlElement> xquery = stanza.findAllElements("x").toList();
          if (xquery.length > 0) {
            XmlElement x;
            String xmlns;
            for (int i = 0, len = xquery.length; i < len; i++) {
              x = xquery[i];
              xmlns = x.getAttribute("xmlns");
              if (xmlns != null &&
                  new RegExp(xmlns).hasMatch(Strophe.NS['MUC'])) {
                if (roomAt != null) handlers = roomAt._presence_handlers;
                break;
              }
            }
          }
        }
        handlers.forEach((key, value) {
          if (!value(stanza, room)) {
            handlers.remove(key);
          }
        });
        return true;
      }, null, null);
    }
    if (this.rooms[room] != null) {
      this.rooms[room] = new XmppRoom(this, room, nick, password);
      if (presHandlerCb != null) {
        this.rooms[room].addHandler('presence', presHandlerCb);
      }
      if (msgHandlerCb != null) {
        this.rooms[room].addHandler('message', msgHandlerCb);
      }
      if (rosterCb != null) {
        this.rooms[room].addHandler('roster', rosterCb);
      }
      this.roomNames.add(room);
    }
    return this.connection.send(pres);
  }

  /*Function
  Leave a multi-user chat room
  Parameters:
  (String) room - The multi-user chat room to leave.
  (String) nick - The nick name used in the room.
  (Function) handlerCb - Optional  to handle the successful leave.
  (String) exit_msg - optional exit message.
  Returns:
  iqid - The unique id for the room leave.
   */
  leave(String room, String nick, [Function handlerCb, String exitMsg]) {
    int id = this.roomNames.indexOf(room);
    this.rooms.remove(room);
    if (id >= 0) {
      this.roomNames.removeAt(id);
      if (this.roomNames.length == 0) {
        this.connection.deleteHandler(this._mucHandler);
        this._mucHandler = null;
      }
    }
    String roomNick = this.testAppendNick(room, nick);
    String presenceid = this.connection.getUniqueId();
    StanzaBuilder presence = Strophe.$pres({
      'type': "unavailable",
      'id': presenceid,
      'from': this.connection.jid,
      'to': roomNick
    });
    if (exitMsg != null) {
      presence.c("status", null, exitMsg);
    }
    if (handlerCb != null) {
      this.connection.addHandler(handlerCb, null, "presence", null, presenceid);
    }
    this.connection.send(presence);
    return presenceid;
  }

  /*Function
  Parameters:
  (String) room - The multi-user chat room name.
  (String) nick - The nick name used in the chat room.
  (String) message - The plaintext message to send to the room.
  (String) htmlMessage - The message to send to the room with html markup.
  (String) type - "groupchat" for group chat messages o
                  "chat" for private chat messages
  Returns:
  msgiq - the unique id used to send the message
   */
  String message(String room, String nick, String message,
      [String htmlMessage, String type, String msgid]) {
    String roomNick = this.testAppendNick(room, nick);
    type = type ?? (nick != null ? "chat" : "groupchat");
    msgid = msgid ?? this.connection.getUniqueId();
    StanzaBuilder msg = Strophe
        .$msg({
          'to': roomNick,
          'from': this.connection.jid,
          'type': type,
          'id': msgid
        })
        .c("body")
        .t(message);
    msg.up();
    if (htmlMessage != null) {
      msg.c("html", {'xmlns': Strophe.NS['XHTML_IM']}).c(
          "body", {'xmlns': Strophe.NS['XHTML']}).h(htmlMessage);
      if (msg.currentNode != null && msg.currentNode.children.length == 0) {
        XmlNode parent = msg.currentNode.parent;
        msg.up().up();
        msg.currentNode.children.remove(parent);
      } else {
        msg.up().up();
      }
    }
    msg.c("x", {'xmlns': "jabber:x:event"}).c("composing");
    this.connection.send(msg);
    return msgid;
  }

  /*Function
  Convenience Function to send a Message to all Occupants
  Parameters:
  (String) room - The multi-user chat room name.
  (String) message - The plaintext message to send to the room.
  (String) htmlMessage - The message to send to the room with html markup.
  (String) msgid - Optional unique ID which will be set as the 'id' attribute of the stanza
  Returns:
  msgiq - the unique id used to send the message
   */
  groupchat(String room, String message, [String htmlMessage, String msgid]) {
    return this.message(room, null, message, htmlMessage, '0', msgid);
  }

  /*Function
  Send a mediated invitation.
  Parameters:
  (String) room - The multi-user chat room name.
  (String) receiver - The invitation's receiver.
  (String) reason - Optional reason for joining the room.
  Returns:
  msgiq - the unique id used to send the invitation
   */
  String invite(String room, String receiver, [String reason]) {
    String msgid = this.connection.getUniqueId();
    StanzaBuilder invitation = Strophe
        .$msg({'from': this.connection.jid, 'to': room, 'id': msgid}).c('x',
            {'xmlns': Strophe.NS['MUC_USER']}).c('invite', {'to': receiver});
    if (reason != null) {
      invitation.c('reason', null, reason);
    }
    this.connection.send(invitation);
    return msgid;
  }

  /*Function
  Send a mediated multiple invitation.
  Parameters:
  (String) room - The multi-user chat room name.
  (Array) receivers - The invitation's receivers.
  (String) reason - Optional reason for joining the room.
  Returns:
  msgiq - the unique id used to send the invitation
   */
  String multipleInvites(String room, List<String> receivers, [String reason]) {
    String msgid, receiver;
    msgid = this.connection.getUniqueId();
    StanzaBuilder invitation = Strophe
        .$msg({'from': this.connection.jid, 'to': room, 'id': msgid}).c(
            'x', {'xmlns': Strophe.NS['MUC_USER']});
    for (int i = 0, len = receivers.length; i < len; i++) {
      receiver = receivers[i];
      invitation.c('invite', {'to': receiver});
      if (reason != null) {
        invitation.c('reason', null, reason);
        invitation.up();
      }
      invitation.up();
    }
    this.connection.send(invitation);
    return msgid;
  }

  /*Function
  Send a direct invitation.
  Parameters:
  (String) room - The multi-user chat room name.
  (String) receiver - The invitation's receiver.
  (String) reason - Optional reason for joining the room.
  (String) password - Optional password for the room.
  Returns:
  msgiq - the unique id used to send the invitation
   */
  directInvite(String room, String receiver, [String reason, String password]) {
    String msgid = this.connection.getUniqueId();
    Map<String, String> attrs = {'xmlns': 'jabber:x:conference', 'jid': room};
    if (reason != null) {
      attrs['reason'] = reason;
    }
    if (password != null) {
      attrs['password'] = password;
    }
    StanzaBuilder invitation = Strophe
        .$msg({'from': this.connection.jid, 'to': receiver, 'id': msgid}).c(
            'x', attrs);
    this.connection.send(invitation);
    return msgid;
  }

  /*Function
  Queries a room for a list of occupants
  (String) room - The multi-user chat room name.
  (Function) successCb - Optional  to handle the info.
  (Function) errorCb - Optional  to handle an error.
  Returns:
  id - the unique id used to send the info request
   */
  queryOccupants(String room, [Function successCb, Function errorCb]) {
    Map<String, String> attrs = {'xmlns': Strophe.NS['DISCO_ITEMS']};
    StanzaBuilder info = Strophe
        .$iq({'from': this.connection.jid, 'to': room, 'type': 'get'}).c(
            'query', attrs);
    return this.connection.sendIQ(info.tree(), successCb, errorCb);
  }

  /*Function
  Start a room configuration.
  Parameters:
  (String) room - The multi-user chat room name.
  (Function) handlerCb - Optional  to handle the config form.
  Returns:
  id - the unique id used to send the configuration request
   */
  configure(String room, [Function successCb, Function errorCb]) {
    StanzaBuilder config = Strophe.$iq({'to': room, 'type': "get"}).c(
        "query", {'xmlns': Strophe.NS['MUC_OWNER']});
    XmlElement stanza = config.tree();
    return this.connection.sendIQ(stanza, successCb, errorCb);
  }

  /*Function
  Cancel the room configuration
  Parameters:
  (String) room - The multi-user chat room name.
  Returns:
  id - the unique id used to cancel the configuration.
   */
  cancelConfigure(String room) {
    StanzaBuilder config = Strophe.$iq({'to': room, 'type': "set"}).c("query", {
      'xmlns': Strophe.NS['MUC_OWNER']
    }).c("x", {'xmlns': "jabber:x:data", 'type': "cancel"});
    XmlElement stanza = config.tree();
    return this.connection.sendIQ(stanza);
  }

  /*Function
  Save a room configuration.
  Parameters:
  (String) room - The multi-user chat room name.
  (Array) config- Form Object or an array of form elements used to configure the room.
  Returns:
  id - the unique id used to save the configuration.
   */
  saveConfiguration(String room, List<XmlElement> config,
      [Function successCb, Function errorCb]) {
    StanzaBuilder iq = Strophe.$iq({'to': room, 'type': "set"}).c(
        "query", {'xmlns': Strophe.NS['MUC_OWNER']});
    iq.c("x", {'xmlns': "jabber:x:data", 'type': "submit"});
    XmlElement conf;
    for (int i = 0, len = config.length; i < len; i++) {
      conf = config[i];
      iq.cnode(conf).up();
    }
    XmlElement stanza = iq.tree();
    return this.connection.sendIQ(stanza, successCb, errorCb);
  }

  /*Function
  Parameters:
  (String) room - The multi-user chat room name.
  Returns:
  id - the unique id used to create the chat room.
   */
  createInstantRoom(String room, [Function successCb, Function errorCb]) {
    StanzaBuilder roomiq = Strophe.$iq({'to': room, 'type': "set"}).c("query", {
      'xmlns': Strophe.NS['MUC_OWNER']
    }).c("x", {'xmlns': "jabber:x:data", 'type': "submit"});
    return this.connection.sendIQ(roomiq.tree(), successCb, errorCb);
  }

  /*Function
  Parameters:
  (String) room - The multi-user chat room name.
  (Object) config - the configuration. ex: {"muc#roomconfig_publicroom": "0", "muc#roomconfig_persistentroom": "1"}
  Returns:
  id - the unique id used to create the chat room.
   */
  createConfiguredRoom(String room, Map<String, String> config,
      [Function successCb, Function errorCb]) {
    StanzaBuilder roomiq = Strophe.$iq({'to': room, 'type': "set"}).c("query", {
      'xmlns': Strophe.NS['MUC_OWNER']
    }).c("x", {'xmlns': "jabber:x:data", 'type': "submit"});
    roomiq
        .c('field', {'var': 'FORM_TYPE'})
        .c('value')
        .t('http://jabber.org/protocol/muc#roomconfig')
        .up()
        .up();
    config.forEach((String key, String value) {
      roomiq.c('field', {'var': key}).c('value').t(value).up().up();
    });
    return this.connection.sendIQ(roomiq.tree(), successCb, errorCb);
  }

  /*Function
  Set the topic of the chat room.
  Parameters:
  (String) room - The multi-user chat room name.
  (String) topic - Topic message.
   */
  setTopic(String room, String topic) {
    StanzaBuilder msg = Strophe
        .$msg({'to': room, 'from': this.connection.jid, 'type': "groupchat"}).c(
            "subject", {'xmlns': "jabber:client"}).t(topic);
    return this.connection.send(msg.tree());
  }

  /*Function
  Internal Function that Changes the role or affiliation of a member
  of a MUC room. This  is used by modifyRole and modifyAffiliation.
  The modification can only be done by a room moderator. An error will be
  returned if the user doesn't have permission.
  Parameters:
  (String) room - The multi-user chat room name.
  (Object) item - Object with nick and role or jid and affiliation attribute
  (String) reason - Optional reason for the change.
  (Function) handlerCb - Optional callback for success
  (Function) errorCb - Optional callback for error
  Returns:
  iq - the id of the mode change request.
   */
  _modifyPrivilege(String room, StanzaBuilder item,
      [String reason, Function handlerCb, Function errorCb]) {
    StanzaBuilder iq = Strophe.$iq({'to': room, 'type': "set"}).c(
        "query", {'xmlns': Strophe.NS['MUC_ADMIN']}).cnode(item.currentNode);
    if (reason != null && reason.isNotEmpty) {
      iq.c("reason", null, reason);
    }
    return this.connection.sendIQ(iq.tree(), handlerCb, errorCb);
  }

  /*Function
  Changes the role of a member of a MUC room.
  The modification can only be done by a room moderator. An error will be
  returned if the user doesn't have permission.
  Parameters:
  (String) room - The multi-user chat room name.
  (String) nick - The nick name of the user to modify.
  (String) role - The new role of the user.
  (String) affiliation - The new affiliation of the user.
  (String) reason - Optional reason for the change.
  (Function) handlerCb - Optional callback for success
  (Function) errorCb - Optional callback for error
  Returns:
  iq - the id of the mode change request.
   */
  modifyRole(String room, String nick, String role,
      [String reason, Function handlerCb, Function errorCb]) {
    StanzaBuilder item = Strophe.$build("item", {'nick': nick, 'role': role});
    return this._modifyPrivilege(room, item, reason, handlerCb, errorCb);
  }

  kick(String room, String nick,
      [String reason, Function handlerCb, Function errorCb]) {
    return this.modifyRole(room, nick, 'none', reason, handlerCb, errorCb);
  }

  voice(String room, String nick,
      [String reason, Function handlerCb, Function errorCb]) {
    return this
        .modifyRole(room, nick, 'participant', reason, handlerCb, errorCb);
  }

  mute(String room, String nick,
      [String reason, Function handlerCb, Function errorCb]) {
    return this.modifyRole(room, nick, 'visitor', reason, handlerCb, errorCb);
  }

  op(String room, String nick,
      [String reason, Function handlerCb, Function errorCb]) {
    return this.modifyRole(room, nick, 'moderator', reason, handlerCb, errorCb);
  }

  deop(String room, String nick,
      [String reason, Function handlerCb, Function errorCb]) {
    return this
        .modifyRole(room, nick, 'participant', reason, handlerCb, errorCb);
  }

  /*Function
  Changes the affiliation of a member of a MUC room.
  The modification can only be done by a room moderator. An error will be
  returned if the user doesn't have permission.
  Parameters:
  (String) room - The multi-user chat room name.
  (String) jid  - The jid of the user to modify.
  (String) affiliation - The new affiliation of the user.
  (String) reason - Optional reason for the change.
  (Function) handlerCb - Optional callback for success
  (Function) errorCb - Optional callback for error
  Returns:
  iq - the id of the mode change request.
   */
  modifyAffiliation(String room, String jid, String affiliation,
      [String reason, Function handlerCb, Function errorCb]) {
    StanzaBuilder item =
        Strophe.$build("item", {'jid': jid, 'affiliation': affiliation});
    return this._modifyPrivilege(room, item, reason, handlerCb, errorCb);
  }

  ban(String room, String jid,
      [String reason, Function handlerCb, Function errorCb]) {
    return this
        .modifyAffiliation(room, jid, 'outcast', reason, handlerCb, errorCb);
  }

  member(String room, String jid,
      [String reason, Function handlerCb, Function errorCb]) {
    return this
        .modifyAffiliation(room, jid, 'member', reason, handlerCb, errorCb);
  }

  revoke(String room, String jid,
      [String reason, Function handlerCb, Function errorCb]) {
    return this
        .modifyAffiliation(room, jid, 'none', reason, handlerCb, errorCb);
  }

  owner(String room, String jid,
      [String reason, Function handlerCb, Function errorCb]) {
    return this
        .modifyAffiliation(room, jid, 'owner', reason, handlerCb, errorCb);
  }

  admin(String room, String jid,
      [String reason, Function handlerCb, Function errorCb]) {
    return this
        .modifyAffiliation(room, jid, 'admin', reason, handlerCb, errorCb);
  }

  /*Function
  Change the current users nick name.
  Parameters:
  (String) room - The multi-user chat room name.
  (String) user - The new nick name.
   */
  changeNick(String room, String user) {
    String roomNick = this.testAppendNick(room, user);
    StanzaBuilder presence = Strophe.$pres({
      'from': this.connection.jid,
      'to': roomNick,
      'id': this.connection.getUniqueId()
    });
    return this.connection.send(presence.tree());
  }

  /*Function
  Change the current users status.
  Parameters:
  (String) room - The multi-user chat room name.
  (String) user - The current nick.
  (String) show - The new show-text.
  (String) status - The new status-text.
   */
  setStatus(String room, String user, [String show, String status]) {
    String roomNick = this.testAppendNick(room, user);
    StanzaBuilder presence =
        Strophe.$pres({'from': this.connection.jid, 'to': roomNick});
    if (show != null) {
      presence.c('show', {}, show).up();
    }
    if (status != null) {
      presence.c('status', {}, status);
    }
    return this.connection.send(presence.tree());
  }

  /*Function
  Registering with a room.
  @see http://xmpp.org/extensions/xep-0045.html#register
  Parameters:
  (String) room - The multi-user chat room name.
  (Function) handleCb - Function to call for room list return.
  (Function) errorCb - Function to call on error.
   */
  registrationRequest(String room, Function handleCb, [Function errorCb]) {
    StanzaBuilder iq = Strophe
        .$iq({'to': room, 'from': this.connection.jid, 'type': "get"}).c(
            "query", {'xmlns': Strophe.NS['MUC_REGISTER']});
    return this.connection.sendIQ(iq.tree(), (XmlElement stanza) {
      List<XmlElement> fields = stanza.findAllElements('field').toList();
      XmlElement field;
      Map<String, List> fieldsMap = {'required': [], 'optional': []};
      Map<String, String> fieldMap;
      for (int i = 0, len = fields.length; i < len; i++) {
        field = fields[i];
        fieldMap = {
          "var": field.getAttribute('var'),
          'label': field.getAttribute('label'),
          'type': field.getAttribute('type')
        };
        if (field.findAllElements('required').length > 0) {
          fieldsMap['required'].add(fieldMap);
        } else {
          fieldsMap['optional'].add(fieldMap);
        }
      }
      return handleCb(fields);
    }, errorCb);
  }

  /*Function
  Submits registration form.
  Parameters:
  (String) room - The multi-user chat room name.
  (Function) handleCb - Function to call for room list return.
  (Function) errorCb - Function to call on error.
   */
  submitRegistrationForm(String room, Map<String, dynamic> fields,
      [Function handleCb, Function errorCb]) {
    StanzaBuilder iq = Strophe.$iq({'to': room, 'type': "set"}).c(
        "query", {'xmlns': Strophe.NS['MUC_REGISTER']});
    iq.c("x", {'xmlns': "jabber:x:data", 'type': "submit"});
    iq
        .c('field', {'var': 'FORM_TYPE'})
        .c('value')
        .t('http://jabber.org/protocol/muc#register')
        .up()
        .up();
    fields.forEach((String key, value) {
      iq.c('field', {'var': key}).c('value').t(value).up().up();
    });
    return this.connection.sendIQ(iq.tree(), handleCb, errorCb);
  }

  /*Function
  List all chat room available on a server.
  Parameters:
  (String) server - name of chat server.
  (String) handleCb - Function to call for room list return.
  (String) errorCb - Function to call on error.
   */
  listRooms(String server, [Function handleCb, errorCb]) {
    StanzaBuilder iq = Strophe
        .$iq({'to': server, 'from': this.connection.jid, 'type': "get"}).c(
            "query", {'xmlns': Strophe.NS['DISCO_ITEMS']});
    return this.connection.sendIQ(iq.tree(), handleCb, errorCb);
  }

  String testAppendNick(String room, String nick) {
    String domain, node;
    node = Strophe.escapeNode(Strophe.getNodeFromJid(room));
    domain = Strophe.getDomainFromJid(room);
    return node + "@" + domain + (nick != null ? "/" + nick : "");
  }
}

class XmppRoom {
  MucPlugin client;

  String name;

  String nick;

  String password;

  Map<String, Occupant> roster;

  Map<int, Function> _message_handlers;

  Map<int, Function> _presence_handlers;

  Map<int, Function> _roster_handlers;

  int _handler_ids;

  XmppRoom(MucPlugin client, String name, String nick1, String password1) {
    this.client = client;
    this.name = name;
    this.nick = nick1;
    this.password = password1;
    this.roster = {};
    this._message_handlers = {};
    this._presence_handlers = {};
    this._roster_handlers = {};
    this._handler_ids = 0;
    if (this.client.muc != null) {
      this.client = this.client.muc;
    }
    this.name = Strophe.getBareJidFromJid(this.name);
    this.addHandler('presence', this._roomRosterHandler);
  }

  join(Function msgHandlerCb, Function presHandlerCb, Function rosterCb) {
    return this.client.join(this.name, this.nick, msgHandlerCb, presHandlerCb,
        rosterCb, this.password);
  }

  leave([Function handlerCb, String message]) {
    this.client.leave(this.name, this.nick, handlerCb, message);
    return this.client.rooms.remove(this.name);
  }

  message(String nick, String message, [String htmlMessage, String type]) {
    return this.client.message(this.name, nick, message, htmlMessage, type);
  }

  groupchat(String message, [String htmlMessage]) {
    return this.client.groupchat(this.name, message, htmlMessage);
  }

  invite(String receiver, [String reason]) {
    return this.client.invite(this.name, receiver, reason);
  }

  multipleInvites(List<String> receivers, [String reason]) {
    return this.client.multipleInvites(this.name, receivers, reason);
  }

  directInvite(String receiver, [String reason]) {
    return this.client.directInvite(this.name, receiver, reason, this.password);
  }

  configure([Function handlerCb]) {
    return this.client.configure(this.name, handlerCb);
  }

  cancelConfigure() {
    return this.client.cancelConfigure(this.name);
  }

  saveConfiguration(List<XmlElement> config) {
    return this.client.saveConfiguration(this.name, config);
  }

  queryOccupants([Function successCb, Function errorCb]) {
    return this.client.queryOccupants(this.name, successCb, errorCb);
  }

  setTopic(String topic) {
    return this.client.setTopic(this.name, topic);
  }

  modifyRole(String nick, String role,
      [String reason, Function successCb, Function errorCb]) {
    return this
        .client
        .modifyRole(this.name, nick, role, reason, successCb, errorCb);
  }

  kick(String nick, [String reason, Function handlerCb, Function errorCb]) {
    return this.client.kick(this.name, nick, reason, handlerCb, errorCb);
  }

  voice(String nick, [String reason, Function handlerCb, Function errorCb]) {
    return this.client.voice(this.name, nick, reason, handlerCb, errorCb);
  }

  mute(String nick, [String reason, Function handlerCb, Function errorCb]) {
    return this.client.mute(this.name, nick, reason, handlerCb, errorCb);
  }

  op(String nick, [String reason, Function handlerCb, Function errorCb]) {
    return this.client.op(this.name, nick, reason, handlerCb, errorCb);
  }

  deop(String nick, [String reason, Function handlerCb, Function errorCb]) {
    return this.client.deop(this.name, nick, reason, handlerCb, errorCb);
  }

  modifyAffiliation(String jid, String affiliation,
      [String reason, Function successCb, Function errorCb]) {
    return this.client.modifyAffiliation(
        this.name, jid, affiliation, reason, successCb, errorCb);
  }

  ban(String jid, [String reason, Function handlerCb, Function errorCb]) {
    return this.client.ban(this.name, jid, reason, handlerCb, errorCb);
  }

  member(String jid, [String reason, Function handlerCb, Function errorCb]) {
    return this.client.member(this.name, jid, reason, handlerCb, errorCb);
  }

  revoke(String jid, [String reason, Function handlerCb, Function errorCb]) {
    return this.client.revoke(this.name, jid, reason, handlerCb, errorCb);
  }

  owner(String jid, [String reason, Function handlerCb, Function errorCb]) {
    return this.client.owner(this.name, jid, reason, handlerCb, errorCb);
  }

  admin(String jid, [String reason, Function handlerCb, Function errorCb]) {
    return this.client.admin(this.name, jid, reason, handlerCb, errorCb);
  }

  changeNick(String nick1) {
    this.nick = nick1;
    return this.client.changeNick(this.name, nick);
  }

  setStatus([String show, String status]) {
    return this.client.setStatus(this.name, this.nick, show, status);
  }

  /*Function
  Adds a handler to the MUC room.
    Parameters:
  (String) handlerType - 'message', 'presence' or 'roster'.
  (Function) handler - The handler .
  Returns:
  id - the id of handler.
   */

  addHandler(String handlerType, Function handler) {
    int id = this._handler_ids++;
    switch (handlerType.toLowerCase()) {
      case 'presence':
        this._presence_handlers[id] = handler;
        break;
      case 'message':
        this._message_handlers[id] = handler;
        break;
      case 'roster':
        this._roster_handlers[id] = handler;
        break;
      default:
        this._handler_ids--;
        return null;
    }
    return id;
  }

  /*Function
  Removes a handler from the MUC room.
  This  takes ONLY ids returned by the addHandler 
  of this room. passing handler ids returned by connection.addHandler
  may brake things!
    Parameters:
  (number) id - the id of the handler
   */

  removeHandler(int id) {
    this._presence_handlers.remove(id);
    this._message_handlers.remove(id);
    return this._roster_handlers.remove(id);
  }

  /*Function
  Creates and adds an Occupant to the Room Roster.
    Parameters:
  (Object) data - the data the Occupant is filled with
  Returns:
  occ - the created Occupant.
   */

  Occupant _addOccupant(Map<String, String> data) {
    Occupant occ = new Occupant(data, this);
    this.roster[occ.nick] = occ;
    return occ;
  }

  /*Function
  The standard handler that managed the Room Roster.
    Parameters:
  (Object) pres - the presence stanza containing user information
   */

  _roomRosterHandler(XmlElement pres) {
    Map<String, String> data = _parsePresence(pres);
    String nick = data['nick'];
    String newnick = data['newnick'] ?? null;
    switch (data['type']) {
      case 'error':
        return true;
      case 'unavailable':
        if (newnick != null) {
          data['nick'] = newnick;
          if (this.roster[nick] != null && this.roster[newnick] != null) {
            this.roster[nick].update(this.roster[newnick]);
            this.roster[newnick] = this.roster[nick];
          }
          if (this.roster[nick] != null && this.roster[newnick] == null) {
            this.roster[newnick] = this.roster[nick].update(data);
          }
        }
        this.roster.remove(nick);
        break;
      default:
        if (this.roster[nick] != null) {
          this.roster[nick].update(data);
        } else {
          this._addOccupant(data);
        }
    }
    Map<int, Function> ref = this._roster_handlers;
    ref.forEach((int id, Function handler) {
      if (handler(this.roster, this) == false) {
        this._roster_handlers.remove(id);
      }
    });
    return true;
  }

  /*Function
  Parses a presence stanza
    Parameters:
  (Object) data - the data extracted from the presence stanza
   */

  Map<String, dynamic> _parsePresence(XmlElement pres) {
    Map<String, dynamic> data = {};
    data['nick'] = Strophe.getResourceFromJid(pres.getAttribute("from"));
    data['type'] = pres.getAttribute("type");
    data['states'] = [];
    List<XmlNode> ref = pres.children, ref2;
    XmlElement c, c2;
    XmlElement ref1;
    for (int i = 0, len = ref.length; i < len; i++) {
      c = ref[i];
      switch (c.name.qualified) {
        case "error":
          data['errorcode'] = c.getAttribute("code");
          data['error'] =
              (ref1 = c.children[0]) != null ? ref1.name.qualified : 0;
          break;
        case "status":
          data['status'] = c.text ?? null;
          break;
        case "show":
          data['show'] = c.text ?? null;
          break;
        case "x":
          if (c.getAttribute("xmlns") == Strophe.NS['MUC_USER']) {
            ref2 = c.children;
            for (int j = 0, len1 = ref2.length; j < len1; j++) {
              c2 = ref2[j];
              switch (c2.name.qualified) {
                case "item":
                  data['affiliation'] = c2.getAttribute("affiliation");
                  data['role'] = c2.getAttribute("role");
                  data['jid'] = c2.getAttribute("jid");
                  data['newnick'] = c2.getAttribute("nick");
                  break;
                case "status":
                  if (c2.getAttribute("code") != null) {
                    data['states'].add(c2.getAttribute("code"));
                  }
              }
            }
          }
      }
    }
    return data;
  }
}

class Occupant {
  XmppRoom room;

  String nick;

  String jid;

  String show;

  String status;

  String role;

  String affiliation;

  Occupant(Map<String, String> data, XmppRoom room1) {
    this.room = room1;
    this.update(data);
  }

  modifyRole(String role,
      [String reason, Function successCb, Function errorCb]) {
    return this.room.modifyRole(this.nick, role, reason, successCb, errorCb);
  }

  kick([String reason, Function handlerCb, Function errorCb]) {
    return this.room.kick(this.nick, reason, handlerCb, errorCb);
  }

  voice([String reason, Function handlerCb, Function errorCb]) {
    return this.room.voice(this.nick, reason, handlerCb, errorCb);
  }

  mute([String reason, Function handlerCb, Function errorCb]) {
    return this.room.mute(this.nick, reason, handlerCb, errorCb);
  }

  op([String reason, Function handlerCb, Function errorCb]) {
    return this.room.op(this.nick, reason, handlerCb, errorCb);
  }

  deop([String reason, Function handlerCb, Function errorCb]) {
    return this.room.deop(this.nick, reason, handlerCb, errorCb);
  }

  modifyAffiliation(String affiliation,
      [String reason, Function successCb, Function errorCb]) {
    return this
        .room
        .modifyAffiliation(this.jid, affiliation, reason, successCb, errorCb);
  }

  ban([String reason, Function handlerCb, Function errorCb]) {
    return this.room.ban(this.jid, reason, handlerCb, errorCb);
  }

  member([String reason, Function handlerCb, Function errorCb]) {
    return this.room.member(this.jid, reason, handlerCb, errorCb);
  }

  revoke([String reason, Function handlerCb, Function errorCb]) {
    return this.room.revoke(this.jid, reason, handlerCb, errorCb);
  }

  owner([String reason, Function handlerCb, Function errorCb]) {
    return this.room.owner(this.jid, reason, handlerCb, errorCb);
  }

  admin([String reason, Function handlerCb, Function errorCb]) {
    return this.room.admin(this.jid, reason, handlerCb, errorCb);
  }

  update(data) {
    if (data is Map<String, String>) {
      data = data;
    } else if (data is Occupant) {
      data = {
        'nick': data.nick,
        'affiliation': data.affiliation,
        'role': data.role,
        'jid': data.jid,
        'status': data.status,
        'show': data.show,
      };
    } else
      return this;

    this.nick = data['nick'] ?? null;
    this.affiliation = data['affiliation'] ?? null;
    this.role = data['role'] ?? null;
    this.jid = data['jid'] ?? null;
    this.status = data['status'] ?? null;
    this.show = data['show'] ?? null;
    return this;
  }
}

class RoomConfig {
  List<String> features;

  List<Map<String, String>> identities;

  List<Map<String, String>> x;

  RoomConfig(XmlElement info) {
    if (info != null) {
      this.parse(info);
    }
  }

  Map<String, List> parse(XmlElement result) {
    List<XmlNode> query = result.findAllElements("query").toList()[0].children;
    this.identities = [];
    this.features = [];
    this.x = [];
    XmlElement child, field, firstChild;
    List<XmlAttribute> attrs;
    Map<String, String> identity;
    XmlAttribute attr;
    List<XmlNode> ref;
    for (int i = 0, len = query.length; i < len; i++) {
      child = query[i];
      attrs = child.attributes;
      switch (child.name.qualified) {
        case "identity":
          identity = {};
          for (int j = 0, len1 = attrs.length; j < len1; j++) {
            attr = attrs[j];
            identity[attr.name.qualified] = attr.text;
          }
          this.identities.add(identity);
          break;
        case "feature":
          this.features.add(child.getAttribute("var"));
          break;
        case "x":
          firstChild = child.firstChild;
          if (!(firstChild.getAttribute("var") == 'FORM_TYPE') ||
              !(firstChild.getAttribute("type") == 'hidden')) {
            break;
          }
          ref = child.children;
          for (int l = 0, len2 = ref.length; l < len2; l++) {
            field = ref[l];

            if (field.getAttribute('type') == null ||
                field.getAttribute('type').isEmpty) {
              this.x.add({
                "var": field.getAttribute("var"),
                'label': field.getAttribute("label") ?? "",
                'value': field.firstChild.text ?? ""
              });
            }
          }
      }
    }
    return {
      "identities": this.identities,
      "features": this.features,
      "x": this.x
    };
  }
}
