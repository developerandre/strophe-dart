import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:strophe/src/core.dart';
import 'package:strophe/src/enums.dart';
import 'package:strophe/src/sessionstorage.dart';
import 'package:xml/xml.dart' as xml;

class StropheBosh extends ServiceType {
  StropheConnection _conn;

  int rid;

  String sid;

  int hold;

  int wait;

  int window;

  int errors;

  int inactivity;

  Map<String, String> lastResponseHeaders;

  List<StropheRequest> _requests;

  bool disconnecting;

  StropheBosh(StropheConnection connection) {
    this._conn = connection;
    /* request id for body tags */
    this.rid = new Random().nextInt(4294967295);
    /* The current session ID. */
    this.sid = null;

    // default BOSH values
    this.hold = 1;
    this.wait = 60;
    this.window = 5;
    this.errors = 0;
    this.inactivity = null;

    this.lastResponseHeaders = null;

    this._requests = [];
  }
  @override
  StropheConnection get conn => null;
/** Variable: strip
     *
     *  BOSH-Connections will have all stanzas wrapped in a <body> tag when
     *  passed to <Strophe.Connection.xmlInput> or <Strophe.Connection.xmlOutput>.
     *  To strip this tag, User code can set <Strophe.Bosh.strip> to "body":
     *
     *  > Strophe.Bosh.prototype.strip = "body";
     *
     *  This will enable stripping of the body tag in both
     *  <Strophe.Connection.xmlInput> and <Strophe.Connection.xmlOutput>.
     */
  String strip = null;

  /** PrivateFunction: _buildBody
     *  _Private_ helper function to generate the <body/> wrapper for BOSH.
     *
     *  Returns:
     *    A Strophe.Builder with a <body/> element.
     */
  StanzaBuilder _buildBody() {
    StanzaBuilder bodyWrap = Strophe.$build(
        'body', {'rid': this.rid++, 'xmlns': Strophe.NS['HTTPBIND']});
    if (this.sid != null) {
      bodyWrap = bodyWrap.attrs({sid: this.sid});
    }
    if (this._conn.options['keepalive'] &&
        this._conn.sessionCachingSupported()) {
      this._cacheSession();
    }
    return bodyWrap;
  }

  /** PrivateFunction: _reset
     *  Reset the connection.
     *
     *  This function is called by the reset function of the Strophe Connection
     */
  reset() {
    this._reset();
  }

  _reset() {
    this.rid = new Random().nextInt(4294967295);
    this.sid = null;
    this.errors = 0;
    if (this._conn.sessionCachingSupported()) {
      SessionStorage.removeItem('strophe-bosh-session');
    }

    this._conn.nextValidRid(this.rid);
  }

  /** PrivateFunction: _connect
     *  _Private_ function that initializes the BOSH connection.
     *
     *  Creates and sends the Request that initializes the BOSH connection.
     */
  connect([int wait, int hold, String route]) {
    _connect(wait, hold, route);
  }

  _connect([int wait, int hold, String route]) {
    this.wait = wait ?? this.wait;
    this.hold = hold ?? this.hold;
    this.errors = 0;

    // build the body tag
    var body = this._buildBody().attrs({
      'to': this._conn.domain,
      "xml:lang": "en",
      'wait': this.wait,
      'hold': this.hold,
      'content': "text/xml; charset=utf-8",
      'ver': "1.6",
      "xmpp:version": "1.0",
      "xmlns:xmpp": Strophe.NS['BOSH']
    });

    if (route != null && route.isNotEmpty) {
      body.attrs({route: route});
    }
    StropheRequest req =
        new StropheRequest(body.tree(), null, body.tree().getAttribute("rid"));
    req.func = this._onRequestStateChange(this._conn.connectCb, req);
    req.origFunc = req.func;

    this._requests.add(req);
    this._throttledRequestHandler();
  }

  /** PrivateFunction: _attach
     *  Attach to an already created and authenticated BOSH session.
     *
     *  This function is provided to allow Strophe to attach to BOSH
     *  sessions which have been created externally, perhaps by a Web
     *  application.  This is often used to support auto-login type features
     *  without putting user credentials into the page.
     *
     *  Parameters:
     *    (String) jid - The full JID that is bound by the session.
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
     *      allowed range of request ids that are valid.  The default is 5.
     */
  void attach(String jid, String sid, int rid, Function callback, int wait,
      int hold, int wind) {
    this._attach(jid, sid, rid, callback, wait, hold, wind);
  }

  _attach(String jid, String sid, int rid, Function callback, int wait,
      int hold, int wind) {
    this._conn.jid = jid;
    this.sid = sid;
    this.rid = rid;

    this._conn.connectCallback = callback;

    this._conn.domain = Strophe.getDomainFromJid(this._conn.jid);

    this._conn.authenticated = true;
    this._conn.connected = true;

    this.wait = wait ?? this.wait;
    this.hold = hold ?? this.hold;
    this.window = wind ?? this.window;

    this._conn.changeConnectStatus(Strophe.Status['ATTACHED'], null);
  }

  /** PrivateFunction: _restore
     *  Attempt to restore a cached BOSH session
     *
     *  Parameters:
     *    (String) jid - The full JID that is bound by the session.
     *      This parameter is optional but recommended, specifically in cases
     *      where prebinded BOSH sessions are used where it's important to know
     *      that the right session is being restored.
     *    (Function) callback The connect callback function.
     *    (Integer) wait - The optional HTTPBIND wait value.  This is the
     *      time the server will wait before returning an empty result for
     *      a request.  The default setting of 60 seconds is recommended.
     *      Other settings will require tweaks to the Strophe.TIMEOUT value.
     *    (Integer) hold - The optional HTTPBIND hold value.  This is the
     *      number of connections the server will hold at one time.  This
     *      should almost always be set to 1 (the default).
     *    (Integer) wind - The optional HTTBIND window value.  This is the
     *      allowed range of request ids that are valid.  The default is 5.
     */
  void restore(String jid, Function callback, int wait, int hold, int wind) {
    this._restore(jid, callback, wait, hold, wind);
  }

  _restore(String jid, Function callback, int wait, int hold, int wind) {
    var session =
        JsonCodec().decode(SessionStorage.getItem('strophe-bosh-session'));
    if (session != null &&
        session.rid &&
        session.sid &&
        session.jid &&
        (jid == null ||
            Strophe.getBareJidFromJid(session.jid) ==
                Strophe.getBareJidFromJid(jid) ||
            // If authcid is null, then it's an anonymous login, so
            // we compare only the domains:
            ((Strophe.getNodeFromJid(jid) == null) &&
                (Strophe.getDomainFromJid(session.jid) == jid)))) {
      this._conn.restored = true;
      this._attach(
          session.jid, session.sid, session.rid, callback, wait, hold, wind);
    } else {
      throw {
        'name': "StropheSessionError",
        'message': "_restore: no restoreable session."
      };
    }
  }

  /** PrivateFunction: _cacheSession
     *  _Private_ handler for the beforeunload event.
     *
     *  This handler is used to process the Bosh-part of the initial request.
     *  Parameters:
     *    (Request) bodyWrap - The received stanza.
     */
  void _cacheSession() {
    if (this._conn.authenticated) {
      if (this._conn.jid != null &&
          this._conn.jid.isNotEmpty &&
          this.rid != null &&
          this.rid != 0 &&
          this.sid != null &&
          this.sid.isNotEmpty) {
        SessionStorage.setItem(
            'strophe-bosh-session',
            JsonCodec().encode(
                {'jid': this._conn.jid, 'rid': this.rid, 'sid': this.sid}));
      }
    } else {
      SessionStorage.removeItem('strophe-bosh-session');
    }
  }

  /** PrivateFunction: _connect_cb
     *  _Private_ handler for initial connection request.
     *
     *  This handler is used to process the Bosh-part of the initial request.
     *  Parameters:
     *    (Request) bodyWrap - The received stanza.
     */
  connectCb(xml.XmlElement bodyWrap) {
    this._connectCb(bodyWrap);
  }

  _connectCb(xml.XmlElement bodyWrap) {
    String typ = bodyWrap.getAttribute("type");
    String cond;
    List<xml.XmlElement> conflict;
    if (typ != null && typ == "terminate") {
      // an error occurred
      cond = bodyWrap.getAttribute("condition");
      Strophe.error("BOSH-Connection failed: " + cond);
      conflict = bodyWrap.findAllElements("conflict");
      if (cond != null) {
        if (cond == "remote-stream-error" && conflict.length > 0) {
          cond = "conflict";
        }
        this._conn.changeConnectStatus(Strophe.Status['CONNFAIL'], cond);
      } else {
        this._conn.changeConnectStatus(Strophe.Status['CONNFAIL'], "unknown");
      }
      this._conn.doDisconnect(cond);
      return Strophe.Status['CONNFAIL'];
    }

    // check to make sure we don't overwrite these if _connect_cb is
    // called multiple times in the case of missing stream:features
    if (this.sid == null || this.sid.isEmpty) {
      this.sid = bodyWrap.getAttribute("sid");
    }
    String wind = bodyWrap.getAttribute('requests');
    if (wind != null) {
      this.window = int.parse(wind);
    }
    String hold = bodyWrap.getAttribute('hold');
    if (hold != null) {
      this.hold = int.parse(hold);
    }
    String wait = bodyWrap.getAttribute('wait');
    if (wait != null) {
      this.wait = int.parse(wait);
    }
    String inactivity = bodyWrap.getAttribute('inactivity');
    if (inactivity != null) {
      this.inactivity = int.parse(inactivity);
    }
  }

  /** PrivateFunction: _disconnect
     *  _Private_ part of Connection.disconnect for Bosh
     *
     *  Parameters:
     *    (Request) pres - This stanza will be sent before disconnecting.
     */
  disconnect(xml.XmlElement pres) {
    this._disconnect(pres);
  }

  _disconnect(xml.XmlElement pres) {
    this._sendTerminate(pres);
  }

  /** PrivateFunction: _doDisconnect
     *  _Private_ function to disconnect.
     *
     *  Resets the SID and RID.
     */
  doDisconnect() {
    this._doDisconnect();
  }

  _doDisconnect() {
    this.sid = null;
    this.rid = new Random().nextInt(4294967295);
    if (this._conn.sessionCachingSupported()) {
      SessionStorage.removeItem('strophe-bosh-session');
    }

    this._conn.nextValidRid(this.rid);
  }

  /** PrivateFunction: _emptyQueue
     * _Private_ function to check if the Request queue is empty.
     *
     *  Returns:
     *    True, if there are no Requests queued, False otherwise.
     */
  bool emptyQueue() {
    return this._emptyQueue();
  }

  bool _emptyQueue() {
    return this._requests.length == 0;
  }

  /** PrivateFunction: _callProtocolErrorHandlers
     *  _Private_ function to call error handlers registered for HTTP errors.
     *
     *  Parameters:
     *    (Request) req - The request that is changing readyState.
     */
  _callProtocolErrorHandlers(StropheRequest req) {
    int reqStatus = this._getRequestStatus(req);
    Function err_callback = this._conn.protocolErrorHandlers['HTTP'][reqStatus];
    if (err_callback != null) {
      err_callback.call(this, reqStatus);
    }
  }

  /** PrivateFunction: _hitError
     *  _Private_ function to handle the error count.
     *
     *  Requests are resent automatically until their error count reaches
     *  5.  Each time an error is encountered, this function is called to
     *  increment the count and disconnect if the count is too high.
     *
     *  Parameters:
     *    (Integer) reqStatus - The request status.
     */
  void _hitError(int reqStatus) {
    this.errors++;
    Strophe.warn("request errored, status: " +
        reqStatus.toString() +
        ", number of errors: " +
        this.errors.toString());
    if (this.errors > 4) {
      this._conn.onDisconnectTimeout();
    }
  }

  /** PrivateFunction: _onDisconnectTimeout
     *  _Private_ timeout handler for handling non-graceful disconnection.
     *
     *  Cancels all remaining Requests and clears the queue.
     */
  onDisconnectTimeout() {
    this._onDisconnectTimeout();
  }

  _onDisconnectTimeout() {
    this._abortAllRequests();
  }

  /** PrivateFunction: _abortAllRequests
     *  _Private_ helper function that makes sure all pending requests are aborted.
     */
  abortAllRequests() {
    this._abortAllRequests();
  }

  _abortAllRequests() {
    StropheRequest req;
    while (this._requests.length > 0) {
      req = this._requests.removeLast();
      req.abort = true;
      req.xhr.close();
    }
  }

  /** PrivateFunction: _onIdle
     *  _Private_ handler called by Strophe.Connection._onIdle
     *
     *  Sends all queued Requests or polls with empty Request if there are none.
     */
  onIdle() {
    this._onIdle();
  }

  _onIdle() {
    var data = this._conn.data;
    // if no requests are in progress, poll
    if (this._conn.authenticated &&
        this._requests.length == 0 &&
        data.length == 0 &&
        !this._conn.disconnecting) {
      Strophe.info("no requests during idle cycle, sending " + "blank request");
      data.add(null);
    }

    if (this._conn.paused) {
      return;
    }

    if (this._requests.length < 2 && data.length > 0) {
      StanzaBuilder body = this._buildBody();
      for (int i = 0; i < data.length; i++) {
        if (data[i] != null) {
          if (data[i] == "restart") {
            body.attrs({
              'to': this._conn.domain,
              "xml:lang": "en",
              "xmpp:restart": "true",
              "xmlns:xmpp": Strophe.NS['BOSH']
            });
          } else {
            body.cnode(data[i]).up();
          }
        }
      }
      this._conn.data = [];
      StropheRequest req = new StropheRequest(
          body.tree(), null, body.tree().getAttribute("rid"));
      req.func = this._onRequestStateChange(this._conn.dataRecv, req);
      req.origFunc = req.func;
      this._requests.add(req);
      this._throttledRequestHandler();
    }

    if (this._requests.length > 0) {
      var time_elapsed = this._requests[0].age();
      if (this._requests[0].dead != null) {
        if (this._requests[0].timeDead() >
            (Strophe.SECONDARY_TIMEOUT * this.wait).floor()) {
          this._throttledRequestHandler();
        }
      }

      if (time_elapsed > (Strophe.TIMEOUT * this.wait).floor()) {
        Strophe.warn("Request " +
            this._requests[0].id.toString() +
            " timed out, over " +
            (Strophe.TIMEOUT * this.wait).floor().toString() +
            " seconds since last activity");
        this._throttledRequestHandler();
      }
    }
  }

  /** PrivateFunction: _getRequestStatus
     *
     *  Returns the HTTP status code from a Request
     *
     *  Parameters:
     *    (Request) req - The Request instance.
     *    (Integer) def - The default value that should be returned if no
     *          status value was found.
     */
  int _getRequestStatus(StropheRequest req, [num def]) {
    int reqStatus;
    if (req.response != null) {
      try {
        reqStatus = req.response.statusCode;
      } catch (e) {
        Strophe.error("Caught an error while retrieving a request's status, " +
            "reqStatus: " +
            reqStatus.toString());
      }
    }
    if (reqStatus == null) {
      reqStatus = def ?? 0;
    }
    return reqStatus;
  }

  /** PrivateFunction: _onRequestStateChange
     *  _Private_ handler for Request state changes.
     *
     *  This function is called when the XMLHttpRequest readyState changes.
     *  It contains a lot of error handling logic for the many ways that
     *  requests can fail, and calls the request callback when requests
     *  succeed.
     *
     *  Parameters:
     *    (Function) func - The handler for the request.
     *    (Request) req - The request that is changing readyState.
     */
  _onRequestStateChange(Function func, StropheRequest req) {
    Strophe.debug("request id " +
        req.id.toString() +
        "." +
        req.sends.toString() +
        " state changed to " +
        (req.response != null ? req.response.statusCode : "0"));
    if (req.abort) {
      req.abort = false;
      return;
    }
    if (req.response != null &&
        req.response.statusCode != 200 &&
        req.response.statusCode != 304) {
      // The request is not yet complete
      return;
    }
    int reqStatus = this._getRequestStatus(req);
    this.lastResponseHeaders = req.response.headers;
    if (this.disconnecting && reqStatus >= 400) {
      this._hitError(reqStatus);
      this._callProtocolErrorHandlers(req);
      return;
    }

    bool valid_request = reqStatus > 0 && reqStatus < 500;
    bool too_many_retries = req.sends > this._conn.maxRetries;
    if (valid_request || too_many_retries) {
      // remove from internal queue
      this._removeRequest(req);
      Strophe.debug(
          "request id " + req.id.toString() + " should now be removed");
    }

    if (reqStatus == 200) {
      // request succeeded
      bool reqIs0 = (this._requests[0] == req);
      bool reqIs1 = (this._requests[1] == req);
      // if request 1 finished, or request 0 finished and request
      // 1 is over Strophe.SECONDARY_TIMEOUT seconds old, we need to
      // restart the other - both will be in the first spot, as the
      // completed request has been removed from the queue already
      if (reqIs1 ||
          (reqIs0 &&
              this._requests.length > 0 &&
              this._requests[0].age() >
                  (Strophe.SECONDARY_TIMEOUT * this.wait).floor())) {
        this._restartRequest(0);
      }
      this._conn.nextValidRid(int.parse(req.rid) + 1);
      Strophe.debug("request id " +
          req.id.toString() +
          "." +
          req.sends.toString() +
          " got 200");
      func(req); // call handler
      this.errors = 0;
    } else if (reqStatus == 0 ||
        (reqStatus >= 400 && reqStatus < 600) ||
        reqStatus >= 12000) {
      // request failed
      Strophe.error("request id " +
          req.id.toString() +
          "." +
          req.sends.toString() +
          " error " +
          reqStatus.toString() +
          " happened");
      this._hitError(reqStatus);
      this._callProtocolErrorHandlers(req);
      if (reqStatus >= 400 && reqStatus < 500) {
        this._conn.changeConnectStatus(Strophe.Status['DISCONNECTING'], null);
        this._conn.doDisconnect();
      }
    } else {
      Strophe.error("request id " +
          req.id.toString() +
          "." +
          req.sends.toString() +
          " error " +
          reqStatus.toString() +
          " happened");
    }

    if (!valid_request && !too_many_retries) {
      this._throttledRequestHandler();
    } else if (too_many_retries && !this._conn.connected) {
      this._conn.changeConnectStatus(Strophe.Status['CONNFAIL'], "giving-up");
    }
  }

  /** PrivateFunction: _processRequest
     *  _Private_ function to process a request in the queue.
     *
     *  This function takes requests off the queue and sends them and
     *  restarts dead requests.
     *
     *  Parameters:
     *    (Integer) i - The index of the request in the queue.
     */
  _processRequest(int i) {
    StropheRequest req = this._requests[i];
    int reqStatus = this._getRequestStatus(req, -1);

    // make sure we limit the number of retries
    if (req.sends > this._conn.maxRetries) {
      this._conn.onDisconnectTimeout();
      return;
    }

    var time_elapsed = req.age();
    var primaryTimeout = (time_elapsed is num &&
        time_elapsed > (Strophe.TIMEOUT * this.wait).floor());
    var secondaryTimeout = (req.dead != null &&
        req.timeDead() > (Strophe.SECONDARY_TIMEOUT * this.wait).floor());
    var requestCompletedWithServerError =
        (req.response != null && (reqStatus < 1 || reqStatus >= 500));
    if (primaryTimeout || secondaryTimeout || requestCompletedWithServerError) {
      if (secondaryTimeout) {
        Strophe.error("Request " +
            this._requests[i].id.toString() +
            " timed out (secondary), restarting");
      }
      req.abort = true;
      req.xhr.close();
      this._requests[i] =
          new StropheRequest(req.xmlData, req.origFunc, req.rid, req.sends);
      req = this._requests[i];
    }

    if (req.response == null) {
      Strophe.debug("request id " +
          req.id.toString() +
          "." +
          req.sends.toString() +
          " posting");

      // Fires the XHR request -- may be invoked immediately
      // or on a gradually expanding retry window for reconnects

      // Implement progressive backoff for reconnects --
      // First retry (send == 1) should also be instantaneous
      if (req.sends > 1) {
        // Using a cube of the retry number creates a nicely
        // expanding retry window
        num backoff =
            min((Strophe.TIMEOUT * this.wait).floor(), pow(req.sends, 3)) *
                1000;
        new Timer(new Duration(milliseconds: backoff), () {
          // XXX: setTimeout should be called only with function expressions (23974bc1)
          this._sendFunc(req);
        });
      } else {
        this._sendFunc(req);
      }

      req.sends++;

      //if (this._conn.xmlOutput != Strophe.Connection.xmlOutput) {
      if (req.xmlData.name == this.strip && req.xmlData.children.length > 0) {
        this._conn.xmlOutput(req.xmlData.firstChild);
      } else {
        this._conn.xmlOutput(req.xmlData);
      }
      //}
      //if (this._conn.rawOutput != Strophe.Connection.rawOutput) {
      this._conn.rawOutput(req.data);
      //}
    } else {
      Strophe.debug("_processRequest: " +
          (i == 0 ? "first" : "second") +
          " request has readyState of " +
          (req.response != null ? req.response.reasonPhrase : "0"));
    }
  }

  _sendFunc(StropheRequest req) {
    String contentType;
    Map<String, dynamic> map;
    http.Request request;
    try {
      contentType =
          this._conn.options['contentType'] ?? "text/xml; charset=utf-8";
      request = new http.Request("POST", Uri.parse(this._conn.service));
      request.persistentConnection = this._conn.options['sync'] ? false : true;
      map = {"Content-Type": contentType};
      if (this._conn.options['withCredentials']) {
        map['withCredentials'] = true;
      }
    } catch (e2) {
      Strophe.error("XHR open failed: " + e2.toString());
      if (!this._conn.connected) {
        this
            ._conn
            .changeConnectStatus(Strophe.Status['CONNFAIL'], "bad-service");
      }
      this._conn.disconnect();
      return;
    }
    req.date = new DateTime.now().millisecondsSinceEpoch;
    if (this._conn.options['customHeaders']) {
      var headers = this._conn.options['customHeaders'];
      for (var header in headers) {
        map[header] = headers[header];
      }
    }

    request.bodyFields = map;
    req.xhr.send(request).then((http.StreamedResponse response) {
      req.response = response as http.Response;
    }).catchError(() {});
  }

  /** PrivateFunction: _removeRequest
     *  _Private_ function to remove a request from the queue.
     *
     *  Parameters:
     *    (Request) req - The request to remove.
     */
  void _removeRequest(StropheRequest req) {
    Strophe.debug("removing request");
    for (int i = this._requests.length - 1; i >= 0; i--) {
      if (req == this._requests[i]) {
        this._requests.removeAt(i);
      }
    }
    this._throttledRequestHandler();
  }

  /** PrivateFunction: _restartRequest
     *  _Private_ function to restart a request that is presumed dead.
     *
     *  Parameters:
     *    (Integer) i - The index of the request in the queue.
     */
  _restartRequest(i) {
    var req = this._requests[i];
    if (req.dead == null) {
      req.dead = new DateTime.now().millisecondsSinceEpoch;
    }

    this._processRequest(i);
  }

  /** PrivateFunction: _reqToData
     * _Private_ function to get a stanza out of a request.
     *
     * Tries to extract a stanza out of a Request Object.
     * When this fails the current connection will be disconnected.
     *
     *  Parameters:
     *    (Object) req - The Request.
     *
     *  Returns:
     *    The stanza that was passed.
     */
  xml.XmlElement reqToData(dynamic req) {
    req = req as StropheRequest;
    return this._reqToData(req);
  }

  xml.XmlElement _reqToData(StropheRequest req) {
    try {
      return req.getResponse();
    } catch (e) {
      if (e != "parsererror") {
        throw e;
      }
      this._conn.disconnect("strophe-parsererror");
      return null;
    }
  }

  /** PrivateFunction: _sendTerminate
     *  _Private_ function to send initial disconnect sequence.
     *
     *  This is the first step in a graceful disconnect.  It sends
     *  the BOSH server a terminate body and includes an unavailable
     *  presence if authentication has completed.
     */
  _sendTerminate(pres) {
    Strophe.info("_sendTerminate was called");
    StanzaBuilder body = this._buildBody().attrs({'type': "terminate"});
    if (pres) {
      body.cnode(pres.tree());
    }
    StropheRequest req =
        new StropheRequest(body.tree(), null, body.tree().getAttribute("rid"));
    req.func = this._onRequestStateChange(this._conn.dataRecv, req);
    req.origFunc = req.func;
    this._requests.add(req);
    this._throttledRequestHandler();
  }

  /** PrivateFunction: _send
     *  _Private_ part of the Connection.send function for BOSH
     *
     * Just triggers the RequestHandler to send the messages that are in the queue
     */
  send() {
    this._send();
  }

  _send() {
    if (this._conn.idleTimeout != null) this._conn.idleTimeout.cancel();
    this._throttledRequestHandler();

    // XXX: setTimeout should be called only with function expressions (23974bc1)
    this._conn.idleTimeout = new Timer(new Duration(milliseconds: 100), () {
      this._onIdle();
    });
  }

  /** PrivateFunction: _sendRestart
     *
     *  Send an xmpp:restart stanza.
     */
  sendRestart() {
    this._sendRestart();
  }

  _sendRestart() {
    this._throttledRequestHandler();
    if (this._conn.idleTimeout != null) this._conn.idleTimeout.cancel();
  }

  /** PrivateFunction: _throttledRequestHandler
     *  _Private_ function to throttle requests to the connection window.
     *
     *  This function makes sure we don't send requests so fast that the
     *  request ids overflow the connection window in the case that one
     *  request died.
     */
  _throttledRequestHandler() {
    if (this._requests == null) {
      Strophe.debug(
          "_throttledRequestHandler called with " + "undefined requests");
    } else {
      Strophe.debug("_throttledRequestHandler called with " +
          this._requests.length.toString() +
          " requests");
    }

    if (this._requests == null || this._requests.length == 0) {
      return;
    }

    if (this._requests.length > 0) {
      this._processRequest(0);
    }
    if (this._requests.length > 1 &&
        (int.parse(this._requests[0].rid) - int.parse(this._requests[1].rid))
                .abs() <
            this.window) {
      this._processRequest(1);
    }
  }
}
/** PrivateClass: Request
 *  _Private_ helper class that provides a cross implementation abstraction
 *  for a BOSH related XMLHttpRequest.
 *
 *  The Request class is used internally to encapsulate BOSH request
 *  information.  It is not meant to be used from user's code.
 */

/** PrivateConstructor: Request
 *  Create and initialize a new Request object.
 *
 *  Parameters:
 *    (XMLElement) elem - The XML data to be sent in the request.
 *    (Function) func - The function that will be called when the
 *      XMLHttpRequest readyState changes.
 *    (Integer) rid - The BOSH rid attribute associated with this request.
 *    (Integer) sends - The number of times this same request has been sent.
 */
class StropheRequest {
  int id;

  xml.XmlElement xmlData;

  String data;

  Function origFunc;

  Function func;

  num date;

  String rid;

  int sends;

  bool abort;

  int dead;

  http.Client xhr;
  http.Response response;

  StropheRequest(xml.XmlElement elem, Function func, String rid, [int sends]) {
    this.id = ++Strophe.requestId;
    this.xmlData = elem;
    this.data = Strophe.serialize(elem);
    // save original function in case we need to make a new request
    // from this one.
    this.origFunc = func;
    this.func = func;
    this.rid = rid;
    this.date = null;
    this.sends = sends ?? 0;
    this.abort = false;
    this.dead = null;
    this.age();
    this.xhr = this._newXHR();
  }
  num timeDead() {
    if (this.dead == null) {
      return 0;
    }
    int now = new DateTime.now().millisecondsSinceEpoch;
    return (now - this.dead) / 1000;
  }

  num age() {
    if (this.date == null || this.date == 0) {
      return 0;
    }
    int now = new DateTime.now().millisecondsSinceEpoch;
    return (now - this.date) / 1000;
  }

/** PrivateFunction: getResponse
     *  Get a response from the underlying XMLHttpRequest.
     *
     *  This function attempts to get a response from the request and checks
     *  for errors.
     *
     *  Throws:
     *    "parsererror" - A parser error occured.
     *    "badformat" - The entity has sent XML that cannot be processed.
     *
     *  Returns:
     *    The DOM element tree of the response.
     */
  xml.XmlElement getResponse() {
    String body = response.body;
    xml.XmlElement node = null;
    try {
      node = xml.parse(body).rootElement;
      Strophe.error("responseXML: " + Strophe.serialize(node));
      if (node == null) {
        throw {'message': 'Parsing produced null node'};
      }
    } catch (e) {
      // if (node.name == "parsererror") {
      Strophe.error("invalid response received" + e.toString());
      Strophe.error("responseText: " + body);
      throw "parsererror";
      //}
    }
    return node;
  }

  /** PrivateFunction: _newXHR
     *  _Private_ helper function to create XMLHttpRequests.
     *
     *  This function creates XMLHttpRequests across all implementations.
     *
     *  Returns:
     *    A new XMLHttpRequest.
     */
  http.Client _newXHR() {
    return new http.Client();
  }
}
