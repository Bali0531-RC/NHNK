# NHNK

**Nem Hivatalos Neptun Kliens** — alternatív Neptun mobilalkalmazás, a modern Neptun REST API-ra építve.

[![Letöltések](https://img.shields.io/github/downloads/Bali0531-RC/NHNK/total?style=for-the-badge&color=blue)](https://github.com/Bali0531-RC/NHNK/releases)
[![Legfrissebb verzió](https://img.shields.io/github/v/release/Bali0531-RC/NHNK?style=for-the-badge&color=green)](https://github.com/Bali0531-RC/NHNK/releases/latest)

> [!IMPORTANT]
> **Ez egy független, nem hivatalos alkalmazás.** Nem áll kapcsolatban a Campus Codeworks Zrt.-vel
> (korábban SDA Informatika Zrt., a Neptun rendszer fejlesztője), sem bármely felsőoktatási
> intézménnyel, és azok nem támogatják vagy hagyták jóvá. A „Neptun" név és védjegy a jogosultja
> tulajdona, itt kizárólag leíró jelleggel szerepel. A belépési adatok közvetlenül az intézmény
> Neptun-kiszolgálójára mennek; az NHNK nem üzemeltet saját szervert és nem gyűjt felhasználói
> adatokat. Hivatalos adatnak minden esetben a webes Neptun felületén látható információ számít.

Weboldal: **https://nhnk.bali0531.hu**

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
