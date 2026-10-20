"""Strings of the "About this position" panel (D-105)."""
from strings_a import s, I, T
from strings_e import uk_pl, en_pl

s('aboutPosition', 'About this position', 'Про позицію')
s('navPosition', 'Position', 'Позиція')
s('aboutMyComment', 'My comment', 'Мій коментар')
s('aboutInRepertoire', 'In “{name}”', 'У «{name}»', name=T)
s('aboutOpening', 'Opening', 'Дебют')
s('aboutEngine', 'Engine', 'Рушій')
s('aboutAnalyze', 'Analyze', 'Аналізувати')
s('aboutEmptyHint',
  'Nothing is known about this position yet. Add it to a repertoire to write your own comment.',
  'Про цю позицію ще нічого немає. Додайте її в репертуар, щоб написати свій коментар.')
s('aboutFinalPosition', 'About the final position', 'Про кінцеву позицію')

# ---- the verdict
s('verdictEqual', 'The position is equal', 'Позиція рівна')
s('verdictSlightWhite', 'White is slightly better', 'У білих невелика перевага')
s('verdictSlightBlack', 'Black is slightly better', 'У чорних невелика перевага')
s('verdictClearWhite', 'White is clearly better', 'У білих помітна перевага')
s('verdictClearBlack', 'Black is clearly better', 'У чорних помітна перевага')
s('verdictDecisiveWhite', 'White is winning', 'У білих вирішальна перевага')
s('verdictDecisiveBlack', 'Black is winning', 'У чорних вирішальна перевага')
s('verdictMateWhite', en_pl('n', 'White mates in {n} move', 'White mates in {n} moves'),
  uk_pl('n', 'Білі ставлять мат за {n} хід', 'Білі ставлять мат за {n} ходи', 'Білі ставлять мат за {n} ходів',
        'Білі ставлять мат за {n} ходу'), n=I)
s('verdictMateBlack', en_pl('n', 'Black mates in {n} move', 'Black mates in {n} moves'),
  uk_pl('n', 'Чорні ставлять мат за {n} хід', 'Чорні ставлять мат за {n} ходи', 'Чорні ставлять мат за {n} ходів',
        'Чорні ставлять мат за {n} ходу'), n=I)

# ---- the best move, the threat
s('bestMoveIs', 'Best move: {move}', 'Найкращий хід: {move}', move=T)
s('kindMate', 'mate', 'мат')
s('kindPromotion', 'promotes a pawn', 'перетворення пішака')
s('kindWinsMaterial', 'wins material', 'виграє матеріал')
s('kindCastling', 'castling', 'рокіровка')
s('kindCheck', 'with check', 'з шахом')
s('kindCapture', 'a capture', 'взяття')
s('onlyMoveHere', 'Only one move holds the position here', 'Тут лише один хід тримає позицію')
s('threatIs', 'Threat: {move}', 'Загроза: {move}', move=T)
s('threatMate', en_pl('n', 'Threat: {move}, mate in {n}', 'Threat: {move}, mate in {n}'),
  uk_pl('n', 'Загроза: {move}, мат за {n} хід', 'Загроза: {move}, мат за {n} ходи', 'Загроза: {move}, мат за {n} ходів',
        'Загроза: {move}, мат за {n} ходу'), move=T, n=I)

# ---- opening texts from Wikibooks (D-106)
s('textForPositionAfter', 'There is an explanation for the position after {move}', 'Є пояснення до позиції після {move}', move=T)
s('wikibooksMachine', 'Wikibooks · machine translation · CC BY-SA 4.0', 'Wikibooks · машинний переклад · CC BY-SA 4.0')
s('wikibooksReviewed', 'Wikibooks · translation checked · CC BY-SA 4.0', 'Wikibooks · переклад перевірено · CC BY-SA 4.0')
s('wikibooksOriginal', 'Wikibooks · CC BY-SA 4.0', 'Wikibooks · англійською · CC BY-SA 4.0')
s('textShowOriginal', 'Original', 'Оригінал')
s('textShowTranslation', 'Translation', 'Переклад')
s('textReadMore', 'Read more', 'Читати далі')
s('textReadLess', 'Show less', 'Згорнути')
s('dataSources', 'Data sources', 'Джерела даних')
s('sourceOpeningNames', 'Opening names: lichess-org/chess-openings', 'Назви дебютів: lichess-org/chess-openings')
s('sourceOpeningTexts', 'Opening texts: Wikibooks, Chess Opening Theory', 'Тексти про дебюти: Wikibooks, Chess Opening Theory')
s('sourceOpeningTextsLicense',
  'CC BY-SA 4.0. The Ukrainian translation is machine-made and shared under the same licence.',
  'CC BY-SA 4.0. Український переклад машинний і поширюється на тих самих умовах.')

# ---- structure and small features (D-107)
s('aboutStructure', 'Structure', 'Структура')
s('structureWhite', '{name} · White', '{name} · у білих', name=T)
s('structureBlack', '{name} · Black', '{name} · у чорних', name=T)
s('structureSource', 'Repertorium chess', 'Repertorium chess')
s('structureNotReviewed', 'Repertorium chess · not reviewed yet', 'Repertorium chess · ще не вичитано')
s('featPassedWhite', en_pl('n', 'White has a passed pawn on {squares}', 'White has passed pawns on {squares}'),
  uk_pl('n', 'У білих прохідний пішак {squares}', 'У білих прохідні пішаки {squares}', 'У білих прохідні пішаки {squares}',
        'У білих прохідні пішаки {squares}'), n=I, squares=T)
s('featPassedBlack', en_pl('n', 'Black has a passed pawn on {squares}', 'Black has passed pawns on {squares}'),
  uk_pl('n', 'У чорних прохідний пішак {squares}', 'У чорних прохідні пішаки {squares}', 'У чорних прохідні пішаки {squares}',
        'У чорних прохідні пішаки {squares}'), n=I, squares=T)
s('featIsolatedWhite', en_pl('n', 'White has an isolated pawn on {squares}', 'White has isolated pawns on {squares}'),
  uk_pl('n', 'У білих ізольований пішак {squares}', 'У білих ізольовані пішаки {squares}', 'У білих ізольовані пішаки {squares}',
        'У білих ізольовані пішаки {squares}'), n=I, squares=T)
s('featIsolatedBlack', en_pl('n', 'Black has an isolated pawn on {squares}', 'Black has isolated pawns on {squares}'),
  uk_pl('n', 'У чорних ізольований пішак {squares}', 'У чорних ізольовані пішаки {squares}', 'У чорних ізольовані пішаки {squares}',
        'У чорних ізольовані пішаки {squares}'), n=I, squares=T)
s('featBackwardWhite', en_pl('n', 'White has a backward pawn on {squares}', 'White has backward pawns on {squares}'),
  uk_pl('n', 'У білих відсталий пішак {squares}', 'У білих відсталі пішаки {squares}', 'У білих відсталі пішаки {squares}',
        'У білих відсталі пішаки {squares}'), n=I, squares=T)
s('featBackwardBlack', en_pl('n', 'Black has a backward pawn on {squares}', 'Black has backward pawns on {squares}'),
  uk_pl('n', 'У чорних відсталий пішак {squares}', 'У чорних відсталі пішаки {squares}', 'У чорних відсталі пішаки {squares}',
        'У чорних відсталі пішаки {squares}'), n=I, squares=T)
s('featDoubledWhite', 'White has doubled pawns on {squares}', 'У білих здвоєні пішаки {squares}', squares=T)
s('featDoubledBlack', 'Black has doubled pawns on {squares}', 'У чорних здвоєні пішаки {squares}', squares=T)
s('featOpenFile', 'The {file}-file is open: a road for the rooks', 'Вертикаль {file} відкрита - її можуть зайняти тури', file=T)
s('featHalfOpenWhite', 'The {file}-file is half-open for White', 'Вертикаль {file} напіввідкрита для білих', file=T)
s('featHalfOpenBlack', 'The {file}-file is half-open for Black', 'Вертикаль {file} напіввідкрита для чорних', file=T)
s('featOppositeCastling', 'Kings on opposite wings: usually a race of pawn storms',
  'Королі на різних флангах - зазвичай це гонка пішакових атак')
s('featWeakShelterWhite', "The pawn shelter of White's king is weakened", 'Пішакове прикриття білого короля ослаблене')
s('featWeakShelterBlack', "The pawn shelter of Black's king is weakened", 'Пішакове прикриття чорного короля ослаблене')

# ---- the comment editor (D-110)
s('commentHint', 'A plan, an idea, a trap worth remembering', 'План, ідея, пастка, яку варто памʼятати')
s('commentAfterMove', 'After {move}', 'Після {move}', move=T)
s('commentStartPosition', 'Starting position', 'Початкова позиція')
s('signsMore', 'More signs', 'Більше знаків')
s('signsLess', 'Fewer signs', 'Менше знаків')
s('signsMove', 'Move', 'Оцінка ходу')
s('signsPosition', 'Position', 'Оцінка позиції')
s('signsIdeas', 'Ideas', 'Ідеї та обставини')

# ---- the menu sheet (D-112)
s('menuImportExport', 'Import and export', 'Імпорт і експорт')
s('menuTools', 'Tools', 'Інструменти')

# ---- polish 18.10 (D-114 … D-118)
s('modesTitle', 'How to train', 'Як тренуватись')
s('modesUnavailable', 'Not available yet', 'Поки недоступно')
s('streakStartHint', 'Train today and your week shows up here', 'Потренуйтесь сьогодні, і тут зʼявиться ваш тиждень')
s('lineSoFar', 'Line: {moves}', 'Лінія: {moves}', moves=T)
s('modeDrillLocked', 'Opens once you have learned a move', 'Зʼявиться, щойно ви вивчите перший хід')

# ---- polish 18.10, part 2 (D-119 … D-122)
s('ecoGroupA', 'Flank openings', 'Флангові дебюти')
s('ecoGroupB', 'Semi-open games', 'Напіввідкриті дебюти')
s('ecoGroupC', 'Open games and the French', 'Відкриті дебюти й французький захист')
s('ecoGroupD', 'Closed and semi-closed games', 'Закриті й напівзакриті дебюти')
s('ecoGroupE', 'Indian defences', 'Індійські захисти')
s('openingVariations', en_pl('count', '{count} line', '{count} lines'),
  uk_pl('count', '{count} варіант', '{count} варіанти', '{count} варіантів', '{count} варіанта'), count=I)
s('repertoireOtherSideHint', 'You train one side so far. Add the other to be ready for both colours.', 'Поки ви тренуєте одну сторону. Додайте другу, щоб мати відповіді за обидва кольори.')
s('analysisEmptyHint', 'Make a move on the board, or paste a PGN or FEN', 'Зробіть хід на дошці або вставте PGN чи FEN')
s('pasteGame', 'Paste', 'Вставити')
