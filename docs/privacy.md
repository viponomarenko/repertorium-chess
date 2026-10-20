# Політика приватності Repertorium chess / Repertorium chess Privacy Policy

_Чинна з 20.10.2026 / Effective 20 October 2026_

## Українською

**Коротко:** Repertorium chess не має серверів, акаунтів, аналітики та реклами. Усі ваші дані зберігаються лише на вашому пристрої.

1. **Які дані зберігаються.** Колекції партій, репертуари, прогрес тренувань, налаштування, завантажені вами партії з Lichess/Chess.com. Усе — в локальній базі даних на пристрої.
2. **Передача даних.** Застосунок звертається до мережі лише за вашою явною дією:
   - **Lichess** (lichess.org, explorer.lichess.org): вхід через OAuth, завантаження ваших студій і партій, дебютна база, хмарна оцінка, експорт репертуару в студію, головоломки. На Lichess передаються лише запити, необхідні для цих дій, і ваш токен доступу.
   - **Головоломки**: задачі завантажуються з Lichess. Без підключеного акаунта – без токена, у запиті лише тема й складність, а рейтинг і результати зберігаються тільки на пристрої. Якщо акаунт Lichess підключено, задачі запитуються з вашим токеном, а результати розвʼязання (номер задачі, розвʼязано чи ні) надсилаються на Lichess і зараховуються у ваш рейтинг там; розвʼязане без інтернету надсилається пізніше. Без інтернету задачі беруться з набору, вбудованого в застосунок.
   - **Chess.com** (api.chess.com): публічні дані за вашим нікнеймом (профіль, архіви партій). Пароль не запитується.
   - **Завантаження за посиланням**: запит лише за адресою, яку ви вказали.
3. **Токен Lichess** зберігається в захищеному сховищі системи (Keychain / Keystore), не потрапляє в журнали, резервні копії чи звіти. Під час відключення акаунта токен відкликається на Lichess і видаляється з пристрою.
4. **Резервні копії** створюються лише за вашою командою у файл, яким ви розпоряджаєтеся самі. Токени до них не входять.
5. **Сповіщення** — лише локальні, вимкнені за замовчуванням.
6. **Діти.** Застосунок не збирає персональних даних і придатний для будь-якого віку.
7. **Видалення даних.** Видаліть застосунок або окремі колекції/репертуари в ньому; для Lichess — відключіть акаунт у «Акаунтах».
8. **Контакти:** розділ Issues репозиторію – https://github.com/viponomarenko/repertorium-chess/issues.

## English

**In short:** Repertorium chess has no servers, accounts, analytics or ads. All your data stays on your device.

1. **Stored data.** Game collections, repertoires, training progress, settings and games you downloaded from Lichess/Chess.com — in a local database on the device.
2. **Network access** happens only on your explicit action:
   - **Lichess** (lichess.org, explorer.lichess.org): OAuth login, your studies and games, the opening explorer, cloud evaluation, exporting a repertoire to a study, puzzles.
   - **Puzzles** are loaded from Lichess. Without a connected account no token is sent, a request carries only the theme and the difficulty, and your rating and results stay on the device. With a connected Lichess account, puzzles are requested with your token and the results (puzzle id, solved or not) are sent to Lichess and count into your rating there; puzzles solved offline are sent later. Offline, puzzles come from a set built into the app.
   - **Chess.com** (api.chess.com): public data for the username you enter. No password is requested.
   - **Download by link**: only the address you provided.
3. **The Lichess token** is kept in the system secure storage (Keychain / Keystore) and never written to logs, backups or reports. Disconnecting revokes it on Lichess and deletes it locally.
4. **Backups** are created only on your request, as a file you control. Tokens are never included.
5. **Notifications** are local only and off by default.
6. **Children.** No personal data is collected.
7. **Deleting data.** Delete the app or individual collections/repertoires; disconnect Lichess under “Accounts”.
8. **Contact:** the repository's issue tracker – https://github.com/viponomarenko/repertorium-chess/issues.
