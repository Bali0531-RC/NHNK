# Biztonsági irányelvek / Security Policy

<details open>
<summary><b>Magyar</b></summary>

## Támogatott verziók

Kizárólag a legfrissebb kiadási ág (`2.0.x`) kap biztonsági frissítéseket. Kérjük, mindig frissíts a legújabb verzióra (Google Play-en vagy GitHub Releases-en keresztül).

| Verzió | Támogatott | Megjegyzés |
| --- | --- | --- |
| `2.0.10+` | Igen | `RSA-OAEP` + `AES-GCM` tárolás, biometrikus zár, automatikus KeyStore önteszt |
| `2.0.0 – 2.0.9` | Frissítés javasolt | Frissíts `2.0.10` vagy újabb verzióra |
| `< 2.0.0` | Nem | Elavult; nem kap javításokat |

## Biztonsági architektúra

Az NHNK tervezésekor az elsődleges szempont az volt, hogy a hallgatói belépési és tanulmányi adatok soha ne hagyják el a felhasználó saját eszközét és az intézményi Neptun-kiszolgálót:

1. **Köztes szerver nélküli (Zero-Server) kommunikáció és TLS-validáció:**
   - Az alkalmazás közvetlenül az adott egyetem hivatalos HTTPS végpontjával kommunikál. Nem üzemeltetünk proxy-, analitikai vagy közvetítő szervert.
   - A hálózati réteg (`lib/API/cert_Configuration.dart`) az operációs rendszer natív tanúsítványtárát használja szigorú, 20 másodperces időkorláttal; érvénytelen vagy önaláírt TLS-tanúsítványokat nem fogad el.
2. **Hardveres kulcstároló (`AndroidKeyStore` / iOS Keychain):**
   - A jelszó, a munkamenet-tokenek (`JWT`, `sessionCookie`, `deviceCookie`), az `.ics` naptárlink és az opcionális 2FA (TOTP) titkos kulcs a `flutter_secure_storage` v11 segítségével kerül tárolásra:
     - **Androidon:** `RSA/ECB/OAEPWithSHA-256AndMGF1Padding` (`AndroidKeyStore`) által csomagolt `AES/GCM/NoPadding` kulcsok, indításkori integritás-ellenőrzéssel (`MainActivity.java`).
     - **iOS-en:** iOS Keychain hardveres védelemmel.
   - Az Android felhőalapú automatikus biztonsági mentés ki van kapcsolva (`android:allowBackup="false"`, `android:fullBackupContent="false"`), így a titkosított állományok nem kerülnek fel külső felhőtárhelyre.
   - Kijelentkezéskor (`DataCache.fullCleanReset()`) mind a `SharedPreferences`, mind a `FlutterSecureStorage` és az `AndroidKeyStore` kulcsok maradéktalanul törlődnek.
3. **Alapértelmezett biometrikus / PIN alkalmazászár (`lib/biometric_lock.dart`):**
   - Az alkalmazás megnyitáskor alapértelmezetten biometrikus azonosítást (ujjlenyomat, arcfelismerés) vagy a készülék képernyőzárát (`BiometricPrompt` / `KeyguardManager` / `LAContext`) kéri.
4. **Személyes adatok szűrése a diagnosztikában (PII Redaction):**
   - A fejlesztői diagnosztikai napló (`lib/dev/`) automatikusan kiszűri az önállóan hitelesítő `.ics` URL-eket, tokeneket, sütiket és jelszavakat.
5. **Kiadási integritás és jogosultság-ellenőrzés (CI/CD):**
   - A `.github/workflows/release.yml` minden kiadásnál ellenőrzi a kiadási aláírást, és garantálja, hogy a Google Play (`playstore`) build nem tartalmazza a `REQUEST_INSTALL_PACKAGES` vagy más felesleges jogosultságokat (`READ_MEDIA_*`, `FOREGROUND_SERVICE`).

## Sérülékenység bejelentése (Responsible Disclosure)

Ha biztonsági hibát vagy sérülékenységet találsz az alkalmazásban vagy a weboldalon:

- **Kérjük, NE nyiss nyilvános GitHub Issue-t** a sérülékenység részleteivel!
- Jelentsd privátban a [**GitHub Security Advisories**](https://github.com/Bali0531-RC/NHNK/security/advisories/new) felületen, vagy írj közvetlenül az **`nhnk@bali0531.hu`** e-mail címre.
- A bejelentéshez mellékeld az érintett verziót, a reprodukálás lépéseit és (ha releváns) a javasolt javítást. **Soha ne küldj valódi Neptun belépési adatokat vagy személyes tanulmányi adatokat!**
- A bejelentésekre 72 órán belül válaszolunk, és a javítás kiadása után (kérésre) feltüntetjük a nevedet a kiadási jegyzetben.

</details>

<details>
<summary><b>English</b></summary>

## Supported Versions

Only the latest release branch (`2.0.x`) receives security updates. Please keep your installation up to date via Google Play or GitHub Releases.

| Version | Supported | Notes |
| --- | --- | --- |
| `2.0.10+` | Yes | `RSA-OAEP` + `AES-GCM` storage, default biometric lock, startup KeyStore self-test |
| `2.0.0 – 2.0.9` | Upgrade advised | Please update to `2.0.10` or newer |
| `< 2.0.0` | No | End of life |

## Security Architecture

NHNK is designed so that student credentials and academic records never leave the user's device and their institution's official Neptun server:

1. **Zero-Server Direct TLS Communication:**
   - The client connects directly to the institution's HTTPS Neptun server. There is no middleman proxy, analytics backend, or telemetry collector.
   - Network requests (`lib/API/cert_Configuration.dart`) enforce platform TLS certificate validation with a 20-second timeout; invalid or self-signed certificates are rejected.
2. **Hardware-Backed Credential Storage (`AndroidKeyStore` / iOS Keychain):**
   - Passwords, session tokens (`JWT`, `sessionCookie`, `deviceCookie`), `.ics` calendar export URLs, and optional 2FA (TOTP) secrets are stored via `flutter_secure_storage` v11:
     - **Android:** `AES/GCM/NoPadding` keys wrapped with `RSA/ECB/OAEPWithSHA-256AndMGF1Padding` in `AndroidKeyStore`, verified on startup (`MainActivity.java`).
     - **iOS:** Hardware-backed iOS Keychain.
   - Android cloud auto-backup is disabled (`android:allowBackup="false"`, `android:fullBackupContent="false"`) so encrypted storage files are never uploaded to cloud backups.
   - Logging out (`DataCache.fullCleanReset()`) wipes `SharedPreferences`, `FlutterSecureStorage`, and `AndroidKeyStore` aliases completely.
3. **Default Biometric / Device Credential Lock (`lib/biometric_lock.dart`):**
   - Prompts for fingerprint, face unlock, or device screen lock (`BiometricPrompt` / `KeyguardManager` / `LAContext`) by default on app launch.
4. **PII Redaction in Diagnostics:**
   - Optional on-device diagnostic logs (`lib/dev/`) automatically redact self-authenticating `.ics` URLs, tokens, cookies, and credentials.
5. **Release Integrity & Permission Verification (CI/CD):**
   - `.github/workflows/release.yml` verifies release signing certificates and ensures the `playstore` flavor strips `REQUEST_INSTALL_PACKAGES`, `READ_MEDIA_*`, and `FOREGROUND_SERVICE` permissions on every release.

## Reporting a Vulnerability

If you discover a security vulnerability in the NHNK app or website:

- **Please do NOT open a public GitHub Issue** with exploit details.
- Report it privately via [**GitHub Security Advisories**](https://github.com/Bali0531-RC/NHNK/security/advisories/new) or email **`nhnk@bali0531.hu`**.
- Include the affected version and reproduction steps. **Never include real Neptun credentials or personal student records.**
- Reports are acknowledged within 72 hours, and credit is given in the release notes upon disclosure if desired.

</details>
