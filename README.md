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

### Android

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

- Órarend, benne a Neptun naptár-exportjából jövő órákkal is, ha a Neptun API üresen hagyja
- Szellemjegyek az átlagszámításhoz
- Értesítések órákról, vizsgákról és befizetésekről
- Jegyek, átlagok, kreditek, üzenetek, befizetések, időszakok
- Kétlépcsős azonosítás, opcionálisan elmentett kulccsal automatikus újrabejelentkezés
- Testreszabható témák és nyelvek

## Verziók

### 1.0.7

Munkamenet-kezelés javítása: a token-frissítés eddig sosem működött, ezért a lejáró
munkamenet kiürítette az adatokat. Az órarend mostantól a Neptun naptár-exportjából is
betölthető, így munkamenet nélkül is látszik. A 2FA titkos kulcs elmenthető az automatikus
újrabejelentkezéshez. Az 52. tanulmányi hét után is lehet lapozni, és a fejlécben látszik
a hét tényleges dátuma. Sokkal kevesebb emoji a felületen.

### 1.0.6

Az app indulásakor azonnal összeomlott, mert a csomagátnevezéskor törölt `MainActivity`
nem került vissza. Ezzel együtt a hiányzó ProGuard szabályok is pótolva lettek.

### 1.0.5

Első saját kulccsal aláírt kiadás, így a frissítések telepíthetők a korábbi verzióra.

### 1.0.4 és korábbi

Órarend, naptár logika, pénzügyek, tárgyak, üzenetek, időszakok oldalak, 2FA alapok.
A korábbi változások a lenti forkok repóiban találhatók.

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

## Licenc

MIT — lásd a [LICENSE](LICENSE) fájlt.
