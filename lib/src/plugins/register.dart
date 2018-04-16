import 'dart:math';

import 'package:strophe/src/core.dart';
import 'package:strophe/src/enums.dart';
import 'package:strophe/src/plugins/plugins.dart';
import 'package:strophe/src/utils.dart';
import 'package:xml/xml/nodes/document.dart';
import 'package:xml/xml/nodes/element.dart';

/*
This library is free software; you can redistribute it and/or modify it
 under the terms of the GNU Lesser General Public License as published
 by the Free Software Foundation; either version 2.1 of the License, or
 (at your option) any later version.
 .
 This library is distributed in the hope that it will be useful, but
 WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
 General Public License for more details.
  Copyright (c) dodo <dodo@blacksec.org>, 2011
*/

class RegisterPlugin extends PluginClass {
  String domain;
  String instructions;
  Map<String, dynamic> fields;
  bool registered = false;
  bool _registering = false;
  bool processed_features = false;

  Map<String, dynamic> _connect_cb_data = {};
  //The plugin must have the init function.
  @override
  init(StropheConnection conn) {
    this.connection = conn;
    // compute free emun index number
    int i = 0;
    Strophe.Status.forEach((String key, int value) {
      i = max(i, Strophe.Status[key]);
    });

    /* extend name space
         *  NS['REGISTER'] - In-Band Registration
         *              from XEP 77.
         */
    Strophe.addNamespace('REGISTER', 'jabber:iq:register');
    Strophe.Status['REGIFAIL'] = i + 1;
    Strophe.Status['REGISTER'] = i + 2;
    Strophe.Status['REGISTERED'] = i + 3;
    Strophe.Status['CONFLICT'] = i + 4;
    Strophe.Status['NOTACCEPTABLE'] = i + 5;
    if (conn.disco != null) {
      if (conn.disco.addFeature is Function)
        conn.disco.addFeature(Strophe.NS['REGISTER']);
      //if (conn.disco.addNode is Function)
      //conn.disco.addNode(Strophe.NS['REGISTER'], {'items': []});
    }

    // hooking strophe's connection.reset
    Function reset = conn.reset;
    conn.reset = () {
      reset();
      this.instructions = "";
      this.fields = {};
      this.registered = false;
    };

    // hooking strophe's _connect_cb
    Function connect_cb = conn.connectCb;
    conn.connectCb = (req, Function _callback, String raw) {
      if (!this._registering) {
        if (this.processed_features) {
          // exchange Input hooks to not print the stream:features twice
          //var xmlInput = conn.xmlInput;
          //conn.xmlInput = Strophe.Connection.xmlInput;
          //var rawInput = conn.rawInput;
          //conn.rawInput = Strophe.Connection.prototype.rawInput;
          connect_cb(req, _callback, raw);
          //conn.xmlInput = xmlInput;
          //conn.rawInput = rawInput;
          this.processed_features = false;
        } else {
          connect_cb(req, _callback, raw);
        }
      } else {
        // Save this request in case we want to authenticate later
        this._connect_cb_data = {'req': req, 'raw': raw};
        if (this._register_cb(req, _callback, raw)) {
          // remember that we already processed stream:features
          this.processed_features = true;
          this._registering = false;
        }
      }
    };

    // hooking strophe`s authenticate
    Function auth_old = conn.authenticate;
    conn.authenticate = (List<StropheSASLMechanism> matched) {
      if (matched == null) {
        var conn = this.connection;

        if (this.fields['username'] == null ||
            this.fields['username'].isEmpty ||
            this.domain == null ||
            this.fields['password'] == null ||
            this.fields['password'].isEmpty) {
          Strophe.info("Register a JID first!");
          return;
        }

        String jid = this.fields['username'] + "@" + this.domain;

        conn.jid = jid;
        conn.authzid = Strophe.getBareJidFromJid(conn.jid);
        conn.authcid = Strophe.getNodeFromJid(conn.jid);
        conn.pass = this.fields['password'];
        var req = this._connect_cb_data['req'];
        var callback = conn.connectCallback;
        var raw = this._connect_cb_data['raw'];
        conn.connectCb(req, callback, raw);
      } else {
        auth_old(matched);
      }
    };
  }

  /** Function: connect
     *  Starts the registration process.
     *
     *  As the registration process proceeds, the user supplied callback will
     *  be triggered multiple times with status updates.  The callback
     *  should take two arguments - the status code and the error condition.
     *
     *  The status code will be one of the values in the Strophe.Status
     *  constants.  The error condition will be one of the conditions
     *  defined in RFC 3920 or the condition 'strophe-parsererror'.
     *
     *  Please see XEP 77 for a more detailed explanation of the optional
     *  parameters below.
     *
     *  Parameters:
     *    (String) domain - The xmpp server's Domain.  This will be the server,
     *      which will be contacted to register a new JID.
     *      The server has to provide and allow In-Band Registration (XEP-0077).
     *    (Function) callback The connect callback function.
     *    (Integer) wait - The optional HTTPBIND wait value.  This is the
     *      time the server will wait before returning an empty result for
     *      a request.  The default setting of 60 seconds is recommended.
     *      Other settings will require tweaks to the Strophe.TIMEOUT value.
     *    (Integer) hold - The optional HTTPBIND hold value.  This is the
     *      number of connections the server will hold at one time.  This
     *      should almost always be set to 1 (the default).
     */
  connect(String domain, ConnectCallBack callback,
      [int wait, int hold, String route]) {
    StropheConnection conn = this.connection;
    this.domain = Strophe.getDomainFromJid(domain);
    this.instructions = "";
    this.fields = {};
    this.registered = false;

    this._registering = true;
    conn.connect(this.domain, "", callback, wait, hold, route);
  }

  /** PrivateFunction: _register_cb
     *  _Private_ handler for initial registration request.
     *
     *  This handler is used to process the initial registration request
     *  response from the BOSH server. It is used to set up a bosh session
     *  and requesting registration fields from host.
     *type
     *  Parameters:
     *    (Strophe.Request) req - The current request.
     */
  _register_cb(req, Function _callback, String raw) {
    StropheConnection conn = this.connection;
    Strophe.info("_register_cb was called");
    conn.connected = true;

    XmlElement bodyWrap = conn.proto.reqToData(req);
    if (bodyWrap == null) {
      return false;
    }
    //if (conn.xmlInput !== Strophe.Connection.prototype.xmlInput) {
    if (bodyWrap.name.qualified == conn.proto.strip &&
        bodyWrap.children.length > 0) {
      conn.xmlInput(bodyWrap.firstChild);
    } else {
      conn.xmlInput(bodyWrap);
    }
    //}
    //if (conn.rawInput !== Strophe.Connection.prototype.rawInput) {
    if (raw != null) {
      conn.rawInput(raw);
    } else {
      conn.rawInput(Strophe.serialize(bodyWrap));
    }
    //}

    var conncheck = conn.proto.connectCb(bodyWrap);
    if (conncheck == Strophe.Status['CONNFAIL']) {
      return false;
    }
    // Check for the stream:features tag
    List<XmlElement> register = bodyWrap.findAllElements("register").toList();
    List<XmlElement> mechanisms =
        bodyWrap.findAllElements("mechanism").toList();
    if (register.length == 0 && mechanisms.length == 0) {
      conn.noAuthReceived(_callback);
      return false;
    }

    if (register.length == 0) {
      conn.changeConnectStatus(Strophe.Status['REGIFAIL'], null);
      return true;
    }

    // send a get request for registration, to get all required data fields
    conn.addSysHandler(this._get_register_cb, null, "iq", null, null);
    conn.sendIQ(Strophe.$iq({'type': "get"}).c(
        "query", {'xmlns': Strophe.NS['REGISTER']}).tree());

    return true;
  }

  /** PrivateFunction: _get_register_cb
     *  _Private_ handler for Registration Fields Request.
     *
     *  Parameters:
     *    (XMLElement) elem - The query stanza.
     *
     *  Returns:
     *    false to remove SHOULD contain the registration information currentlSHOULD contain the registration information currentlSHOULD contain the registration information currentlthe handler.
     */
  _get_register_cb(dynamic elem) {
    XmlElement field;
    List<XmlElement> queries;
    StropheConnection conn = this.connection;
    XmlElement stanza;
    if (elem is XmlDocument)
      stanza = elem.rootElement;
    else if (elem is XmlElement)
      stanza = elem;
    else
      stanza = elem;
    queries = stanza.findAllElements("query").toList();

    if (queries.length != 1) {
      conn.changeConnectStatus(Strophe.Status['REGIFAIL'], "unknown");
      return false;
    }
    XmlElement query = queries.first;
    // get required fields
    for (int i = 0; i < query.children.length; i++) {
      field = query.children[i];
      if (field.name.qualified.toLowerCase() == 'instructions') {
        // this is a special element
        // it provides info about given data fields in a textual way.
        conn.register.instructions = Strophe.getText(field);
        continue;
      } else if (field.name.qualified.toLowerCase() == 'x') {
        // ignore x for now
        continue;
      }
      conn.register.fields[field.name.qualified.toLowerCase()] =
          Strophe.getText(field);
    }
    conn.changeConnectStatus(Strophe.Status['REGISTER'], null);
    return false;
  }

  /** Function: submit
     *  Submits Registration data.
     *
     *  As the registration process proceeds, the user supplied callback will
     *  be triggered with status code Strophe.Status['REGISTER']. At this point
     *  the user should fill all required fields in connection['REGISTER'].fields
     *  and invoke this function to procceed in the registration process.
     */
  submit() {
    String name;
    List<String> fields;
    StropheConnection conn = this.connection;
    StanzaBuilder query = Strophe
        .$iq({'type': "set"}).c("query", {'xmlns': Strophe.NS['REGISTER']});
    // set required fields
    fields = this.fields.keys.toList();
    for (int i = 0; i < fields.length; i++) {
      name = fields[i];
      query.c(name).t(this.fields[name]).up();
    }

    // providing required information
    conn.addSysHandler(this._submit_cb, null, "iq", null, null);
    conn.sendIQ(query.tree());
  }

  /** PrivateFunction: _submit_cb
     *  _Private_ handler for submitted registration information.
     *
     *  Parameters:
     *    (XMLElement) elem - The query stanza.
     *
     *  Returns:
     *    false to remove the handler.
     */
  _submit_cb(XmlElement stanza) {
    XmlElement field;
    List<XmlElement> errors;
    List<XmlElement> queries;
    StropheConnection conn = this.connection;

    queries = stanza.findAllElements("query").toList();
    if (queries.length > 0) {
      XmlElement query = queries[0];
      // update fields
      for (int i = 0; i < query.children.length; i++) {
        field = query.children[i];
        if (field.name.qualified.toLowerCase() == 'instructions') {
          // this is a special element
          // it provides info about given data fields in a textual way
          this.instructions = Strophe.getText(field);
          continue;
        }
        this.fields[field.name.qualified.toLowerCase()] =
            Strophe.getText(field);
      }
    }

    if (stanza.getAttribute("type") == "error") {
      errors = stanza.findAllElements("error").toList();
      if (errors.length != 1) {
        conn.changeConnectStatus(Strophe.Status['REGIFAIL'], "unknown");
        return false;
      }

      Strophe.info("Registration failed.");

      // this is either 'conflict' or 'not-acceptable'
      XmlElement firstChild = errors[0].firstChild as XmlElement;
      String error = firstChild.name.qualified.toLowerCase();
      if (error == 'conflict') {
        conn.changeConnectStatus(Strophe.Status['CONFLICT'], error);
      } else if (error == 'not-acceptable') {
        conn.changeConnectStatus(Strophe.Status['NOTACCEPTABLE'], error);
      } else {
        String text =
            Strophe.getText(errors[0].findElements('text').toList()[0]) +
                '/$error';
        conn.changeConnectStatus(Strophe.Status['REGIFAIL'], text ?? error);
      }
    } else {
      Strophe.info("Registration successful.");

      conn.changeConnectStatus(Strophe.Status['REGISTERED'], null);
    }

    return false;
  }
}
