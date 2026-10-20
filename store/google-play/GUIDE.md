# Repertorium chess у Google Play: покрокова інструкція

Усе, що можна було підготувати на компʼютері, вже готово. Нижче — що натискати в Play Console і що відповідати на кожну анкету.

## Що вже зроблено

| | |
|---|---|
| Підписаний App Bundle | `Repertorium-chess-1.1.0-1.aab` (106 МБ; на телефон завантажується лише потрібна архітектура, ≈ 35–40 МБ) |
| Пакет | `app.repertorium`, версія 1.1.0, versionCode 1 |
| SDK | minSdk 24 (Android 7.0), targetSdk 36 (Android 16) — відповідає вимогам Google на 2026 рік |
| Сторінки памʼяті 16 КБ | усі нативні бібліотеки (Flutter, Stockfish, SQLite) вирівняні — вимога Google для нових застосунків виконана |
| Дозволи | INTERNET, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, VIBRATE. Без точних будильників, рекламного ID, геолокації, доступу до файлів — окремих декларацій не треба |
| Перевірка | релізна збірка запущена на емуляторі Android 16 (Pixel 10 Pro): вітання, стартовий репертуар, тренування, аналіз зі Stockfish 19 працюють, падінь немає |
| Тексти й графіка | `LISTING.md`, `icon-512.png`, `feature-graphic-*.png`, `phone/`, `tablet/` |

## Ключ підпису — збережіть його

Ключ завантаження (upload key) лежить поза репозиторієм:

- `~/keys/repertorium-upload.jks` — сам ключ
- `~/keys/repertorium-upload.properties` — пароль і alias (копія `android/key.properties`)

**Скопіюйте обидва файли в менеджер паролів або на зашифрований диск.** У git вони не потрапляють (`android/.gitignore`).

Google Play сам підписує застосунок для користувачів своїм ключем (Play App Signing), а цим ключем ви лише підтверджуєте, що збірку завантажили саме ви. Якщо його втратити, ключ завантаження можна скинути через підтримку Google, але це займає кілька днів.

Відбиток ключа завантаження (для звірки в Play Console → Test and release → App integrity):

```
SHA-256: 8F:06:C1:5F:FC:C6:64:C6:2E:20:93:FD:3B:A7:34:03:FA:18:51:C9:16:49:53:78:67:98:68:5E:82:60:E8:C1
```

---

## Крок 0. Акаунт розробника

1. https://play.google.com/console/signup — внесок 25 $ один раз.
2. Тип акаунта: **Personal** (особистий) або **Organization** (потрібен D-U-N-S номер).
3. Підтвердження особи документом і телефоном Android — Google вимагає це для всіх нових акаунтів, перевірка займає від кількох годин до кількох днів.

> **Важливо для особистих акаунтів.** Якщо акаунт особистий і створений після листопада 2023 року, Google не пустить застосунок одразу у відкритий доступ. Спершу потрібне **закрите тестування: щонайменше 12 тестувальників протягом 14 днів поспіль**. Лише після цього в розділі Dashboard зʼявиться кнопка **Apply for production access**. Збирайте 12–15 людей заздалегідь (знайомі шахісти, клуб, чат). Організаційних акаунтів це не стосується.

## Крок 1. Створити застосунок

Home → **Create app**:

| Поле | Значення |
|---|---|
| App name | `Repertorium chess` |
| Default language | **Українська – uk-UA** |
| App or game | **App** |
| Free or paid | **Free** |
| Declarations | позначити обидві галочки (Developer Program Policies, US export laws) |

Поля для назви пакета тут немає. Google бере її з першого завантаженого AAB: це **`app.repertorium`**. В App Store ідентифікатор інший (`app.tabiya`), бо в Google Play `app.tabiya` вже зайнятий іншим розробником. Після першого завантаження назву пакета **змінити вже не можна**.

## Крок 2. App content (Policy → App content)

Тут кілька анкет; кожну треба пройти до першого випуску.

### Privacy policy
```
https://github.com/viponomarenko/repertorium-chess/blob/main/docs/privacy.md
```

### App access
**All functionality in my app is available without any access restrictions.** (Вхід у Lichess необовʼязковий.)

### Ads
**No, my app does not contain ads.**

### Content rating
Start questionnaire:
- Email — ваша пошта
- Category: **All Other App Types** (або Reference, News, or Educational, якщо буде в списку)
- На всі питання (насильство, сексуальний зміст, лайка, наркотики, азартні ігри, спілкування між користувачами, передача геолокації, цифрові покупки) — **No**
- Очікуваний результат: **3+ / Everyone**

### Target audience and content
- Target age: **13–15, 16–17, 18 and over**. Молодших вікових груп не вибирайте: тоді застосунок підпадає під програму Families, а там свої вимоги й окрема перевірка.
- Appeal to children: **No**

### Data safety
Застосунок не має свого сервера. Але Google вважає «збором» будь-яку передачу з пристрою, зокрема в Lichess і Chess.com, коли користувач сам їх підключає. Найчесніша відповідь:

1. **Does your app collect or share any of the required user data types?** → **Yes**
2. **Is all of the user data collected by your app encrypted in transit?** → **Yes** (лише HTTPS)
3. **Which of the following methods of account creation does your app support?** → **My app does not allow users to create an account**
4. **Data deletion**: користувач видаляє все, видаливши застосунок; а токен Lichess — кнопкою «Відключити» в «Акаунтах»
5. Типи даних — позначити лише **Personal info → User IDs**:
   - Collected: **Yes**; Shared: **No** (дані йдуть у Lichess / Chess.com на прохання самого користувача — Google це не вважає «передачею третім особам»)
   - Processed ephemerally: **No**
   - Required or optional: **Users can choose whether this data is collected**
   - Purpose: **App functionality**

Більше нічого не позначайте: аналітики, реклами, звітів про збої, геолокації, контактів, файлів немає.

### Government apps / Financial features / Health / News
Усюди **No** / **My app doesn't provide any financial features** / **No health features**.

### Advertising ID
**No** (дозволу AD_ID у збірці немає).

## Крок 3. Сторінка в магазині (Grow users → Store presence → Main store listing)

1. Тексти українською — з `LISTING.md`.
2. Графіка: `icon-512.png`, `feature-graphic-uk.png`, скріншоти з `phone/` (усі 8 по черзі), за бажанням — `tablet/` у поле 10-inch tablet.
3. **Add translation → English (United States) – en-US**: англійські тексти з `LISTING.md` і `feature-graphic-en.png`. Скріншоти для en-US можна не завантажувати.

Store settings (Store presence → Store settings): Category **Education**, контактна пошта (публічна), сайт `https://github.com/viponomarenko/repertorium-chess`.

## Крок 4. Закрите тестування (обовʼязкове для нового особистого акаунта)

1. Test and release → Testing → **Closed testing** → Create track (або вибрати Alpha).
2. **Countries/regions**: Add countries → вибрати всі (або Україна + потрібні).
3. **Testers**: Create email list → додати пошти 12+ тестувальників (Google-акаунти, з якими вони заходять у Play на телефоні). Feedback URL/email — ваша пошта або посилання на Issues.
4. **Create new release**:
   - Play App Signing → **Use Google-generated key** (за замовчуванням, нічого не міняти)
   - Upload `Repertorium-chess-1.1.0-1.aab`
   - Release name: `1.1.0 (1)`
   - Release notes — блок з `LISTING.md`
   - Next → Save → **Send for review** (Publishing overview)
5. Перша перевірка Google — зазвичай від кількох годин до 7 днів.
6. Після схвалення скопіюйте **посилання для тестувальників** (Testers → Copy link) і розішліть. Кожен має відкрити його, натиснути **Become a tester** і встановити застосунок із Play.
7. Тестувальники мають лишатися в програмі **14 днів поспіль**. Попросіть їх не виходити й хоч раз-два відкрити застосунок — Google дивиться на активність.

## Крок 5. Вихід у відкритий доступ

1. Через 14 днів: Dashboard → **Apply for production access** → коротка анкета (як шукали тестувальників, що вони казали, що виправили). Відповідайте конкретно, своїми словами.
2. Після схвалення (зазвичай до 7 днів): Test and release → **Production** → Create new release → **Add from library** (той самий AAB) або новий AAB → Countries → **Send for review**.
3. За бажанням — **Managed publishing** (Publishing overview): тоді після схвалення застосунок вийде лише тоді, коли ви натиснете Publish.

---

## Наступні оновлення

Кожен AAB для Google Play має мати **більший versionCode**, ніж попередній. Це число після `+` у `pubspec.yaml` (`version: 1.1.0+1`). Його можна підняти лише для Android, не чіпаючи iOS:

```bash
~/development/flutter-3.47.5/bin/flutter build appbundle --release --build-number=2
```

Файл буде в `build/app/outputs/bundle/release/app-release.aab`. Ключ підхоплюється автоматично з `android/key.properties`. Якщо цього файлу немає (наприклад, у CI), релізна збірка підпишеться debug-ключем, і Google Play її не прийме.

## Що не перевірено

- Вхід у Lichess (OAuth) на Android: на емуляторі не проходив, бо потрібен реальний акаунт. Варто попросити когось із тестувальників.
- Нагадування (сповіщення) на Android 13+ — перевірте на тестовому телефоні: застосунок має попросити дозвіл, коли ви вмикаєте нагадування.
- Скріншоти зроблено на iPhone (без системного рядка iOS). Інтерфейс на Android такий самий, тож для запуску годиться; згодом можна замінити знімками з Android.
