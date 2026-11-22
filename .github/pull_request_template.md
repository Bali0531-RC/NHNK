## Összefoglaló / Summary

<!-- Írd le röviden, mit változtat ez a Pull Request és miért. / Briefly describe what this Pull Request changes and why. -->


## Érintett platform / Affected Platform

- [ ] **Android / Web Demo** (`lib/`, `android/`, `web/` — Flutter / Dart)
- [ ] **iOS** (`ios-app/` — Expo / React Native)
- [ ] **Közös erőforrások / Dokumentáció** (`universityNameUrlPairs.json`, `API-DOCS/`, `.github/`, `README.md`)

## Kapcsolódó Issue / Related Issue

<!-- Pl. Fixes #123 / e.g. Fixes #123 -->


## Változtatás típusa / Type of Change

- [ ] Hibajavítás / Bug fix (`fix`)
- [ ] Új funkció / New feature (`feat`)
- [ ] Intézményi URL / szerver frissítés (`universityNameUrlPairs.json`)
- [ ] Fordítás / UI / Téma (`i18n`, `theme`)
- [ ] Dokumentáció / CI / Tesztek (`docs`, `ci`, `test`)

## Ellenőrzőlista / Checklist

- [ ] **Nincs személyes adat (No PII):** A commitok, tesztek és képernyőképek nem tartalmaznak valódi Neptun-kódot, jelszót, JWT tokent, `devicecookie`-t, `.ics` URL-t vagy személyes tanulmányi adatot.
- [ ] **Kétnyelvűség (Bilingual UI):** Az új/módosított feliratok magyarul és angolul is szerepelnek.
- [ ] **Témák & Kontraszt (Themes & OLED):** Az új UI elemek támogatják a világos, sötét és OLED témákat.
- [ ] **Intézménylista kompatibilitás (`universityNameUrlPairs.json`):** Meglévő `Name` kulcsot nem neveztem át és nem töröltem.
- [ ] **Tesztek & Analízis:** A helyi ellenőrzések (`flutter test` / `flutter analyze` vagy `ios-app` alatt `npx tsc --noEmit`) hiba nélkül lefutottak.
