import 'package:flutter/services.dart';

import 'platform_support.dart';

/// Thin wrapper over the battery optimisation bits of MainActivity.
class PowerSettings{
  static const MethodChannel _channel = MethodChannel('hu.bali0531.nhnk/power');

  static Future<bool> isExempt() async{
    if(!AppPlatform.isMobile) return true;
    try{
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
    }
    on MissingPluginException{
      return true;
    }
    catch(_){
      return true;
    }
  }

  static Future<void> openSettings() async{
    if(!AppPlatform.isMobile) return;
    try{
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    }
    catch(_){ }
  }

  /// True only on vendors that ship their own "protected apps" list.
  static Future<bool> hasOemSettings() async{
    if(!AppPlatform.isMobile) return false;
    try{
      return await _channel.invokeMethod<bool>('hasOemBackgroundSettings') ?? false;
    }
    catch(_){
      return false;
    }
  }

  static Future<void> openOemSettings() async{
    if(!AppPlatform.isMobile) return;
    try{
      await _channel.invokeMethod('openOemBackgroundSettings');
    }
    catch(_){ }
  }
}
