# NHNK

**Nem Hivatalos Neptun Kliens** / **Unofficial Neptun Client** — an alternative Neptun
mobile app built on the modern Neptun REST API.

[![Downloads](https://img.shields.io/github/downloads/Bali0531-RC/NHNK/total?style=for-the-badge&color=blue)](https://github.com/Bali0531-RC/NHNK/releases)
[![Latest release](https://img.shields.io/github/v/release/Bali0531-RC/NHNK?style=for-the-badge&color=green)](https://github.com/Bali0531-RC/NHNK/releases/latest)

Website / Weboldal: **https://nhnk.bali0531.hu**

<details open>
<summary><b>English</b></summary>

> [!IMPORTANT]
> **This is an independent, unofficial application.** It is not affiliated with, endorsed
> or approved by Campus Codeworks Zrt. (formerly SDA Informatika Zrt., the developer of
> the Neptun system), nor by any higher education institution. The "Neptun" name and
> trademark belong to their respective owner and are used here for descriptive purposes
> only. Login credentials go directly to your institution's Neptun server; NHNK does not
> operate a server of its own and does not collect user data. The information shown in
> the Neptun web interface is always the authoritative source.

## Download

Latest release: **https://github.com/Bali0531-RC/NHNK/releases/latest**

### Google Play

The app is currently in **closed testing**, so only testers can see it on the Play
Store. You can sign up here: **https://nhnk.bali0531.hu/zart-teszt/**

The Play build has no built-in updater (Play policy forbids it); updates are handled by
the store.

### Android (sideload)

Most phones need the `arm64-v8a` APK. For automatic updates we recommend
[Obtainium](https://github.com/ImranR98/Obtainium): point it at this repository and
future releases will install themselves.

### iPhone

Releases also contain an `unsigned.ipa`, but it is **not signed**: signing would require
a paid Apple Developer account, so you have to sign it yourself with your own Apple ID,
for example using [AltStore](https://altstore.io/), [SideStore](https://sidestore.io/)
or [Sideloadly](https://sideloadly.io/). iOS 14 or newer is required.

With a free Apple ID the app expires every 7 days and has to be re-signed — this is an
Apple limitation. If that is not for you, the timetable can also be added to Apple
Calendar as a subscription from Neptun's calendar export.

## Reporting bugs

**https://github.com/Bali0531-RC/NHNK/issues/new/choose**

It helps if you include your phone model, the Android version and the app version.

## Features

**Timetable**
- Weekly view, browse to any week; one tap next to the week name jumps back to the current week
- If the Neptun API returns an empty timetable, it is loaded from the calendar export instead
- Home screen widget with today's classes (Android)
- Export the timetable to an `.ics` file that your phone's calendar can import

**Notifications**
- Before classes, exams, payments and periods
- For new grades and new messages, even after the app is closed, with a configurable interval (15 minutes – 12 hours, or off)
- Mark a message as read straight from the notification
- If the system or the manufacturer restricts background execution, the settings screen takes you to the relevant system setting in one tap

**Grades and finances**
- Grades, averages, credits, messages, payments, periods
- Ghost grades: what a not-yet-earned grade would do to your average
- Average calculator: the average you need across your remaining credits to reach your target
- Search messages by subject or sender

**Other**
- Offline mode: the most recently downloaded data is kept, a bar shows when it was refreshed
- Automatic failover at institutions with several servers, if the primary one does not respond
- Two-factor authentication, with an optionally stored secret for automatic re-login
- Customizable themes and languages

## Versions

Detailed release notes for every version:
**https://github.com/Bali0531-RC/NHNK/releases**

### 1.2

Home screen widget with today's classes. Offline mode now keeps the most recently
downloaded data: previously losing the network cleared the lists, because the app
compared the return value of `connectivity_plus` incorrectly and never knew it was
offline. Average calculator, message search, and a notice about the unofficial status
shown before login. Tapping next to the 2FA dialog no longer aborts the login.

### 1.1

Notifications for new grades and new messages, in the background as well, with a
configurable interval. Timetable export to an `.ics` file. Automatic failover at
institutions with several servers, if the primary server does not respond. The "back to
the current week" button moved into the week switcher bar, because as a floating button
it covered the bottom navigation bar.

### 1.0

Session handling fixes: token refresh never actually worked, so an expiring session
cleared the data. The timetable can also be loaded from Neptun's calendar export, so it
is visible even without a session. The 2FA secret can be stored for automatic re-login.
Own signing key, so updates can be installed over an earlier version. The Play build no
longer requests the permissions that were pulled in by dependencies and that the app
does not use.

## Origin

This project is a fork of [Neptun 2](https://github.com/domedav/Neptun-2) (domedav), by
way of the [Neptun Mobile](https://github.com/zoligamer/Neptun-Mobile-fork) (zoligamer)
fork. MIT licensed, keeping the earlier copyright notices.

## Development

There are two build flavors, because Google Play forbids self-updating applications:

| Flavor | Distribution | Built-in updater | `REQUEST_INSTALL_PACKAGES` |
| --- | --- | --- | --- |
| `github` | sideload / Obtainium | yes | yes |
| `playstore` | Google Play | no | no |

```sh
flutter pub get

# Sideload release (GitHub Releases)
flutter build apk --release --split-per-abi \
  --flavor github --dart-define=NHNK_DISTRIBUTION=github

# Google Play release
flutter build appbundle --release \
  --flavor playstore --dart-define=NHNK_DISTRIBUTION=playstore
```

`--dart-define` and `--flavor` must always go together: the flavor decides the manifest
permission, while the dart-define switches off the updater on the Dart side.

A release needs a signing key: copy `android/key.properties.example` to
`android/key.properties` and fill it in. Without it the release build uses the debug
key, which cannot be installed as an update over an earlier version.

### Institutions

The institution list is stored in `universityNameUrlPairs.json`, and installed apps
download it **at runtime** from the `main` branch. It may therefore only be extended:
renaming or removing the `Name` and `Url` fields would break the versions that are
already out there.

If an institution runs several equivalent Neptun servers, they can be listed in a
`Fallbacks` array. If the active server does not respond, the app switches to the next
one and logs in again with the stored credentials — sessions are per-server.

```jsonc
{
   "Name": "Pannon Egyetem",
   "Url": "https://neptun-ws01.uni-pannon.hu/hallgato",
   "Fallbacks": ["https://neptun-ws03.uni-pannon.hu/hallgato"]
}
```

Before adding a new server it is worth checking that the mobile API really is the one
answering, and not the web interface: a GET request to `/api/Account/Authenticate` must
respond with `405` and JSON.

### Tests

```sh
flutter test
```

## License

MIT — see the [LICENSE](LICENSE) file.

</details>

<details>
<summary><b>Magyar</b></summary>

> [!IMPORTANT]
> **Ez egy független, nem hivatalos alkalmazás.** Nem áll kapcsolatban a Campus Codeworks Zrt.-vel
> (korábban SDA Informatika Zrt., a Neptun rendszer fejlesztője), sem bármely felsőoktatási
> intézménnyel, és azok nem támogatják vagy hagyták jóvá. A „Neptun" név és védjegy a jogosultja
> tulajdona, itt kizárólag leíró jelleggel szerepel. A belépési adatok közvetlenül az intézmény
> Neptun-kiszolgálójára mennek; az NHNK nem üzemeltet saját szervert és nem gyűjt felhasználói
> adatokat. Hivatalos adatnak minden esetben a webes Neptun felületén látható információ számít.

## Letöltés

Legfrissebb kiadás: **https://github.com/Bali0531-RC/NHNK/releases/latest**

### Google Play

Az app jelenleg **zárt tesztelés** alatt áll, így a Play Áruházban csak a tesztelők
látják. Jelentkezni itt lehet: **https://nhnk.bali0531.hu/zart-teszt/**

A Play-es változatban nincs beépített frissítő (ezt a Play szabályzata tiltja), a
frissítéseket az áruház kezeli.

### Android (sideload)

A legtöbb telefonra az `arm64-v8a` APK kell. Automatikus frissítéshez ajánlott az
[Obtainium](https://github.com/ImranR98/Obtainium): add meg neki ezt a repót, és a
későbbi kiadások maguktól települnek.

### iPhone

A kiadásokban van `unsigned.ipa` is, de **aláírás nélkül**: az aláíráshoz fizetős Apple
Developer fiók kellene, ezért magadnak kell aláírnod a saját Apple ID-ddal, például
[AltStore](https://altstore.io/), [SideStore](https://sidestore.io/) vagy
[Sideloadly](https://sideloadly.io/) segítségével. iOS 14 vagy újabb kell hozzá.

Ingyenes Apple ID-val az app 7 naponta lejár és újra alá kell írni — ez az Apple
korlátozása. Aki ezt nem vállalja, annak az órarend a Neptun naptár-exportjából
feliratkozásként is hozzáadható az Apple Naptárhoz.

## Hibabejelentés

**https://github.com/Bali0531-RC/NHNK/issues/new/choose**

Hasznos, ha leírod a telefon típusát, az Android verziót és az app verzióját.

## Funkciók

**Órarend**
- Heti nézet, tetszőleges hétre lapozva; a hét neve mellől egy koppintással vissza a mai hétre
- Ha a Neptun API üresen hagyja az órarendet, a naptár-exportból tölti be
- Kezdőképernyő-widget a mai órákkal (Android)
- Órarend mentése `.ics` fájlba, amit a telefon naptára beolvas

**Értesítések**
- Órák, vizsgák, befizetések és időszakok előtt
- Új jegyről és új üzenetről, az app bezárása után is, állítható gyakorisággal (15 perc – 12 óra, vagy ki)
- Üzenet olvasottnak jelölése egyből az értesítésből
- Ha a rendszer vagy a gyártó korlátozza a háttérfutást, a beállításokban egy koppintással eljutsz a megfelelő rendszerbeállításhoz

**Jegyek és pénzügyek**
- Jegyek, átlagok, kreditek, üzenetek, befizetések, időszakok
- Szellemjegyek: mit tenne az átlagoddal egy még meg nem szerzett jegy
- Átlagszámító: milyen átlag kell a hátralévő kreditekre a célodhoz
- Keresés az üzenetek között tárgy vagy feladó szerint

**Egyéb**
- Offline mód: a legutóbb letöltött adatok megmaradnak, egy sáv jelzi, mikor frissültek
- Több kiszolgálós intézményeknél automatikus átváltás, ha az elsődleges nem válaszol
- Kétlépcsős azonosítás, opcionálisan elmentett kulccsal automatikus újrabejelentkezés
- Testreszabható témák és nyelvek

## Verziók

Részletes kiadási jegyzet minden verzióhoz:
**https://github.com/Bali0531-RC/NHNK/releases**

### 1.2

Kezdőképernyő-widget a mai órákkal. Offline módban megmaradnak a legutóbb letöltött
adatok: korábban a hálózat elvesztése kiürítette a listákat, mert az app a
`connectivity_plus` visszatérési értékét rosszul hasonlította össze, és sosem tudta,
hogy offline van. Átlagszámító, keresés az üzenetek között, és a belépés előtt megjelenő
tájékoztató a nem hivatalos státuszról. A 2FA ablak mellé koppintás többé nem szakítja
félbe a bejelentkezést.

### 1.1

Értesítés új jegyről és új üzenetről, a háttérben is, állítható gyakorisággal. Órarend
exportálása `.ics` fájlba. Több kiszolgálós intézményeknél automatikus átváltás, ha az
elsődleges szerver nem válaszol. A „vissza a mai hétre" gomb átkerült a hétváltó sávba,
mert lebegő gombként rátakart az alsó menüsorra.

### 1.0

Munkamenet-kezelés javítása: a token-frissítés eddig sosem működött, ezért a lejáró
munkamenet kiürítette az adatokat. Az órarend a Neptun naptár-exportjából is betölthető,
így munkamenet nélkül is látszik. A 2FA titkos kulcs elmenthető az automatikus
újrabejelentkezéshez. Saját aláírókulcs, hogy a frissítések telepíthetők legyenek a
korábbi verzióra. A Play-es változatból kikerültek azok a jogosultságok, amelyeket
függőségek húztak be, és amelyeket az app nem használ.

## Származás

Ez a projekt a [Neptun 2](https://github.com/domedav/Neptun-2) (domedav) forkja, a
[Neptun Mobile](https://github.com/zoligamer/Neptun-Mobile-fork) (zoligamer) forkon
keresztül. MIT licenc, a korábbi szerzői jogi megjelölések megtartásával.

## Fejlesztés

Két build flavor van, mert a Google Play tiltja az önmagukat frissítő alkalmazásokat:

| Flavor | Terítés | Beépített frissítő | `REQUEST_INSTALL_PACKAGES` |
| --- | --- | --- | --- |
| `github` | sideload / Obtainium | igen | igen |
| `playstore` | Google Play | nem | nem |

```sh
flutter pub get

# Sideload kiadás (GitHub Releases)
flutter build apk --release --split-per-abi \
  --flavor github --dart-define=NHNK_DISTRIBUTION=github

# Google Play kiadás
flutter build appbundle --release \
  --flavor playstore --dart-define=NHNK_DISTRIBUTION=playstore
```

A `--dart-define` és a `--flavor` mindig együtt járjon: a flavor a manifest jogosultságát
dönti el, a dart-define pedig a Dart oldali frissítőt kapcsolja ki.

Kiadáshoz aláírókulcs kell: másold az `android/key.properties.example` fájlt
`android/key.properties` néven, és töltsd ki. Enélkül a release build a debug kulcsot
használja, ami nem telepíthető frissítésként a korábbi verzióra.

### Intézmények

Az intézménylistát a `universityNameUrlPairs.json` tartalmazza, és a telepített appok
**futásidőben** töltik le a `main` ágról. Ezért csak bővíteni szabad: a `Name` és `Url`
mezők átnevezése vagy törlése a már kint lévő verziókat is elrontaná.

Ha egy intézmény több egyenrangú Neptun-kiszolgálót üzemeltet, azok `Fallbacks` tömbként
vehetők fel. Ha az aktív kiszolgáló nem válaszol, az app átvált a következőre, és a
mentett belépési adatokkal újra bejelentkezik — a munkamenet ugyanis kiszolgálónként szól.

```jsonc
{
   "Name": "Pannon Egyetem",
   "Url": "https://neptun-ws01.uni-pannon.hu/hallgato",
   "Fallbacks": ["https://neptun-ws03.uni-pannon.hu/hallgato"]
}
```

Új kiszolgáló felvétele előtt érdemes ellenőrizni, hogy tényleg a mobil API válaszol-e
rajta, és nem a webes felület: a `/api/Account/Authenticate` címre küldött GET kérésre
`405`-tel és JSON-nal kell válaszolnia.

### Tesztek

```sh
flutter test
```

## Licenc

MIT — lásd a [LICENSE](LICENSE) fájlt.

</details>
