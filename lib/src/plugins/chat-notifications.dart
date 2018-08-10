import 'package:strophe/src/core.dart';
import 'package:strophe/src/enums.dart';
import 'package:strophe/src/plugins/plugins.dart';
import 'package:xml/xml.dart' as xml;

/**
 * Chat state notifications (XEP 0085) plugin
 * @see http://xmpp.org/extensions/xep-0085.html
 */
class ChatStatesNotificationPlugin extends PluginClass {
  @override
  init(StropheConnection conn) {
    this.connection = conn;
    statusChanged = (int status, [condition, el]) {
      if (status == Strophe.Status['CONNECTED'] ||
          status == Strophe.Status['ATTACHED']) {
        this.connection.addHandler(
            this._notificationReceived, Strophe.NS['CHATSTATES'], "message");
      }
    };
    Strophe.addNamespace('CHATSTATES', 'http://jabber.org/protocol/chatstates');
  }

  addActive(StanzaBuilder message) {
    return message.c('active', {'xmlns': Strophe.NS['CHATSTATES']}).up();
  }

  _notificationReceived(element) {
    xml.XmlElement message;
    if (element is String) {
      message = xml.parse(element).rootElement;
    } else if (element is xml.XmlElement)
      message = element;
    else if (element is xml.XmlDocument) message = element.rootElement;

    if (message != null && message.findAllElements('error').length > 0)
      return true;

    /* List<xml.XmlElement> composing =
            message.findAllElements('composing').toList(),
        paused = message.findAllElements('paused').toList(),
        active = message.findAllElements('active').toList(),
        inactive = message.findAllElements('inactive').toList(),
        gone = message.findAllElements('gone').toList();

    String jid = message.getAttribute('from'); */

    /*  if (composing.length > 0) {
      $(document).trigger('composing.chatstates', jid);
    }

    if (paused.length > 0) {
      $(document).trigger('paused.chatstates', jid);
    }

    if (active.length > 0) {
      $(document).trigger('active.chatstates', jid);
    }

    if (inactive.length > 0) {
      $(document).trigger('inactive.chatstates', jid);
    }

    if (gone.length > 0) {
      $(document).trigger('gone.chatstates', jid);
    } */

    return true;
  }

  sendActive(String jid, String type) {
    this._sendNotification(jid, type, 'active');
  }

  sendComposing(String jid, String type) {
    this._sendNotification(jid, type, 'composing');
  }

  sendPaused(String jid, String type) {
    this._sendNotification(jid, type, 'paused');
  }

  sendInactive(String jid, String type) {
    this._sendNotification(jid, type, 'inactive');
  }

  sendGone(String jid, String type) {
    this._sendNotification(jid, type, 'gone');
  }

  _sendNotification(String jid, String type, String notification) {
    if (type == null || type.isEmpty) type = 'chat';

    this.connection.send(Strophe.$msg({'to': jid, 'type': type}).c(
        notification, {'xmlns': Strophe.NS['CHATSTATES']}));
  }
}
