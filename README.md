# NHNK

**Nem Hivatalos Neptun Kliens** / Unofficial Neptun Client. Flutter alkalmazás magyar egyetemistáknak, akiknek muszáj Neptunt használniuk, de nem akarnak szenvedni vele.

[![Letöltések](https://img.shields.io/github/downloads/Bali0531-RC/NHNK/total?style=for-the-badge&color=blue)](https://github.com/Bali0531-RC/NHNK/releases)
[![Legújabb kiadás](https://img.shields.io/github/v/release/Bali0531-RC/NHNK?style=for-the-badge&color=green)](https://github.com/Bali0531-RC/NHNK/releases/latest)
[![Google Play](https://img.shields.io/badge/Google_Play-Elérhető-34A853?style=for-the-badge&logo=google-play&logoColor=white)](https://play.google.com/store/apps/details?id=hu.bali0531.nhnk.app)

Weboldal (élő böngészős demóval): **https://nhnk.bali0531.hu**

> [!IMPORTANT]
> Ez egy független, nem hivatalos alkalmazás. Semmilyen kapcsolatban nem áll a Campus Codeworks Zrt.-vel (korábban SDA Informatika Zrt., a Neptun fejlesztője), sem egyetemekkel, és egyikük sem hagyta jóvá. A „Neptun” név a jogosultja tulajdona, itt kizárólag leíró jelleggel szerepel. A belépési adatok közvetlenül az intézményed Neptun-szerverére mennek, én nem üzemeltetek köztes szervert és nem gyűjtök adatot. Ha az app és a webes Neptun mást mond, mindig a webes felület a mérvadó.
>
> This is an independent, unofficial app. It has nothing to do with Campus Codeworks Zrt. (formerly SDA Informatika Zrt., who make Neptun) or with any university, and none of them have endorsed it. Your login goes straight to your university's own Neptun server. I don't run a server and I don't collect anything. If the app and the Neptun website disagree, the website is right.

---

<details open>
<summary><b>Magyar</b></summary>

## Miért ezt forkoltam (és miért nem nulláról kezdtem)

18 évesen, az egyetemet kezdve tudtam, hogy minden nap nyitogatnom kell majd a Neptunt. A hivatalos app évek óta használhatatlan, a webes felület mobilon meg kész szenvedés.

Nem akartam heteket elpazarolni egy üres `flutter create`-tel meg az alap dizájnolással. Régen volt a domedav-féle Neptun 2, de az megállt, amikor a Neptun API-t váltott. Zoligamer forkolta és elkezdte áthozni az új végpontokra, én pedig innen vettem át. Így volt egy kiindulási alapom, amire építve a valódi problémákra és az új funkciókra tudtam fókuszálni.

Viszont az a kód, amit letöltöttem, az első napon elég komoly javításra szorult:
- A `MainActivity` el volt törve, így az app indításkor azonnal összeomlott.
- A háttérben frissülő tokenek egy beragadt képzés-azonosítót kérdezgettek, ezért az órarend teljesen üres maradt.
- A naptármatematika annyira el volt csúszva, hogy a hétfőket 8 nappal a múltba rakta.
- **A legdurvább:** A biztonság gyakorlatilag nulla volt. Egy globális override *minden* TLS tanúsítványt vakon elfogadott, vagyis a Neptun jelszavad egyetlen nyilvános wifire volt attól, hogy olvashatóan kilopják. Ezt azonnal kukáztam, és rendes, 20 másodperces timeouttal védett platform-szintű TLS validációra cseréltem.

Azóta a kódbázis több mint fele már saját fejlesztés: teljesen új 2.0-s Neptun API-integráció (`API-DOCS/`), biometrikus / PIN zárolás, 2FA elmenthető TOTP kulccsal, háttérértesítések, offline mód, szerver failover, Android kezdőképernyő-widget, tárgyoldal tematika-letöltéssel, valódi `#000000` OLED téma, automatizált tesztcsomag és Google Play kiadás. Minden nap ezt használom, így a legtöbb hibába én futok bele először.

## Ami a legtöbb időmet elvitte (Android & Google Play)

**Háttérértesítések.** Az Android utálja, ha az appok felébrednek a háttérben. A Doze, az akku-optimalizáció és a gyártók (Xiaomi, Huawei, Honor, Samsung, OnePlus) saját háttérfolyamat-gyilkosai miatt ez külön művészet. Magát az oprendszert nem tudom átírni, de a Beállításokban csináltam egy gombot (`lib/power_settings.dart`), ami felismeri a telefonod gyártóját, megmondja mi blokkolja a háttérfutást, és egy érintéssel odadob a megfelelő rendszermenübe.

**Google Play.** A Play Áruház tiltja az önmagukat frissítő APK-kat, viszont a GitHubról (sideload) telepítőknek pont erre van szükségük — ezért két külön build flavor (`playstore` és `github`) készül. A Play emellett visszadobja az olyan jogosultságokat is, amiket egy-egy külső függőség húz be a háttérben, úgyhogy a manifestből ezeket kifejezetten ki kellett gyomlálni, a CI pedig minden kiadásnál ellenőrzi az aláírást és az engedélyeket.

## Letöltés

- **Google Play Áruház (ajánlott):** [**NHNK Kliens Neptunhoz a Google Play-en**](https://play.google.com/store/apps/details?id=hu.bali0531.nhnk.app) *(automatikus áruházi frissítésekkel)*.
- **GitHub Releases (Android APK sideload):** [**Legújabb kiadás letöltése**](https://github.com/Bali0531-RC/NHNK/releases/latest). A legtöbb mai telefonra az `arm64-v8a` APK kell. Beépített frissítéskezelőt tartalmaz, vagy bekötheted [Obtainium](https://github.com/ImranR98/Obtainium)-ba is.
- **Webes kipróbálás (telepítés nélkül):** [**https://nhnk.bali0531.hu**](https://nhnk.bali0531.hu) — a nyitóoldalon lévő telefonban maga a valódi Flutter app fut demó módban.
- **iPhone (`.ipa`):** Minden kiadásnál ott az `unsigned.ipa`. Fizetős Apple Developer fiók híján [AltStore](https://altstore.io/), [SideStore](https://sidestore.io/) vagy [Sideloadly](https://sideloadly.io/) segítségével tudod aláírni a saját Apple ID-ddal.

## Funkciók

**Órarend és Kezdőképernyő-widget**
- Heti nézet, tetszőleges hétre lapozva; a hét neve mellől egy koppintással vissza a mai hétre.
- **Kezdőképernyő-widget (Android):** A mai óráid közvetlenül a főképernyőn, háttérbeli automatikus frissítéssel és kézi frissítés gombbal.
- **Órák elrejtése:** Ha egy tárgy előadására nem jársz be, elrejtheted az órarendből, a widgetről és az emlékeztetőkből is.
- **Közelgő események (Upcoming):** A következő 8 hét vizsgái, számonkérései és bejelentkezési/regisztrációs időszakai egyetlen átlátható listában.
- **Naptárexport és fallback:** Ha a Neptun API üres hetet ad vissza, az app a naptár-exportból pótolja az órákat; az órarendedet szabványos `.ics` fájlként bármikor ki is exportálhatod a telefonod naptárába.

**Jegyek, Tárgyoldal és Statisztika**
- **Tárgyak részletes oldala (2.0.5+):** Egy tárgyra koppintva megnyílik a számonkérés típusa, oktató, tanszék, heti óraszámok, leírás, és **PDF-ben letölthető a tárgytematika (szillabusz)**.
- **Szellemjegyek (Ghost grades):** Írj be előre egy még meg nem szerzett jegyet (akár 0 kredites tárgyra is), és azonnal látod, hogyan változna a súlyozott átlagod és a kreditindexed.
- **Statisztika és Diplomahaladás:** Féléves és halmozott átlagok, jegymegoszlás, valamint kredithaladás a képzésed – Neptunból automatikusan kiolvasott – kreditkövetelményéhez képest.
- **Átlagszámító:** Kiszámolja, milyen átlagot kell hoznod a hátralévő kreditekből a célod eléréséhez.

**Értesítések (Push-szerver nélkül, közvetlenül a készüléken)**
- **Háttérbeli jegy- és üzenetfigyelés:** Állítható gyakorisággal (15 perc – 12 óra) ellenőrzi az új jegyeket és üzeneteket, ismétlődő riasztások nélkül, visszanézhető értesítési előzményekkel.
- **Testreszabható óra-emlékeztetők:** Te választhatod ki, hány perccel az órák előtt szóljon (pl. 30, 15, 10 perc vagy kezdéskor), plusz emlékeztetők vizsgák, befizetések és időszakok előtt.
- **Üzenet olvasottnak jelölése:** Amit az appban (vagy közvetlenül az értesítés gombjával) elolvasol, azt a hivatalos Neptun végponton keresztül a webes Neptunban is olvasottnak jelöli.

**Biztonság, Pénzügyek és Megjelenés**
- **Biometrikus / PIN zárolás (2.0.7+):** Megnyitáskor alapértelmezetten ujjlenyomatot, arcfelismerést vagy képernyőzárat kér (első indításkor és a Beállítások → Biztonság menüben bármikor kikapcsolható).
- **Kétlépcsős azonosítás (2FA / TOTP):** Opcionálisan elmenthető titkos kulcs (`flutter_secure_storage` hardveres AES-GCM + RSA-OAEP tárolóban), amivel a lejáró munkamenetet az app magától megújítja.
- **Okos Fizetések fül:** Állami ösztöndíjas hallgatóknál a Fizetések fül alapból rejtve marad, hacsak nincs tényleges befizetnivaló (Beállításokban visszakapcsolható), a törölt tételeket pedig nem számolja bele a költésekbe.
- **Valódi fekete OLED téma:** `#000000` háttér OLED kijelzőkhöz (WCAG AA kontraszt-ellenőrzéssel), több beépített színpaletta, állítható betűméret, magyar és angol nyelv.
- **Offline mód és Szerver Failover:** Hálózat nélkül a legutóbb letöltött adatok megmaradnak; többkiszolgálós egyetemeknél pedig automatikusan átvált a tartalék szerverre, ha az elsődleges nem válaszol.

## Főbb verziók

Részletes kiadási jegyzetek minden verzióhoz: **https://github.com/Bali0531-RC/NHNK/releases**

- **2.0 (2.0.0 – 2.0.9):**
  - **2.0.8 – 2.0.9:** Automatikus, öngyógyító natív kulcsmigráció (`RSA-PKCS1`/`AES-CBC` → `RSA-OAEP`/`AES-GCM`), teljes `FlutterSecureStorage` törlés kijelentkezéskor, valamint a Statisztika és Közelgő fül tokenfrissítési és gyorsítótár-fallback javítása.
  - **2.0.7:** Biometrikus / képernyőzáras alkalmazászár (alapból bekapcsolva, első indításkor és a Beállításokban kapcsolható), teljes stack frissítés (Flutter 3.47, AGP 9.4, Gradle 9.8, Kotlin 2.4), R8 erőforrás-optimalizálás és automatizált Google Play kiadási pipeline.
  - **2.0.6:** Új, saját NHNK alkalmazásikon és indítóképernyő minden platformon.
  - **2.0.5:** Részletes tárgyoldal PDF tematika-letöltéssel, Fizetések fül automatikus elrejtése állami ösztöndíjasoknak, külön szellemjegy gomb.
  - **2.0.4:** Órák elrejtése, szabadon választható óra-emlékeztető időpontok, pontosított widget-méretezés.
  - **2.0.2 – 2.0.3:** Háttérbeli widget-frissítés, 0 kredites szellemjegyek, értesítési előzmények és duplikáció-szűrés.
  - **2.0.0:** Teljes modern Neptun REST API térkép (`API-DOCS/`, 180 végpont), képességalapú végpont-felismerés (`ModernApi`), automatikus kreditkövetelmény-lekérés (`dashboard/creditprogress`) és adatforgalom-kímélő olvasatlanüzenet-számláló.
- **1.3 (1.3.0 – 1.3.1):** Új, négylépéses első indítás (onboarding) ékezetfüggetlen intézménykeresővel és valódi fekete (`#000000`) OLED témával.
- **1.2 (1.2.0 – 1.2.10):** Kezdőképernyő-widget, Közelgő események oldal, féléves statisztika és diplomahaladás, webes demó build, fejlesztői diagnosztikai fül PII-redakcióval, indítási gyorsítás és akadálymentesítés (screen reader támogatás).
- **1.1:** Háttérbeli jegy- és üzenetértesítések, `.ics` naptárexport, szerver failover és gyártói akkumulátor-beállítás irányító.
- **1.0:** A fork talpra állítása: `MainActivity`, TLS tanúsítvány-ellenőrzés, munkamenet-frissítés, 2FA alapok és Google Play build szétválasztás.

## Hibabejelentés

**https://github.com/Bali0531-RC/NHNK/issues/new/choose**
Kérlek, írd bele a telefon típusát, az Android verziót és az app verzióját.

## Fordítás és Fejlesztés

Két build flavor van a Google Play szabályai miatt:

| Flavor | Terjesztés | Beépített frissítő | `REQUEST_INSTALL_PACKAGES` |
| --- | --- | --- | --- |
| `github` | Sideload / Obtainium | van | van |
| `playstore` | Google Play | nincs | nincs |

```sh
flutter pub get

# GitHub / Sideload APK
flutter build apk --release --split-per-abi --flavor github --dart-define=NHNK_DISTRIBUTION=github

# Google Play App Bundle (.aab)
flutter build appbundle --release --flavor playstore --dart-define=NHNK_DISTRIBUTION=playstore
```

Tesztek futtatása: `flutter test`

### Intézmények hozzáadása

Az intézménylistát a `universityNameUrlPairs.json` tartalmazza, és az app **futásidőben** tölti le a `main` ágról. Régi bejegyzést átnevezni vagy törölni nem szabad, csak bővíteni. Több szerveres egyetemnél a tartalék kiszolgálók a `Fallbacks` tömbbe vehetők fel.

## Származás és Licenc

A projekt a [Neptun 2](https://github.com/domedav/Neptun-2) (domedav) forkja, a [Neptun Mobile](https://github.com/zoligamer/Neptun-Mobile-fork) (zoligamer) forkon keresztül.
**MIT licenc** — lásd a [LICENSE](LICENSE) fájlt.

</details>

<details>
<summary><b>English</b></summary>

## Why I forked this (and didn't start from scratch)

Starting university in Hungary means opening Neptun every single day. The official mobile app has been abandoned for years, and the desktop web UI on a phone screen is painful to use.

Rather than spending weeks on an empty `flutter create`, I built on top of existing open-source community work: domedav's original Neptun 2 (which stopped working when Neptun switched APIs) and zoligamer's Neptun Mobile fork (which began wiring up the newer endpoints).

When I pulled the repository, several core parts were broken:
- `MainActivity` was missing/broken, crashing the app immediately on launch.
- Silent token refreshes queried a stale training ID, leaving the timetable empty.
- The calendar week math placed Mondays eight days in the past.
- **Security:** A global `HttpOverrides` accepted *any* TLS certificate without validation. I replaced this immediately with proper platform TLS validation and 20-second request timeouts.

Since then, over half of the codebase has been rewritten or newly built: full modern Neptun REST API mapping (`API-DOCS/`), default biometric / PIN lock, 2FA with hardware-backed TOTP secret storage, background grade and message alerts, offline resilience, multi-server failover, an Android home screen widget, subject detail pages with PDF syllabus downloads, a true `#000000` OLED theme, an automated test suite (`test/`), and Google Play production builds.

## Download

- **Google Play (recommended):** [**NHNK on Google Play**](https://play.google.com/store/apps/details?id=hu.bali0531.nhnk.app) *(automatic updates via Play Store)*.
- **GitHub Releases (Android sideload):** [**Latest release**](https://github.com/Bali0531-RC/NHNK/releases/latest). Most current phones need the `arm64-v8a` APK. Includes an in-app updater and works with [Obtainium](https://github.com/ImranR98/Obtainium).
- **Try in browser (no install):** [**https://nhnk.bali0531.hu**](https://nhnk.bali0531.hu) — runs the real Flutter app compiled to Web in demo mode.
- **iPhone (`.ipa`):** Each release attaches an `unsigned.ipa` that you can sign with your own Apple ID using [AltStore](https://altstore.io/), [SideStore](https://sidestore.io/), or [Sideloadly](https://sideloadly.io/).

## Features

**Timetable & Home Screen Widget**
- Weekly view with swipe navigation and one-tap return to the current week.
- **Android Home Screen Widget** with automatic background refreshes and a manual refresh button.
- **Hide classes:** Hide specific courses from the timetable, widget, and reminders.
- **Upcoming view:** Unified 8-week lookahead for exams, task deadlines, and registration periods.
- **`.ics` fallback & export:** Automatically fills in missing timetable weeks from the calendar export, and exports your timetable as a standard `.ics` file.

**Grades, Subjects & Statistics**
- **Subject details (2.0.5+):** Tap any subject to view its assessment type, lecturer, department, weekly hours, description, and download the **course syllabus as a PDF**.
- **Ghost grades:** Pencil in hypothetical marks (including on 0-credit courses) to see how they affect your weighted average and credit index.
- **Statistics & Degree Progress:** Semester and cumulative averages, grade distribution, and credit progress against your degree requirement (fetched automatically from Neptun).
- **Target average calculator:** Calculates the exact average needed on your remaining credits to hit your target GPA.

**Notifications (On-device, no push server)**
- **Background grade & message checks:** Configurable polling interval (15 min – 12 hours) with deduplication and persistent notification history.
- **Configurable class reminders:** Choose your own reminder offsets before classes, plus alerts for exams, payments, and periods.
- **Mark messages as read:** Reading a message in the app (or tapping "Mark as read" on the notification) marks its unread posts as read in Neptun (`Posts/Processed`).
- **OEM battery helper:** Detects manufacturer-specific background killers (`lib/power_settings.dart`) and links directly to the relevant system screen.

**Security & Appearance**
- **Biometric / PIN lock (2.0.7+):** Prompts for fingerprint, face unlock, or device screen lock on launch by default (with an opt-out toggle during first-run setup and under Settings → Security).
- **Two-factor authentication (2FA / TOTP):** Optional stored TOTP secret in hardware-backed `flutter_secure_storage` (AES-GCM + RSA-OAEP) for automatic session renewal.
- **Smart Payments tab:** Automatically stays hidden for full state-scholarship students unless there is an active balance due.
- **True black OLED theme (`#000000`)**, multiple colour palettes, adjustable font scaling, and full Hungarian/English support (including translated demo mode fixtures).

## Version History

Full release notes: **https://github.com/Bali0531-RC/NHNK/releases**

- **2.0 (2.0.0 – 2.0.9):**
  - **2.0.8 – 2.0.9:** Self-healing native legacy-to-v11 credential migration (`RSA-PKCS1`/`AES-CBC` → `RSA-OAEP`/`AES-GCM`), complete secure-storage wipe on logout, and token-refresh / cache fallback fixes for Statistics and Upcoming views.
  - **2.0.7:** Default biometric / screen-lock protection (with onboarding opt-out and settings toggle), full stack upgrade (Flutter 3.47, AGP 9.4, Gradle 9.8, Kotlin 2.4), R8 resource shrinking, and automated Google Play production release pipeline.
  - **2.0.6:** Redesigned custom NHNK app icon and splash assets across all platforms.
  - **2.0.5:** Subject detail page with PDF syllabus downloads, automatic hiding of the Payments tab for full state-scholarship students, dedicated ghost-grade button.
  - **2.0.4:** Hide courses from timetable/widget/reminders, custom class reminder offsets.
  - **2.0.2 – 2.0.3:** Background home-screen widget refresh, 0-credit ghost grades, persistent notification history and deduplication.
  - **2.0.0:** Full modern Neptun REST API map (`API-DOCS/`), capability discovery (`ModernApi`), automatic degree credit requirement (`dashboard/creditprogress`), and lightweight unread message count polling.
- **1.3 (1.3.0 – 1.3.1):** 4-step onboarding with accent-insensitive institution search and true black (`#000000`) OLED theme.
- **1.2 (1.2.0 – 1.2.10):** Android home-screen widget, Upcoming events page, semester statistics & degree progress, web demo build, PII-redacted diagnostics tab, startup optimization, and screen-reader accessibility.
- **1.1:** Background grade & message notifications, `.ics` calendar export, multi-server failover, and OEM battery helper.
- **1.0:** Initial stabilization of the fork: fixed `MainActivity`, TLS certificate validation, session renewal, 2FA support, and Google Play build flavors.

## Building & Testing

```sh
flutter pub get

# Sideload release
flutter build apk --release --split-per-abi --flavor github --dart-define=NHNK_DISTRIBUTION=github

# Google Play release
flutter build appbundle --release --flavor playstore --dart-define=NHNK_DISTRIBUTION=playstore

# Run unit & widget test suite
flutter test
```

## Credits & License

Forked from [Neptun 2](https://github.com/domedav/Neptun-2) by domedav, via [Neptun Mobile](https://github.com/zoligamer/Neptun-Mobile-fork) by zoligamer.
Released under the **MIT License** — see [LICENSE](LICENSE).

</details>
