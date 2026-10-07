"""UX wording pass and complete plural forms (T-17). Overrides earlier tables."""
from strings_a import s, I, T

def uk_pl(var, one, few, many, other=None, zero=None):
    other = other or few
    z = f'=0{{{zero}}} ' if zero else ''
    return f'{{{var}, plural, {z}one{{{one}}} few{{{few}}} many{{{many}}} other{{{other}}}}}'

def en_pl(var, one, other, zero=None):
    z = f'=0{{{zero}}} ' if zero else ''
    return f'{{{var}, plural, {z}one{{{one}}} other{{{other}}}}}'

# ---- plurals (T-17)
s('problemPositionsHint',
  en_pl('count', '{count} position with frequent mistakes in 30 days', '{count} positions with frequent mistakes in 30 days'),
  uk_pl('count', '{count} позиція з частими помилками за 30 днів', '{count} позиції з частими помилками за 30 днів', '{count} позицій з частими помилками за 30 днів'),
  count=I)
s('repertoireCounts',
  '{learned} of ' + en_pl('total', '{total} move', '{total} moves') + ' learned',
  'Вивчено {learned} з ' + uk_pl('total', '{total} ходу', '{total} ходів', '{total} ходів', '{total} ходу'),
  learned=I, total=I)
s('pliesCount', en_pl('count', '{count} ply', '{count} plies'),
  uk_pl('count', '{count} напівхід', '{count} напівходи', '{count} напівходів', '{count} напівходу'), count=I)
s('gamesWithErrors',
  en_pl('count', '{count} game with errors was imported up to the problem', '{count} games with errors were imported up to the problem'),
  uk_pl('count', '{count} партію з помилками імпортовано до місця помилки', '{count} партії з помилками імпортовано до місця помилки', '{count} партій з помилками імпортовано до місця помилки'),
  count=I)
s('maxDepthPlies', 'Depth: ' + en_pl('count', '{count} ply', '{count} plies'),
  'Глибина: ' + uk_pl('count', '{count} напівхід', '{count} напівходи', '{count} напівходів', '{count} напівходу'), count=I)
s('deletePlan',
  en_pl('positions', '{positions} position', '{positions} positions') + ' will be deleted, including training progress for ' + en_pl('cards', '{cards} move', '{cards} moves') + '. Positions still reachable through transpositions are kept.',
  'Буде видалено ' + uk_pl('positions', '{positions} позицію', '{positions} позиції', '{positions} позицій') + ' і прогрес тренування для ' + uk_pl('cards', '{cards} ходу', '{cards} ходів', '{cards} ходів', '{cards} ходу') + '. Позиції, досяжні через транспозиції, залишаться.',
  positions=I, cards=I)
s('deleteRepertoireMessage',
  en_pl('positions', '{positions} position', '{positions} positions') + ' and the training history of ' + en_pl('cards', '{cards} move', '{cards} moves') + ' will be deleted.',
  'Буде видалено ' + uk_pl('positions', '{positions} позицію', '{positions} позиції', '{positions} позицій') + ' та історію тренувань для ' + uk_pl('cards', '{cards} ходу', '{cards} ходів', '{cards} ходів', '{cards} ходу') + '.',
  positions=I, cards=I)
s('tooManyChaptersMessage',
  'The export has ' + en_pl('count', '{count} chapter', '{count} chapters') + ', but the study has room for {free} (Lichess limit: 64). Only the first {free} will be exported.',
  'Експорт містить ' + uk_pl('count', '{count} главу', '{count} глави', '{count} глав') + ', а в студії є місце лише для {free} (обмеження Lichess - 64). Буде експортовано перші {free}.',
  count=I, free=I)
s('coverageItem', '{percent}% of games · ' + en_pl('games', '{games} game', '{games} games'),
  '{percent}% партій · ' + uk_pl('games', '{games} партія', '{games} партії', '{games} партій'), percent=T, games=I)
s('linesN', en_pl('count', '{count} line', '{count} lines'),
  uk_pl('count', '{count} лінія', '{count} лінії', '{count} ліній'), count=I)
s('syncFailed', 'Stopped after ' + en_pl('count', '{count} game', '{count} games') + ': {error}',
  'Зупинено після ' + uk_pl('count', '{count} партії', '{count} партій', '{count} партій') + ': {error}', count=I, error=T)
s('maxGames', 'At most ' + en_pl('count', '{count} game', '{count} games'),
  'Не більше ' + uk_pl('count', '{count} партії', '{count} партій', '{count} партій'), count=I)
s('lastDays', en_pl('days', 'Last day', 'Last {days} days'),
  uk_pl('days', 'Останній {days} день', 'Останні {days} дні', 'Останні {days} днів', 'Останні {days} дня'), days=I)
s('cardsSuspended', en_pl('count', '{count} move paused', '{count} moves paused', zero='Nothing to pause'),
  uk_pl('count', 'Призупинено {count} хід', 'Призупинено {count} ходи', 'Призупинено {count} ходів', 'Призупинено {count} ходу', zero='Нічого призупиняти'), count=I)
s('cardsResumed', en_pl('count', '{count} move resumed', '{count} moves resumed', zero='Nothing to resume'),
  uk_pl('count', 'Відновлено {count} хід', 'Відновлено {count} ходи', 'Відновлено {count} ходів', 'Відновлено {count} ходу', zero='Нічого відновлювати'), count=I)
s('modeReviewHint', en_pl('count', '{count} move to review', '{count} moves to review', zero='Nothing to review now'),
  uk_pl('count', '{count} хід до повторення', '{count} ходи до повторення', '{count} ходів до повторення', '{count} ходу до повторення', zero='Зараз нічого повторювати'), count=I)
s('modeLearnHint', en_pl('count', '{count} new move', '{count} new moves', zero='No new moves'),
  uk_pl('count', '{count} новий хід', '{count} нові ходи', '{count} нових ходів', '{count} нового ходу', zero='Нових ходів немає'), count=I)
s('modeProblemsHint', en_pl('count', '{count} position with frequent mistakes', '{count} positions with frequent mistakes', zero='No frequent mistakes'),
  uk_pl('count', '{count} позиція з частими помилками', '{count} позиції з частими помилками', '{count} позицій з частими помилками', zero='Частих помилок немає'), count=I)
s('reviewDue', 'Review ({count})', 'Повторити ({count})', count=I)
s('todaySummary',
  en_pl('due', '{due} move to review', '{due} moves to review', zero='Nothing to review') + ' · ' + en_pl('fresh', '{fresh} new', '{fresh} new', zero='no new'),
  uk_pl('due', '{due} хід до повторення', '{due} ходи до повторення', '{due} ходів до повторення', '{due} ходу до повторення', zero='Нічого повторювати') + ' · ' + uk_pl('fresh', '{fresh} новий', '{fresh} нові', '{fresh} нових', '{fresh} нового', zero='нових немає'),
  due=I, fresh=I)
s('modeDrill', 'All lines in a row', 'Усі лінії підряд')
s('modeDrillHint', 'Play every line of the branch; does not change your review schedule', 'Пройти всі лінії гілки; розклад повторень не змінюється')

# ---- terms: "card" -> "move to remember"
s('cardAtPosition', 'Your move here', 'Ваш хід у цій позиції')
s('cardNone', 'No move to train here yet', 'Тут ще немає ходу для тренування')
s('cardNew', 'New - not learned yet', 'Новий - ще не вивчений')
s('cardSuspended', 'Paused', 'Призупинено')
s('cardDueNow', 'Time to review', 'Час повторити')
s('statCards', 'moves to remember', 'ходів для запамʼятовування')
s('statLearned', 'learned', 'вивчено')
s('suspendBranch', 'Pause training of this branch', 'Призупинити тренування гілки')
s('resumeBranch', 'Resume training of this branch', 'Відновити тренування гілки')

# ---- grades shown after a correct answer
s('correctAgain', 'Correct, with help - we will repeat it soon', 'Правильно, але з підказкою - скоро повторимо')
s('correctHard', 'Correct, but slow - it will come back sooner', 'Правильно, але повільно - повторимо раніше')
s('correctGood', 'Correct!', 'Правильно!')
s('correctEasy', 'Correct and fast!', 'Правильно і швидко!')

# ---- clearer names
s('builder', 'Line editor', 'Редактор ліній')
s('gapUserDeviation', 'You left the repertoire', 'Ви відійшли від репертуару')
s('gapUserText', 'You played {played}; your repertoire has {expected}', 'Ви зіграли {played}, а за репертуаром - {expected}', played=T, expected=T)
s('cloudEval', 'Lichess eval', 'Оцінка Lichess')
s('cloudMissing', 'No Lichess eval', 'Lichess не має оцінки')
s('cloudDepth', 'Lichess, depth {depth}', 'Lichess, глибина {depth}', depth=I)
s('speedBullet', 'Bullet', 'Куля')
s('retry', 'Try again', 'Спробувати ще')
s('engineLines', 'Engine lines shown', 'Скільки ліній рушія показувати')
s('engineHash', 'Engine memory', 'Памʼять рушія')
s('engineThreads', 'Engine threads', 'Потоки рушія')
s('engineThreshold', 'Flag moves that worsen the eval by more than', 'Позначати ходи, що погіршують оцінку більш ніж на')
s('desiredRetention', 'Target share of remembered moves', 'Цільова частка пригаданих ходів')
s('showAnswer', 'Show the move', 'Показати хід')
s('showAnswerHint', 'Counts as a mistake: the move will be repeated soon', 'Зараховується як помилка: хід скоро повториться')
s('hintHint', 'Each hint counts as a mistake', 'Будь-яка підказка зараховується як помилка')
s('noCommentYet', 'No comment in the repertoire for this move yet. You can add it in the line editor.', 'У репертуарі ще немає коментаря до цього ходу. Його можна додати в редакторі ліній.')
