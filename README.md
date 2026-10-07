# Repertorium chess

Мобільний застосунок для вивчення й заучування шахових дебютів: читання та редагування PGN, власний репертуар, тренування з інтервальним повторенням (FSRS) на рівні позицій, вбудований Stockfish, інтеграції з Lichess і Chess.com. Працює офлайн, без акаунта.

_A mobile app to learn chess openings: PGN reader/editor, repertoire builder, position-based spaced repetition, offline Stockfish, optional Lichess and Chess.com integration._

Ліцензія: **GPL-3.0** (див. `LICENSE`, сторонні компоненти — `NOTICE`).

## Можливості

- **Бібліотека PGN** — імпорт з файлу, буфера, за посиланням (Lichess-студії/глави/партії, будь-який URL), «Відкрити в Repertorium»; кодування UTF-8/Windows-1251/1252 з автовизначенням; помилки у файлі не зупиняють імпорт (список з номерами рядків).
- **Перегляд і редактор** — варіанти будь-якої глибини, коментарі, NAG, стрілки `[%cal]`/`[%csl]`, режим малювання, undo/redo, заголовки, редактор позиції, експорт (поділитися / файл / буфер) без втрат.
- **Репертуар** — граф позицій з транспозиціями; будівник (з дебютною базою Lichess і рушієм); імпорт з PGN/студій з попереднім переглядом, злиттям і розв'язанням конфліктів; дерево, «проблеми», експорт у PGN і в студію Lichess.
- **Тренування** — вивчення (показ → без підказок), повторення за FSRS з автопрограванням до прострочених позицій, прогін, проблемні позиції, «тренувати звідси»; ступінчасті підказки, «Чому?», автоматична оцінка за часом і помилками.
- **Статистика** — прогноз на 7/30 днів, запам'ятовування, серія днів, денна ціль, найслабші позиції.
- **Рушій** — Stockfish 19 офлайн, MultiPV, хмарна оцінка Lichess, перевірка репертуару рушієм.
- **Інтеграції** — Lichess OAuth (PKCE), студії, партії (NDJSON), explorer з кешем, ваги зі статистики, експорт у студію; Chess.com — нікнейм, архіви з ETag; аналіз «де мої партії вийшли з репертуару».
- **Дані** — резервна копія `.tabiya` (замінити/об'єднати), українська та англійська мови, світла/темна тема.

## Збірка

Потрібно: Flutter **3.47.5** stable (Dart 3.13), Xcode 16+ (iOS 15+), Android SDK (API 24+), JDK 17.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift (БД)
flutter run                                                  # на підключеному пристрої/симуляторі
```

Релізні збірки:

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ios --release          # потрібен підпис; для CI: --no-codesign
```

Локалізація генерується автоматично з `lib/l10n/app_*.arb` (`flutter gen-l10n`). Рядки редагуються в `tool/l10n/strings_*.py`, потім:

```bash
python3 tool/l10n/build_arb.py && flutter gen-l10n
```

База назв дебютів (CC0) перебудовується так:

```bash
dart run tool/build_openings.dart
```

## Тести

```bash
flutter analyze
flutter test                           # усі тести, крім продуктивності
flutter test --tags perf --run-skipped # тест продуктивності парсера
```

Покрито: PGN round-trip (варіанти, коментарі, NAG, `[%cal]`, `[%clk]`, cp1251, помилки), ключі позицій і транспозиції (зокрема en passant), імпорт у репертуар (злиття, конфлікти, INV-1…INV-5), стратегії вибору ходу суперника, FSRS і автооцінка, усі режими тренування, аналіз відхилень на еталонних партіях, клієнти Lichess/Chess.com з підмінним HTTP (429, 304, 401, обрив потоку), репозиторії й міграції БД.

## Структура

```
lib/
  domain/        чиста логіка без Flutter: pgn, chess, repertoire, training, srs (FSRS), gap, openings
  data/          БД (drift), репозиторії, Lichess, Chess.com, рушій, бекап, імпорт, нагадування
  presentation/  екрани й віджети (Riverpod, go_router)
  l10n/          ARB-файли uk/en
assets/          база дебютів, стартові репертуари, звуки
docs/            DECISIONS.md, STATUS.md, privacy.md
test/            юніт- та інтеграційні тести, фікстури PGN
```

Архітектурні рішення — `docs/DECISIONS.md`, стан етапів — `docs/STATUS.md`.

## Підтримка / Support

Питання, помилки й побажання — у розділі [Issues](https://github.com/viponomarenko/repertorium-chess/issues).

_Questions, bug reports and requests: please open an [issue](https://github.com/viponomarenko/repertorium-chess/issues)._

Політика приватності / Privacy policy: [docs/privacy.md](docs/privacy.md).

_Repertorium chess не пов'язаний з Lichess чи Chess.com. / Repertorium chess is not affiliated with Lichess or Chess.com._
