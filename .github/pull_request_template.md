## Összefoglaló / Summary

<!-- Írd le röviden, mit változtat ez a Pull Request és miért. / Briefly describe what this Pull Request changes and why. -->


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
- [ ] **Kétnyelvűség (Bilingual UI):** Az új/módosított feliratok magyarul és angolul is szerepelnek (`lib/language.dart` / `_t(hu, en)`).
- [ ] **Témák & Kontraszt (Themes & OLED):** Az új UI elemek az `AppColors.getTheme()` palettát használják (világos, sötét és `#000000` OLED témában is olvashatóak).
- [ ] **Intézménylista kompatibilitás (`universityNameUrlPairs.json`):** Meglévő `Name` kulcsot nem neveztem át és nem töröltem.
- [ ] **Tesztek (`flutter test`):** A helyi tesztek és a `flutter analyze` hiba nélkül lefutottak.
