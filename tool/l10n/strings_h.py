"""Strings of the redesigned Repertoires, Library and Collection screens (D-104)."""
from strings_a import s, I, T
from strings_e import uk_pl, en_pl

# ---- repertoires
s('repSummaryIn', en_pl('count', 'In {count} repertoire', 'In {count} repertoires'),
  uk_pl('count', 'У {count} репертуарі', 'У {count} репертуарах', 'У {count} репертуарах', 'У {count} репертуарах'),
  count=I)
s('dueToday', 'to review today', 'на повторення сьогодні')
s('repSummaryLine',
  en_pl('fresh', '{fresh} new move', '{fresh} new moves') + ' · {learned} of {total} learned',
  uk_pl('fresh', '{fresh} новий хід', '{fresh} нові ходи', '{fresh} нових ходів', '{fresh} нового ходу')
  + ' · вивчено {learned} з {total}',
  fresh=I, learned=I, total=I)
s('trainAll', 'Train all', 'Тренувати все')
s('repStatusDue',
  '{due} to review · ' + en_pl('fresh', '{fresh} new', '{fresh} new'),
  '{due} на повторення · ' + uk_pl('fresh', '{fresh} новий', '{fresh} нові', '{fresh} нових', '{fresh} нового'),
  due=I, fresh=I)
s('repStatusNew', en_pl('fresh', '{fresh} new move', '{fresh} new moves'),
  uk_pl('fresh', '{fresh} новий хід', '{fresh} нові ходи', '{fresh} нових ходів', '{fresh} нового ходу'), fresh=I)
s('repStatusDone', 'All done for today', 'На сьогодні все')

# ---- library
s('librarySearchHint', 'Search by name, player or opening', 'Пошук за назвою, гравцем або дебютом')
s('collectionsTitle', 'Collections', 'Колекції')
s('importFileTitle', 'PGN file', 'Файл PGN')
s('importFileSub', 'From the device or Files', 'З пристрою або «Файлів»')
s('importClipboardTitle', 'From clipboard', 'З буфера')
s('importClipboardSub', 'Paste PGN', 'Вставити PGN')
s('importLinkTitle', 'By link', 'За посиланням')
s('importLinkSub', 'Lichess study, game, URL', 'Студія Lichess, партія, URL')
s('srcFilesClipboard', 'Files and clipboard', 'Файли й буфер')
s('srcFile', 'File', 'Файл')
s('srcClipboard', 'Clipboard', 'Буфер')
s('srcManual', 'Collection', 'Колекція')
s('srcAnalysis', 'Analyses', 'Аналізи')
s('nothingFoundFor', 'Nothing found for «{query}»', 'Нічого не знайдено за «{query}»', query=T)

# ---- collection
s('collectionMeta', '{games} · {source} · updated {date}', '{games} · {source} · оновлено {date}',
  games=T, source=T, date=T)
s('exportShort', 'Export', 'Експорт')
s('importHereShort', 'Import here', 'Імпорт сюди')
s('toRepertoireShort', 'To repertoire', 'В репертуар')
s('endSelection', 'Done', 'Готово')
