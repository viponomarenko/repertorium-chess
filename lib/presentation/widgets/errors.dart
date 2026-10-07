/// Human messages for errors: users see what happened and what to do, not
/// exception class names.
library;

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/l10n.dart';
import '../../data/backup/backup_service.dart';
import '../../data/lichess/lichess_client.dart';

String friendlyError(Object e, AppLocalizations l) {
  if (e is TimeoutException || e is SocketException || e is http.ClientException || e is HandshakeException) {
    return l.networkError;
  }
  if (e is LichessException) {
    if (e.isRateLimited) return l.lichessRateLimited;
    if (e.isUnauthorized) return l.lichessNoAccess;
    if (e.isNotFound) return l.lichessNotFound;
    return l.lichessError(e.message);
  }
  if (e is BackupException) {
    return e.message.contains('newer') ? l.backupTooNew : l.notABackup;
  }
  if (e is FormatException) return e.message;
  return l.somethingWentWrong;
}
