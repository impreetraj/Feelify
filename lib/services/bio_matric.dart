import 'package:local_auth/local_auth.dart';

class BioMatric {
  final LocalAuthentication localauth = LocalAuthentication();

  Future<bool> authenticateLocally() async {
    try {
      final bool isSupported = await localauth.isDeviceSupported();
      if (!isSupported) {
        return true;
      }

      return await localauth.authenticate(
        localizedReason: "Please authenticate to access the app",
      );
    } on LocalAuthException catch (e) {
      final code = e.code.toString();
      if (code == 'NotEnrolled' || code == 'PasscodeNotSet' || code == 'NotAvailable' || code == 'noBiometricHardware') {
        return true; 
      }
      return false;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('notenrolled') || errorStr.contains('passcodenotset') || errorStr.contains('notavailable')) {
        return true;
      }
      return false;
    }
  }
}

