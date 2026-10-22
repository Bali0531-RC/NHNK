# Közreműködési Útmutató / Contributing Guide

<details open>
<summary><b>Magyar</b></summary>

Köszönjük, hogy segítesz jobbá tenni az **NHNK – Nem Hivatalos Neptun Klienst**! Legyen szó hibabejelentésről, új intézményi Neptun-szerver felvételéről, fordításról vagy kódbeli javításról, minden hozzájárulást szívesen fogadunk.

A közreműködéssel elfogadod a projekt [Magatartási Kódexét (`CODE_OF_CONDUCT.md`)](CODE_OF_CONDUCT.md), és hozzájárulsz ahhoz, hogy a beküldött munkád a projekt [MIT licence (`LICENSE`)](LICENSE) alatt kerüljön terjesztésre.

---

## 1. Személyes adatok védelme (Kritikus szabály!)

A Neptun szenzitív tanulmányi és pénzügyi adatokat kezel. **Soha ne küldj be (se commitban, se issue-ban, se képernyőképen):**
- Valódi Neptun-kódot, jelszót, 2FA/TOTP kulcsot vagy `Bearer` JWT tokent.
- `devicecookie-*` vagy munkamenet-sütiket (`sessionCookie`).
- Személyes `.ics` naptárexport URL-t (ez önmagában hitelesítő kulcs!).
- Nyers JSON válaszokat (`response.body`), amelyek valódi jegyeket, üzeneteket, oktatói neveket vagy pénzügyi tételeket tartalmaznak.

Az `API-DOCS/` mappában kizárólag anonimizált útvonalak és üres/szintetikus sémák szerepelhetnek.

---

## 2. Új egyetem vagy tartalék Neptun-szerver hozzáadása

Az intézmények listáját a gyökérkönyvtárban található **`universityNameUrlPairs.json`** fájl tartalmazza, amelyet az alkalmazás futásidőben tölt le a `main` ágról.

1. **Kompatibilitási szabály:** Soha ne törölj vagy nevezz át meglévő intézménynevet (`Name`), mert a már bejelentkezett felhasználók gyorsítótára erre hivatkozik!
2. Ha egy egyetemnek több Neptun-kiszolgálója van (pl. `neptun1...`, `neptun2...`), az elsődleges címet az `Url` mezőbe, a tartalék szervereket pedig a `Fallbacks` tömbbe vedd fel:
   ```json
   {
     "Name": "Példa Egyetem",
     "Url": "https://neptun.pelda.hu/hallgato",
     "Fallbacks": [
       "https://neptun2.pelda.hu/hallgato"
     ]
   }
   ```
3. Futtasd a `flutter test test/institute_search_test.dart` tesztet a beküldés előtt.

---

## 3. Fejlesztői környezet és Build Flavorök

### Előfeltételek
- **Flutter SDK:** `3.47.x` vagy újabb stabil verzió (Dart `>=3.5.0 <4.0.0`)
- **Java / JDK:** Java 21 (Temurin ajánlott az Android Gradle buildhez)

### Függőségek telepítése és tesztelés
```sh
flutter pub get
flutter analyze
flutter test
```

### Build Flavorök (`github` vs `playstore`)
A Google Play Áruház szabályzata tiltja az önfrissítő (`REQUEST_INSTALL_PACKAGES`) csomagokat, ezért két külön build flavor létezik:

| Flavor | Parancs | Leírás |
| --- | --- | --- |
| `github` | `flutter build apk --debug --no-shrink --flavor github --dart-define=NHNK_DISTRIBUTION=github` | Tartalmazza a GitHubos beépített frissítőt (`lib/Misc/auto_updater.dart`). |
| `playstore` | `flutter build appbundle --release --flavor playstore --dart-define=NHNK_DISTRIBUTION=playstore` | Google Play kompatibilis `.aab`, eltávolított sideload jogosultsággal. |

---

## 4. Kódolási irányelvek és Pull Request folyamat

1. **Csak olvasható (Read-Only) biztonsági elv:**
   - Az NHNK szándékosan nem hajt végre tanulmányi vagy pénzügyi kockázattal járó írási műveleteket (tárgyfelvétel, vizsgajelentkezés, tárgyleadás). Az egyetlen engedélyezett állapotmódosító hívás az üzenetek olvasottnak jelölése (`POST Messages/{id}/Posts/Processed`).
2. **Téma és Akadálymentesítés (WCAG AA):**
   - Minden új UI elemnek támogatnia kell a világos, sötét és valódi fekete (`#000000` OLED) témákat az `AppColors.getTheme()` palettán keresztül.
   - Ha színpalettát módosítasz, futtasd a `flutter test test/contrast_test.dart` tesztet.
3. **Kétnyelvűség (Magyar & Angol):**
   - Minden felhasználói felületen megjelenő szövegnek magyarul és angolul is működnie kell (`lib/language.dart` / `_t(hu, en)`).
4. **Tesztek:**
   - Új üzleti logika, dátum-/hétszámítás, gyorsítótár-módosítás vagy API-transzformáció esetén egészítsd ki a `test/` mappában lévő egységteszteket, és győződj meg róla, hogy a `flutter test` zölddel fut le.

</details>

<details>
<summary><b>English</b></summary>

Thank you for helping improve **NHNK – Unofficial Neptun Client**! Whether you are reporting a bug, adding or updating an institution's Neptun server URL, improving translations, or submitting code fixes, your contributions are welcome.

By contributing to this repository, you agree to abide by our [Code of Conduct (`CODE_OF_CONDUCT.md`)](CODE_OF_CONDUCT.md) and agree that your contributions will be licensed under the project's [MIT License (`LICENSE`)](LICENSE).

---

## 1. Protecting Personal & Student Data (Critical Rule!)

Neptun handles sensitive academic and financial records. **Never commit or paste (in commits, issues, PRs, or screenshots):**
- Real Neptun codes, passwords, 2FA/TOTP secrets, or `Bearer` JWT tokens.
- `devicecookie-*` or session cookies (`sessionCookie`).
- Personal `.ics` calendar export URLs (these URLs are self-authenticating credentials!).
- Raw JSON response bodies (`response.body`) containing real grades, messages, lecturer names, or financial items.

Files under `API-DOCS/` must only document anonymized route paths and synthetic/redacted schemas.

---

## 2. Adding or Updating an Institution URL

Institution URLs live in **`universityNameUrlPairs.json`** at the repository root and are fetched at runtime from `main`.

1. **Backwards compatibility:** Never delete or rename an existing `Name` entry, as existing installs reference it in local storage.
2. For universities with multiple Neptun servers, put the primary server in `Url` and backup servers in `Fallbacks`:
   ```json
   {
     "Name": "Example University",
     "Url": "https://neptun.example.edu/hallgato",
     "Fallbacks": [
       "https://neptun2.example.edu/hallgato"
     ]
   }
   ```
3. Run `flutter test test/institute_search_test.dart` before opening a PR.

---

## 3. Development Setup & Build Flavors

### Prerequisites
- **Flutter SDK:** `3.47.x` or newer stable (Dart `>=3.5.0 <4.0.0`)
- **Java / JDK:** Java 21 (Temurin recommended for Android Gradle builds)

### Install dependencies & run tests
```sh
flutter pub get
flutter analyze
flutter test
```

### Build Flavors (`github` vs `playstore`)
Google Play policy forbids self-updating APKs (`REQUEST_INSTALL_PACKAGES`), so the project uses two flavors:

| Flavor | Command | Description |
| --- | --- | --- |
| `github` | `flutter build apk --debug --no-shrink --flavor github --dart-define=NHNK_DISTRIBUTION=github` | Includes the GitHub in-app updater (`lib/Misc/auto_updater.dart`). |
| `playstore` | `flutter build appbundle --release --flavor playstore --dart-define=NHNK_DISTRIBUTION=playstore` | Google Play compliant `.aab` with sideload permissions stripped. |

---

## 4. Coding Guidelines & Pull Request Checklist

1. **Safety-by-Design (Read-Only Principle):**
   - NHNK intentionally avoids high-risk academic or financial write operations (course enrollment, exam registration, dropping subjects). The only state-changing call is marking messages as read (`POST Messages/{id}/Posts/Processed`).
2. **Theming & Accessibility (WCAG AA):**
   - New UI screens and widgets must use `AppColors.getTheme()` so they work across Light, Dark, and true black (`#000000` OLED) themes.
   - Verify colour changes with `flutter test test/contrast_test.dart`.
3. **Bilingual UI (Hungarian & English):**
   - User-facing strings must provide both Hungarian and English text (`lib/language.dart` / `_t(hu, en)`).
4. **Automated Tests:**
   - Add or update unit/widget tests in `test/` for any parser, cache, or logic change, and ensure `flutter test` passes before submitting your PR.

</details>
