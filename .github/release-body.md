## Melyik fájl kell?

| Fájl / Áruház | Kinek |
|---|---|
| `NHNK-<verzió>-arm64-v8a.apk` | **Android — szinte biztosan ez.** Minden nagyjából 2017 utáni telefon |
| `NHNK-<verzió>-armeabi-v7a.apk` | Régebbi, 32 bites Android készülékek |
| `NHNK-<verzió>-x86_64.apk` | Emulátor vagy x86 Chromebook |
| `NHNK-<verzió>-universal.apk` | Ha nem tudod melyik kell, és nem zavar a nagyobb méret |
| `NHNK-<verzió>-playstore.aab` | Csak a Google Play Áruházba feltöltéshez. **Telefonra nem telepíthető.** |
| [**Apple App Store (iOS)**](https://apps.apple.com/us/app/nhnk-uni-schedule-grades/id6835257595) | **iPhone / iOS** — kizárólag a hivatalos Apple App Store-ból érhető el (GitHubon `.ipa` nem készül) |

A letöltés ellenőrizhető: `sha256sum -c SHA256SUMS.txt`

## Telepítés Androidra

- **Google Play Áruház (ajánlott):** [**NHNK Kliens Neptunhoz a Google Play-en**](https://play.google.com/store/apps/details?id=hu.bali0531.nhnk.app)
- **GitHub APK (sideload):**
  1. Töltsd le az `arm64-v8a` APK-t.
  2. Nyisd meg. Android rá fog kérdezni, hogy engedélyezed-e az ismeretlen forrásból való telepítést — ez sideloadolásnál normális.
  3. Ha korábbi NHNK verzió van fent, simán rátelepül, nem kell törölni.

Automatikus frissítéshez (ha nem a Google Play-t használod) ajánlott az [Obtainium](https://github.com/ImranR98/Obtainium): add meg neki ezt a repót, és a következő kiadások maguktól érkeznek.

> [!NOTE]
> A `Neptun Mobile` néven telepített régi verzió **nem** frissül erre, mert más a csomagnév. Azt előbb el kell távolítani, és a benne tárolt adatok nem öröklődnek át.

## Telepítés iPhone-ra (iOS)

Az iOS verzió natív alkalmazásként (**Expo / React Native**, fejlesztő és App Store kiadó: **Béres Marcell**) kizárólag a hivatalos **Apple App Store-ból** tölthető le:

- [**NHNK – Uni Schedule & Grades az Apple App Store-ban**](https://apps.apple.com/us/app/nhnk-uni-schedule-grades/id6835257595) *(v1.0.0 megjelenés: **2026. november 30.** — előrendelhető / az áruházi adatlap már elérhető).*

---
