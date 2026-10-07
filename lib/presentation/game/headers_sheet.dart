import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../theme/app_icons.dart';
import '../widgets/common.dart';

/// View and edit game headers (F-VIEW-08).
Future<Map<String, String>?> showHeadersEditor(BuildContext context, Map<String, String> headers) =>
    Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => _HeadersEditor(headers: headers)),
    );

class _HeadersEditor extends StatefulWidget {
  const _HeadersEditor({required this.headers});
  final Map<String, String> headers;

  @override
  State<_HeadersEditor> createState() => _HeadersEditorState();
}

class _HeadersEditorState extends State<_HeadersEditor> {
  /// The start position is defined by these tags; editing them would make
  /// the moves illegal, so they are kept as they are and not shown.
  static bool _locked(String key) => const {'fen', 'setup'}.contains(key.toLowerCase());

  late final Map<String, String> _lockedHeaders = {
    for (final e in widget.headers.entries)
      if (_locked(e.key)) e.key: e.value,
  };

  late final List<(TextEditingController, TextEditingController)> _rows = [
    for (final e in widget.headers.entries)
      if (!_locked(e.key)) (TextEditingController(text: e.key), TextEditingController(text: e.value)),
  ];

  /// The name of a tag of one's own, beside its value.
  static const _tagNameWidth = 120.0;

  static const _common = [
    'Event',
    'Site',
    'Date',
    'Round',
    'White',
    'Black',
    'Result',
    'WhiteElo',
    'BlackElo',
    'ECO',
    'Opening',
    'Annotator',
  ];

  @override
  void initState() {
    super.initState();
    for (final k in _common.take(7)) {
      if (!_rows.any((r) => r.$1.text == k)) _rows.add((TextEditingController(text: k), TextEditingController()));
    }
  }

  @override
  void dispose() {
    for (final (a, b) in _rows) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  String _label(String key, AppLocalizations l) => switch (key) {
    'Event' => l.hEvent,
    'Site' => l.hSite,
    'Date' => l.hDate,
    'Round' => l.hRound,
    'White' => l.white,
    'Black' => l.black,
    'Result' => l.hResult,
    'WhiteElo' => l.hWhiteElo,
    'BlackElo' => l.hBlackElo,
    'Annotator' => l.hAnnotator,
    'Opening' => l.hOpening,
    _ => key,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.gameInfo),
        actions: [
          TextButton(
            onPressed: () {
              final out = <String, String>{..._lockedHeaders};
              for (final (k, v) in _rows) {
                final key = k.text.trim().replaceAll(RegExp(r'\s+'), '');
                if (key.isEmpty || _locked(key)) continue;
                final value = v.text.trim();
                if (value.isEmpty && !_common.take(7).contains(key)) continue;
                out[key] = value.isEmpty ? (key == 'Date' ? '????.??.??' : (key == 'Result' ? '*' : '?')) : value;
              }
              Navigator.pop(context, out);
            },
            child: Text(l.save),
          ),
        ],
      ),
      body: ListView(
        padding: AppInsets.page,
        children: [
          for (var i = 0; i < _rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _rows[i].$1.text.isNotEmpty && _common.contains(_rows[i].$1.text)
                  ? (_rows[i].$1.text == 'Result'
                        ? DropdownButtonFormField<String>(
                            icon: const Icon(AppIcons.expand, size: AppSizes.iconMd),
                            initialValue: const ['1-0', '0-1', '1/2-1/2', '*'].contains(_rows[i].$2.text)
                                ? _rows[i].$2.text
                                : '*',
                            decoration: InputDecoration(labelText: _label('Result', l)),
                            items: [
                              for (final r in const ['1-0', '0-1', '1/2-1/2', '*'])
                                DropdownMenuItem(value: r, child: Text(r)),
                            ],
                            onChanged: (v) => _rows[i].$2.text = v ?? '*',
                          )
                        : TextField(
                            controller: _rows[i].$2,
                            decoration: InputDecoration(
                              labelText: _label(_rows[i].$1.text, l),
                              hintText: _rows[i].$1.text == 'Date' ? '2026.09.27' : null,
                            ),
                          ))
                  : Row(
                      children: [
                        SizedBox(
                          width: _tagNameWidth,
                          child: TextField(
                            controller: _rows[i].$1,
                            decoration: InputDecoration(labelText: l.tagName),
                          ),
                        ),
                        AppGap.h8,
                        Expanded(
                          child: TextField(
                            controller: _rows[i].$2,
                            decoration: InputDecoration(labelText: l.tagValue),
                          ),
                        ),
                        IconButton(
                          tooltip: l.delete,
                          onPressed: () {
                            final removed = _rows[i];
                            setState(() => _rows.removeAt(i));
                            // Dispose after the fields are gone from the tree.
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              removed.$1.dispose();
                              removed.$2.dispose();
                            });
                          },
                          icon: const Icon(AppIcons.close),
                        ),
                      ],
                    ),
            ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _rows.add((TextEditingController(), TextEditingController()))),
            icon: const Icon(AppIcons.add),
            label: Text(l.addTag),
          ),
        ],
      ),
    );
  }
}
