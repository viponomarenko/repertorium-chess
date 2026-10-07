import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n.dart';
import '../theme/app_icons.dart';
import 'common.dart';

/// Makes a file name safe for all platforms.
String safeFileName(String name, String ext) {
  var n = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]+'), '_');
  if (n.isEmpty) n = 'tabiya';
  if (n.length > 80) n = n.substring(0, 80);
  return '$n.$ext';
}

Rect? _origin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

Future<void> shareBytes(BuildContext context, Uint8List bytes, String fileName, String mime) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: fileName, mimeType: mime)],
      fileNameOverrides: [fileName],
      sharePositionOrigin: _origin(context),
    ),
  );
}

Future<bool> saveBytes(Uint8List bytes, String fileName, String mime) async {
  final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mime);
  return uri != null;
}

/// Export via "Share", "Save to file" or "Copy" (F-EDIT-06).
Future<void> showExportSheet(
  BuildContext context, {
  required String text,
  required String baseName,
  String ext = 'pgn',
  String mime = 'application/x-chess-pgn',
}) async {
  final l = context.l10n;
  final bytes = Uint8List.fromList(utf8.encode(text));
  final fileName = safeFileName(baseName, ext);
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(AppIcons.share),
            title: Text(l.share),
            subtitle: Text(fileName),
            onTap: () async {
              Navigator.pop(ctx);
              await shareBytes(context, bytes, fileName, mime);
            },
          ),
          ListTile(
            leading: const Icon(AppIcons.download),
            title: Text(l.saveToFile),
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await saveBytes(bytes, fileName, mime);
              if (ok && context.mounted) showSnack(context, l.saved);
            },
          ),
          if (bytes.length < 2 * 1024 * 1024)
            ListTile(
              leading: const Icon(AppIcons.copy),
              title: Text(l.copyToClipboard),
              onTap: () async {
                Navigator.pop(ctx);
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) showSnack(context, l.copied);
              },
            ),
        ],
      ),
    ),
  );
}
