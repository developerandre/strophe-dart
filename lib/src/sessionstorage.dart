import 'dart:io';

class SessionStorage {
  static Map<String, String> _session = {};
  static List<Cookie> _cookie = [];
  List<Cookie> get cookies {
    return _cookie;
  }

  Map<String, String> get session {
    return _session;
  }

  static void addCookie(Cookie newCookie) {
    _cookie.add(newCookie);
  }

  static void clearCookie() {
    _cookie.clear();
  }

  static void removeCookie(Cookie removedCookie) {
    _cookie.remove(removedCookie);
  }

  static void removeCookieAt(int index) {
    _cookie.removeAt(index);
  }

  static Cookie getCookie(int index) {
    return _cookie.elementAt(index);
  }

  static void setItem(String name, String value) {
    if (name == null || name.isEmpty || name.trim().length == 0) return;
    if (_session.containsKey(name)) {
      _session.update(name, (String str) {
        return value;
      });
    } else {
      _session.addAll({name: value});
    }
  }

  static String getItem(String name) {
    return _session[name];
  }

  static void clear(String name) {
    _session.clear();
  }

  static void removeItem(String name) {
    _session.remove(name);
  }
}
