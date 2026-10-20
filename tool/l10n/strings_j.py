"""Strings of the puzzles (D-123): screens and the Lichess themes.

Theme names and descriptions are our own words, not Lichess translations.
Key of a theme: 'pt' + the Lichess key with a capital letter ('ptFork'),
its description: + 'Desc'. The Dart lookup is puzzle_theme_names.dart.
"""
from strings_a import s, I, T
from strings_e import uk_pl, en_pl

s('puzzlesTitle', 'Puzzles', 'Головоломки')
s('puzzlesSubtitle', 'Lichess puzzles by theme', 'Задачі Lichess за темами')
s('puzzleRating', 'Puzzle rating', 'Рейтинг у задачах')
s('puzzleRatingProvisional', 'Provisional rating {rating}', 'Попередній рейтинг {rating}', rating=I)
s('puzzleStatPlayed', 'Puzzles', 'Задач')
s('puzzleStatSolved', 'Solved', 'Розвʼязано')
s('puzzlesNoteLocal',
  'Puzzles come from Lichess; without the internet, or while Lichess limits them, from the app\'s own set of 50,000. Your rating stays on this device.',
  'Задачі надходять з Lichess, а без інтернету чи поки Lichess їх обмежує, з власного набору застосунку на 50 000 задач. Рейтинг зберігається на цьому пристрої.')
s('puzzlesNoteLichess',
  'Results count into your Lichess rating ({user}). Without the internet, puzzles come from the app\'s own set and the results are sent later.',
  'Результати зараховуються у ваш рейтинг на Lichess ({user}). Без інтернету задачі беруться з набору застосунку, а результати надсилаються пізніше.',
  user=T)
s('puzzlesReconnect',
  'To count puzzles into your Lichess rating, connect the account again: Lichess will ask for access to puzzles.',
  'Щоб задачі зараховувались у ваш рейтинг на Lichess, підключіть акаунт ще раз: Lichess попросить доступ до задач.')
s('puzzlesReconnectAction', 'Connect', 'Підключити')
s('puzzlesPending',
  en_pl('n', '{n} result waits to be sent to Lichess', '{n} results wait to be sent to Lichess'),
  uk_pl('n', 'Не надіслано на Lichess: {n} результат', 'Не надіслано на Lichess: {n} результати',
        'Не надіслано на Lichess: {n} результатів', 'Не надіслано на Lichess: {n} результату'), n=I)
s('puzzleRatingLichess', 'Lichess rating', 'Рейтинг Lichess')
s('puzzleFromPackOffline', 'No internet: a puzzle from the app\'s set', 'Без інтернету: задача з набору застосунку')
s('puzzleFromPackLimited', 'Lichess limits puzzles for now: a puzzle from the app\'s set',
  'Lichess зараз обмежує задачі: задача з набору застосунку')
s('puzzleThemeScore', '{won} of {played}', '{won} з {played}', won=I, played=I)
s('puzzleThemeScoreLabel',
  en_pl('played', '{won} of {played} puzzle solved', '{won} of {played} puzzles solved'),
  uk_pl('played', 'Розвʼязано {won} з {played} задачі', 'Розвʼязано {won} з {played} задач',
        'Розвʼязано {won} з {played} задач', 'Розвʼязано {won} з {played} задачі'), won=I, played=I)

s('puzzleCatRecommended', 'Recommended', 'Рекомендовано')
s('puzzleCatPhases', 'Phases', 'Стадії гри')
s('puzzleCatMotifs', 'Motifs', 'Мотиви')
s('puzzleCatAdvanced', 'Advanced', 'Складніші прийоми')
s('puzzleCatMates', 'Checkmates', 'Мати')
s('puzzleCatMateThemes', 'Mate patterns', 'Типові мати')
s('puzzleCatSpecialMoves', 'Special moves', 'Особливі ходи')
s('puzzleCatGoals', 'Goals', 'Мета')
s('puzzleCatLengths', 'Length', 'Довжина')
s('puzzleCatOrigin', 'Origin', 'Походження')

# ---- the puzzle screen
s('puzzleFindWhite', 'Your move: find the best move for White', 'Ваш хід: знайдіть найкращий хід за білих')
s('puzzleFindBlack', 'Your move: find the best move for Black', 'Ваш хід: знайдіть найкращий хід за чорних')
s('puzzleBestMove', 'Best move! Keep going', 'Найкращий хід! Далі')
s('puzzleWrongMove', 'That is not the move. Try another one', 'Це не той хід. Спробуйте інший')
s('puzzleSolved', 'Solved', 'Розвʼязано')
s('puzzleNotSolved', 'Not solved', 'Не розвʼязано')
s('puzzleSolutionShown', 'Solution shown', 'Показано рішення')
s('puzzleRatingAfter', 'Rating {rating}, {change}', 'Рейтинг {rating}, {change}', rating=T, change=T)
s('puzzleRatingUnchanged', 'unchanged', 'без змін')
s('puzzleShowSolution', 'Show solution', 'Показати рішення')
s('puzzleNext', 'Next puzzle', 'Наступна задача')
s('puzzleOnLichess', 'Open on Lichess', 'Відкрити на Lichess')
s('puzzleInfo', 'Puzzle {id} · rating {rating}', 'Задача {id} · рейтинг {rating}', id=T, rating=I)
s('puzzleRateLimited',
  'Lichess limits how many puzzles one network can take in an hour, and that limit is reached. Try again in a while.',
  'Lichess обмежує, скільки задач одна мережа може взяти за годину, і цю межу вичерпано. Спробуйте трохи згодом.')
s('puzzleLoadError',
  'Could not load puzzles. Check the internet connection.',
  'Не вдалося завантажити задачі. Перевірте підключення до інтернету.')

# ---- themes: key, en name, en description, uk name, uk description
THEMES = [
  ('mix', 'All themes', 'A bit of everything, near your rating.',
   'Усі теми', 'Усього потроху, біля вашого рейтингу.'),
  ('opening', 'Opening', 'Tactics in the first moves of the game.',
   'Дебют', 'Тактика в перших ходах партії.'),
  ('middlegame', 'Middlegame', 'Tactics in the middle of the game.',
   'Мітельшпіль', 'Тактика в середині партії.'),
  ('endgame', 'Endgame', 'Tactics in the last phase of the game.',
   'Ендшпіль', 'Тактика в завершальній стадії партії.'),
  ('rookEndgame', 'Rook endgame', 'Only rooks and pawns.',
   'Туровий ендшпіль', 'Лише тури й пішаки.'),
  ('bishopEndgame', 'Bishop endgame', 'Only bishops and pawns.',
   'Слоновий ендшпіль', 'Лише слони й пішаки.'),
  ('pawnEndgame', 'Pawn endgame', 'Only pawns.',
   'Пішаковий ендшпіль', 'Лише пішаки.'),
  ('knightEndgame', 'Knight endgame', 'Only knights and pawns.',
   'Коневий ендшпіль', 'Лише коні й пішаки.'),
  ('queenEndgame', 'Queen endgame', 'Only queens and pawns.',
   'Ферзевий ендшпіль', 'Лише ферзі й пішаки.'),
  ('queenRookEndgame', 'Queen and rook', 'Only queens, rooks and pawns.',
   'Ферзь і тура', 'Лише ферзі, тури й пішаки.'),

  ('advancedPawn', 'Advanced pawn', 'A pawn close to promotion decides.',
   'Просунутий пішак', 'Усе вирішує пішак, близький до перетворення.'),
  ('attackingF2F7', 'Attacking f2 or f7', 'Strike at the weakest square near the king.',
   'Атака на f2 чи f7', 'Удар по найслабшому полю біля короля.'),
  ('capturingDefender', 'Capture the defender', 'Take the piece that guards another.',
   'Знищення захисту', 'Заберіть фігуру, яка захищає іншу.'),
  ('discoveredAttack', 'Discovered attack', 'Move one piece to unmask an attack by another.',
   'Відкритий напад', 'Хід однією фігурою відкриває напад іншої.'),
  ('doubleCheck', 'Double check', 'Check with two pieces at once.',
   'Подвійний шах', 'Шах двома фігурами одночасно.'),
  ('exposedKing', 'Exposed king', 'Attack a king with few defenders.',
   'Відкритий король', 'Атака на короля, якого майже ніхто не захищає.'),
  ('fork', 'Fork', 'One piece attacks two at once.',
   'Вилка', 'Одна фігура нападає на дві одразу.'),
  ('hangingPiece', 'Hanging piece', 'Win a piece left without defence.',
   'Висяча фігура', 'Заберіть фігуру, яку лишили без захисту.'),
  ('kingsideAttack', 'Kingside attack', 'Attack the king after short castling.',
   'Атака на королівському фланзі', 'Атака на короля після короткої рокіровки.'),
  ('pin', 'Pin', 'A piece cannot move without exposing a more valuable one behind it.',
   'Звʼязка', 'Фігура не може піти, не відкривши ціннішу за собою.'),
  ('queensideAttack', 'Queenside attack', 'Attack the king after long castling.',
   'Атака на ферзевому фланзі', 'Атака на короля після довгої рокіровки.'),
  ('sacrifice', 'Sacrifice', 'Give up material for a bigger gain.',
   'Жертва', 'Віддайте матеріал заради більшого.'),
  ('skewer', 'Skewer', 'Attack a valuable piece; when it moves, the one behind it falls.',
   'Лінійний удар', 'Напад на цінну фігуру: коли вона відходить, гине та, що за нею.'),
  ('trappedPiece', 'Trapped piece', 'A piece with nowhere to go.',
   'Спіймана фігура', 'Фігура, якій нікуди відступити.'),

  ('attraction', 'Attraction', 'Lure a piece to a square where it gets hit.',
   'Заманювання', 'Заманіть фігуру на поле, де її чекає удар.'),
  ('clearance', 'Clearance', 'Clear a square, file or diagonal for another piece.',
   'Звільнення лінії', 'Звільніть поле, вертикаль чи діагональ для іншої фігури.'),
  ('collinearMove', 'Collinear move', 'Two pieces face each other on a line; one slides along it without taking.',
   'Хід по лінії', 'Дві фігури стоять на одній лінії, одна рухається вздовж неї, не беручи іншу.'),
  ('discoveredCheck', 'Discovered check', 'Move a piece to uncover a check by another.',
   'Відкритий шах', 'Хід фігурою відкриває шах іншої.'),
  ('defensiveMove', 'Defensive move', 'The one move that avoids a loss.',
   'Захисний хід', 'Єдиний хід, що рятує від втрат.'),
  ('deflection', 'Deflection', 'Draw a piece away from a duty, such as guarding a square.',
   'Відволікання', 'Відведіть фігуру від важливого обовʼязку, наприклад захисту поля.'),
  ('interference', 'Interference', 'Put a piece between two enemy pieces so one loses its guard.',
   'Перекриття', 'Поставте фігуру між двома фігурами суперника, щоб одна лишилась без захисту.'),
  ('intermezzo', 'Intermezzo', 'An unexpected move before the obvious one.',
   'Проміжний хід', 'Несподіваний хід перед очевидним.'),
  ('quietMove', 'Quiet move', 'No check or capture, yet it sets up an unstoppable threat.',
   'Тихий хід', 'Без шаху чи взяття, але готує загрозу, від якої не захиститись.'),
  ('xRayAttack', 'X-ray attack', 'A piece attacks or defends through an enemy piece.',
   'Рентген', 'Фігура нападає чи захищає крізь фігуру суперника.'),
  ('zugzwang', 'Zugzwang', 'The opponent must move, and every move makes it worse.',
   'Цугцванг', 'Суперник мусить ходити, і кожен хід погіршує його становище.'),

  ('mate', 'Checkmate', 'Finish the game with mate.',
   'Мат', 'Завершіть партію матом.'),
  ('mateIn1', 'Mate in 1', 'Deliver mate in one move.',
   'Мат в 1 хід', 'Поставте мат одним ходом.'),
  ('mateIn2', 'Mate in 2', 'Deliver mate in two moves.',
   'Мат у 2 ходи', 'Поставте мат за два ходи.'),
  ('mateIn3', 'Mate in 3', 'Deliver mate in three moves.',
   'Мат у 3 ходи', 'Поставте мат за три ходи.'),
  ('mateIn4', 'Mate in 4', 'Deliver mate in four moves.',
   'Мат у 4 ходи', 'Поставте мат за чотири ходи.'),
  ('mateIn5', 'Mate in 5 or more', 'A long road to mate.',
   'Мат у 5 ходів і більше', 'Довгий шлях до мату.'),

  ('anastasiaMate', 'Anastasia\'s mate', 'Knight and rook or queen trap the king between the edge and its own piece.',
   'Мат Анастасії', 'Кінь і тура чи ферзь ловлять короля між краєм дошки і його ж фігурою.'),
  ('arabianMate', 'Arabian mate', 'Knight and rook mate the king in the corner.',
   'Арабський мат', 'Кінь і тура матують короля в куті.'),
  ('backRankMate', 'Back rank mate', 'Mate on the home rank, the king hemmed in by its own pawns.',
   'Мат по останній горизонталі', 'Короля на крайній горизонталі затисли власні пішаки.'),
  ('balestraMate', 'Balestra mate', 'A bishop mates while the queen covers the escape squares.',
   'Мат Балестри', 'Слон ставить мат, а ферзь забирає поля відступу.'),
  ('blindSwineMate', 'Blind swine mate', 'Two rooks on the seventh rank mate the king.',
   'Мат «сліпих свиней»', 'Дві тури на сьомій горизонталі матують короля.'),
  ('bodenMate', 'Boden\'s mate', 'Two bishops on crossing diagonals mate a king boxed in by its own pieces.',
   'Мат Бодена', 'Два слони на перехресних діагоналях матують короля, затисненого своїми фігурами.'),
  ('cornerMate', 'Corner mate', 'A rook or queen holds the king in the corner, a knight mates.',
   'Кутовий мат', 'Тура чи ферзь тримають короля в куті, кінь ставить мат.'),
  ('doubleBishopMate', 'Double bishop mate', 'Two bishops on neighbouring diagonals mate.',
   'Мат двома слонами', 'Два слони на сусідніх діагоналях ставлять мат.'),
  ('dovetailMate', 'Dovetail mate', 'The queen mates next to the king; its own pieces block both escapes.',
   'Мат «голубиний хвіст»', 'Ферзь матує впритул, обидва поля відступу зайняті власними фігурами короля.'),
  ('epauletteMate', 'Epaulette mate', 'Pieces on both sides of the king take away its escape.',
   'Еполетний мат', 'Фігури з обох боків від короля забирають у нього поля відступу.'),
  ('hookMate', 'Hook mate', 'Rook, knight and pawn mate together.',
   'Мат гаком', 'Мат турою, конем і пішаком разом.'),
  ('killBoxMate', 'Kill box mate', 'A rook next to the king, backed by the queen, traps it in a box.',
   'Мат «коробка»', 'Тура поруч із королем під захистом ферзя замикає його в коробці.'),
  ('pillsburysMate', 'Pillsbury\'s mate', 'A rook mates, a bishop helps hem the king in.',
   'Мат Пілсбері', 'Тура ставить мат, слон допомагає затиснути короля.'),
  ('morphysMate', 'Morphy\'s mate', 'A bishop mates, a rook helps hem the king in.',
   'Мат Морфі', 'Слон ставить мат, тура допомагає затиснути короля.'),
  ('operaMate', 'Opera mate', 'A rook mates on the back rank, guarded by a bishop.',
   'Оперний мат', 'Тура ставить мат на крайній горизонталі під захистом слона.'),
  ('swallowstailMate', 'Swallow\'s tail mate', 'The queen mates face to face; the squares behind the king are blocked.',
   'Мат «ластівчин хвіст»', 'Ферзь матує впритул, поля позаду короля зайняті.'),
  ('triangleMate', 'Triangle mate', 'Queen and rook, one square from the king, form a triangle.',
   'Трикутний мат', 'Ферзь і тура через поле від короля утворюють трикутник.'),
  ('vukovicMate', 'Vuković mate', 'A rook mates with support, a knight covers the escapes.',
   'Мат Вуковича', 'Тура ставить мат під захистом, кінь забирає поля відступу.'),
  ('smotheredMate', 'Smothered mate', 'A knight mates a king surrounded by its own pieces.',
   'Спертий мат', 'Кінь матує короля, оточеного власними фігурами.'),

  ('castling', 'Castling', 'Bring the king to safety and the rook into play.',
   'Рокіровка', 'Сховайте короля й введіть туру в гру.'),
  ('enPassant', 'En passant', 'Take a pawn that has just moved two squares.',
   'Взяття на проході', 'Візьміть пішака, який щойно пішов на два поля.'),
  ('promotion', 'Promotion', 'Turn a pawn into a queen or another piece.',
   'Перетворення', 'Перетворіть пішака на ферзя чи іншу фігуру.'),
  ('underPromotion', 'Underpromotion', 'Promote to a knight, bishop or rook.',
   'Перетворення на слабшу фігуру', 'Перетворіть пішака на коня, слона чи туру.'),

  ('equality', 'Equality', 'Come back from a worse position to an equal one.',
   'Урівняння', 'Врятуйтесь із гіршої позиції: нічия або рівна гра.'),
  ('advantage', 'Advantage', 'Get a clear advantage.',
   'Перевага', 'Здобудьте помітну перевагу.'),
  ('crushing', 'Crushing', 'Find the move that wins.',
   'Розгром', 'Знайдіть хід, що дає вирішальну перевагу.'),

  ('oneMove', 'One move', 'Puzzles one move long.',
   'Один хід', 'Задачі на один хід.'),
  ('short', 'Short', 'Two moves to win.',
   'Короткі', 'Два ходи до перемоги.'),
  ('long', 'Long', 'Three moves to win.',
   'Довгі', 'Три ходи до перемоги.'),
  ('veryLong', 'Very long', 'Four moves or more.',
   'Дуже довгі', 'Чотири ходи й більше.'),

  ('master', 'Master games', 'From games of titled players.',
   'Партії майстрів', 'З партій титулованих гравців.'),
  ('masterVsMaster', 'Master vs master', 'From games between two titled players.',
   'Майстер проти майстра', 'З партій, де обидва гравці мають звання.'),
  ('superGM', 'Super GM games', 'From games of the world\'s best players.',
   'Партії супергросмейстерів', 'З партій найсильніших гравців світу.'),
]

for key, en, en_desc, uk, uk_desc in THEMES:
    k = 'pt' + key[0].upper() + key[1:]
    s(k, en, uk)
    # Subtitles of list rows end without a full stop, as elsewhere.
    s(k + 'Desc', en_desc.rstrip('.'), uk_desc.rstrip('.'))
