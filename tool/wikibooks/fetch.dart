// Downloads the Wikibooks "Chess Opening Theory" pages (CC BY-SA 4.0) for
// "About this position" (D-106): the latest revision id and wikitext of
// every page that is not a redirect.
//
// Usage: dart run tool/wikibooks/fetch.dart
// Output: tool/wikibooks/raw/pages.jsonl (one {title, revid, text} per
// line; not committed - the revision ids in manifest.json are).
// ignore_for_file: avoid_dynamic_calls - reads the MediaWiki JSON as it comes.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _api = 'https://en.wikibooks.org/w/api.php';
const _agent = 'RepertoriumChess-build/1.0 (https://github.com/viponomarenko; viponomarenko@gmail.com)';

/// Wikimedia asks bots to go one request at a time and slowly.
const _pause = Duration(milliseconds: 600);

Future<Map<String, dynamic>> _query(http.Client c, Map<String, String> q) async {
  // POST: fifty long page titles do not fit into a URL.
  final uri = Uri.parse(_api);
  final form = {...q, 'format': 'json', 'formatversion': '2', 'maxlag': '5'};
  for (var attempt = 0; ; attempt++) {
    final r = await c.post(uri, headers: {'User-Agent': _agent}, body: form);
    final body = r.statusCode == 200 ? jsonDecode(r.body) as Map<String, dynamic> : null;
    final lagged = body?['error']?['code'] == 'maxlag';
    if (body != null && !lagged) return body;
    if (attempt >= 5) throw HttpException('HTTP ${r.statusCode} for $uri');
    await Future<void>.delayed(Duration(seconds: 5 * (attempt + 1)));
  }
}

Future<void> main() async {
  final c = http.Client();
  final titles = <String>[];
  String? cont;
  do {
    final d = await _query(c, {
      'action': 'query',
      'list': 'allpages',
      'apprefix': 'Chess_Opening_Theory/',
      'apnamespace': '0',
      'apfilterredir': 'nonredirects',
      'aplimit': 'max',
      'apcontinue': ?cont,
    });
    titles.addAll([for (final p in d['query']['allpages'] as List) p['title'] as String]);
    cont = d['continue']?['apcontinue'] as String?;
    stdout.write('\r${titles.length} titles');
    await Future<void>.delayed(_pause);
  } while (cont != null);
  stdout.writeln();

  final dir = Directory('tool/wikibooks/raw')..createSync(recursive: true);
  final out = File('${dir.path}/pages.jsonl').openWrite();
  var done = 0;
  for (var i = 0; i < titles.length; i += 50) {
    final batch = titles.sublist(i, i + 50 > titles.length ? titles.length : i + 50);
    final d = await _query(c, {
      'action': 'query',
      'prop': 'revisions',
      'rvprop': 'ids|content',
      'rvslots': 'main',
      'titles': batch.join('|'),
    });
    for (final p in d['query']['pages'] as List) {
      final revs = p['revisions'] as List?;
      if (revs == null || revs.isEmpty) continue;
      final rev = revs.first as Map<String, dynamic>;
      out.writeln(
        jsonEncode({'title': p['title'], 'revid': rev['revid'], 'text': rev['slots']['main']['content']}),
      );
      done++;
    }
    stdout.write('\r$done / ${titles.length} pages');
    await Future<void>.delayed(_pause);
  }
  await out.close();
  c.close();
  stdout.writeln('\nWrote ${dir.path}/pages.jsonl');
}
