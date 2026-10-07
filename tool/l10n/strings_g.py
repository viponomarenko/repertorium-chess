"""Strings added or reworded after the audit of 05.10.2026."""
from strings_a import s, I, T
from strings_e import uk_pl, en_pl

# ---- training
s('enterMoveHint', 'For example Nf3, e4, O-O', 'Наприклад Nf3, e4, O-O')
s('statLines', en_pl('count', 'line', 'lines'), uk_pl('count', 'лінія', 'лінії', 'ліній'), count=I)
s('statStreak', en_pl('count', 'day in a row', 'days in a row'),
  uk_pl('count', 'день поспіль', 'дні поспіль', 'днів поспіль', 'дня поспіль'), count=I)
s('finishSession', 'Finish', 'Завершити')
s('lineNumber', 'Line {number}', 'Лінія {number}', number=I)
s('correctHard', 'Correct, but it took over {seconds} s - it will come back sooner',
  'Правильно, але довше {seconds} с - повторимо раніше', seconds=I)

# ---- repertoire
s('deleteRepertoireNoHistory',
  en_pl('positions', '{positions} position', '{positions} positions') + ' will be deleted.',
  'Буде видалено ' + uk_pl('positions', '{positions} позицію', '{positions} позиції', '{positions} позицій') + '.',
  positions=I)
s('repertoireDeleted', 'Repertoire deleted', 'Репертуар видалено')
s('moveDeleted', 'Move {san} deleted', 'Хід {san} видалено', san=T)
s('branchPaused', 'Training of this branch is paused', 'Тренування цієї гілки призупинено')
s('nameOptional', 'Name (optional)', 'Назва (необовʼязково)')
s('coverageFailed', 'Could not check the coverage. Check the connection and try again.',
  'Не вдалося перевірити покриття. Перевірте звʼязок і спробуйте ще раз.')

# ---- import and library
s('issueIllegalMove', 'Illegal or unreadable move', 'Неможливий або нерозбірливий хід')
s('issueUnreadKept', 'Unread moves are kept in a comment', 'Нерозпізнані ходи збережено в коментарі')
s('issueUnsupportedVariant', 'Unsupported variant', 'Цей варіант шахів не підтримується')
s('issueInvalidFen', 'Invalid FEN header', 'Некоректна позиція у заголовку FEN')
s('issueMalformedHeader', 'Malformed header', 'Пошкоджений заголовок')
s('issueUnterminatedHeader', 'Unterminated header', 'Незакритий заголовок')
s('issueVariationWithoutMove', 'Variation without a preceding move', 'Варіант без попереднього ходу')
s('issueUnbalancedParen', 'Unbalanced ")"', 'Зайва дужка ")"')
s('issueUnclosedVariation', 'Unclosed variation', 'Незакритий варіант')
s('issueUnterminatedComment', 'Unterminated comment', 'Незакритий коментар')
s('gameParseIssues', 'The file had an error: {issue}. The moves after it are kept in a comment marked [?].',
  'У файлі була помилка: {issue}. Ходи після неї збережено в коментарі з позначкою [?].', issue=T)
s('unreadMovesKept', 'The moves after the error are kept in a comment.', 'Ходи після помилки збережено в коментарі.')
s('gamesWithErrors',
  en_pl('count', '{count} game has an error and is readable up to it.', '{count} games have errors and are readable up to them.'),
  uk_pl('count', '{count} партія має помилку й читається до неї.', '{count} партії мають помилки й читаються до них.', '{count} партій мають помилки й читаються до них.'),
  count=I)
s('gamesAlreadyThere',
  en_pl('count', '{count} game was already in the collection', '{count} games were already in the collection'),
  uk_pl('count', '{count} партія вже була в колекції', '{count} партії вже були в колекції', '{count} партій уже було в колекції'),
  count=I)
s('leaveImportQ', 'Leave the import?', 'Вийти з імпорту?')
s('leaveImportSavedMessage', 'The games are already saved in the library. Nothing has been added to the repertoire.',
  'Партії вже збережено в бібліотеці. У репертуар нічого не додано.')
s('leaveImportConfirm', 'Leave', 'Вийти')
s('leaveImportStay', 'Continue the import', 'Продовжити імпорт')
s('closeSearch', 'Close search', 'Закрити пошук')
s('fullMovesCount', en_pl('count', '{count} move', '{count} moves'),
  uk_pl('count', '{count} хід', '{count} ходи', '{count} ходів', '{count} ходу'), count=I)

# ---- game, analysis, position editor
s('setupEmptyBoard', 'The board is empty: add the kings of both sides', 'Дошка порожня: додайте королів обох сторін')
s('leavePositionQ', 'Leave the editor?', 'Вийти з редактора?')
s('leavePositionMessage', 'The position you set up will be lost.', 'Розставлену позицію буде втрачено.')
s('saveFailedLeave', 'The last changes could not be saved. You can try again, copy the game or leave without them.',
  'Останні зміни не вдалося зберегти. Можна спробувати ще раз, скопіювати партію або вийти без них.')
s('leaveWithoutSaving', 'Leave without saving', 'Вийти без збереження')
s('copyPgn', 'Copy PGN', 'Скопіювати PGN')
s('cloudMissingHint', 'This position is not in the Lichess cloud, so the phone calculates it.',
  'Цієї позиції немає в хмарі Lichess, тому її рахує телефон.')

# ---- accounts, backup, my games
s('loginFailedGeneric', 'Could not sign in to Lichess. Check the connection and try again.',
  'Не вдалося увійти в Lichess. Перевірте звʼязок і спробуйте ще раз.')
s('openSystemSettings', 'Open settings', 'Відкрити налаштування')
s('restoreMergeHint', 'Merge adds only what is not on this device yet. Replace deletes everything here first.',
  '«Обʼєднати» додає лише те, чого ще немає на пристрої. «Замінити» спершу видаляє все, що тут є.')
s('restoreNothingNew', 'Everything from this backup is already here', 'Усе з цієї копії вже є на пристрої')
s('restoreMerged', 'Added: {added}. Already here: {skipped}', 'Додано: {added}. Уже було: {skipped}', added=I, skipped=I)
s('analysisDone',
  en_pl('count', 'Found {count} place where a game left the repertoire', 'Found {count} places where games left the repertoire', zero='Your games stay inside the repertoire'),
  uk_pl('count', 'Знайдено {count} розбіжність із репертуаром', 'Знайдено {count} розбіжності з репертуаром', 'Знайдено {count} розбіжностей із репертуаром', zero='Ваші партії не виходять за репертуар'),
  count=I)

# ---- texts
s('engineCheckDone',
  en_pl('count', 'Flagged {count} move - see Problems', 'Flagged {count} moves - see Problems', zero='No doubtful moves found'),
  '{count, plural, =0{Сумнівних ходів не знайдено} other{Позначено ходів: {count} - див. «Проблеми»}}', count=I)
s('importDone',
  en_pl('count', 'Added {count} move', 'Added {count} moves', zero='Nothing new was added'),
  '{count, plural, =0{Нічого нового не додано} other{Додано ходів: {count}}}', count=I)
s('syncDone',
  en_pl('count', 'Added {count} game', 'Added {count} games', zero='No new games'),
  '{count, plural, =0{Нових партій немає} other{Додано партій: {count}}}', count=I)
s('drillAffectsScheduleHint',
  'Answers in "All lines in a row" move the review dates, as in a review',
  'Відповіді в режимі «Усі лінії підряд» змінюють дати повторень, як у повторенні')
s('privacySummary',
  'No account needed, no analytics, no ads. Data stays on the device; Lichess/Chess.com are contacted only when you ask.',
  'Обліковий запис не потрібен, аналітики й реклами немає. Дані - на пристрої; до Lichess/Chess.com звертаємося лише на ваш запит.')

s('gameUnreadKept', 'Some moves of this game could not be read. They are kept in the comment marked [?].',
  'Частину ходів цієї партії не вдалося прочитати. Вони збережені в коментарі з позначкою [?].')

# ---- one vocabulary (D-064): four mode names, the trained unit is a move
s('modeLearn', 'New moves', 'Нові ходи')
s('modeProblems', 'Frequent mistakes', 'Часті помилки')
s('modeProblemsHint',
  en_pl('count', '{count} move with frequent mistakes', '{count} moves with frequent mistakes', zero='No frequent mistakes'),
  uk_pl('count', '{count} хід із частими помилками', '{count} ходи з частими помилками', '{count} ходів із частими помилками', '{count} ходу з частими помилками', zero='Частих помилок немає'),
  count=I)
s('problemPositions', 'Frequent mistakes', 'Часті помилки')
s('problemPositionsHint',
  en_pl('count', '{count} move with frequent mistakes in 30 days', '{count} moves with frequent mistakes in 30 days'),
  uk_pl('count', '{count} хід із частими помилками за 30 днів', '{count} ходи з частими помилками за 30 днів', '{count} ходів із частими помилками за 30 днів', '{count} ходу з частими помилками за 30 днів'),
  count=I)
s('extraPractice', 'All lines in a row: 5 lines', 'Усі лінії підряд: 5 ліній')
s('drillAffectsSchedule', '"All lines in a row" changes the schedule', '«Усі лінії підряд» змінює розклад')
s('drillAffectsScheduleHint', 'Answers in this mode move the review dates, as in a review',
  'Відповіді в цьому режимі змінюють дати повторень, як у повторенні')
s('newPerDay', 'New moves per day', 'Нових ходів на день')
s('statPositions', 'positions in the repertoire', 'позицій у репертуарі')
s('weakestPositions', 'Weakest moves', 'Найслабші ходи')
s('newCardRecall', 'First real test of a new move', 'Перша справжня перевірка нового ходу')
s('autoplayToDue', 'Auto-play to the first move to review', 'Автопрогравання до першого ходу на повторення')
s('restoreSummary', 'Backup from {date}: {repertoires} repertoires, {games} games, {cards} moves to remember.',
  'Копія від {date}: репертуарів {repertoires}, партій {games}, ходів для запамʼятовування {cards}.',
  date=T, repertoires=I, games=I, cards=I)
s('trainThisPosition', 'Train this move', 'Тренувати цей хід')
s('learnNewLines', 'More new moves', 'Ще нові ходи')
s('nothingDueHint', 'Everything is reviewed. You can play all lines in a row or learn new moves.',
  'Усе повторено. Можна пройти всі лінії підряд або вивчити нові ходи.')
s('maxDepthPlies', 'Depth: up to move {count}', 'Глибина: до {count}-го ходу', count=I)
s('pliesCount', en_pl('count', '{count} move', '{count} moves'),
  uk_pl('count', '{count} хід', '{count} ходи', '{count} ходів', '{count} ходу'), count=I)

# ---- one Train button, staged session (D-065)
s('trainNow', 'Train', 'Тренуватись')
s('otherModes', 'Other modes', 'Інші режими')
s('nextStage', 'Next: {mode}', 'Далі: {mode}', mode=T)
s('stageReviewCount', en_pl('count', '{count} to review', '{count} to review'),
  uk_pl('count', '{count} повторення', '{count} повторення', '{count} повторень'), count=I)
s('stageProblemsCount', en_pl('count', '{count} frequent mistake', '{count} frequent mistakes'),
  uk_pl('count', '{count} часта помилка', '{count} часті помилки', '{count} частих помилок'), count=I)
s('stageNewCount', en_pl('count', '{count} new', '{count} new'),
  uk_pl('count', '{count} новий', '{count} нові', '{count} нових', '{count} нового'), count=I)

# ---- grading without a hidden clock (D-066)
s('timedGrading', 'Take the answer time into account', 'Зважати на час відповіді')
s('timedGradingHint', 'A slow answer comes back sooner, a fast one later', 'Повільна відповідь повертається раніше, швидка - пізніше')

# ---- one repertoire screen with an editing mode (D-067)
s('editRepertoire', 'Edit', 'Редагувати')
s('editingMode', 'Editing: moves on the board are added', 'Редагування: ходи на дошці додаються')
s('moveAddedShort', 'Move added', 'Хід додано')
s('newMovesShort', 'Not in the repertoire', 'Цього немає в репертуарі')
s('noCommentYet', 'No comment in the repertoire for this move yet. You can add one while editing the repertoire.',
  'У репертуарі ще немає коментаря до цього ходу. Його можна додати під час редагування репертуару.')

# ---- import: Read or Learn (D-068)
s('importRead', 'Read', 'Читати')
s('importReadTo', 'Save to the library: {name}', 'Зберегти в бібліотеку: {name}', name=T)
s('importLearn', 'Learn', 'Вчити')
s('importLearnTo', 'Add to the repertoire: {name}', 'Додати в репертуар: {name}', name=T)
s('importLearnNew', 'Add to a new repertoire', 'Додати в новий репертуар')
s('change', 'Change', 'Змінити')
s('movesAddedTo',
  en_pl('count', '{count} move added to {name}', '{count} moves added to {name}'),
  uk_pl('count', '{count} хід додано в «{name}»', '{count} ходи додано в «{name}»', '{count} ходів додано в «{name}»', '{count} ходу додано в «{name}»'),
  count=I, name=T)
s('learnNowLong', 'Learn them now', 'Вчити зараз')
s('pasteText', 'Paste text', 'Вставити текст')
s('pasteTextHint', 'PGN or FEN from the clipboard, or type it in', 'PGN або FEN з буфера обміну, або введіть вручну')
s('importOptions', 'Import options', 'Налаштування імпорту')
s('importOptionsHint', 'Variations, depth, comments, arrows', 'Варіанти, глибина, коментарі, стрілки')

# ---- More in three groups, one "My games" screen, report sections (D-069)
s('moreYourGames', 'Your games', 'Ваші партії')
s('moreTools', 'Tools', 'Інструменти')
s('moreApp', 'App', 'Застосунок')
s('myGamesSubtitle', 'Download, your openings, differences from the repertoire',
  'Завантаження, ваші дебюти, розбіжності з репертуаром')
s('tabGames', 'Games', 'Партії')
s('tabOpenings', 'Openings', 'Дебюти')
s('tabGaps', 'Differences', 'Розбіжності')
s('gapSectionForgot', 'You forgot your move', 'Ви забули свій хід')
s('gapSectionNovelty', 'The opponent played something new', 'Суперник зіграв нове')
s('gapSectionEnd', 'The line ended', 'Лінія закінчилась')
s('gapSectionOther', 'Another opening', 'Інший дебют')
s('gapOtherOpening', 'No repertoire for this opening', 'Для цього дебюту репертуару немає')
s('gapOtherText', 'You started with {played}; your repertoire begins differently',
  'Ви почали з {played}; ваш репертуар починається інакше', played=T)
s('gamesCountShort', en_pl('count', '{count} game', '{count} games'),
  uk_pl('count', '{count} партія', '{count} партії', '{count} партій'), count=I)
s('trainThisPosition', 'Review', 'Повторити')
s('prepareAnswer', 'Add an answer', 'Додати відповідь')

# ---- first run and settings (D-070)
s('startWithStarter', 'Start with a ready-made repertoire', 'Почати з готового репертуару')
s('welcomeMessage', 'A ready-made repertoire is the quickest way to try training. You can also build your own or open a PGN file.',
  'Готовий репертуар - найшвидший спосіб спробувати тренування. Можна також створити свій або відкрити файл PGN.')
s('advancedIntegrationsHint', 'Opening explorer filters, coverage threshold, cache',
  'Фільтри дебютної бази, поріг покриття, кеш')
s('advancedTrainingHint', 'Daily limits, alternative moves, answer time, opponent moves',
  'Денні ліміти, альтернативні ходи, час відповіді, ходи суперника')

s('dontShowAgain', 'Do not show again', 'Більше не показувати')

s('editingMode', 'Editing', 'Редагування')
s('movesAddedTo',
  en_pl('count', '{count} move of yours added to {name}', '{count} moves of yours added to {name}', zero='Added to {name}: only opponent moves'),
  uk_pl('count', '{count} ваш хід додано в «{name}»', '{count} ваші ходи додано в «{name}»', '{count} ваших ходів додано в «{name}»', '{count} вашого ходу додано в «{name}»', zero='Додано в «{name}»: лише ходи суперника'),
  count=I, name=T)

# ---- Learn goes only to a repertoire the lines belong to (D-073)
s('importLearnChoose', 'Choose a repertoire or create a new one', 'Обрати репертуар або створити новий')
s('importLearnChecking', 'Looking for the right repertoire…', 'Шукаємо відповідний репертуар…')
s('importLearnChoose', 'Choose a repertoire', 'Обрати репертуар')
s('importLearnChecking', 'Looking for a repertoire…', 'Шукаємо репертуар…')

# ---- ready-made repertoires are offered where a repertoire is created
s('orTakeStarter', 'Or take a ready-made repertoire', 'Або взяти готовий репертуар')
s('installStarter', 'Ready-made repertoires', 'Готові репертуари')

# ---- the main action of a list, as a labelled pill in the app bar
s('newShort', 'New', 'Новий')
s('importShort', 'Import', 'Імпорт')

# ---- compact row under the repertoire board (D-074)
s('trainFromHere', 'Train', 'Тренувати')
s('trainFromHereLong', 'Train from here', 'Тренувати звідси')
s('arrowsShort', 'Arrows', 'Стрілки')
