import 'dart:convert';

import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/services.dart';

import '../../domain/pgn/pgn_parser.dart';
import '../../domain/repertoire/repertoire_import.dart';
import '../repositories/repertoire_repository.dart';

/// Starter repertoires shipped in `assets/starter/` (F-THEORY-03).
class StarterRepertoire {
  const StarterRepertoire({
    required this.id,
    required this.file,
    required this.color,
    required this.level,
    required this.author,
    required this.license,
    required this.names,
    required this.descriptions,
  });

  final String id;
  final String file;
  final Side color;
  final String level;
  final String author;
  final String license;
  final Map<String, String> names;
  final Map<String, String> descriptions;

  String name(String lang) => names[lang] ?? names['en'] ?? id;
  String description(String lang) => descriptions[lang] ?? descriptions['en'] ?? '';

  factory StarterRepertoire.fromJson(Map<String, Object?> j) => StarterRepertoire(
    id: j['id']! as String,
    file: j['file']! as String,
    color: j['color'] == 'black' ? Side.black : Side.white,
    level: (j['level'] as String?) ?? '',
    author: (j['author'] as String?) ?? '',
    license: (j['license'] as String?) ?? '',
    names: ((j['name'] as Map?) ?? {}).cast<String, String>(),
    descriptions: ((j['description'] as Map?) ?? {}).cast<String, String>(),
  );
}

class StarterService {
  StarterService(this.repertoires, {AssetBundle? bundle}) : bundle = bundle ?? rootBundle;
  final RepertoireRepository repertoires;
  final AssetBundle bundle;

  Future<List<StarterRepertoire>> list() async {
    final raw = await bundle.loadString('assets/starter/index.json');
    return [for (final e in jsonDecode(raw) as List) StarterRepertoire.fromJson((e as Map).cast<String, Object?>())];
  }

  /// Installs [s] as a regular repertoire. Returns its id.
  Future<int> install(StarterRepertoire s, String lang) async {
    final pgn = await bundle.loadString('assets/starter/${s.file}');
    final game = PgnParser.parseOne(pgn);
    // Keep only the comment in the user's language ("en / uk" pairs).
    for (final n in game.root.descendants()) {
      n.comments = [for (final c in n.comments) c.copyWith(text: _pickLang(c.text, lang))];
    }
    final id = await repertoires.create(name: s.name(lang), color: s.color, description: s.description(lang));
    final graph = await repertoires.loadGraph(id);
    importIntoRepertoire(graph, [
      ImportSource.game(game),
    ], const RepImportOptions(ownAllVariations: true, source: 'starter'));
    await repertoires.saveGraph(id, graph);
    return id;
  }

  static String _pickLang(String text, String lang) {
    final parts = text.split(' / ');
    if (parts.length != 2) return text;
    return lang == 'uk' ? parts[1].trim() : parts[0].trim();
  }
}
