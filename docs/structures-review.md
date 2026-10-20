# Вичитка текстів пішакових структур (D-107)

Кожна структура: назва й текст українською та англійською. Що гаразд - познач ✅;
що виправити - напиши поруч. Схвалені отримують `"reviewed": true` у
`assets/structures/structures.json` і тоді видні в релізній збірці.

---

## Висячі пішаки / Hanging pawns

- [x] перевірено · `hanging_pawns` · пріоритет 85

Два пішаки c і d стоять поруч, без сусідів на вертикалях b і e, а вертикалі обабіч них відкриті. Поки вони стоять пліч-о-пліч, то контролюють центр і дають фігурам простір; сторона з висячими пішаками готує прорив одного з них уперед, щоб розкрити гру і атакувати. Суперник тисне на них фігурами з вертикалей c і d, змушує один із пішаків просунутися, а тоді блокує та атакує той, що відстав.

*Two pawns on the c- and d-files stand side by side with no neighbours on the b- and e-files and open files around them. As long as they stand abreast they control the centre and give the pieces room; the side with the hanging pawns prepares to push one of them to open the game and attack. The opponent presses them with pieces along the c- and d-files, forces one of them forward, then blockades and attacks the one left behind.*

---

## Ізольований ферзевий пішак / Isolated queen's pawn

- [x] перевірено · `isolated_queen_pawn` · пріоритет 80

Ферзевий пішак не має сусідів на вертикалях c і e, тож захищати його можуть лише фігури. Сторона з ізольованим пішаком має більше простору, напіввідкриті вертикалі c і e і сильні поля для коней обабіч поля перед пішаком; її план - активна гра фігурами, атака на королівському фланзі і в слушний момент прорив пішака вперед. Суперник ставить коня на поле перед пішаком, щоб заблокувати його, розмінює легкі фігури і веде гру до ендшпілю, де пішак стає просто слабкістю.

*The queen's pawn has no neighbours on the c- and e-files, so only pieces can defend it. The side with the isolated pawn has more space, half-open c- and e-files and strong knight squares beside the square in front of the pawn; its plan is active piece play, a kingside attack and, at the right moment, a break with the pawn. The opponent puts a knight on the square in front of the pawn to blockade it, trades minor pieces and steers towards an endgame, where the pawn is just a weakness.*

---

## Їжак / Hedgehog

- [x] перевірено · `hedgehog` · пріоритет 78

Пішаки a, b, d і e стоять на своїй третій горизонталі, пішака c немає, а суперник має пішаки c і e на своїй четвертій. Сторона з «їжаком» має менше простору, але її позиція міцна: фігури стоять тісно, слон на довгій діагоналі, і кожен підрив - пішаком b або d - може раптом відкрити гру. Суперник, маючи простір, обережно розставляє фігури і не дає підривам відбутися, бо інакше «голки» вистрілюють.

*The a-, b-, d- and e-pawns stand on their own third rank, there is no c-pawn, and the opponent has c- and e-pawns on its own fourth rank. The hedgehog side has less space, but its position is solid: the pieces stand close together, a bishop on the long diagonal, and either break - with the b- or the d-pawn - can suddenly open the game. The opponent, with more space, arranges the pieces carefully and keeps those breaks from happening, otherwise the spines come out.*

---

## Скріпа Мароці / Maróczy Bind

- [x] перевірено · `maroczy_bind` · пріоритет 75

Пішаки c і e на своїй четвертій горизонталі тримають поле d перед собою, а пішака d немає; у суперника немає пішака c, а пішак d стоїть позаду. Сторона зі скріпою має простір, стримує підрив пішаком d, грає на всій дошці і поволі тисне. Суперник шукає контргри підривами пішаками b і f, розмінює фігури, щоб стало просторіше, і використовує поле d у таборі суперника для свого коня.

*The c- and e-pawns on their own fourth rank hold the d-file square in front of them and there is no d-pawn; the opponent has no c-pawn and its d-pawn stands back. The side with the bind has space, keeps the d-pawn break in check, plays across the board and squeezes slowly. The opponent looks for counterplay with b- and f-pawn breaks, trades pieces to get more room and uses the d-file square in the other camp for a knight.*

---

## Стоунвол / Stonewall

- [x] перевірено · `stonewall` · пріоритет 72

Пішаки c, d, e і f утворюють «камʼяну стіну»: d і f на своїй четвертій горизонталі, c і e на третій. Центр закритий, а сильним опорним пунктом для коня стає поле e у таборі суперника; сторона зі стоунволом зазвичай атакує на королівському фланзі. Її слабкості - поле перед власним пішаком e і поганий слон того ж кольору, що й пішаки; суперник розмінює свого слона проти доброго слона стоунволу і займає це поле конем.

*The c-, d-, e- and f-pawns form a stone wall: d and f on their own fourth rank, c and e on the third. The centre is closed and the e-file square in the opponent's camp becomes a strong outpost for a knight; the stonewall side usually attacks on the kingside. Its weaknesses are the square in front of its own e-pawn and a bad bishop of the pawns' colour; the opponent trades its bishop for the stonewall's good one and puts a knight on that square.*

---

## Карлсбадська структура / Carlsbad structure

- [x] перевірено · `carlsbad` · пріоритет 70

Після розміну на вертикалі d в однієї сторони пішаки d і e, а пішака c немає; у суперника пішаки c і d, а пішака e немає. Перша сторона часто проводить «атаку меншості»: пішаки a і b ідуть уперед, щоб розмінятися на пішак c суперника і залишити йому слабкий пішак. Суперник шукає ініціативи на королівському фланзі, ставить коня на поле e у таборі першої сторони і користується напіввідкритою вертикаллю e.

*After the exchange on the d-file one side has d- and e-pawns and no c-pawn; the opponent has c- and d-pawns and no e-pawn. The first side often plays the minority attack: the a- and b-pawns go forward to trade on the opponent's c-pawn and leave it a weak pawn. The opponent looks for kingside play, puts a knight on the e-file square in the first side's camp and uses the half-open e-file.*

---

## Структура Бенуні / Benoni structure

- [x] перевірено · `benoni` · пріоритет 68

Далеко просунутий пішак d врізається в табір суперника, у якого пішаки c і d, а пішака e немає. Сторона з пішаком d має перевагу в центрі і просторі та готує прорив пішаком e, щоб розірвати оборону. Суперник має більшість на ферзевому фланзі, грає там підривом пішака b і використовує напіввідкриту вертикаль e та довгу діагональ для слона.

*An advanced d-pawn cuts into the opponent's camp; the opponent has c- and d-pawns and no e-pawn. The side with the d-pawn has more centre and space and prepares an e-pawn break to tear the defence open. The opponent has a queenside majority, plays there with the b-pawn break and uses the half-open e-file and the long diagonal for a bishop.*

---

## Ланцюг Староіндійського захисту / King's Indian pawn chain

- [x] перевірено · `kings_indian_chain` · пріоритет 66

Пішаки d і e однієї сторони просунуті до половини суперника й упираються в його пішаки d і e: центр замкнений, а ланцюги дивляться один на одного. Гра йде на флангах, і правило просте - атакуй у той бік, куди дивиться твій ланцюг. Сторона з просунутими пішаками атакує на ферзевому фланзі підривом пішака c; суперник іде пішаком f і пішаками королівського флангу на короля.

*One side's d- and e-pawns have advanced into the opponent's half and block its d- and e-pawns: the centre is locked and the chains point at each other. The play is on the wings, and the rule is simple - attack where your chain points. The side with the advanced pawns attacks on the queenside with the c-pawn break; the opponent goes for the king with the f-pawn and the kingside pawns.*

---

## Ланцюг Французького захисту / French pawn chain

- [x] перевірено · `french_chain` · пріоритет 65

Пішак e однієї сторони вже на половині суперника, пішак d підтримує його ззаду, а пішаки суперника d і e стоять навпроти: центр замкнений ланцюгом. Сторона з просунутим пішаком e має простір на королівському фланзі і грає там, підтримуючи ланцюг. Суперник атакує основу ланцюга - пішак d - підривом пішака c, а згодом і верхівку підривом пішака f.

*One side's e-pawn is already in the opponent's half, its d-pawn supports it from behind, and the opponent's d- and e-pawns stand opposite: the centre is locked by a chain. The side with the advanced e-pawn has kingside space and plays there, supporting the chain. The opponent attacks the base of the chain - the d-pawn - with the c-pawn break, and later the head with the f-pawn break.*

---

## Структура Болеславського / Boleslavsky structure

- [x] перевірено · `boleslavsky` · пріоритет 61

Пішак d однієї сторони стоїть позаду пішака e, пішака c немає, а в суперника є пішак e і немає пішака d. Поле перед пішаком d - дірка, за яку йде вся боротьба: суперник ставить туди коня і тисне на відсталий пішак d. Сторона з цією структурою контролює центр, активно розвиває фігури і чекає слушного моменту для підриву пішаком d - тоді слабкість зникає.

*One side's d-pawn stands behind its e-pawn with no c-pawn, and the opponent has an e-pawn and no d-pawn. The square in front of the d-pawn is a hole and the whole fight is about it: the opponent puts a knight there and presses the backward d-pawn. The side with this structure controls the centre, develops actively and waits for the right moment to break with the d-pawn - then the weakness disappears.*

---

## Малий центр Шевенінгена / Scheveningen small centre

- [x] перевірено · `scheveningen` · пріоритет 60

Пішаки d і e однієї сторони стоять поруч на своїй третій горизонталі без пішака c, а суперник має пішак e і не має пішака d. Цей скромний центр міцний і гнучкий: він стримує фігури суперника і готує підриви пішаком d або e. Сторона з малим центром грає на ферзевому фланзі і по напіввідкритій вертикалі c; суперник має простір і часто атакує пішаками королівського флангу.

*One side's d- and e-pawns stand side by side on their own third rank with no c-pawn, and the opponent has an e-pawn and no d-pawn. This modest centre is solid and flexible: it holds the opponent's pieces back and prepares breaks with the d- or e-pawn. The side with the small centre plays on the queenside and along the half-open c-file; the opponent has space and often attacks with the kingside pawns.*

---

## Структура Каро-Канн / Caro-Kann structure

- [x] перевірено · `caro_slav` · пріоритет 58

Пішаки c і e однієї сторони стоять на своїй третій горизонталі, а пішака d немає; у суперника пішак d і немає пішака e. Позиція міцна і без слабкостей: сторона з цією структурою спокійно розвивається і готує підрив пішаком c або e, щоб вирівняти гру в центрі. Суперник має трохи більше простору і грає на королівському фланзі або ставить коня на поле e у таборі першої сторони.

*One side's c- and e-pawns stand on their own third rank with no d-pawn; the opponent has a d-pawn and no e-pawn. The position is solid and has no weaknesses: the side with this structure develops calmly and prepares a break with the c- or e-pawn to level the centre. The opponent has a little more space and plays on the kingside or puts a knight on the e-file square in the first side's camp.*

---

## Здвоєні пішаки c / Doubled c-pawns

- [x] перевірено · `doubled_c_pawns` · пріоритет 55

Два пішаки однієї сторони стоять на вертикалі c, як після розміну слона на коня в захисті Німцовича. Здвоєні пішаки малорухливі, і передній стає мішенню; натомість власник має пару слонів і сильний центр. Його план - відкрити гру для слонів і атакувати, поки здвоєні пішаки не стали слабкістю; суперник закриває позицію, блокує пішаки і тисне на передній.

*Two pawns of one side stand on the c-file, as after bishop takes knight in the Nimzo-Indian. Doubled pawns are not mobile and the front one becomes a target; in return their owner has the bishop pair and a strong centre. The plan is to open the game for the bishops and attack before the doubled pawns become a weakness; the opponent keeps the position closed, blockades the pawns and presses the front one.*

