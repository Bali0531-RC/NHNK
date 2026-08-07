package hu.bali0531.nhnk.app;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.PowerManager;
import android.provider.Settings;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "hu.bali0531.nhnk/power";

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
