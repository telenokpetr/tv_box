import 'dart:convert';

/// One cookie of the embedded browser, as DevTools' `Network.getAllCookies`
/// reports it.
class BrowserCookie {
  const BrowserCookie({
    required this.domain,
    required this.path,
    required this.name,
    required this.value,
    required this.secure,
    required this.httpOnly,
    required this.expires,
  });

  final String domain;
  final String path;
  final String name;
  final String value;
  final bool secure;
  final bool httpOnly;

  /// Unix seconds; 0 for a session cookie.
  final int expires;
}

/// The cookies in a `Network.getAllCookies` reply; rows without a name or a
/// domain are dropped.
List<BrowserCookie> parseBrowserCookies(String json) {
  final Object? decoded = jsonDecode(json);
  final Object? rows = decoded is Map<String, dynamic>
      ? decoded['cookies']
      : null;
  if (rows is! List<dynamic>) return const <BrowserCookie>[];
  final List<BrowserCookie> cookies = <BrowserCookie>[];
  for (final Object? row in rows) {
    if (row is! Map<String, dynamic>) continue;
    final Object? name = row['name'];
    final Object? domain = row['domain'];
    if (name is! String || name.isEmpty) continue;
    if (domain is! String || domain.isEmpty) continue;
    final Object? expires = row['expires'];
    cookies.add(
      BrowserCookie(
        domain: domain,
        path: row['path'] is String ? row['path'] as String : '/',
        name: name,
        value: row['value'] is String ? row['value'] as String : '',
        secure: row['secure'] == true,
        httpOnly: row['httpOnly'] == true,
        // DevTools says -1 for a session cookie.
        expires: expires is num && expires > 0 ? expires.toInt() : 0,
      ),
    );
  }
  return cookies;
}

bool _onYoutube(String domain) => domain.toLowerCase().contains('youtube.com');

/// Whether the browser is signed in to YouTube: it sets `LOGIN_INFO` on its
/// own domain once the account is accepted, and that is what yt-dlp needs.
bool hasYoutubeLogin(List<BrowserCookie> cookies) => cookies.any(
  (BrowserCookie c) =>
      _onYoutube(c.domain) &&
      (c.name == 'LOGIN_INFO' || c.name == 'SAPISID') &&
      c.value.isNotEmpty,
);

/// The cookies yt-dlp reads for a YouTube session: YouTube's own and the
/// Google account's, in any country domain.
bool isYoutubeSessionDomain(String domain) {
  final String d = domain.toLowerCase();
  return d.contains('youtube.com') || d.contains('google.');
}

/// The cookies in the Netscape file format yt-dlp's `--cookies` takes.
String toNetscapeCookies(
  List<BrowserCookie> cookies, {
  bool Function(String domain) keep = isYoutubeSessionDomain,
}) {
  final StringBuffer out = StringBuffer('# Netscape HTTP Cookie File\n');
  for (final BrowserCookie c in cookies) {
    if (!keep(c.domain)) continue;
    // A leading dot means the cookie is sent to subdomains as well.
    final String subdomains = c.domain.startsWith('.') ? 'TRUE' : 'FALSE';
    final String prefix = c.httpOnly ? '#HttpOnly_' : '';
    out.writeln(
      '$prefix${c.domain}\t$subdomains\t${c.path}\t'
      '${c.secure ? 'TRUE' : 'FALSE'}\t${c.expires}\t${c.name}\t${c.value}',
    );
  }
  return out.toString();
}
