import 'dart:async';
import 'dart:io';

import 'package:strophe/src/core.dart';
import 'package:strophe/src/enums.dart';
import 'package:xml/xml.dart' as xml;

class StropheWebSocket extends ServiceType {
  StropheConnection _conn;

  String strip;

  WebSocket socket;

  StreamSubscription _socketListen;

  StreamSubscription get socketListen {
    return _socketListen;
  }

  set socketListen(StreamSubscription listen) {
    if (listen != null) _socketListen = listen;
  }

  StropheWebSocket(StropheConnection connection) {
    this._conn = connection;
    this.strip = "wrapper";

    //String service = connection.service;
    //if (service.indexOf("ws:") != 0 && service.indexOf("wss:") != 0) {
    // If the service is not an absolute URL, assume it is a path and put the absolute
    // URL together from options, current URL and the path.
    /* var new_service = ""; */

    /* if (connection.options['protocol'] == "ws" && window.location.protocol != "https:") {
            new_service += "ws";
        } else {
            new_service += "wss";
        }

        new_service += "://" + service;

        if (service.indexOf("/") != 0) {
            new_service += window.location.pathname + service;
        } else {
            new_service += service;
        } */

    //connection.service = new_service;
    //}
  }
/** PrivateFunction: _buildStream
     *  _Private_ helper function to generate the <stream> start tag for WebSockets
     *
     *  Returns:
     *    A Strophe.Builder with a <stream> element.
     */
  StanzaBuilder _buildStream() {
    return Strophe.$build("open", {
      "xmlns": Strophe.NS['FRAMING'],
      "to": this._conn.domain,
      "version": '1.0'
    });
  }

  /** PrivateFunction: _check_streamerror
     * _Private_ checks a message for stream:error
     *
     *  Parameters:
     *    (Strophe.Request) bodyWrap - The received stanza.
     *    connectstatus - The ConnectStatus that will be set on error.
     *  Returns:
     *     true if there was a streamerror, false otherwise.
     */
  bool _checkStreamError(xml.XmlNode bodyWrapNode, int connectstatus) {
    Iterable<xml.XmlElement> errors;
    xml.XmlElement bodyWrap;
    if (bodyWrapNode is xml.XmlDocument)
      bodyWrap = bodyWrapNode.rootElement;
    else if (bodyWrapNode is xml.XmlElement) bodyWrap = bodyWrapNode;

    if (bodyWrap.getAttribute("xmlns") == Strophe.NS['STREAM']) {
      errors = bodyWrap.findAllElements("error");
    } else {
      errors = bodyWrap.findAllElements("stream:error");
    }
    if (errors.length == 0) {
      return false;
    }
    xml.XmlElement error = errors.elementAt(0);

    String condition = "";
    String text = "";

    String ns = "urn:ietf:params:xml:ns:xmpp-streams";
    xml.XmlElement e;
    for (int i = 0; i < error.children.length; i++) {
      e = error.children.elementAt(i) as xml.XmlElement;
      if (e.getAttribute("xmlns") != ns) {
        break;
      }
      if (e.name.qualified == "text") {
        text = e.text;
      } else {
        condition = e.name.qualified;
      }
    }

    String errorString = "WebSocket stream error: ";

    if (condition != null) {
      errorString += condition;
    } else {
      errorString += "unknown";
    }

    if (text != null) {
      errorString += " - " + text;
    }

    Strophe.error(errorString);

    // close the connection on stream_error
    this._conn.changeConnectStatus(connectstatus, condition);
    this._conn.doDisconnect();
    return true;
  }

  /** PrivateFunction: _reset
     *  Reset the connection.
     *
     *  This function is called by the reset function of the Strophe Connection.
     *  Is not needed by WebSockets.
     */
  reset() {
    this._reset();
  }

  _reset() {
    return;
  }

  /** PrivateFunction: _connect
     *  _Private_ function called by Strophe.Connection.connect
     *
     *  Creates a WebSocket for a connection and assigns Callbacks to it.
     *  Does nothing if there already is a WebSocket.
     */
  connect([int wait, int hold, String route]) {
    this._connect();
  }

  _connect() {
    // Ensure that there is no open WebSocket from a previous Connection.
    this._disconnect();
    if (this.socketListen == null || this.socket == null) {
      // Create the new WebSocket
      WebSocket.connect(this._conn.service, protocols: ['xmpp'])
          .then((WebSocket socket) {
        this.socket = socket;
        this.socketListen = this.socket.listen(this._connectCbWrapper,
            onError: this._onError, onDone: this._onClose);
        this._onOpen();
      }).catchError((e) {
        this._conn.connexionError("impossible de joindre le serveur XMPP : $e");
      });
    }
  }

  /** PrivateFunction: _connect_cb
     *  _Private_ function called by Strophe.Connection._connect_cb
     *
     * checks for stream:error
     *
     *  Parameters:
     *    (Strophe.Request) bodyWrap - The received stanza.
     */
  connectCb(bodyWrap) {
    this._connectCb(bodyWrap);
  }

  _connectCb(bodyWrap) {
    bool error = this._checkStreamError(bodyWrap, Strophe.Status['CONNFAIL']);
    if (error) {
      return Strophe.Status['CONNFAIL'];
    }
  }

  /** PrivateFunction: _handleStreamStart
     * _Private_ function that checks the opening <open /> tag for errors.
     *
     * Disconnects if there is an error and returns false, true otherwise.
     *
     *  Parameters:
     *    (Node) message - Stanza containing the <open /> tag.
     */
  bool _handleStreamStart(xml.XmlDocument message) {
    String error = "";

    // Check for errors in the <open /> tag
    String ns = message.rootElement.getAttribute("xmlns");
    if (ns == null) {
      error = "Missing xmlns in <open />";
    } else if (ns != Strophe.NS['FRAMING']) {
      error = "Wrong xmlns in <open />: " + ns;
    }

    String ver = message.rootElement.getAttribute("version");
    if (ver == null) {
      error = "Missing version in <open />";
    } else if (ver != "1.0") {
      error = "Wrong version in <open />: " + ver;
    }

    if (error != null && error.isNotEmpty) {
      this._conn.changeConnectStatus(Strophe.Status['CONNFAIL'], error);
      this._conn.doDisconnect();
      return false;
    }
    return true;
  }

  /** PrivateFunction: _connect_cb_wrapper
     * _Private_ function that handles the first connection messages.
     *
     * On receiving an opening stream tag this callback replaces itself with the real
     * message handler. On receiving a stream error the connection is terminated.
     */
  void _connectCbWrapper(message) {
    try {
      message = message as String;
    } catch (e) {
      message = message.toString();
    }
    if (message == null || message.isEmpty) return;
    if (message.trim().indexOf("<open ") == 0 ||
        message.trim().indexOf("<?xml") == 0) {
      // Strip the XML Declaration, if there is one
      String data = message.replaceAll(new RegExp(r"^(<\?.*?\?>\s*)*"), "");
      if (data == '') return;

      xml.XmlDocument streamStart = xml.parse(data);
      this._conn.xmlInput(streamStart.rootElement);
      this._conn.rawInput(message);

      //_handleStreamSteart will check for XML errors and disconnect on error
      if (this._handleStreamStart(streamStart)) {
        //_connect_cb will check for stream:error and disconnect on error
        this.connectCb(streamStart.rootElement);
      }
    } else if (message.trim().indexOf("<close ") == 0) {
      // <close xmlns="urn:ietf:params:xml:ns:xmpp-framing />
      this._conn.rawInput(message);
      this._conn.xmlInput(xml.parse(message).rootElement);
      String seeUri =
          xml.parse(message).rootElement.getAttribute("see-other-uri");
      if (seeUri != null && seeUri.isNotEmpty) {
        this._conn.changeConnectStatus(Strophe.Status['REDIRECT'],
            "Received see-other-uri, resetting connection");
        this._conn.reset();
        this._conn.service = seeUri;
        this._connect();
      } else {
        this._conn.changeConnectStatus(
            Strophe.Status['CONNFAIL'], "Received closing stream");
        this._conn.doDisconnect();
      }
    } else {
      String string = this._streamWrap(message);
      xml.XmlDocument elem = xml.parse(string);
      this.socketListen.onData(this._onMessage);
      this._conn.connectCb(elem, null, message);
    }
  }

  /** PrivateFunction: _disconnect
     *  _Private_ function called by Strophe.Connection.disconnect
     *
     *  Disconnects and sends a last stanza if one is given
     *
     *  Parameters:
     *    (Request) pres - This stanza will be sent before disconnecting.
     */
  void _disconnect([StanzaBuilder pres]) {
    if (this.socket != null && this.socket.readyState != WebSocket.CLOSED) {
      if (pres != null) {
        this._conn.send(pres.tree());
      }

      StanzaBuilder close =
          Strophe.$build("close", {"xmlns": Strophe.NS['FRAMING']});
      this._conn.xmlOutput(close.tree());
      String closeString = Strophe.serialize(close.tree());
      this._conn.rawOutput(closeString);
      try {
        if (this.socket != null) this.socket.add(closeString);
      } catch (e) {
        Strophe.info("Couldn't send <close /> tag.");
      }
      this._conn.doDisconnect();
    }
  }

  /** PrivateFunction: _doDisconnect
     *  _Private_ function to disconnect.
     *
     *  Just closes the Socket for WebSockets
     */
  void doDisconnect() {
    this._doDisconnect();
  }

  void _doDisconnect() {
    this._closeSocket();
  }

  /** PrivateFunction _streamWrap
     *  _Private_ helper function to wrap a stanza in a <stream> tag.
     *  This is used so Strophe can process stanzas from WebSockets like BOSH
     */
  String _streamWrap(String stanza) {
    return "<wrapper>" + stanza + '</wrapper>';
  }

  /** PrivateFunction: _closeSocket
     *  _Private_ function to close the WebSocket.
     *
     *  Closes the socket if it is still open and deletes it
     */
  void _closeSocket() {
    if (this.socket != null) {
      try {
        this.socket.handleError(() {});
        this.socketListen.cancel();
        this.socketListen = null;
        this.socket.close();
        this.socket = null;
      } catch (e) {}
    }
  }

  /** PrivateFunction: _emptyQueue
     * _Private_ function to check if the message queue is empty.
     *
     *  Returns:
     *    True, because WebSocket messages are send immediately after queueing.
     */
  bool emptyQueue() {
    return this._emptyQueue();
  }

  bool _emptyQueue() {
    return true;
  }

  /** PrivateFunction: _onClose
     * _Private_ function to handle websockets closing.
     *
     * Nothing to do here for WebSockets
     */
  void _onClose() {
    if (this._conn.connected && !this._conn.disconnecting) {
      Strophe.error("Websocket closed unexpectedly");
      this._conn.doDisconnect();
    } else if (!this._conn.connected && this.socket != null) {
      // in case the onError callback was not called (Safari 10 does not
      // call onerror when the initial connection fails) we need to
      // dispatch a CONNFAIL status update to be consistent with the
      // behavior on other browsers.
      Strophe.error("Websocket closed unexcectedly");
      this._conn.changeConnectStatus(Strophe.Status['CONNFAIL'],
          "The WebSocket connection could not be established or was disconnected.");
      this._conn.doDisconnect();
    } else {
      Strophe.info("Websocket closed");
    }
  }

  /** PrivateFunction: _onDisconnectTimeout
     *  _Private_ timeout handler for handling non-graceful disconnection.
     *
     *  This does nothing for WebSockets
     */
  void onDisconnectTimeout() {
    this._onDisconnectTimeout();
  }

  void _onDisconnectTimeout() {}

  /** PrivateFunction: _abortAllRequests
     *  _Private_ helper function that makes sure all pending requests are aborted.
     */
  void abortAllRequests() {
    _abortAllRequests();
  }

  void _abortAllRequests() {}

  /** PrivateFunction: _onError
     * _Private_ function to handle websockets errors.
     *
     * Parameters:
     * (Object) error - The websocket error.
     */
  void _onError(Object error) {
    Strophe.error("Websocket error " + error.toString());
    this._conn.changeConnectStatus(Strophe.Status['CONNFAIL'],
        "The WebSocket connection could not be established or was disconnected.");
    this._disconnect();
  }

  /** PrivateFunction: _onIdle
     *  _Private_ function called by Strophe.Connection._onIdle
     *
     *  sends all queued stanzas
     */
  void onIdle() {
    this._onIdle();
  }

  void _onIdle() {
    List data = this._conn.data;
    if (data.length > 0 && !this._conn.paused) {
      for (int i = 0; i < data.length; i++) {
        if (data[i] != null) {
          xml.XmlElement stanza;
          String rawStanza;
          if (data[i] == "restart") {
            stanza = this._buildStream().tree();
          } else {
            stanza = data[i];
          }
          rawStanza = Strophe.serialize(stanza);
          this._conn.xmlOutput(stanza);
          this._conn.rawOutput(rawStanza);
          if (this.socket != null) this.socket.add(rawStanza);
        }
      }
      this._conn.data = [];
    }
  }

  /** PrivateFunction: _onMessage
     * _Private_ function to handle websockets messages.
     *
     * This function parses each of the messages as if they are full documents.
     * [TODO : We may actually want to use a SAX Push parser].
     *
     * Since all XMPP traffic starts with
     *  <stream:stream version='1.0'
     *                 xml:lang='en'
     *                 xmlns='jabber:client'
     *                 xmlns:stream='http://etherx.jabber.org/streams'
     *                 id='3697395463'
     *                 from='SERVER'>
     *
     * The first stanza will always fail to be parsed.
     *
     * Additionally, the seconds stanza will always be <stream:features> with
     * the stream NS defined in the previous stanza, so we need to 'force'
     * the inclusion of the NS in this stanza.
     *
     * Parameters:
     * (string) message - The websocket message.
     */
  void _onMessage(dynamic msg) {
    String message = msg as String;
    xml.XmlDocument elem;
    String data;
    // check for closing stream
    String close = '<close xmlns="urn:ietf:params:xml:ns:xmpp-framing" />';
    if (message == close) {
      this._conn.rawInput(close);
      this._conn.xmlInput(xml.parse(message).rootElement);
      if (!this._conn.disconnecting) {
        this._conn.doDisconnect();
      }
      return;
    } else if (message.trim().indexOf("<open ") == 0) {
      // This handles stream restarts
      elem = xml.parse(message);
      if (!this._handleStreamStart(elem)) {
        return;
      }
    } else {
      data = this._streamWrap(message);
      elem = xml.parse(data);
    }
    if (this._checkStreamError(elem, Strophe.Status['ERROR'])) {
      return;
    }

    //handle unavailable presence stanza before disconnecting
    xml.XmlElement firstChild = elem.firstChild;
    if (this._conn.disconnecting &&
        firstChild.name.qualified == "presence" &&
        firstChild.getAttribute("type") == "unavailable") {
      this._conn.xmlInput(elem.root);
      this._conn.rawInput(Strophe.serialize(elem));
      // if we are already disconnecting we will ignore the unavailable stanza and
      // wait for the </stream:stream> tag before we close the connection
      return;
    }
    this._conn.dataRecv(elem.rootElement, message);
  }

  /** PrivateFunction: _onOpen
     * _Private_ function to handle websockets connection setup.
     *
     * The opening stream tag is sent here.
     */
  _onOpen() {
    StanzaBuilder start = this._buildStream();
    this._conn.xmlOutput(start.tree());

    String startString = Strophe.serialize(start.tree());
    this._conn.rawOutput(startString);
    if (this.socket != null) this.socket.add(startString);
  }

  /** PrivateFunction: _reqToData
     * _Private_ function to get a stanza out of a request.
     *
     * WebSockets don't use requests, so the passed argument is just returned.
     *
     *  Parameters:
     *    (Object) stanza - The stanza.
     *
     *  Returns:
     *    The stanza that was passed.
     */
  xml.XmlElement reqToData(stanza) {
    return this._reqToData(stanza);
  }

  xml.XmlElement _reqToData(stanza) {
    if (stanza == null) return null;
    //if (stanza is StropheRequest) return stanza.getResponse();
    if (stanza is xml.XmlDocument) return stanza.rootElement;
    return stanza as xml.XmlElement;
  }

  /** PrivateFunction: _send
     *  _Private_ part of the Connection.send function for WebSocket
     *
     * Just flushes the messages that are in the queue
     */
  send() {
    this._send();
  }

  _send() {
    this._conn.flush();
  }

  /** PrivateFunction: _sendRestart
     *
     *  Send an xmpp:restart stanza.
     */
  sendRestart() {
    this._sendRestart();
  }

  _sendRestart() {
    this._conn.idleTimeout.cancel();
    this._conn.onIdle();
  }

  StropheConnection get conn => null;
}
