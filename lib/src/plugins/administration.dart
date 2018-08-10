import 'package:strophe/src/core.dart';
import 'package:strophe/src/enums.dart';
import 'package:strophe/src/plugins/plugins.dart';

class AdministrationPlugin extends PluginClass {
  @override
  init(StropheConnection conn) {
    this.connection = conn;
    if (Strophe.NS['COMMANDS'] == null)
      Strophe.addNamespace('COMMANDS', 'http://jabber.org/protocol/commands');
    Strophe.addNamespace('REGISTERED_USERS_NUM',
        'http://jabber.org/protocol/admin#get-registered-users-num');
    Strophe.addNamespace('ONLINE_USERS_NUM',
        'http://jabber.org/protocol/admin#get-online-users-num');
  }

  getRegisteredUsersNum(Function success, [Function error]) {
    String id = this.connection.getUniqueId('get-registered-users-num');
    this.connection.sendIQ(
        Strophe.$iq({
          'type': 'set',
          'id': id,
          'xml:lang': 'en',
          'to': this.connection.domain
        }).c('command', {
          'xmlns': Strophe.NS['COMMANDS'],
          'action': 'execute',
          'node': Strophe.NS['REGISTERED_USERS_NUM']
        }).tree(),
        success,
        error);
    return id;
  }

  getOnlineUsersNum(Function success, [Function error]) {
    String id = this.connection.getUniqueId('get-registered-users-num');
    this.connection.sendIQ(
        Strophe.$iq({
          'type': 'set',
          'id': id,
          'xml:lang': 'en',
          'to': this.connection.domain
        }).c('command', {
          'xmlns': Strophe.NS['COMMANDS'],
          'action': 'execute',
          'node': Strophe.NS['ONLINE_USERS_NUM']
        }).tree(),
        success,
        error);
    return id;
  }
}
