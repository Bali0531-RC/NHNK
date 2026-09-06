import 'package:nhnk/platform_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nhnk/API/api_coms.dart' as api;
import 'package:nhnk/colors.dart';
import 'package:nhnk/haptics.dart';
import 'package:nhnk/language.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../storage.dart';
import '../startup_trace.dart';
import 'main_page.dart' as main_page;
import 'onboarding/onboarding_steps.dart' as onboarding;

class Splitter extends StatefulWidget{
  const Splitter({super.key});
  @override
  State<StatefulWidget> createState() => _SplitterState();
}
class _SplitterState extends State<Splitter>{
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: AppColors.isDarktheme() ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: AppColors.getTheme().rootBackground, // navigation bar color
      statusBarColor: AppColors.getTheme().rootBackground, // status bar color
    ));

    DataCache.loadData().then((value) async {
      StartupTrace.mark('loadData');
      AppHaptics.initialise();
      if(((await getInt('NextFirstWeekCacheTime')) ?? 0) < DateTime.now().millisecondsSinceEpoch){
        DataCache.setHasCachedFirstWeekEpoch(0);
        saveInt('NextFirstWeekCacheTime', DateTime.now().add(Duration(days: 1)).millisecondsSinceEpoch);
      }
      final flag = DataCache.getHasCachedFirstWeekEpoch();

      if(flag != null && !flag && DataCache.getHasNetwork() && DataCache.getHasLogin()!){
        Future.delayed(Duration.zero, () async{
          final firstWeekOfSemester = await api.InstitutesRequest.getFirstStudyweek();
          DataCache.setHasCachedFirstWeekEpoch(1);
          DataCache.setFirstWeekEpoch(firstWeekOfSemester);
        });
      }
      else if(flag != null && !flag){
        DataCache.setFirstWeekEpoch(-1);
      }

      final flag2 = DataCache.getIsInstalledFromGPlay(excludeDefaultState: false);
      if(flag2 == 0){
        final pinfo = await PackageInfo.fromPlatform();
        StartupTrace.mark('PackageInfo.fromPlatform');
        DataCache.setIsInstalledFromGPlay(pinfo.installerStore == 'com.android.vending' ? 2 : 1);
      }
    }).then((value)async{
      await AppStrings.loadDownloadedLanguageData(context);
      StartupTrace.mark('loadDownloadedLanguageData');
      Future.delayed(Duration.zero,()async{
        await api.Language.getAllLanguages();
      });
      Future.delayed(Duration.zero,()async{
        await api.Coloring.getAllThemes();
      });
    }).then((value) {
      Navigator.popUntil(context, (route) => route.willHandlePopInternally);
      // The web build exists only to let people try the app from the site. A real
      // login could not work anyway: Neptun servers send no CORS headers, and the
      // site must not invite anyone to type institutional credentials into a page.
      if (AppPlatform.isWeb) {
        Future.microtask(() async {
          await api.InstitutesRequest.validateLoginCredentialsUrl('', 'DEMO', 'DEMO');
          await DataCache.setUsername('DEMO');
          await DataCache.setPassword('DEMO');
          await DataCache.setInstituteUrl('');
          await DataCache.setHasLogin(1);
          await DataCache.setHasAcceptedTerms(1);
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const main_page.HomePage()),
          );
        });
        return;
      }
      if (DataCache.getHasLogin() != null && DataCache.getHasLogin()!) {
        StartupTrace.mark('push HomePage');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const main_page.HomePage()),
        );
        return;
      }
      // Terms are the first step of onboarding rather than a wall in front of it.
      // Existing users who already accepted are not re-prompted.
      if (!DataCache.getHasAcceptedTerms()) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const onboarding.OnboardingTermsPage()),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const onboarding.OnboardingWelcomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: SizedBox(
                height: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.20 : MediaQuery.of(context).size.height * 0.20,
                width: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.20 : MediaQuery.of(context).size.height * 0.20,
                child: CircularProgressIndicator(
                  color: AppColors.getTheme().textColor,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              api.Generic.randomLoadingComment(DataCache.getNeedFamilyFriendlyComments()!),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.getTheme().textColor.withValues(alpha: .2),
                  fontWeight: FontWeight.w300,
                  fontSize: 10
              ),
            )
          ],
        )
    );
  }
}