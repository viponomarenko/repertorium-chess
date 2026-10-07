/// Project-wide constants. Values marked "to agree" are open questions for
/// the customer (ТЗ 12) and are kept in one place.
class AppInfo {
  static const name = 'Repertorium chess';

  /// Product token for HTTP User-Agent headers (no spaces).
  static const userAgentName = 'RepertoriumChess';

  /// Bundle id / package name (ТЗ 2: `app.tabiya`, to agree).
  static const bundleId = 'app.tabiya';

  /// Public repository with the source code (GPL-3.0).
  static const repositoryUrl = 'https://github.com/viponomarenko/repertorium-chess';

  /// Where users and API operators reach the developer: the repository's
  /// issue tracker (also the contact in the Chess.com User-Agent).
  static const supportUrl = '$repositoryUrl/issues';

  /// OAuth redirect (reverse-domain custom scheme accepted by Lichess).
  static const oauthRedirect = 'app.tabiya://oauth';
  static const oauthScheme = 'app.tabiya';
}

/// Lichess limits a study to 64 chapters (F-LI-12).
const kLichessMaxChapters = 64;
