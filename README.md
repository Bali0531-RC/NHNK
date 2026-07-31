# Neptun Mobile

Alternatív Neptun mobilalkalmazás, a modern Neptun REST API-ra építve.

[![Letöltések](https://img.shields.io/github/downloads/Bali0531-RC/Neptun-Mobile/total?style=for-the-badge&color=blue)](https://github.com/Bali0531-RC/Neptun-Mobile/releases)
[![Legfrissebb verzió](https://img.shields.io/github/v/release/Bali0531-RC/Neptun-Mobile?style=for-the-badge&color=green)](https://github.com/Bali0531-RC/Neptun-Mobile/releases/latest)

## Letöltés

Legfrissebb kiadás: **https://github.com/Bali0531-RC/Neptun-Mobile/releases/latest**

A legtöbb telefonra az `arm64-v8a` APK kell. Automatikus frissítéshez ajánlott az
[Obtainium](https://github.com/ImranR98/Obtainium): add meg neki ezt a repót, és a
későbbi kiadások maguktól települnek.

## Hibabejelentés

**https://github.com/Bali0531-RC/Neptun-Mobile/issues/new/choose**

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

```sh
flutter pub get
flutter build apk --release --split-per-abi
```

Kiadáshoz aláírókulcs kell: másold az `android/key.properties.example` fájlt
`android/key.properties` néven, és töltsd ki. Enélkül a release build a debug kulcsot
használja, ami nem telepíthető frissítésként a korábbi verzióra.
