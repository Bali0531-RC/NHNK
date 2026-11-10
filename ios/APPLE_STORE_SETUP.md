# Apple App Store & TestFlight – Beállítási útmutató (NHNK)

Ez a dokumentum lépésről lépésre leírja, hogyan tudjátok a szaktársad **Apple Developer Program** előfizetésével (`$99/év`) teljesen automatizáltan publikálni az **NHNK** alkalmazást az Apple App Store-ba és a TestFlightba.

---

## 1. Hozzáférések megosztása (App Store Connect)

1. A szaktársad lépjen be az **[App Store Connect](https://appstoreconnect.apple.com) → Users and Access** felületre.
2. Kattintson a **`+`** gombra, és hívja meg a **te Apple ID e-mail-címedet**:
   - **Role:** `Admin` (vagy `App Manager` + `Developer`)
   - **Additional Resources:** pipálja be az *Access to Certificates, Identifiers & Profiles* opciót.
3. Így mindketten látjátok az App Store Connectet, és **később bármikor 1 kattintással átadható az app (`Transfer App`)** egy másik Apple Developer fiókra a Bundle ID, az értékelések és a felhasználók elvesztése nélkül.

---

## 2. App ID és Alkalmazás létrehozása (Egyszeri lépés – ~5 perc)

1. **[developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers)**:
   - Hozzatok létre egy új **App ID**-t:
     - **Description:** `NHNK`
     - **Bundle ID (Explicit):** `hu.bali0531.nhnk.app`
2. **[appstoreconnect.apple.com/apps](https://appstoreconnect.apple.com/apps)**:
   - Kattintsatok a **`+` → New App** gombra:
     - **Platforms:** iOS
     - **Name:** `NHNK – Kliens Neptunhoz`
     - **Primary Language:** Hungarian (`Magyar`)
     - **Bundle ID:** `hu.bali0531.nhnk.app`
     - **SKU:** `hu.bali0531.nhnk.app`

---

## 3. A 7 GitHub Secret előállítása (Egyszeri lépés – ~10 perc)

A GitHub Actions (`.github/workflows/release.yml`) automatikusan aláírja és feltölti az `.ipa`-t minden `v*` tag pusholásakor, ha az alábbi 7 secret be van állítva a GitHub repóban (**Settings → Secrets and variables → Actions**):

| Secret neve | Mit kell beleírni? |
| --- | --- |
| `IOS_TEAM_ID` | A 10 karakteres Apple Developer **Team ID** (pl. `A1B2C3D4E5`, megtalálható a [Membership details](https://developer.apple.com/account#MembershipDetailsCard) alatt). |
| `IOS_DIST_CERT_BASE64` | Egy **Apple Distribution** típusú `.p12` tanúsítvány `base64` kódolva (`base64 -w0 dist.p12`). |
| `IOS_DIST_CERT_PASSWORD` | A `.p12` exportálásakor megadott jelszó. |
| `IOS_PROVISION_PROFILE_BASE64` | Egy **App Store Connect** típusú Provisioning Profile (`hu.bali0531.nhnk.app` App ID-hoz) `.mobileprovision` fájlja `base64` kódolva (`base64 -w0 NHNK_AppStore.mobileprovision`). |
| `APPSTORE_API_KEY_ID` | Az App Store Connectben (*Users and Access → Integrations → App Store Connect API*) generált kulcs **Key ID**-ja (pl. `2X9R4HXF34`). |
| `APPSTORE_ISSUER_ID` | Ugyanezen az oldalon felül látható **Issuer ID** (UUID formátum). |
| `APPSTORE_API_PRIVATE_KEY` | A letöltött `AuthKey_XXXXXXXX.p8` fájl teljes szöveges tartalma (`-----BEGIN PRIVATE KEY-----` ... `-----END PRIVATE KEY-----`). |

### Mac nélkül (Linuxon) hogyan generálható le a `.p12` tanúsítvány?
Ha egyikőtöknek sincs kéznél Mac, Linuxon 3 paranccsal legenerálható a `.p12`:
```bash
# 1. Privát kulcs és CSR generálása (ezt a .certSigningRequest fájlt kell feltölteni a developer.apple.com -> Certificates -> + -> Apple Distribution alá):
openssl req -new -newkey rsa:2048 -nodes -keyout ios_distribution.key -out ios_distribution.certSigningRequest -subj "/emailAddress=contact@nhnk.hu/CN=NHNK Distribution/C=HU"

# 2. Az Apple-től letöltött distribution.cer átalakítása PEM-re, majd .p12-re:
openssl x509 -in distribution.cer -inform DER -out distribution.pem -outform PEM
openssl pkcs12 -export -inkey ios_distribution.key -in distribution.pem -out dist.p12 -passout pass:VALAMI_EROS_JELSZO

# 3. Base64-olás a GitHub Secretbe:
base64 -w0 dist.p12
```

---

## 4. App Store Review előkészítés (Hogy elsőre átmenjen az ellenőrzésen)

Az `apple-release` ágon már minden kódoldali Apple-követelmény be van állítva:
- **Külső támogatási (`Donate`) linkek elrejtve iOS-en** (`lib/Misc/app_drawer.dart`, `lib/Pages/about_page.dart`) — így megfelel az App Store Guideline 3.1.1 szabálynak.
- **`PrivacyInfo.xcprivacy` bekötve** (`ios/Runner/PrivacyInfo.xcprivacy`) — így az `ITMS-91053` (Required Reason API: `UserDefaults`, `FileTimestamp`, `SystemBootTime`, `DiskSpace`) automatikusan elfogadásra kerül.
- **`ITSAppUsesNonExemptEncryption = false`** (`ios/Runner/Info.plist`) — így a TestFlight / App Store nem kér minden feltöltésnél export-titkosítási nyilatkozatot.
- **Értesítések (`UNUserNotificationCenter`) és háttérfrissítés (`UIBackgroundModes`)** beállítva.

### Mit írjatok az App Store Connect „App Review Information” részébe?
- **Sign-in required:** pipa be
- **User name:** `DEMO`
- **Password:** `DEMO`
- **Notes for Reviewer:**
  > NHNK is an open-source student client for the Hungarian Neptun university system.
  > To test all features without a live university account:
  > 1. Either tap **"Just let me look around first" ("Előbb körülnéznék")** on the welcome screen to enter Demo Mode immediately, OR
  > 2. Select any institution and sign in with Username: `DEMO` and Password: `DEMO`.
  > Demo Mode populates the timetable, grades, GPA calculator, upcoming exams, statistics, periods, and messages with sample data.
- **Privacy Policy URL:** `https://nhnk.hu/adatvedelem`
- **Support URL:** `https://nhnk.hu`
- **Marketing URL:** `https://nhnk.hu`
