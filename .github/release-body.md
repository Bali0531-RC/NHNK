## Melyik fájl kell?

| Fájl | Kinek |
|---|---|
| `NHNK-<verzió>-arm64-v8a.apk` | **Android — szinte biztosan ez.** Minden nagyjából 2017 utáni telefon |
| `NHNK-<verzió>-armeabi-v7a.apk` | Régebbi, 32 bites Android készülékek |
| `NHNK-<verzió>-x86_64.apk` | Emulátor vagy x86 Chromebook |
| `NHNK-<verzió>-universal.apk` | Ha nem tudod melyik kell, és nem zavar a nagyobb méret |
| `NHNK-<verzió>-unsigned.ipa` | **iPhone** — alá kell írnod magadnak, lásd lent |
| `NHNK-<verzió>-playstore.aab` | Csak a Play Áruházba feltöltéshez. **Telefonra nem telepíthető.** |

A letöltés ellenőrizhető: `sha256sum -c SHA256SUMS.txt`

## Telepítés Androidra

1. Töltsd le az `arm64-v8a` APK-t.
2. Nyisd meg. Android rá fog kérdezni, hogy engedélyezed-e az ismeretlen forrásból való telepítést — ez sideloadolásnál normális.
3. Ha korábbi NHNK verzió van fent, simán rátelepül, nem kell törölni.

Automatikus frissítéshez ajánlott az [Obtainium](https://github.com/ImranR98/Obtainium): add meg neki ezt a repót, és a következő kiadások maguktól érkeznek.

> [!NOTE]
> A `Neptun Mobile` néven telepített régi verzió **nem** frissül erre, mert más a csomagnév. Azt előbb el kell távolítani, és a benne tárolt adatok nem öröklődnek át.

## Telepítés iPhone-ra

Az `.ipa` **aláírás nélküli**, szándékosan: az aláíráshoz fizetős Apple Developer fiók kellene. Ezért magadnak kell aláírnod a saját Apple ID-ddal.

Kell hozzá: **iOS 14 vagy újabb**, és az alábbiak egyike:

- [AltStore](https://altstore.io/) vagy [SideStore](https://sidestore.io/) — telefonra települő alkalmazásbolt
- [Sideloadly](https://sideloadly.io/) — számítógépről telepít

Menete: telepítsd a fentiek egyikét, jelentkezz be a saját Apple ID-ddal, majd add hozzá a letöltött `.ipa` fájlt.

> [!IMPORTANT]
> **Ingyenes Apple ID esetén az app 7 naponta lejár**, és újra alá kell írni. Ez az Apple korlátozása, nem az appé, és nem lehet megkerülni. Egyszerre legfeljebb 3 ilyen app lehet fent. Fizetős Apple Developer fiókkal (99 USD/év) az aláírás 1 évig érvényes.

Ha ez túl macerás, iPhone-on a Neptun **naptár-exportja** feliratkozásként hozzáadható az Apple Naptárhoz: így az órarend appok nélkül is látszik (jegyek, üzenetek, befizetések viszont nem).

---
