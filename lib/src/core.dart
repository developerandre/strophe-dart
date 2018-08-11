import 'package:strophe/src/bosh.dart';
import 'package:strophe/src/plugins/plugins.dart';
import 'package:strophe/src/websocket.dart';
import 'package:xml/xml.dart' as xml;
import 'package:strophe/src/enums.dart';

class Strophe {
  static const String VERSION = '0.0.1';
  /** PrivateConstants: Timeout Values
     *  Timeout values for error states.  These values are in seconds.
     *  These should not be changed unless you know exactly what you are
     *  doing.
     *
     *  TIMEOUT - Timeout multiplier. A waiting request will be considered
     *      failed after Math.floor(TIMEOUT * wait) seconds have elapsed.
     *      This defaults to 1.1, and with default wait, 66 seconds.
     *  SECONDARY_TIMEOUT - Secondary timeout multiplier. In cases where
     *      Strophe can detect early failure, it will consider the request
     *      failed if it doesn't return after
     *      Math.floor(SECONDARY_TIMEOUT * wait) seconds have elapsed.
     *      This defaults to 0.1, and with default wait, 6 seconds.
     */
  static const num TIMEOUT = 1.1;
  static const num SECONDARY_TIMEOUT = 0.1;
  static Map<String, int> Status = ConnexionStatus;
  static Map<String, String> NS = NAMESPACE;
  static const Map<String, String> ErrorCondition = ERRORSCONDITIONS;
  static const Map<String, int> LogLevel = LOGLEVEL;
  static const Map<String, int> ElementType = ELEMENTTYPE;
  static Map<String, dynamic> XHTML = {
    "tags": [
      'a',
      'blockquote',
      'br',
      'cite',
      'em',
      'img',
      'li',
      'ol',
      'p',
      'span',
      'strong',
      'ul',
      'body'
    ],
    'attributes': {
      'a': ['href'],
      'blockquote': ['style'],
      'br': [],
      'cite': ['style'],
      'em': [],
      'img': ['src', 'alt', 'style', 'height', 'width'],
      'li': ['style'],
      'ol': ['style'],
      'p': ['style'],
      'span': ['style'],
      'strong': [],
      'ul': ['style'],
      'body': []
    },
    'css': [
      'background-color',
      'color',
      'font-family',
      'font-size',
      'font-style',
      'font-weight',
      'margin-left',
      'margin-right',
      'text-align',
      'text-decoration'
    ],
    /** Function: XHTML.validTag
         *
         * Utility method to determine whether a tag is allowed
         * in the XHTML_IM namespace.
         *
         * XHTML tag names are case sensitive and must be lower case.
         */
    'validTag': (String tag) {
      for (int i = 0; i < Strophe.XHTML['tags'].length; i++) {
        if (tag == Strophe.XHTML['tags'][i]) {
          return true;
        }
      }
      return false;
    },
    /** Function: XHTML.validAttribute
         *
         * Utility method to determine whether an attribute is allowed
         * as recommended per XEP-0071
         *
         * XHTML attribute names are case sensitive and must be lower case.
         */
    'validAttribute': (String tag, String attribute) {
      if (Strophe.XHTML['attributes'][tag] != null &&
          Strophe.XHTML['attributes'][tag].length > 0) {
        for (int i = 0; i < Strophe.XHTML['attributes'][tag].length; i++) {
          if (attribute == Strophe.XHTML['attributes'][tag][i]) {
            return true;
          }
        }
      }
      return false;
    },
    'validCSS': (style) {
      for (int i = 0; i < Strophe.XHTML['css'].length; i++) {
        if (style == Strophe.XHTML['css'][i]) {
          return true;
        }
      }
      return false;
    }
  };

  /** Function: addNamespace
     *  This function is used to extend the current namespaces in
     *  Strophe.NS.  It takes a key and a value with the key being the
     *  name of the new namespace, with its actual value.
     *  For example:
     *  Strophe.addNamespace('PUBSUB', "http://jabber.org/protocol/pubsub");
     *
     *  Parameters:
     *    (String) name - The name under which the namespace will be
     *      referenced under Strophe.NS
     *    (String) value - The actual namespace.
     */
  static void addNamespace(String name, String value) {
    Strophe.NS[name] = value;
  }

/** Function: forEachChild
     *  Map a function over some or all child elements of a given element.
     *
     *  This is a small convenience function for mapping a function over
     *  some or all of the children of an element.  If elemName is null, all
     *  children will be passed to the function, otherwise only children
     *  whose tag names match elemName will be passed.
     *
     *  Parameters:
     *    (XMLElement) elem - The element to operate on.
     *    (String) elemName - The child element tag name filter.
     *    (Function) func - The function to apply to each child.  This
     *      function should take a single argument, a DOM element.
     */
  static void forEachChild(elem, String elemName, Function func) {
    if (elem == null) return;
    var childNode;
    for (int i = 0; i < elem.children.length; i++) {
      try {
        if (elem.children.elementAt(i) is xml.XmlElement)
          childNode = elem.children.elementAt(i);
        else if (elem.children.elementAt(i) is xml.XmlDocument)
          childNode = elem.rootElement.children.elementAt(i);
      } catch (e) {
        childNode = null;
      }
      if (childNode == null) continue;
      if (childNode.nodeType == xml.XmlNodeType.ELEMENT &&
          (elemName == null || isTagEqual(childNode, elemName))) {
        func(childNode);
      }
    }
  }

/** Function: isTagEqual
     *  Compare an element's tag name with a string.
     *
     *  This function is case sensitive.
     *
     *  Parameters:
     *    (XMLElement) el - A DOM element.
     *    (String) name - The element name.
     *
     *  Returns:
     *    true if the element's tag name matches _el_, and false
     *    otherwise.
     */
  static bool isTagEqual(xml.XmlElement el, String name) {
    return el.name.qualified == name;
  }

  /** PrivateVariable: _xmlGenerator
     *  _Private_ variable that caches a DOM document to
     *  generate elements.
     */
  static xml.XmlBuilder _xmlGenerator;

  /** PrivateFunction: _makeGenerator
     *  _Private_ function that creates a dummy XML DOM document to serve as
     *  an element and text node generator.
     */
  static xml.XmlBuilder _makeGenerator() {
    xml.XmlBuilder builder = new xml.XmlBuilder();
    //builder.element('strophe', namespace: 'jabber:client');
    return builder;
  }

/** Function: xmlGenerator
     *  Get the DOM document to generate elements.
     *
     *  Returns:
     *    The currently used DOM document.
     */
  static xml.XmlBuilder xmlGenerator() {
    //if (Strophe._xmlGenerator == null) {
    Strophe._xmlGenerator = Strophe._makeGenerator();
    //}
    return Strophe._xmlGenerator;
  }

  /** Function: xmlElement
     *  Create an XML DOM element.
     *
     *  This function creates an XML DOM element correctly across all
     *  implementations. Note that these are not HTML DOM elements, which
     *  aren't appropriate for XMPP stanzas.
     *
     *  Parameters:
     *    (String) name - The name for the element.
     *    (Array|Object) attrs - An optional array or object containing
     *      key/value pairs to use as element attributes. The object should
     *      be in the format {'key': 'value'} or {key: 'value'}. The array
     *      should have the format [['key1', 'value1'], ['key2', 'value2']].
     *    (String) text - The text child data for the element.
     *
     *  Returns:
     *    A new XML DOM element.
     */
  static xml.XmlNode xmlElement(String name, {dynamic attrs, String text}) {
    if (name == null || name.isEmpty || name.trim().length == 0) {
      return null;
    }
    if (attrs != null &&
        (attrs is! List<List<String>>) &&
        (attrs is! Map<String, dynamic>)) {
      return null;
    }
    Map<String, String> attributes = {};
    if (attrs != null) {
      if (attrs is List<List<String>>) {
        for (int i = 0; i < attrs.length; i++) {
          List<String> attr = attrs[i];
          if (attr.length == 2 && attr[1] != null && attr.isNotEmpty) {
            attributes[attr[0]] = attr[1].toString();
          }
        }
      } else if (attrs is Map<String, dynamic>) {
        List<String> keys = attrs.keys.toList();
        for (int i = 0, len = keys.length; i < len; i++) {
          String key = keys[i];
          if (key != null && key.isNotEmpty && attrs[key] != null) {
            attributes[key] = attrs[key].toString();
          }
        }
      }
    }
    xml.XmlBuilder builder = Strophe.xmlGenerator();
    builder.element(name, attributes: attributes, nest: text);
    return builder.build();
  }
/*  Function: xmlescape
     *  Excapes invalid xml characters.
     *
     *  Parameters:
     *     (String) text - text to escape.
     *
     *  Returns:
     *      Escaped text.
     */

  static String xmlescape(String text) {
    text = text.replaceAll(new RegExp(r'&'), "&amp;");
    text = text.replaceAll(new RegExp(r'<'), "&lt;");
    text = text.replaceAll(new RegExp(r'>'), "&gt;");
    text = text.replaceAll(new RegExp(r"'"), "&apos;");
    text = text.replaceAll(new RegExp(r'"'), "&quot;");
    return text;
  }

  /*  Function: xmlunescape
    *  Unexcapes invalid xml characters.
    *
    *  Parameters:
    *     (String) text - text to unescape.
    *
    *  Returns:
    *      Unescaped text.
    */
  static String xmlunescape(String text) {
    text = text.replaceAll(new RegExp(r'&amp;'), "&");
    text = text.replaceAll(new RegExp(r'&lt;'), "<");
    text = text.replaceAll(new RegExp(r'&gt;'), ">");
    text = text.replaceAll(new RegExp(r"&apos;"), "'");
    text = text.replaceAll(new RegExp(r'&quot;'), '"');
    return text;
  }

  /** Function: xmlTextNode
     *  Creates an XML DOM text node.
     *
     *
     *  Parameters:
     *    (String) text - The content of the text node.
     *
     *  Returns:
     *    A new XML DOM text node.
     */
  static xml.XmlNode xmlTextNode(String text) {
    xml.XmlBuilder builder = Strophe.xmlGenerator();
    builder.element('strophe', nest: text);
    return builder.build();
  }

  /** Function: xmlHtmlNode
     *  Creates an XML DOM html node.
     *
     *  Parameters:
     *    (String) html - The content of the html node.
     *
     *  Returns:
     *    A new XML DOM text node.
     */
  static xml.XmlNode xmlHtmlNode(String html) {
    xml.XmlNode parsed;
    try {
      parsed = xml.parse(html);
    } catch (e) {
      parsed = null;
    }
    return parsed;
  }

  /** Function: getText
     *  Get the concatenation of all text children of an element.
     *
     *  Parameters:
     *    (XMLElement) elem - A DOM element.
     *
     *  Returns:
     *    A String with the concatenated text of all text element children.
     */
  static String getText(xml.XmlNode elem) {
    if (elem == null) {
      return null;
    }
    String str = "";
    if (elem.children.length == 0 && elem.nodeType == xml.XmlNodeType.TEXT) {
      str += elem.toString();
    }

    for (int i = 0; i < elem.children.length; i++) {
      if (elem.children[i].nodeType == xml.XmlNodeType.TEXT) {
        str += elem.children[i].toString();
      }
    }
    return Strophe.xmlescape(str);
  }

  /** Function: copyElement
     *  Copy an XML DOM element.
     *
     *  This function copies a DOM element and all its descendants and returns
     *  the new copy.
     *
     *  Parameters:
     *    (XMLElement) elem - A DOM element.
     *
     *  Returns:
     *    A new, copied DOM element tree.
     */
  static xml.XmlNode copyElement(xml.XmlNode elem) {
    var el = elem;
    if (elem.nodeType == xml.XmlNodeType.ELEMENT) {
      el = elem.copy();
    } else if (elem.nodeType == xml.XmlNodeType.TEXT) {
      el = elem;
    } else if (elem.nodeType == xml.XmlNodeType.DOCUMENT) {
      el = elem.document.rootElement;
    }
    return el;
  }

/** Function: createHtml
     *  Copy an HTML DOM element into an XML DOM.
     *
     *  This function copies a DOM element and all its descendants and returns
     *  the new copy.
     *
     *  Parameters:
     *    (HTMLElement) elem - A DOM element.
     *
     *  Returns:
     *    A new, copied DOM element tree.
     */
  static xml.XmlNode createHtml(xml.XmlNode elem) {
    xml.XmlNode el;
    String tag;
    if (elem.nodeType == xml.XmlNodeType.ELEMENT) {
      // XHTML tags must be lower case.
      //tag = elem.
      if (Strophe.XHTML['validTag'](tag)) {
        try {
          el = Strophe.copyElement(elem);
        } catch (e) {
          // invalid elements
          el = Strophe.xmlTextNode('');
        }
      } else {
        el = Strophe.copyElement(elem);
      }
    } else if (elem.nodeType == xml.XmlNodeType.DOCUMENT_FRAGMENT) {
      el = Strophe.copyElement(elem);
    } else if (elem.nodeType == xml.XmlNodeType.TEXT) {
      el = Strophe.xmlTextNode(elem.toString());
    }
    return el;
  }

  /** Function: escapeNode
     *  Escape the node part (also called local part) of a JID.
     *
     *  Parameters:
     *    (String) node - A node (or local part).
     *
     *  Returns:
     *    An escaped node (or local part).
     */
  static String escapeNode(String node) {
    return node
        .replaceAll(new RegExp(r"^\s+|\s+$"), '')
        .replaceAll(new RegExp(r"\\"), "\\5c")
        .replaceAll(new RegExp(r" "), "\\20")
        .replaceAll(new RegExp(r'"'), "\\22")
        .replaceAll(new RegExp(r'&'), "\\26")
        .replaceAll(new RegExp(r"'"), "\\27")
        .replaceAll(new RegExp(r'/'), "\\2f")
        .replaceAll(new RegExp(r':'), "\\3a")
        .replaceAll(new RegExp(r'<'), "\\3c")
        .replaceAll(new RegExp(r'>'), "\\3e")
        .replaceAll(new RegExp(r'@'), "\\40");
  }

/** Function: unescapeNode
     *  Unescape a node part (also called local part) of a JID.
     *
     *  Parameters:
     *    (String) node - A node (or local part).
     *
     *  Returns:
     *    An unescaped node (or local part).
     */
  static String unescapeNode(String node) {
    return node
        .replaceAll(new RegExp(r"\\5c"), "\\")
        .replaceAll(new RegExp(r"\\20"), " ")
        .replaceAll(new RegExp(r'\\22'), '"')
        .replaceAll(new RegExp(r'\\26'), "&")
        .replaceAll(new RegExp(r"\\27"), "'")
        .replaceAll(new RegExp(r'\\2f'), "/")
        .replaceAll(new RegExp(r'\\3a'), ":")
        .replaceAll(new RegExp(r'\\3c'), "<")
        .replaceAll(new RegExp(r'\\3e'), ">")
        .replaceAll(new RegExp(r'\\40'), "@");
  }

  /** Function: getNodeFromJid
     *  Get the node portion of a JID String.
     *
     *  Parameters:
     *    (String) jid - A JID.
     *
     *  Returns:
     *    A String containing the node.
     */
  static String getNodeFromJid(String jid) {
    if (jid.indexOf("@") < 0) {
      return null;
    }
    return jid.split("@")[0];
  }

  /** Function: getDomainFromJid
     *  Get the domain portion of a JID String.
     *
     *  Parameters:
     *    (String) jid - A JID.
     *
     *  Returns:
     *    A String containing the domain.
     */
  static String getDomainFromJid(String jid) {
    String bare = Strophe.getBareJidFromJid(jid);
    if (bare.indexOf("@") < 0) {
      return bare;
    } else {
      List<String> parts = bare.split("@");
      parts.removeAt(0);
      return parts.join('@');
    }
  }

  /** Function: getResourceFromJid
     *  Get the resource portion of a JID String.
     *
     *  Parameters:
     *    (String) jid - A JID.
     *
     *  Returns:
     *    A String containing the resource.
     */
  static String getResourceFromJid(String jid) {
    List<String> s = jid.split("/");
    if (s.length < 2) {
      return null;
    }
    s.removeAt(0);
    return s.join('/');
  }

  /** Function: getBareJidFromJid
     *  Get the bare JID from a JID String.
     *
     *  Parameters:
     *    (String) jid - A JID.
     *
     *  Returns:
     *    A String containing the bare JID.
     */
  static String getBareJidFromJid(String jid) {
    return jid != null && jid.isNotEmpty ? jid.split("/")[0] : null;
  }

/** PrivateFunction: _handleError
     *  _Private_ function that properly logs an error to the console
     */
  static handleError(Error e) {
    if (e.stackTrace != null) {
      Strophe.fatal(e.stackTrace.toString());
    }
    if (e.toString() != null) {
      Strophe.fatal("error: " +
          e.hashCode.toString() +
          " - " +
          e.runtimeType.toString() +
          ": " +
          e.toString());
    }
  }

  /** Function: log
     *  User overrideable logging function.
     *
     *  This function is called whenever the Strophe library calls any
     *  of the logging functions.  The default implementation of this
     *  function logs only fatal errors.  If client code wishes to handle the logging
     *  messages, it should override this with
     *  > Strophe.log = function (level, msg) {
     *  >   (user code here)
     *  > };
     *
     *  Please note that data sent and received over the wire is logged
     *  via Strophe.Connection.rawInput() and Strophe.Connection.rawOutput().
     *
     *  The different levels and their meanings are
     *
     *    DEBUG - Messages useful for debugging purposes.
     *    INFO - Informational messages.  This is mostly information like
     *      'disconnect was called' or 'SASL auth succeeded'.
     *    WARN - Warnings about potential problems.  This is mostly used
     *      to report transient connection errors like request timeouts.
     *    ERROR - Some error occurred.
     *    FATAL - A non-recoverable fatal error occurred.
     *
     *  Parameters:
     *    (Integer) level - The log level of the log message.  This will
     *      be one of the values in Strophe.LogLevel.
     *    (String) msg - The log message.
     */
  static log(int level, String msg) {
    if (level != Strophe.LogLevel['FATAL']) {
      print(msg);
    }
  }

  /** Function: debug
     *  Log a message at the Strophe.LogLevel.DEBUG level.
     *
     *  Parameters:
     *    (String) msg - The log message.
     */
  static debug(String msg) {
    Strophe.log(Strophe.LogLevel['DEBUG'], msg);
  }

  /** Function: info
     *  Log a message at the Strophe.LogLevel.INFO level.
     *
     *  Parameters:
     *    (String) msg - The log message.
     */
  static info(String msg) {
    Strophe.log(Strophe.LogLevel['INFO'], msg);
  }

  /** Function: warn
     *  Log a message at the Strophe.LogLevel.WARN level.
     *
     *  Parameters:
     *    (String) msg - The log message.
     */
  static warn(String msg) {
    Strophe.log(Strophe.LogLevel['WARN'], msg);
  }

  /** Function: error
     *  Log a message at the Strophe.LogLevel.ERROR level.
     *
     *  Parameters:
     *    (String) msg - The log message.
     */
  static error(String msg) {
    Strophe.log(Strophe.LogLevel['ERROR'], msg);
  }

  /** Function: fatal
     *  Log a message at the Strophe.LogLevel.FATAL level.
     *
     *  Parameters:
     *    (String) msg - The log message.
     */
  static fatal(String msg) {
    Strophe.log(Strophe.LogLevel['FATAL'], msg);
  }

/** Function: serialize
     *  Render a DOM element and all descendants to a String.
     *
     *  Parameters:
     *    (XMLElement) elem - A DOM element.
     *
     *  Returns:
     *    The serialized element tree as a String.
     */
  static String serialize(xml.XmlNode elem) {
    if (elem == null) {
      return null;
    }

    return elem.toXmlString();
  }

  /** PrivateVariable: _requestId
     *  _Private_ variable that keeps track of the request ids for
     *  connections.
     */
  static int requestId = 0;

  /** PrivateVariable: Strophe.connectionPlugins
     *  _Private_ variable Used to store plugin names that need
     *  initialization on Strophe.Connection construction.
     */
  static Map<String, PluginClass> _connectionPlugins = {};
  static Map<String, PluginClass> get connectionPlugins {
    return _connectionPlugins;
  }

  /** Function: addConnectionPlugin
     *  Extends the Strophe.Connection object with the given plugin.
     *
     *  Parameters:
     *    (String) name - The name of the extension.
     *    (Object) ptype - The plugin's prototype.
     */
  static void addConnectionPlugin(String name, ptype) {
    Strophe._connectionPlugins[name] = ptype;
  }
/** Class: Strophe.Builder
 *  XML DOM builder.
 *
 *  This object provides an interface similar to JQuery but for building
 *  DOM elements easily and rapidly.  All the functions except for toString()
 *  and tree() return the object, so calls can be chained.  Here's an
 *  example using the $iq() builder helper.
 *  > $iq({to: 'you', from: 'me', type: 'get', id: '1'})
 *  >     .c('query', {xmlns: 'strophe:example'})
 *  >     .c('example')
 *  >     .toString()
 *
 *  The above generates this XML fragment
 *  > <iq to='you' from='me' type='get' id='1'>
 *  >   <query xmlns='strophe:example'>
 *  >     <example/>
 *  >   </query>
 *  > </iq>
 *  The corresponding DOM manipulations to get a similar fragment would be
 *  a lot more tedious and probably involve several helper variables.
 *
 *  Since adding children makes new operations operate on the child, up()
 *  is provided to traverse up the tree.  To add two children, do
 *  > builder.c('child1', ...).up().c('child2', ...)
 *  The next operation on the Builder will be relative to the second child.
 */

/** Constructor: Strophe.Builder
 *  Create a Strophe.Builder object.
 *
 *  The attributes should be passed in object notation.  For example
 *  > var b = new Builder('message', {to: 'you', from: 'me'});
 *  or
 *  > var b = new Builder('messsage', {'xml:lang': 'en'});
 *
 *  Parameters:
 *    (String) name - The name of the root element.
 *    (Object) attrs - The attributes for the root element in object notation.
 *
 *  Returns:
 *    A new Strophe.Builder.
*/
  static StanzaBuilder Builder(String name, {Map<String, dynamic> attrs}) {
    return new StanzaBuilder(name, attrs);
  }
/** PrivateClass: Strophe.Handler
 *  _Private_ helper class for managing stanza handlers.
 *
 *  A Strophe.Handler encapsulates a user provided callback function to be
 *  executed when matching stanzas are received by the connection.
 *  Handlers can be either one-off or persistant depending on their
 *  return value. Returning true will cause a Handler to remain active, and
 *  returning false will remove the Handler.
 *
 *  Users will not use Strophe.Handler objects directly, but instead they
 *  will use Strophe.Connection.addHandler() and
 *  Strophe.Connection.deleteHandler().
 */

/** PrivateConstructor: Strophe.Handler
 *  Create and initialize a new Strophe.Handler.
 *
 *  Parameters:
 *    (Function) handler - A function to be executed when the handler is run.
 *    (String) ns - The namespace to match.
 *    (String) name - The element name to match.
 *    (String) type - The element type to match.
 *    (String) id - The element id attribute to match.
 *    (String) from - The element from attribute to match.
 *    (Object) options - Handler options
 *
 *  Returns:
 *    A new Strophe.Handler object.
*/
  static StanzaHandler Handler(Function handler, String ns, String name,
      [type, String id, String from, Map options]) {
    if (options != null) {
      options.putIfAbsent('matchBareFromJid', () => false);
      options.putIfAbsent('ignoreNamespaceFragment', () => false);
    } else
      options = {'matchBareFromJid': false, 'ignoreNamespaceFragment': false};
    StanzaHandler stanzaHandler =
        new StanzaHandler(handler, ns, name, type, id, options);
    // BBB: Maintain backward compatibility with old `matchBare` option
    if (stanzaHandler.options['matchBare'] != null) {
      Strophe.warn(
          'The "matchBare" option is deprecated, use "matchBareFromJid" instead.');
      stanzaHandler.options['matchBareFromJid'] =
          stanzaHandler.options['matchBare'];
      stanzaHandler.options.remove('matchBare');
    }

    if (stanzaHandler.options['matchBareFromJid'] != null &&
        stanzaHandler.options['matchBareFromJid'] == true) {
      stanzaHandler.from = (from != null && from.isNotEmpty)
          ? Strophe.getBareJidFromJid(from)
          : null;
    } else {
      stanzaHandler.from = from;
    }
    // whether the handler is a user handler or a system handler
    stanzaHandler.user = true;
    return stanzaHandler;
  }
  /** PrivateClass: Strophe.TimedHandler
 *  _Private_ helper class for managing timed handlers.
 *
 *  A Strophe.TimedHandler encapsulates a user provided callback that
 *  should be called after a certain period of time or at regular
 *  intervals.  The return value of the callback determines whether the
 *  Strophe.TimedHandler will continue to fire.
 *
 *  Users will not use Strophe.TimedHandler objects directly, but instead
 *  they will use Strophe.Connection.addTimedHandler() and
 *  Strophe.Connection.deleteTimedHandler().
 */

/** PrivateConstructor: Strophe.TimedHandler
 *  Create and initialize a new Strophe.TimedHandler object.
 *
 *  Parameters:
 *    (Integer) period - The number of milliseconds to wait before the
 *      handler is called.
 *    (Function) handler - The callback to run when the handler fires.  This
 *      function should take no arguments.
 *
 *  Returns:
 *    A new Strophe.TimedHandler object.
 */
  static StanzaTimedHandler TimedHandler(int period, Function handler) {
    StanzaTimedHandler stanzaTimedHandler =
        new StanzaTimedHandler(period, handler);
    return stanzaTimedHandler;
  }

  static StanzaBuilder $build(String name, Map<String, dynamic> attrs) {
    return Strophe.Builder(name, attrs: attrs);
  }

  static StanzaBuilder $msg([Map<String, dynamic> attrs]) {
    return Strophe.Builder("message", attrs: attrs);
  }

  static StanzaBuilder $iq([Map<String, dynamic> attrs]) {
    return Strophe.Builder("iq", attrs: attrs);
  }

  static StanzaBuilder $pres([Map<String, dynamic> attrs]) {
    return Strophe.Builder("presence", attrs: attrs);
  }
  /** Class: Strophe.Connection
 *  XMPP Connection manager.
 *
 *  This class is the main part of Strophe.  It manages a BOSH or websocket
 *  connection to an XMPP server and dispatches events to the user callbacks
 *  as data arrives. It supports SASL PLAIN, SASL DIGEST-MD5, SASL SCRAM-SHA1
 *  and legacy authentication.
 *
 *  After creating a Strophe.Connection object, the user will typically
 *  call connect() with a user supplied callback to handle connection level
 *  events like authentication failure, disconnection, or connection
 *  complete.
 *
 *  The user will also have several event handlers defined by using
 *  addHandler() and addTimedHandler().  These will allow the user code to
 *  respond to interesting stanzas or do something periodically with the
 *  connection. These handlers will be active once authentication is
 *  finished.
 *
 *  To send data to the connection, use send().
 */

/** Constructor: Strophe.Connection
 *  Create and initialize a Strophe.Connection object.
 *
 *  The transport-protocol for this connection will be chosen automatically
 *  based on the given service parameter. URLs starting with "ws://" or
 *  "wss://" will use WebSockets, URLs starting with "http://", "https://"
 *  or without a protocol will use BOSH.
 *
 *  To make Strophe connect to the current host you can leave out the protocol
 *  and host part and just pass the path, e.g.
 *
 *  > var conn = new Strophe.Connection("/http-bind/");
 *
 *  Options common to both Websocket and BOSH:
 *  ------------------------------------------
 *
 *  cookies:
 *
 *  The *cookies* option allows you to pass in cookies to be added to the
 *  document. These cookies will then be included in the BOSH XMLHttpRequest
 *  or in the websocket connection.
 *
 *  The passed in value must be a map of cookie names and string values.
 *
 *  > { "myCookie": {
 *  >     "value": "1234",
 *  >     "domain": ".example.org",
 *  >     "path": "/",
 *  >     "expires": expirationDate
 *  >     }
 *  > }
 *
 *  Note that cookies can't be set in this way for other domains (i.e. cross-domain).
 *  Those cookies need to be set under those domains, for example they can be
 *  set server-side by making a XHR call to that domain to ask it to set any
 *  necessary cookies.
 *
 *  mechanisms:
 *
 *  The *mechanisms* option allows you to specify the SASL mechanisms that this
 *  instance of Strophe.Connection (and therefore your XMPP client) will
 *  support.
 *
 *  The value must be an array of objects with Strophe.SASLMechanism
 *  prototypes.
 *
 *  If nothing is specified, then the following mechanisms (and their
 *  priorities) are registered:
 *
 *      SCRAM-SHA1 - 70
 *      DIGEST-MD5 - 60
 *      PLAIN - 50
 *      OAUTH-BEARER - 40
 *      OAUTH-2 - 30
 *      ANONYMOUS - 20
 *      EXTERNAL - 10
 *
 *  WebSocket options:
 *  ------------------
 *
 *  If you want to connect to the current host with a WebSocket connection you
 *  can tell Strophe to use WebSockets through a "protocol" attribute in the
 *  optional options parameter. Valid values are "ws" for WebSocket and "wss"
 *  for Secure WebSocket.
 *  So to connect to "wss://CURRENT_HOSTNAME/xmpp-websocket" you would call
 *
 *  > var conn = new Strophe.Connection("/xmpp-websocket/", {protocol: "wss"});
 *
 *  Note that relative URLs _NOT_ starting with a "/" will also include the path
 *  of the current site.
 *
 *  Also because downgrading security is not permitted by browsers, when using
 *  relative URLs both BOSH and WebSocket connections will use their secure
 *  variants if the current connection to the site is also secure (https).
 *
 *  BOSH options:
 *  -------------
 *
 *  By adding "sync" to the options, you can control if requests will
 *  be made synchronously or not. The default behaviour is asynchronous.
 *  If you want to make requests synchronous, make "sync" evaluate to true.
 *  > var conn = new Strophe.Connection("/http-bind/", {sync: true});
 *
 *  You can also toggle this on an already established connection.
 *  > conn.options.sync = true;
 *
 *  The *customHeaders* option can be used to provide custom HTTP headers to be
 *  included in the XMLHttpRequests made.
 *
 *  The *keepalive* option can be used to instruct Strophe to maintain the
 *  current BOSH session across interruptions such as webpage reloads.
 *
 *  It will do this by caching the sessions tokens in sessionStorage, and when
 *  "restore" is called it will check whether there are cached tokens with
 *  which it can resume an existing session.
 *
 *  The *withCredentials* option should receive a Boolean value and is used to
 *  indicate wether cookies should be included in ajax requests (by default
 *  they're not).
 *  Set this value to true if you are connecting to a BOSH service
 *  and for some reason need to send cookies to it.
 *  In order for this to work cross-domain, the server must also enable
 *  credentials by setting the Access-Control-Allow-Credentials response header
 *  to "true". For most usecases however this setting should be false (which
 *  is the default).
 *  Additionally, when using Access-Control-Allow-Credentials, the
 *  Access-Control-Allow-Origin header can't be set to the wildcard "*", but
 *  instead must be restricted to actual domains.
 *
 *  The *contentType* option can be set to change the default Content-Type
 *  of "text/xml; charset=utf-8", which can be useful to reduce the amount of
 *  CORS preflight requests that are sent to the server.
 *
 *  Parameters:
 *    (String) service - The BOSH or WebSocket service URL.
 *    (Object) options - A hash of configuration options
 *
 *  Returns:
 *    A new Strophe.Connection object.
 */
  static StropheConnection Connection(String service, [Map options]) {
    StropheConnection stropheConnection =
        new StropheConnection(service, options);
    return stropheConnection;
  }

  static StropheWebSocket Websocket(StropheConnection connection) {
    return new StropheWebSocket(connection);
  }

  static StropheBosh Bosh(StropheConnection connection) {
    return new StropheBosh(connection);
  }

  static StropheSASLAnonymous SASLAnonymous = new StropheSASLAnonymous();
  static StropheSASLPlain SASLPlain = new StropheSASLPlain();
  static StropheSASLMD5 SASLMD5 = new StropheSASLMD5();
  static StropheSASLSHA1 SASLSHA1 = new StropheSASLSHA1();
  static StropheSASLOAuthBearer SASLOAuthBearer = new StropheSASLOAuthBearer();
  static StropheSASLExternal SASLExternal = new StropheSASLExternal();
  static StropheSASLXOAuth2 SASLXOAuth2 = new StropheSASLXOAuth2();
}
