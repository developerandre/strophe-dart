import 'package:strophe/src/core.dart';
import 'package:strophe/src/enums.dart';
import 'package:strophe/src/plugins/plugins.dart';
import 'package:xml/xml.dart' as xml;
import 'package:xml/xml.dart';

class VCardTemp extends PluginClass {
  StanzaBuilder _buildIq(String type, String jid, [xml.XmlElement vCardEl]) {
    StanzaBuilder iq =
        Strophe.$iq(jid != null ? {'type': type, 'to': jid} : {'type': type});

    if (vCardEl != null) {
      iq.cnode(vCardEl);
    } else
      iq.c("vCard", {'xmlns': Strophe.NS['VCARD']});
    return iq;
  }

  init(StropheConnection conn) {
    this.connection = conn;
    return Strophe.addNamespace('VCARD', 'vcard-temp');
  }

  /* Function
         * Retrieve a vCard for a JID/Entity
         * Parameters:
         * (Function) handler_cb - The callback function used to handle the request.
         * (String) jid - optional - The name of the entity to request the vCard
         *     If no jid is given, this function retrieves the current user's vcard.
         * */
  get(Function handlerCb, String jid, Function errorCb) {
    var iq =
        _buildIq("get", jid ?? Strophe.getBareJidFromJid(this.connection.jid));
    return this.connection.sendIQ(iq.tree(), handlerCb, errorCb);
  }

  /* Function
         *  Set an entity's vCard.
         */
  set(Function handlerCb, VCardEl vCardEl, String jid, Function errorCb) {
    if (vCardEl == null) return null;
    StanzaBuilder iq = _buildIq("set",
        jid ?? Strophe.getBareJidFromJid(this.connection.jid), vCardEl.tree());
    return this.connection.sendIQ(iq.tree(), handlerCb, errorCb);
  }
}

class VCardEl {
  String FN = '';
  String FAMILY = '';
  String GIVEN = '';
  String MIDDLE = '';
  String NICKNAME = '';
  String URL = '';
  String BDAY = '';
  String ORGNAME = '';
  String ORGUNIT = '';
  String TITLE = '';
  String ROLE = '';
  String USERID = '';
  String JABBERID = '';
  String DESC = '';
  String EMAIL = '';
  List<VCardElAddr> _addresses = [];
  List<VCardElAddr> get addresses {
    return _addresses;
  }

  set addresses(List<VCardElAddr> addr) {
    if (addr != null) _addresses = addr;
  }

  VCardEl(
      {String fn,
      String family,
      String given,
      String middle,
      String nickName,
      String url,
      String bday,
      String orgName,
      String orgUnit,
      String title,
      String role,
      String userId,
      String jabberdId,
      String desc,
      String email}) {
    FN = fn ?? '';
    FAMILY = family ?? '';
    GIVEN = given ?? '';
    MIDDLE = middle ?? '';
    NICKNAME = nickName ?? '';
    URL = url ?? '';
    EMAIL = email ?? '';
    BDAY = bday ?? '';
    ORGNAME = orgName ?? '';
    ORGUNIT = orgUnit ?? '';
    TITLE = title ?? '';
    ROLE = role ?? '';
    USERID = userId ?? '';
    JABBERID = jabberdId ?? '';
    DESC = desc ?? '';
  }
  XmlElement tree() {
    StanzaBuilder build =
        Strophe.$build("vCard", {'xmlns': Strophe.NS['VCARD']})
            .c('FN')
            .t(FN)
            .up()
            .c('N')
            .c('FAMILY')
            .t(FAMILY)
            .up()
            .c('GIVEN')
            .t(GIVEN)
            .up()
            .c('MIDDLE')
            .t(MIDDLE)
            .up()
            .up()
            .c('NICKNAME')
            .t(NICKNAME)
            .up()
            .c('URL')
            .t(URL)
            .up()
            .c('EMAIL')
            .t(EMAIL)
            .up()
            .c('BDAY')
            .t(BDAY)
            .up()
            .c('ORG')
            .c('ORGNAME')
            .t(ORGNAME)
            .up()
            .c('ORGUNIT')
            .t(ORGUNIT)
            .up()
            .up()
            .c('TITLE')
            .t(TITLE)
            .up()
            .c('ROLE')
            .t(ROLE)
            .up();
    addresses.forEach((VCardElAddr addr) {
      if (addr != null) {
        addr.tree().children.forEach((XmlNode elem) {
          build.cnode(elem).up();
        });
      }
    });
    build
        .c('EMAIL')
        .c('INTERNET')
        .t(EMAIL)
        .up()
        .c('PREF')
        .t(EMAIL)
        .up()
        .c('USERID')
        .t(USERID)
        .up()
        .up()
        .c('JABBERID')
        .t(JABBERID)
        .c('DESC')
        .t(DESC);
    print(build.tree());
    return build.tree();
  }
}

class VCardElAddr {
  String VOICE_NUMBER = '';
  String FAX_NUMBER = '';
  String MSG_NUMBER = '';
  String WORK = '';
  String EXTADD = '';
  String STREET = '';
  String LOCALITY = '';
  String REGION = '';
  String PCODE = '';
  String CTRY = '';
  String typeAddr;
  VCardElAddr(this.typeAddr,
      {String voiceNum,
      String faxNum,
      String msgNum,
      String work,
      String extAddr,
      String street,
      String locality,
      String region,
      String pCode,
      String country}) {
    VOICE_NUMBER = voiceNum ?? '';
    FAX_NUMBER = faxNum ?? '';
    MSG_NUMBER = msgNum ?? '';
    WORK = work ?? '';
    EXTADD = extAddr ?? '';
    STREET = street ?? '';
    LOCALITY = locality ?? '';
    REGION = region ?? '';
    PCODE = pCode ?? '';
    CTRY = country ?? '';
  }
  XmlElement tree() {
    return Strophe.$build('addr', {})
        .c('TEL')
        .c(typeAddr != null ? typeAddr.toUpperCase() : 'WORK')
        .up()
        .c('VOICE')
        .up()
        .c('NUMBER')
        .t(VOICE_NUMBER)
        .up()
        .up()
        .c('TEL')
        .c(typeAddr != null ? typeAddr.toUpperCase() : 'WORK')
        .up()
        .c('FAX')
        .up()
        .c('NUMBER')
        .t(FAX_NUMBER)
        .up()
        .up()
        .c('TEL')
        .c(typeAddr != null ? typeAddr.toUpperCase() : 'WORK')
        .up()
        .c('MSG')
        .up()
        .c('NUMBER')
        .t(MSG_NUMBER)
        .up()
        .up()
        .c('ADR')
        .c('WORK')
        .t(WORK)
        .up()
        .c('EXTADD')
        .t(EXTADD)
        .up()
        .c('STREET')
        .t(STREET)
        .up()
        .c('LOCALITY')
        .t(LOCALITY)
        .up()
        .c('REGION')
        .t(REGION)
        .up()
        .c('PCODE')
        .t(PCODE)
        .up()
        .c('CTRY')
        .t(CTRY)
        .up()
        .tree();
  }
}
