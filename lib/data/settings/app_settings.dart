import 'dart:convert';

import 'package:flutter/material.dart';

import '../../domain/srs/fsrs.dart';
import '../../domain/training/opponent_strategy.dart';

/// All user preferences. Persisted as JSON in the `settings` table and
/// included in backups (without tokens).
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.localeCode,
    this.boardTheme = 'brown',
    this.pieceSet = 'cburnett',
    this.showCoordinates = true,
    this.animationMs = 250,
    this.sound = true,
    this.haptics = true,
    this.showLegalMoves = true,
    this.moveMethod = 'either',
    this.goodSeconds = 10,
    this.easySeconds = 3,
    this.easyEnabled = true,
    this.timedGrading = false,
    this.explorerLoginHintHidden = false,
    this.mistakesBeforeReveal = 2,
    this.acceptAlternatives = false,
    this.showComments = true,
    this.autoplayToDue = false,
    this.drillAffectsSchedule = false,
    this.newPerDay = 20,
    this.reviewsPerDay = 200,
    this.dailyGoal = 20,
    this.desiredRetention = 0.9,
    this.opponentDelayMs = 350,
    this.notificationsEnabled = false,
    this.notificationHour = 19,
    this.notificationMinute = 0,
    this.engineModel = 'light',
    this.engineThreads = 0,
    this.engineHashMb = 0,
    this.engineLines = 3,
    this.engineDepth = 0,
    this.engineInTraining = false,
    this.enginePowerSaving = true,
    this.engineCloudFirst = true,
    this.engineCheckThresholdCp = 80,
    this.gapCoveragePercent = 5,
    this.transpositionMode = 'comment',
    this.defaultStrategy = OpponentStrategy.dueFirst,
    this.onboardingDone = false,
    this.explorerSource = 'masters',
    this.explorerRatings = const [1600, 1800, 2000, 2200, 2500],
    this.explorerSpeeds = const ['blitz', 'rapid', 'classical'],
    this.notationSize = 'normal',
    this.notationLanguage = 'english',
    this.boardScale = 1.0,
  });

  final ThemeMode themeMode;

  /// null = system language.
  final String? localeCode;
  final String boardTheme;
  final String pieceSet;
  final bool showCoordinates;
  final int animationMs;
  final bool sound;
  final bool haptics;
  final bool showLegalMoves;

  /// either | drag | tapTwoSquares
  final String moveMethod;

  // Training (F-TRN-07/09/15).
  final int goodSeconds;
  final int easySeconds;
  final bool easyEnabled;

  /// Whether the time taken to answer changes the grade (D-066). Off by
  /// default: nothing on the screen shows a clock, so a penalty for a slow
  /// answer looked arbitrary.
  final bool timedGrading;

  /// The user closed the invitation to log in to Lichess for the opening
  /// explorer: it is not shown again.
  final bool explorerLoginHintHidden;
  final int mistakesBeforeReveal;
  final bool acceptAlternatives;
  final bool showComments;
  final bool autoplayToDue;
  final bool drillAffectsSchedule;
  final int newPerDay;
  final int reviewsPerDay;
  final int dailyGoal;
  final double desiredRetention;
  final int opponentDelayMs;
  final bool notificationsEnabled;
  final int notificationHour;
  final int notificationMinute;

  // Engine (F-ENG-03). 0 = automatic.
  /// light | full. Full weights are downloaded separately.
  final String engineModel;
  final int engineThreads;
  final int engineHashMb;
  final int engineLines;
  final int engineDepth;
  final bool engineInTraining;

  /// Battery saver: finite searches (depth/time cap), at most 2 threads.
  final bool enginePowerSaving;

  /// Use the Lichess cloud evaluation when it exists; the device engine
  /// runs only when the position is not in the cloud.
  final bool engineCloudFirst;
  final int engineCheckThresholdCp;

  // Integrations.
  final int gapCoveragePercent;

  /// expand | comment (F-REP-09)
  final String transpositionMode;
  final OpponentStrategy defaultStrategy;
  final bool onboardingDone;

  /// masters | lichess
  final String explorerSource;
  final List<int> explorerRatings;
  final List<String> explorerSpeeds;

  /// small | normal | large (T-08)
  final String notationSize;

  /// Board width on every screen with a board (portrait), a share of the
  /// screen width: 1 = full, smaller leaves room for the text (D-052).
  /// Stored under the old key `analysisBoardScale`.
  final double boardScale;

  /// english | ukrainian | figurine (T-13)
  final String notationLanguage;

  GradingPolicy get grading => GradingPolicy(
    goodThreshold: Duration(seconds: goodSeconds),
    easyThreshold: Duration(seconds: easySeconds),
    easyEnabled: easyEnabled,
    timed: timedGrading,
  );

  FsrsParams get fsrsParams => FsrsParams(desiredRetention: desiredRetention);

  Locale? get locale => localeCode == null ? null : Locale(localeCode!);

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? localeCode,
    bool clearLocale = false,
    String? boardTheme,
    String? pieceSet,
    bool? showCoordinates,
    int? animationMs,
    bool? sound,
    bool? haptics,
    bool? showLegalMoves,
    String? moveMethod,
    int? goodSeconds,
    int? easySeconds,
    bool? easyEnabled,
    bool? timedGrading,
    bool? explorerLoginHintHidden,
    int? mistakesBeforeReveal,
    bool? acceptAlternatives,
    bool? showComments,
    bool? autoplayToDue,
    bool? drillAffectsSchedule,
    int? newPerDay,
    int? reviewsPerDay,
    int? dailyGoal,
    double? desiredRetention,
    int? opponentDelayMs,
    bool? notificationsEnabled,
    int? notificationHour,
    int? notificationMinute,
    String? engineModel,
    int? engineThreads,
    int? engineHashMb,
    int? engineLines,
    int? engineDepth,
    bool? engineInTraining,
    bool? enginePowerSaving,
    bool? engineCloudFirst,
    int? engineCheckThresholdCp,
    int? gapCoveragePercent,
    String? transpositionMode,
    OpponentStrategy? defaultStrategy,
    bool? onboardingDone,
    String? explorerSource,
    List<int>? explorerRatings,
    List<String>? explorerSpeeds,
    String? notationSize,
    String? notationLanguage,
    double? boardScale,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
    boardTheme: boardTheme ?? this.boardTheme,
    pieceSet: pieceSet ?? this.pieceSet,
    showCoordinates: showCoordinates ?? this.showCoordinates,
    animationMs: animationMs ?? this.animationMs,
    sound: sound ?? this.sound,
    haptics: haptics ?? this.haptics,
    showLegalMoves: showLegalMoves ?? this.showLegalMoves,
    moveMethod: moveMethod ?? this.moveMethod,
    goodSeconds: goodSeconds ?? this.goodSeconds,
    easySeconds: easySeconds ?? this.easySeconds,
    easyEnabled: easyEnabled ?? this.easyEnabled,
    timedGrading: timedGrading ?? this.timedGrading,
    explorerLoginHintHidden: explorerLoginHintHidden ?? this.explorerLoginHintHidden,
    mistakesBeforeReveal: mistakesBeforeReveal ?? this.mistakesBeforeReveal,
    acceptAlternatives: acceptAlternatives ?? this.acceptAlternatives,
    showComments: showComments ?? this.showComments,
    autoplayToDue: autoplayToDue ?? this.autoplayToDue,
    drillAffectsSchedule: drillAffectsSchedule ?? this.drillAffectsSchedule,
    newPerDay: newPerDay ?? this.newPerDay,
    reviewsPerDay: reviewsPerDay ?? this.reviewsPerDay,
    dailyGoal: dailyGoal ?? this.dailyGoal,
    desiredRetention: desiredRetention ?? this.desiredRetention,
    opponentDelayMs: opponentDelayMs ?? this.opponentDelayMs,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    notificationHour: notificationHour ?? this.notificationHour,
    notificationMinute: notificationMinute ?? this.notificationMinute,
    engineModel: engineModel ?? this.engineModel,
    engineThreads: engineThreads ?? this.engineThreads,
    engineHashMb: engineHashMb ?? this.engineHashMb,
    engineLines: engineLines ?? this.engineLines,
    engineDepth: engineDepth ?? this.engineDepth,
    engineInTraining: engineInTraining ?? this.engineInTraining,
    enginePowerSaving: enginePowerSaving ?? this.enginePowerSaving,
    engineCloudFirst: engineCloudFirst ?? this.engineCloudFirst,
    engineCheckThresholdCp: engineCheckThresholdCp ?? this.engineCheckThresholdCp,
    gapCoveragePercent: gapCoveragePercent ?? this.gapCoveragePercent,
    transpositionMode: transpositionMode ?? this.transpositionMode,
    defaultStrategy: defaultStrategy ?? this.defaultStrategy,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    explorerSource: explorerSource ?? this.explorerSource,
    explorerRatings: explorerRatings ?? this.explorerRatings,
    explorerSpeeds: explorerSpeeds ?? this.explorerSpeeds,
    notationSize: notationSize ?? this.notationSize,
    notationLanguage: notationLanguage ?? this.notationLanguage,
    boardScale: boardScale ?? this.boardScale,
  );

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.name,
    'localeCode': localeCode,
    'boardTheme': boardTheme,
    'pieceSet': pieceSet,
    'showCoordinates': showCoordinates,
    'animationMs': animationMs,
    'sound': sound,
    'haptics': haptics,
    'showLegalMoves': showLegalMoves,
    'moveMethod': moveMethod,
    'goodSeconds': goodSeconds,
    'easySeconds': easySeconds,
    'easyEnabled': easyEnabled,
    'timedGrading': timedGrading,
    'explorerLoginHintHidden': explorerLoginHintHidden,
    'mistakesBeforeReveal': mistakesBeforeReveal,
    'acceptAlternatives': acceptAlternatives,
    'showComments': showComments,
    'autoplayToDue': autoplayToDue,
    'drillAffectsSchedule': drillAffectsSchedule,
    'newPerDay': newPerDay,
    'reviewsPerDay': reviewsPerDay,
    'dailyGoal': dailyGoal,
    'desiredRetention': desiredRetention,
    'opponentDelayMs': opponentDelayMs,
    'notificationsEnabled': notificationsEnabled,
    'notificationHour': notificationHour,
    'notificationMinute': notificationMinute,
    'engineModel': engineModel,
    'engineThreads': engineThreads,
    'engineHashMb': engineHashMb,
    'engineLines': engineLines,
    'engineDepth': engineDepth,
    'engineInTraining': engineInTraining,
    'enginePowerSaving': enginePowerSaving,
    'engineCloudFirst': engineCloudFirst,
    'engineCheckThresholdCp': engineCheckThresholdCp,
    'gapCoveragePercent': gapCoveragePercent,
    'transpositionMode': transpositionMode,
    'defaultStrategy': defaultStrategy.name,
    'onboardingDone': onboardingDone,
    'explorerSource': explorerSource,
    'explorerRatings': explorerRatings,
    'explorerSpeeds': explorerSpeeds,
    'notationSize': notationSize,
    'notationLanguage': notationLanguage,
    'analysisBoardScale': boardScale,
  };

  factory AppSettings.fromJson(Map<String, Object?> j) {
    const d = AppSettings();
    T v<T>(String k, T def) {
      final x = j[k];
      if (x is T) return x;
      if (def is double && x is num) return x.toDouble() as T;
      if (def is int && x is num) return x.toInt() as T;
      return def;
    }

    return AppSettings(
      themeMode: ThemeMode.values.firstWhere((m) => m.name == j['themeMode'], orElse: () => d.themeMode),
      // Only known values: a backup from a newer or modified app must not
      // break the settings screen.
      localeCode: const {'uk', 'en'}.contains(j['localeCode']) ? j['localeCode'] as String : null,
      boardTheme: v('boardTheme', d.boardTheme),
      pieceSet: v('pieceSet', d.pieceSet),
      showCoordinates: v('showCoordinates', d.showCoordinates),
      animationMs: v('animationMs', d.animationMs),
      sound: v('sound', d.sound),
      haptics: v('haptics', d.haptics),
      showLegalMoves: v('showLegalMoves', d.showLegalMoves),
      moveMethod: const {'either', 'drag', 'tapTwoSquares'}.contains(j['moveMethod'])
          ? j['moveMethod'] as String
          : d.moveMethod,
      goodSeconds: v('goodSeconds', d.goodSeconds),
      timedGrading: v('timedGrading', d.timedGrading),
      explorerLoginHintHidden: v('explorerLoginHintHidden', d.explorerLoginHintHidden),
      easySeconds: v('easySeconds', d.easySeconds),
      easyEnabled: v('easyEnabled', d.easyEnabled),
      mistakesBeforeReveal: v('mistakesBeforeReveal', d.mistakesBeforeReveal),
      acceptAlternatives: v('acceptAlternatives', d.acceptAlternatives),
      showComments: v('showComments', d.showComments),
      autoplayToDue: v('autoplayToDue', d.autoplayToDue),
      drillAffectsSchedule: v('drillAffectsSchedule', d.drillAffectsSchedule),
      newPerDay: v('newPerDay', d.newPerDay),
      reviewsPerDay: v('reviewsPerDay', d.reviewsPerDay),
      dailyGoal: v('dailyGoal', d.dailyGoal),
      desiredRetention: v('desiredRetention', d.desiredRetention),
      opponentDelayMs: v('opponentDelayMs', d.opponentDelayMs),
      notificationsEnabled: v('notificationsEnabled', d.notificationsEnabled),
      notificationHour: v('notificationHour', d.notificationHour),
      notificationMinute: v('notificationMinute', d.notificationMinute),
      engineModel: j['engineModel'] == 'full' ? 'full' : 'light',
      engineThreads: v('engineThreads', d.engineThreads),
      engineHashMb: v('engineHashMb', d.engineHashMb),
      engineLines: v('engineLines', d.engineLines),
      engineDepth: v('engineDepth', d.engineDepth),
      engineInTraining: v('engineInTraining', d.engineInTraining),
      enginePowerSaving: v('enginePowerSaving', d.enginePowerSaving),
      engineCloudFirst: v('engineCloudFirst', d.engineCloudFirst),
      engineCheckThresholdCp: v('engineCheckThresholdCp', d.engineCheckThresholdCp),
      gapCoveragePercent: v('gapCoveragePercent', d.gapCoveragePercent),
      transpositionMode: v('transpositionMode', d.transpositionMode),
      defaultStrategy: OpponentStrategy.fromName(j['defaultStrategy'] as String?),
      onboardingDone: v('onboardingDone', d.onboardingDone),
      explorerSource: v('explorerSource', d.explorerSource),
      explorerRatings:
          (j['explorerRatings'] as List?)?.whereType<num>().map((e) => e.toInt()).toList() ?? d.explorerRatings,
      explorerSpeeds: (j['explorerSpeeds'] as List?)?.whereType<String>().toList() ?? d.explorerSpeeds,
      notationSize: v('notationSize', d.notationSize),
      notationLanguage: v('notationLanguage', d.notationLanguage),
      boardScale: v('analysisBoardScale', d.boardScale).clamp(0.5, 1.0).toDouble(),
    );
  }

  String encode() => jsonEncode(toJson());

  static AppSettings decode(String s) {
    try {
      return AppSettings.fromJson((jsonDecode(s) as Map).cast<String, Object?>());
    } catch (_) {
      return const AppSettings();
    }
  }
}
