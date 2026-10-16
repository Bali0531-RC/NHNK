package hu.bali0531.nhnk.app;

import android.app.Activity;
import android.app.KeyguardManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.hardware.biometrics.BiometricManager;
import android.hardware.biometrics.BiometricPrompt;
import android.net.Uri;
import android.os.Build;
import android.os.CancellationSignal;
import android.os.PowerManager;
import android.provider.Settings;
import android.util.Base64;

import androidx.annotation.NonNull;

import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.security.KeyStore;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "hu.bali0531.nhnk/power";
    private static final String BIOMETRIC_CHANNEL = "hu.bali0531.nhnk/biometrics";
    private static final int REQ_CONFIRM_CREDENTIAL = 4102;

    private MethodChannel.Result pendingAuthResult;

    /**
     * Vendor "protected apps" screens. These sit outside Android's own battery
     * optimisation list, so being exempt there does not satisfy them. Ordered most
     * to least specific per vendor; the manifest <queries> block must list every
     * package named here or package visibility hides them on Android 11+.
     */
    private static final String[][] OEM_SCREENS = {
            // Honor split from Huawei and renamed the package, so this must come first:
            // an Honor device carries no com.huawei.systemmanager at all.
            {"com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"},
            {"com.hihonor.systemmanager", "com.hihonor.systemmanager.appcontrol.activity.StartupAppControlActivity"},
            // Huawei
            {"com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"},
            {"com.huawei.systemmanager", "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity"},
            {"com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"},
            // Xiaomi
            {"com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"},
            {"com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity"},
            // Oppo
            {"com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"},
            {"com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"},
            {"com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"},
            // Vivo
            {"com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"},
            {"com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"},
            // OnePlus
            {"com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"},
            // Samsung
            {"com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity"},
            // Asus
            {"com.asus.mobilemanager", "com.asus.mobilemanager.autostart.AutoStartActivity"},
    };

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "isIgnoringBatteryOptimizations":
                            result.success(isIgnoringBatteryOptimizations());
                            break;
                        case "openBatteryOptimizationSettings":
                            result.success(openBatteryOptimizationSettings());
                            break;
                        case "hasOemBackgroundSettings":
                            result.success(resolveOemScreen() != null);
                            break;
                        case "openOemBackgroundSettings":
                            result.success(openOemBackgroundSettings());
                            break;
                        default:
                            result.notImplemented();
                    }
                });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), BIOMETRIC_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "isDeviceSupported":
                            result.success(isDeviceSecure());
                            break;
                        case "authenticate":
                            String title = call.argument("title");
                            String subtitle = call.argument("subtitle");
                            authenticateUser(
                                    title != null ? title : "NHNK",
                                    subtitle != null ? subtitle : "",
                                    result
                            );
                            break;
                        case "readLegacySecureStorage":
                            result.success(readLegacyV9SecureStorage());
                            break;
                        case "clearLegacySecureStorage":
                            clearLegacyV9SecureStorageKey();
                            result.success(true);
                            break;
                        default:
                            result.notImplemented();
                    }
                });
    }

    /**
     * Decrypts entries written by flutter_secure_storage v9 (RSA/ECB/PKCS1Padding +
     * AES/CBC/PKCS7Padding) so we can jump straight from v9 to v11 without losing
     * credentials on upgrade.
     */
    private Map<String, String> readLegacyV9SecureStorage() {
        Map<String, String> out = new HashMap<>();
        try {
            SharedPreferences keyPrefs = getSharedPreferences("FlutterSecureKeyStorage", Context.MODE_PRIVATE);
            String wrappedAesB64 = keyPrefs.getString(
                    "VGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdlIEFFUyBLZXkK",
                    null
            );
            if (wrappedAesB64 == null || wrappedAesB64.isEmpty()) {
                return out;
            }

            KeyStore ks = KeyStore.getInstance("AndroidKeyStore");
            ks.load(null);
            String rsaAlias = getPackageName() + ".FlutterSecureStoragePluginKey";
            Key privateKey = ks.getKey(rsaAlias, null);
            if (privateKey == null) {
                return out;
            }

            Cipher rsaCipher = Cipher.getInstance("RSA/ECB/PKCS1Padding", "AndroidKeyStoreBCWorkaround");
            rsaCipher.init(Cipher.UNWRAP_MODE, privateKey);
            Key aesKey = rsaCipher.unwrap(
                    Base64.decode(wrappedAesB64, Base64.DEFAULT),
                    "AES",
                    Cipher.SECRET_KEY
            );

            SharedPreferences dataPrefs = getSharedPreferences("FlutterSecureStorage", Context.MODE_PRIVATE);
            String prefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg_";
            Cipher aesCipher = Cipher.getInstance("AES/CBC/PKCS7Padding");

            for (Map.Entry<String, ?> entry : dataPrefs.getAll().entrySet()) {
                String rawKey = entry.getKey();
                Object rawVal = entry.getValue();
                if (!(rawVal instanceof String) || !rawKey.startsWith(prefix) || rawKey.endsWith("_BACKUP")) {
                    continue;
                }
                try {
                    byte[] decoded = Base64.decode((String) rawVal, Base64.DEFAULT);
                    if (decoded.length <= 16) {
                        continue;
                    }
                    byte[] iv = new byte[16];
                    System.arraycopy(decoded, 0, iv, 0, 16);
                    int payloadSize = decoded.length - 16;
                    byte[] payload = new byte[payloadSize];
                    System.arraycopy(decoded, 16, payload, 0, payloadSize);

                    aesCipher.init(Cipher.DECRYPT_MODE, aesKey, new IvParameterSpec(iv));
                    String cleartext = new String(aesCipher.doFinal(payload), StandardCharsets.UTF_8);
                    out.put(rawKey.substring(prefix.length()), cleartext);
                } catch (Exception ignored) {
                    // Entry is already encrypted with v11 AES-GCM; skip it.
                }
            }
        } catch (Exception ignored) {
        }
        return out;
    }

    private void clearLegacyV9SecureStorageKey() {
        try {
            SharedPreferences keyPrefs = getSharedPreferences("FlutterSecureKeyStorage", Context.MODE_PRIVATE);
            keyPrefs.edit()
                    .remove("VGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdlIEFFUyBLZXkK")
                    .apply();
        } catch (Exception ignored) {
        }
    }

    private boolean isDeviceSecure() {
        KeyguardManager km = (KeyguardManager) getSystemService(Context.KEYGUARD_SERVICE);
        return km != null && km.isDeviceSecure();
    }

    private void authenticateUser(String title, String subtitle, MethodChannel.Result result) {
        if (!isDeviceSecure()) {
            result.success(true);
            return;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                final AtomicBoolean completed = new AtomicBoolean(false);
                BiometricPrompt prompt = new BiometricPrompt.Builder(this)
                        .setTitle(title)
                        .setSubtitle(subtitle)
                        .setAllowedAuthenticators(
                                BiometricManager.Authenticators.BIOMETRIC_STRONG
                                        | BiometricManager.Authenticators.BIOMETRIC_WEAK
                                        | BiometricManager.Authenticators.DEVICE_CREDENTIAL
                        )
                        .build();

                prompt.authenticate(
                        new CancellationSignal(),
                        getMainExecutor(),
                        new BiometricPrompt.AuthenticationCallback() {
                            @Override
                            public void onAuthenticationSucceeded(BiometricPrompt.AuthenticationResult authResult) {
                                if (completed.compareAndSet(false, true)) {
                                    result.success(true);
                                }
                            }

                            @Override
                            public void onAuthenticationError(int errorCode, CharSequence errString) {
                                if (completed.compareAndSet(false, true)) {
                                    result.success(false);
                                }
                            }
                        }
                );
                return;
            } catch (Exception ignored) {
                // Fall back to Keyguard credential intent below if BiometricPrompt fails on custom OEM ROMs.
            }
        }
        launchConfirmDeviceCredential(title, subtitle, result);
    }

    @SuppressWarnings("deprecation")
    private void launchConfirmDeviceCredential(String title, String subtitle, MethodChannel.Result result) {
        KeyguardManager km = (KeyguardManager) getSystemService(Context.KEYGUARD_SERVICE);
        if (km == null) {
            result.success(true);
            return;
        }
        Intent intent = km.createConfirmDeviceCredentialIntent(title, subtitle);
        if (intent == null) {
            result.success(true);
            return;
        }
        if (pendingAuthResult != null) {
            pendingAuthResult.success(false);
        }
        pendingAuthResult = result;
        try {
            startActivityForResult(intent, REQ_CONFIRM_CREDENTIAL);
        } catch (Exception e) {
            pendingAuthResult = null;
            result.success(false);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQ_CONFIRM_CREDENTIAL && pendingAuthResult != null) {
            MethodChannel.Result res = pendingAuthResult;
            pendingAuthResult = null;
            res.success(resultCode == Activity.RESULT_OK);
        }
    }

    private boolean isIgnoringBatteryOptimizations() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true;
        }
        PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
        return pm != null && pm.isIgnoringBatteryOptimizations(getPackageName());
    }

    /**
     * Opens the system list so the user exempts the app themselves. The direct-grant
     * action is deliberately not used: Play only permits it where power management
     * breaks the app's core function, which is not the case here.
     */
    private boolean openBatteryOptimizationSettings() {
        try {
            Intent intent = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
            return true;
        } catch (Exception ignored) {
            try {
                Intent fallback = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                fallback.setData(Uri.parse("package:" + getPackageName()));
                fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(fallback);
                return true;
            } catch (Exception alsoIgnored) {
                return false;
            }
        }
    }

    private Intent resolveOemScreen() {
        PackageManager pm = getPackageManager();
        for (String[] screen : OEM_SCREENS) {
            Intent intent = new Intent();
            intent.setComponent(new ComponentName(screen[0], screen[1]));
            if (pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY) != null) {
                return intent;
            }
        }
        return null;
    }

    private boolean openOemBackgroundSettings() {
        Intent intent = resolveOemScreen();
        if (intent == null) {
            return false;
        }
        try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
            return true;
        } catch (Exception ignored) {
            return false;
        }
    }
}
