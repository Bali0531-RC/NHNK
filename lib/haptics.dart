import 'package:nhnk/storage.dart';
import 'package:vibration/vibration.dart';
import 'package:nhnk/platform_support.dart';

class AppHaptics{
  static bool _vibrationStateCached = true;

  static void initialise(){
    Future.delayed(Duration.zero, ()async{
      final value = await DataCache.getNeedsHaptics()!;
      if(value){
        await setVibrationState(true);
        return;
      }
      _vibrationStateCached = value;
    });
  }

  static Future<bool> _canAppVibrate()async{
    if(!AppPlatform.isMobile){
      return false;
    }
    final canVibrate = await Vibration.hasVibrator();
    final settingsVibrate = await DataCache.getNeedsHaptics()!;
    if(!canVibrate || !settingsVibrate){
      return false;
    }
    return true;
  }

  static Future<void> setVibrationState(bool canVibrate)async{
    await DataCache.setNeedsHaptics(canVibrate ? 1 : 0);
    _vibrationStateCached = canVibrate;
  }

  static Future<bool> getVibrationState()async{
    return await DataCache.getNeedsHaptics()!;
  }

  static bool getVibrationStateSync(){
    return _vibrationStateCached;
  }

  /// Android's createWaveform wants one amplitude per pattern slot, and the pattern
  /// alternates wait, vibrate, wait, vibrate. Passing amplitudes only for the vibrate
  /// slots threw IllegalArgumentException on every device with amplitude control, so
  /// no haptic in the app ever actually fired. Amplitudes are 1-255.
  static List<int> buildAmplitudes(List<int> pattern, List<int> vibrateAmplitudes) {
    final amplitudes = <int>[];
    var next = 0;
    for (var i = 0; i < pattern.length; i++) {
      if (i.isEven) {
        amplitudes.add(0);
        continue;
      }
      amplitudes.add(next < vibrateAmplitudes.length ? vibrateAmplitudes[next++] : 255);
    }
    return amplitudes;
  }

  static Future<void> _waveform(List<int> pattern, List<int> vibrateAmplitudes) async {
    await Vibration.vibrate(
      pattern: pattern,
      intensities: buildAmplitudes(pattern, vibrateAmplitudes),
    );
  }

  static void lightImpact(){
    Future.delayed(Duration.zero, ()async{
      final canVibrate = await _canAppVibrate();
      if(!canVibrate){
        return;
      }
      await _waveform([0, 10], [70]);
    });
  }

  static void mediumImpact(){
    Future.delayed(Duration.zero, ()async{
      final canVibrate = await _canAppVibrate();
      if(!canVibrate){
        return;
      }
      await _waveform([0, 16], [130]);
    });
  }

  static void heavyImpact(){
    Future.delayed(Duration.zero, ()async{
      final canVibrate = await _canAppVibrate();
      if(!canVibrate){
        return;
      }
      await _waveform([0, 35], [200]);
    });
  }


  static void textEditingImpact(){
    Future.delayed(Duration.zero, ()async{
      final canVibrate = await _canAppVibrate();
      if(!canVibrate){
        return;
      }
      await _waveform([0, 1], [40]);
    });
  }

  static void attentionImpact(){
    Future.delayed(Duration.zero, ()async{
      final canVibrate = await _canAppVibrate();
      if(!canVibrate){
        return;
      }
      await _waveform([0, 35, 125, 35], [150, 100]);
    });
  }

  static void attentionLightImpact(){
    Future.delayed(Duration.zero, ()async{
      final canVibrate = await _canAppVibrate();
      if(!canVibrate){
        return;
      }
      await _waveform([0, 15, 100, 15], [100, 60]);
    });
  }

  static void bounceImpact(){
    Future.delayed(Duration.zero, ()async{
      final canVibrate = await _canAppVibrate();
      if(!canVibrate){
        return;
      }
      await _waveform(
        [0, 45, 75, 35, 70, 25, 45, 15, 25, 10, 10, 10, 5, 5],
        [200, 170, 140, 110, 80, 55, 35],
      );
    });
  }
}