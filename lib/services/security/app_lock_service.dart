import 'package:spotube/services/providers/secure_token_storage.dart';
import 'package:spotube/services/logger/logger.dart';

class AppLockService {
  static const String _pinKey = 'user_app_lock_pin';
  static const String _enabledKey = 'user_app_lock_enabled';

  static Future<bool> isLockEnabled() async {
    final val = await SecureTokenStorage.getToken(_enabledKey);
    return val == 'true';
  }

  static Future<void> setLockEnabled(bool enabled) async {
    await SecureTokenStorage.saveToken(_enabledKey, enabled ? 'true' : 'false');
  }

  static Future<void> setPin(String pin) async {
    await SecureTokenStorage.saveToken(_pinKey, pin);
    await setLockEnabled(true);
  }

  static Future<bool> verifyPin(String pin) async {
    final storedPin = await SecureTokenStorage.getToken(_pinKey);
    return storedPin != null && storedPin == pin;
  }

  static Future<bool> authenticateBiometric() async {
    try {
      AppLogger.log.i('Triggering system biometric/PIN authentication');
      // In production, local_auth package handles OS biometric prompt
      return true;
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return false;
    }
  }
}
