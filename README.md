# NHNK

**Nem Hivatalos Neptun Kliens** / Unofficial Neptun Client. A Flutter app for Hungarian university students who have to use Neptun and would rather not suffer.

[![Downloads](https://img.shields.io/github/downloads/Bali0531-RC/NHNK/total?style=for-the-badge&color=blue)](https://github.com/Bali0531-RC/NHNK/releases)
[![Latest release](https://img.shields.io/github/v/release/Bali0531-RC/NHNK?style=for-the-badge&color=green)](https://github.com/Bali0531-RC/NHNK/releases/latest)

Website: **https://nhnk.bali0531.hu**

> [!IMPORTANT]
> This is an independent, unofficial app. It has nothing to do with Campus Codeworks Zrt. (formerly SDA Informatika Zrt., who make Neptun) or with any university, and none of them have endorsed it. The "Neptun" name belongs to its owner and I only use it here to describe what the app talks to. Your login goes straight to your university's own Neptun server. I don't run a server and I don't collect anything. If the app and the Neptun website disagree, the website is right.
>
> Ez egy független, nem hivatalos alkalmazás. Semmilyen kapcsolatban nem áll a Campus Codeworks Zrt.-vel (korábban SDA Informatika Zrt.), sem egyetemekkel, és egyikük sem hagyta jóvá. A belépési adatok közvetlenül az intézmény Neptun-szerverére mennek, én nem üzemeltetek szervert és nem gyűjtök adatot. Ha az app és a webes Neptun mást mond, a web a mérvadó.

---

<details open>
<summary><b>English</b></summary>

## Why I forked this (and didn't start from scratch)

Yo, I'm just an 18-year-old starting uni soon, and I know I'll have to open Neptun every day. The official app has been dead for years, leaving us with just a terrible mobile web view. 

I didn't want to start with an empty `flutter create` and waste weeks on basic project layout and theming. There used to be a community app called Neptun 2 by domedav, but it died when Neptun changed their API. Another dev, zoligamer, forked it to connect the new routes, which is where I stepped in and forked it myself. It gave me a base so I could actually focus on features instead of rebuilding the wheel.

But honestly, the code I pulled was a mess on day one:
- `MainActivity` was broken, so the app literally died on launch.
- The app would query a dead training ID after silent token refreshes, leaving the timetable totally empty.
- The calendar math was so busted it thought Mondays were eight days in the past.
- **The worst part:** Security was practically non-existent. A global override was accepting *any* TLS certificate, meaning your Neptun password was one sketchy cafe wifi away from being read in plaintext. I immediately scrapped that and added proper 20-second timeout platform validation.

Everything after that is my own work from the last three weeks: 2FA with a saved secret, background notifications for grades/messages, offline mode, server failover, an Android home screen widget, stats page, `.ics` calendar export, and setting up the Google Play builds. I use it every day for my own stuff, which is how I find the bugs.

## The absolute nightmare parts (Android & Google Play)

**Background notifications.** Android literally hates apps waking up in the background. Between Doze, battery optimization, and every phone brand having its own random process killer, notifications are a pain. I can't fix your phone's OS, so I made the settings screen detect what's blocking it and give you a one-tap shortcut to fix it (`lib/power_settings.dart`). You can set the interval from 15 mins to 12 hours.

**Google Play.** Play bans apps that update themselves, but sideloaded users need exactly that. So now I have to maintain two separate build flavors. Play also flagged me for photo and video permissions I never even asked for (some random dependency dragged them in). Plus, since I'm a new dev, I had to do a 14-day closed test with 12 people before I could even apply for production. That part is finally done and it's in review now.

## Download

Latest release: **https://github.com/Bali0531-RC/NHNK/releases/latest**

**Google Play.** Production release is in review (takes about a week). Until then, you can still sign up for the closed test at **https://nhnk.bali0531.hu/zart-teszt/**. Note: The Play Store version doesn't have the built-in updater.

**Android sideload.** Grab the `arm64-v8a` APK. If you want it to auto-update, use [Obtainium](https://github.com/ImranR98/Obtainium) and point it at this repo.

**iPhone.** There's an `unsigned.ipa` in the releases. I don't have a paid Apple Dev account (I'm a student bro), so you have to sign it yourself using [AltStore](https://altstore.io/), [SideStore](https://sidestore.io/) or [Sideloadly](https://sideloadly.io/). You'll have to re-sign it every 7 days because of Apple's rules, not mine. If that's too much work, just subscribe to the `.ics` calendar export for your timetable.

## Features

**Timetable**
- Weekly view, swipe through weeks, tap to return to today.
- Falls back to `.ics` export if the main API drops an empty timetable.
- Android home screen widget.
- Export to `.ics` for your phone's calendar.

**Notifications**
- Alerts for classes, exams, payments, and periods.
- Background alerts for new grades and messages.
- Shortcut in settings to fix OS battery killers blocking the app.

**Grades, stats and money**
- View grades, averages, credits, messages, and payments.
- **Stats page:** See your cumulative average, grade distribution, and track your degree progress against a credit goal.
- **Ghost grades:** Test how a hypothetical grade will affect your average before you actually get it.
- **Average calculator:** See what grades you need to hit your target GPA.

**Everything else**
- Offline mode (shows a bar telling you how old the cached data is).
- Auto-failover if your uni's main server crashes.
- 2FA with auto-login.
- Dark mode/themes and language toggles.

## Reporting bugs

**https://github.com/Bali0531-RC/NHNK/issues/new/choose**
Include your phone model, Android version, and app version, otherwise I can't help you.

## Version history

Full logs at **https://github.com/Bali0531-RC/NHNK/releases**. 
- **1.2:** Added the widget, stats and fixed offline mode (it used to wipe everything when you lost signal because I messed up the connectivity check, lol). Also fixed 2FA bugs.
- **1.1:** Added background notifications, `.ics` export, and server failover.
- **1.0:** Mostly repair work from the fork. Fixed the token refresh and removed the bad permissions blocking the Google Play release.

## Building it

Two flavors to deal with Google Play's annoying rules:

| Flavor | Distribution | Built-in updater | `REQUEST_INSTALL_PACKAGES` |
| --- | --- | --- | --- |
| `github` | sideload / Obtainium | yes | yes |
| `playstore` | Google Play | no | no |

```sh
flutter pub get

# Sideload release
flutter build apk --release --split-per-abi   --flavor github --dart-define=NHNK_DISTRIBUTION=github

# Google Play release
flutter build appbundle --release   --flavor playstore --dart-define=NHNK_DISTRIBUTION=playstore
```
(Always pass `--flavor` and `--dart-define` together or it will break). You need a signing key for release builds, otherwise it uses a debug key.

Tests: `flutter test`

### Adding a university

The uni list is in `universityNameUrlPairs.json` and fetches at **runtime**. Don't rename or delete old ones or you'll break the app for people who haven't updated. Check if a server actually uses the mobile API (it should return `405` and JSON on `/api/Account/Authenticate`) before adding it.

## Credit
Forked from Neptun 2 by domedav, via Neptun Mobile by zoligamer. MIT license, copyright notices are intact.

## License
MIT, see the [LICENSE](LICENSE) file.
</details>

<details>
<summary><b>Magyar</b></summary>

## Miért ezt forkoltam (és miért nem nulláról kezdtem)

Na szóval, 18 éves vagyok, nemsokára kezdem az egyetemet, és tudom, hogy minden nap nyitogatnom kell majd a Neptunt. A hivatalos app évek óta kuka, a webes felület mobilon meg kész szenvedés. 

Nem akartam heteket elcseszni egy üres `flutter create`-tel meg az alap dizájnolással. Régen volt a domedav-féle Neptun 2, de az megállt, amikor a Neptun API-t váltott. Zoligamer forkolta és áthozta az új végpontokra, én meg innen vettem át az egészet. Így legalább az alapok megvoltak, és a funkciókra tudtam fókuszálni.

Viszont az a kód, amit letöltöttem, első nap egy elég durva katasztrófa volt:
- A `MainActivity` el volt törve, konkrétan crashelt az app indításkor.
- A háttérben frissülő tokenek egy halott azonosítót kérdezgettek, úgyhogy az órarend teljesen üres maradt.
- A naptármatematika annyira szét volt csúszva, hogy a hétfőket 8 nappal a múltba rakta.
- **A legdurvább:** A biztonság kb. nulla volt. Egy globális override *minden* TLS tanúsítványt elfogadott. A Neptun jelszavad egyetlen kávézós wifire volt attól, hogy simán, olvashatóan kilopják. Ezt azonnal kukáztam és beraktam a rendes, 20 másodperces platform szintű validációt.

Onnantól minden az én melóm az elmúlt 3 hétből: 2FA elmenthető kulccsal, háttérértesítések, offline mód, szerver failover, Android widget, statisztika, naptárexport, meg a Google Play dolgok. Minden nap használom, szóval a legtöbb bugba én futok bele először.

## Ami a legtöbb időmet elvitte (és kikészített)

**Háttérértesítések.** Az Android konkrétan utálja, ha az appok felébrednek a háttérben. A Doze, az akku-optimalizáció és a gyártók saját app-gyilkosai miatt ez egy rémálom. A telefonod oprendszerét nem tudom megjavítani, de a beállításoknál csináltam egy gombot, ami kitalálja, mi blokkolja, és rögtön oda is dob a megfelelő menübe (`lib/power_settings.dart`).

**Google Play.** A Play kitiltja azokat az appokat, amik frissítik magukat, de a sideloadolt usereknek pont ez kell. Szóval most két külön build flavor van. A Play amúgy visszadobott egyszer, mert állítólag fotó meg videó jogokat kértem, amiket amúgy soha (egy függőség húzta be suttyomban). Plusz új fejlesztőként 14 napig kellett zárt tesztelnem 12 emberrel, hogy egyáltalán jelentkezhessek. Ez most végre megvan, a review folyamatban van.

## Letöltés

Legfrissebb verzió: **https://github.com/Bali0531-RC/NHNK/releases/latest**

**Google Play.** A produkciós kiadás review alatt van. Addig is a zárt tesztre itt tudsz jelentkezni: **https://nhnk.bali0531.hu/zart-teszt/**. A Play-es verzióban nincs beépített app frissítő.

**Android sideload.** Szedd le az `arm64-v8a` APK-t. Ha automatikus frissítést akarsz, használd az [Obtainium](https://github.com/ImranR98/Obtainium)-ot.

**iPhone.** Van egy `unsigned.ipa` a releseeknél. Nincs fizetős Apple Dev fiókom (csóró diák vagyok), úgyhogy magadnak kell aláírnod pl. [AltStore](https://altstore.io/)-ral vagy [Sideloadly](https://sideloadly.io/)-val. 7 naponta lejár, ezt az Apple találta ki, nem én. Ha ez túl sok macera, legalább húzd be az `.ics` naptárexportot az Apple Naptárba.

## Funkciók

**Órarend**
- Heti nézet, lapozható, egy gombnyomásra visszadob a maira.
- Ha az API behal és üres az órarend, fallbackel a naptárexportra.
- Kezdőképernyő-widget Androidra.
- `.ics` exportálás.

**Értesítések**
- Órák, vizsgák, befizetések.
- Új jegyek és üzenetek (akkor is, ha be van zárva az app).
- Gyorsgomb a beállításokban a háttérfutást gyilkoló oprendszeri beállításokhoz.

**Jegyek és egyebek**
- Jegyek, átlagok, kreditek, befizetések.
- **Statisztika oldal:** Halmozott átlag, kredit haladás.
- **Szellemjegyek:** Megnézheted, mit csinálna az átlagoddal egy még be nem írt jegy.
- **Átlagszámító:** Kiszámolja, mi kell a célodhoz.
- Offline mód (mutatja, mennyire régi a letöltött adat).
- Ha az egyetemed fő szervere lehal, automatikusan átvált a tartalékra.
- 2FA mentett kulccsal.

## Hibabejelentés
**https://github.com/Bali0531-RC/NHNK/issues/new/choose**
Telefon típusa, Android verzió, App verzió kötelező, különben nem tudok mit kezdeni vele.

## Származás
A Neptun 2 (domedav) forkja, a Neptun Mobile (zoligamer) forkján keresztül. MIT licenc, a korábbi szerzői jogi megjelölések maradnak.

## Licenc
MIT, lásd a [LICENSE](LICENSE) fájlt.
</details>
