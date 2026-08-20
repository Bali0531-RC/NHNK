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

## Why I made this

I'm a student and I open Neptun most days. There is no official app to open: the official Neptun mobile app was discontinued years ago, so your choices are the web interface squinted at on a phone screen, or nothing.

I didn't start from an empty `flutter create`. [domedav's Neptun 2](https://github.com/domedav/Neptun-2) was the community answer to that gap for a long time, but Neptun moved to a new API and the app stopped working, so it's dead now. [zoligamer's fork](https://github.com/zoligamer/Neptun-Mobile-fork) is what brought it onto the new routes, and that's where I forked from. It gave me a foundation that already knew the shape of a Neptun client (project layout, timetable rendering, theming) instead of three weeks of scaffolding, and I'd rather spend that time on features than on re-deciding where the state lives.

That foundation still had a rough first day waiting for me. `MainActivity` was broken so the app died on launch, and a lot of the API path was still subtly wrong underneath the new routes. The training ID was cached in a static, but Neptun issues a new one on every login, so any silent token refresh left the app querying a dead ID and rendering an empty timetable. The week window did `now.subtract(Duration(days: now.weekday))`, which puts Mondays eight days in the past. Message counts were hardcoded to zero, so the unread badge could never appear. The display toggles in settings were read from storage and then thrown away in favour of hardcoded values, so they did nothing at all.

The one that actually bothered me was the TLS handling. There was a global `HttpOverrides` whose `badCertificateCallback` returned `true` for everything, meaning the app accepted any certificate anyone handed it. Your Neptun password was one hostile network away from being read in plaintext. That was the first thing I fixed, and it's why the app now just uses platform certificate validation with a 20 second connect timeout instead. The university endpoints all serve valid chains, so there was never a reason for that override to exist.

Everything after that is mine, roughly three weeks of it: 2FA with an optionally persisted secret so you don't retype a code every session, background notifications for new grades and messages, offline mode, automatic failover between a university's servers, an Android home screen widget, semester statistics with degree progress, per-subject pages, an upcoming list, `.ics` calendar export, and the whole Play Store build split.

I use it daily at my own university. That's mostly how the bugs get found.

## The two things that ate my time

**Background notifications.** Android does not want your app to wake up, and it is right to feel that way, but it made this miserable. Between Doze, battery optimisation and every manufacturer skin having its own private process killer, a periodic check that works perfectly on one phone silently never fires on another. I can't fix that from inside the app, so I did the next best thing: the settings screen works out what's blocking it and sends you straight to the system page that controls it (see `lib/power_settings.dart`). The interval is yours, 15 minutes up to 12 hours, or off if you'd rather keep the battery.

**Google Play.** Play bans apps that update themselves. Fair enough, except sideloaded users need exactly that, so now there are two build flavors that differ in whether the updater and `REQUEST_INSTALL_PACKAGES` exist at all. Play also rejected a build over photo and video permissions I never asked for, which turned out to be dependencies quietly merging them into the manifest. Then there's the waiting: a new personal developer account has to run 14 days of closed testing with at least 12 testers before you're even allowed to apply for production. That part is done. The production review itself is in progress as I write this and takes about a week.

## Download

Latest release: **https://github.com/Bali0531-RC/NHNK/releases/latest**

**Google Play.** The 14 day closed test is finished and the production release is in review, which takes roughly a week. Until it clears, only testers can see the listing, and you can still sign up at **https://nhnk.bali0531.hu/zart-teszt/**. The Play build has no built-in updater, Play handles updates itself.

**Android sideload.** Grab the `arm64-v8a` APK, that's what almost every phone wants. If you want automatic updates, [Obtainium](https://github.com/ImranR98/Obtainium) is the easiest option: point it at this repo and it takes care of the rest.

**iPhone.** There's an `unsigned.ipa` in every release, and the name is the warning. Signing it properly needs a paid Apple Developer account that I don't have, so you sign it yourself with your own Apple ID using [AltStore](https://altstore.io/), [SideStore](https://sidestore.io/) or [Sideloadly](https://sideloadly.io/). Needs iOS 14+. On a free Apple ID it expires every 7 days and you re-sign it, which is Apple's rule, not mine. If that sounds like too much hassle, you can subscribe to Neptun's calendar export in Apple Calendar and at least have your timetable.

## Features

**Timetable**
- Weekly view, page to any week, one tap next to the week name to get back to today
- If Neptun's API hands back an empty timetable it falls back to the calendar export
- Android home screen widget showing today's classes
- Export to `.ics` so your phone's calendar can eat it

**Notifications**
- Ahead of classes, exams, payments and periods
- New grades and new messages, including when the app is closed
- Mark a message read from the notification itself
- One tap from settings to whichever system screen is blocking background work

**Grades, stats and money**
- Grades, averages, credits, messages, payments, periods
- Statistics page: cumulative average, average and credits per semester as charts, grade distribution, and degree progress against a credit target you set
- Subject pages: credits, grade, pass/fail/ongoing status, this week's classes and anything upcoming for that subject
- Upcoming list, everything due soon in one place
- Ghost grades, so you can see what a grade you haven't earned yet would do to your average
- Average calculator, telling you what you need across your remaining credits to hit a target
- Search messages by subject or sender

**Everything else**
- Offline mode keeps the last data it downloaded, with a bar telling you how stale it is
- Automatic failover if your university runs several servers and the main one is down
- 2FA, with the secret optionally stored for automatic re-login
- Themes and languages you can change

## Reporting bugs

**https://github.com/Bali0531-RC/NHNK/issues/new/choose**

Tell me your phone model, Android version and app version, otherwise I'm guessing.

## Version history

Full release notes live at **https://github.com/Bali0531-RC/NHNK/releases**. The short version:

**1.2** brought the home screen widget, the statistics and subject pages, the upcoming list, the average calculator and message search. Offline mode also started actually working: losing signal used to wipe every list because I was comparing `connectivity_plus`'s return value wrong, so the app never once realised it was offline. Also fixed 2FA, where tapping beside the dialog cancelled the login the dialog was there to complete.

**1.1** added background notifications for grades and messages, `.ics` export and server failover. The "back to this week" button moved into the week switcher bar because as a floating button it sat right on top of the bottom navigation.

**1.0** was mostly repair work. Token refresh had never worked, so an expiring session just emptied your data. The timetable can now load from the calendar export as well, so it shows up even without a session. Added a real signing key so updates install over older versions instead of failing, and stripped the permissions that dependencies had dragged into the Play build.

## Building it

Two flavors, because of the Play updater rule above:

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

Always pass `--flavor` and `--dart-define` together. The flavor decides the manifest permission, the dart-define switches the updater off on the Dart side, and getting one without the other gives you a build that's wrong in a way you won't notice until Play rejects it.

For a release build you need a signing key: copy `android/key.properties.example` to `android/key.properties` and fill it in. Skip this and the release build quietly uses the debug key, which won't install over an existing version.

Tests:

```sh
flutter test
```

### Adding a university

The list lives in `universityNameUrlPairs.json`, and installed apps fetch it from the `main` branch **at runtime**. So it can only ever be added to. Renaming or deleting the `Name` and `Url` fields breaks every copy of the app already out in the world, including the ones nobody is going to update.

If a university runs several equivalent Neptun servers, list the spares under `Fallbacks`. When the active one stops responding the app moves to the next and logs in again with the saved credentials, because sessions are per server and don't carry across.

```jsonc
{
   "Name": "Pannon Egyetem",
   "Url": "https://neptun-ws01.uni-pannon.hu/hallgato",
   "Fallbacks": ["https://neptun-ws03.uni-pannon.hu/hallgato"]
}
```

Before you add a server, check that it's actually the mobile API answering and not the web frontend. Send a GET to `/api/Account/Authenticate`: you want a `405` and JSON back. Anything else and you've found the website.

## Credit

Forked from [Neptun 2](https://github.com/domedav/Neptun-2) by domedav, by way of [Neptun Mobile](https://github.com/zoligamer/Neptun-Mobile-fork) by zoligamer, who did the work of moving it onto Neptun's new API after the original stopped working. MIT, and their copyright notices stay where they are.

## License

MIT, see [LICENSE](LICENSE).

</details>

<details>
<summary><b>Magyar</b></summary>

## Miért csináltam

Hallgató vagyok, és nagyjából minden nap megnyitom a Neptunt. Csak épp nincs mit megnyitni: a hivatalos Neptun mobilappot évekkel ezelőtt megszüntették, úgyhogy marad a webes felület telefonon hunyorogva, vagy semmi.

Nem nulláról indultam. A [domedav-féle Neptun 2](https://github.com/domedav/Neptun-2) sokáig ezt a hiányt töltötte be, de a Neptun áttért egy új API-ra, és az app megállt, ma már nem működik. A [zoligamer forkja](https://github.com/zoligamer/Neptun-Mobile-fork) hozta át az új végpontokra, én innen forkoltam. Így kaptam egy alapot, ami már ismerte egy Neptun-kliens felépítését (projektstruktúra, órarend megjelenítés, témák), ahelyett hogy három hetet töltöttem volna állványozással.

Az alap azért tartogatott egy elég csúnya első napot. A `MainActivity` el volt törve, így az app indításkor meghalt, az API-réteg alatt pedig még bőven maradt hiba az új végpontok mögött. A képzésazonosító egy statikus mezőben ragadt, pedig a Neptun minden belépésnél újat ad, így egy csendes tokenfrissítés után az app egy halott azonosítót kérdezgetett és üres órarendet rajzolt. A hétablak a `now.subtract(Duration(days: now.weekday))` képletet használta, ami a hétfőket nyolc nappal korábbra tolja. Az üzenetszámlálók fixen nullák voltak, így az olvasatlan jelző soha nem jelenhetett meg. A beállítások megjelenítési kapcsolóit kiolvasta a tárolóból, aztán eldobta és hardkódolt értékeket használt helyettük, vagyis a kapcsolók semmit nem csináltak.

Ami viszont tényleg zavart, az a TLS-kezelés volt. Volt egy globális `HttpOverrides`, aminek a `badCertificateCallback`-je mindenre `true`-val tért vissza, tehát az app bármilyen tanúsítványt elfogadott, amit elé toltak. A Neptun jelszavad egyetlen rosszindulatú hálózatra volt attól, hogy olvashatóan kiessen. Ez volt az első, amit megjavítottam, és ezért használ ma az app sima platform szintű tanúsítványellenőrzést, helyette 20 másodperces csatlakozási időkorláttal. Az egyetemi végpontok érvényes láncot szolgálnak ki, szóval annak az override-nak soha nem volt létjogosultsága.

Onnantól minden a saját munkám, nagyjából három hétnyi: 2FA elmenthető kulccsal, hogy ne kelljen minden belépésnél kódot pötyögni, háttérértesítés új jegyről és üzenetről, offline mód, automatikus átváltás az intézmény tartalék szervereire, kezdőképernyő-widget, statisztika oldal diplomahaladással, tárgyankénti nézet, közelgő események listája, `.ics` naptárexport, és a teljes Play Store-os buildszétválasztás.

Minden nap használom a saját egyetememen. Jellemzően így derülnek ki a hibák.

## Ami a legtöbb időt elvitte

**A háttérértesítések.** Az Android nem szeretné, ha az appod felébredne. Alapvetően igaza van, de ettől még kínszenvedés volt. A Doze, az akkumulátor-optimalizálás és az, hogy minden gyártói felületnek megvan a saját folyamatgyilkosa, együtt oda vezet, hogy egy időzített ellenőrzés az egyik telefonon tökéletesen működik, a másikon meg némán soha nem fut le. Ezt az appon belülről nem tudom megjavítani, úgyhogy azt csináltam, amit lehetett: a beállítások kitalálják, mi blokkolja, és egy koppintással átdobnak a megfelelő rendszerbeállításra (`lib/power_settings.dart`). A gyakoriságot te állítod, 15 perctől 12 óráig, vagy ki, ha inkább az aksi kell.

**A Google Play.** A Play tiltja az önmagukat frissítő appokat. Érthető, csak épp a sideloadolt verziónak pont erre van szüksége, így most két flavor van, amik abban különböznek, hogy létezik-e bennük egyáltalán a frissítő és a `REQUEST_INSTALL_PACKAGES`. Ezen kívül visszadobtak egy buildet fotó- és videójogosultságok miatt, amiket soha nem kértem: függőségek fűzték bele csendben a manifestbe. És ott a várakozás: egy új személyes fejlesztői fióknak 14 nap zárt tesztet kell lefuttatnia legalább 12 tesztelővel, mielőtt egyáltalán jelentkezhet produkcióra. Ez megvan. Maga a produkciós felülvizsgálat most fut, és nagyjából egy hét.

## Letöltés

Legfrissebb kiadás: **https://github.com/Bali0531-RC/NHNK/releases/latest**

**Google Play.** A 14 napos zárt teszt lement, a produkciós kiadás felülvizsgálat alatt van, ami nagyjából egy hét. Amíg át nem megy, csak a tesztelők látják a listázást, jelentkezni továbbra is itt lehet: **https://nhnk.bali0531.hu/zart-teszt/**. A Play-es buildben nincs beépített frissítő, azt az áruház intézi.

**Android sideload.** Az `arm64-v8a` APK kell, gyakorlatilag minden telefonra az jó. Automatikus frissítéshez az [Obtainium](https://github.com/ImranR98/Obtainium) a legegyszerűbb: megadod neki ezt a repót, és onnantól magától megy.

**iPhone.** Minden kiadásban van `unsigned.ipa`, és a név egyben a figyelmeztetés is. A rendes aláíráshoz fizetős Apple Developer fiók kellene, ami nincs, úgyhogy magadnak kell aláírnod a saját Apple ID-ddal, például [AltStore](https://altstore.io/), [SideStore](https://sidestore.io/) vagy [Sideloadly](https://sideloadly.io/) segítségével. iOS 14 vagy újabb kell. Ingyenes Apple ID-val 7 naponta lejár és újra alá kell írni, ez az Apple szabálya, nem az enyém. Ha ez sok, az órarendet a Neptun naptárexportjából fel tudod venni az Apple Naptárba, az legalább megvan.

## Funkciók

**Órarend**
- Heti nézet, bármelyik hétre lapozható, a hét neve mellett egy koppintás visszavisz a maira
- Ha a Neptun API üres órarendet ad vissza, a naptárexportból tölti be
- Kezdőképernyő-widget a mai órákkal (Android)
- Exportálás `.ics` fájlba, amit a telefon naptára beolvas

**Értesítések**
- Órák, vizsgák, befizetések és időszakok előtt
- Új jegyről és új üzenetről, bezárt app mellett is
- Üzenet olvasottnak jelölése egyenesen az értesítésből
- Egy koppintás a beállításokból arra a rendszerképernyőre, ami épp blokkolja a háttérfutást

**Jegyek, statisztika, pénz**
- Jegyek, átlagok, kreditek, üzenetek, befizetések, időszakok
- Statisztika oldal: halmozott átlag, féléves átlagok és kreditek grafikonon, jegyek megoszlása, és diplomahaladás az általad megadott kreditcélhoz mérve
- Tárgyoldalak: kredit, jegy, teljesített/bukott/folyamatban állapot, az adott heti órák és a tárgyhoz tartozó közelgő események
- Közelgő lista, egy helyen minden, ami hamarosan esedékes
- Szellemjegyek: mit csinálna az átlagoddal egy még meg nem szerzett jegy
- Átlagszámító: milyen átlag kell a maradék kreditekre a célodhoz
- Keresés az üzenetek közt tárgy vagy feladó szerint

**Egyéb**
- Offline mód: megmarad a legutóbb letöltött adat, egy sáv jelzi, mennyire régi
- Automatikus átváltás, ha az intézménynek több szervere van és az elsődleges nem válaszol
- 2FA, opcionálisan elmentett kulccsal az automatikus újrabelépéshez
- Állítható témák és nyelvek

## Hibabejelentés

**https://github.com/Bali0531-RC/NHNK/issues/new/choose**

Írd meg a telefon típusát, az Android verziót és az app verzióját, különben tippelek.

## Verziók

Részletes kiadási jegyzet: **https://github.com/Bali0531-RC/NHNK/releases**. Röviden:

**1.2**: kezdőképernyő-widget, statisztika és tárgyoldalak, közelgő lista, átlagszámító, keresés az üzenetek közt. Az offline mód is elkezdett működni: korábban a hálózat elvesztése kiürítette a listákat, mert rosszul hasonlítottam össze a `connectivity_plus` visszatérési értékét, így az app soha nem jött rá, hogy offline van. Javítva a 2FA is, ahol az ablak mellé koppintás megszakította azt a bejelentkezést, amit az ablak épp befejezni akart.

**1.1**: háttérértesítés jegyekről és üzenetekről, `.ics` export, szerverátváltás. A „vissza a mai hétre" gomb átkerült a hétváltó sávba, mert lebegő gombként pont az alsó menüsoron ült.

**1.0**: főleg javítás. A tokenfrissítés soha nem működött, így a lejáró munkamenet egyszerűen kiürítette az adatokat. Az órarend a naptárexportból is betölthető lett, így munkamenet nélkül is látszik. Bekerült egy rendes aláírókulcs, hogy a frissítések rátelepüljenek a korábbi verzióra, és kikerültek a Play-es buildből azok a jogosultságok, amiket a függőségek húztak be.

## Fejlesztés

Két flavor, a fenti Play-szabály miatt:

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

A `--flavor` és a `--dart-define` mindig együtt megy. A flavor a manifest jogosultságát dönti el, a dart-define a Dart oldali frissítőt kapcsolja ki, és ha csak az egyiket adod meg, olyan buildet kapsz, ami rossz, csak ezt majd a Play mondja meg neked.

Kiadáshoz aláírókulcs kell: másold az `android/key.properties.example` fájlt `android/key.properties` néven és töltsd ki. Enélkül a release build szó nélkül a debug kulcsot használja, ami nem telepíthető rá a korábbi verzióra.

Tesztek:

```sh
flutter test
```

### Új intézmény felvétele

A lista a `universityNameUrlPairs.json`-ban van, és a telepített appok **futásidőben** húzzák le a `main` ágról. Ezért csak bővíteni szabad. A `Name` és `Url` mezők átnevezése vagy törlése minden kint lévő példányt elront, azokat is, amiket soha senki nem fog frissíteni.

Ha egy intézmény több egyenrangú Neptun-szervert üzemeltet, a tartalékok a `Fallbacks` tömbbe mennek. Ha az aktív nem válaszol, az app átvált a következőre, és a mentett adatokkal újra belép, mert a munkamenet szerverenként szól és nem vihető át.

```jsonc
{
   "Name": "Pannon Egyetem",
   "Url": "https://neptun-ws01.uni-pannon.hu/hallgato",
   "Fallbacks": ["https://neptun-ws03.uni-pannon.hu/hallgato"]
}
```

Mielőtt felveszel egy szervert, ellenőrizd, hogy tényleg a mobil API válaszol rajta és nem a webes felület. Küldj egy GET kérést a `/api/Account/Authenticate` címre: `405`-öt és JSON-t kell visszakapnod. Ha mást kapsz, a weboldalt találtad meg.

## Származás

A [Neptun 2](https://github.com/domedav/Neptun-2) (domedav) forkja, a [Neptun Mobile](https://github.com/zoligamer/Neptun-Mobile-fork) (zoligamer) forkján keresztül, aki az eredeti leállása után áthozta a Neptun új API-jára. MIT licenc, a korábbi szerzői jogi megjelölések maradnak.

## Licenc

MIT, lásd a [LICENSE](LICENSE) fájlt.

</details>
