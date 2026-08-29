import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'welcome_page.dart';

// Development-only Android App Check debug secret. Register this UUID in
// Firebase Console → App Check → your Android app → Manage debug tokens.
// Never used in release builds (kDebugMode is false there).
const _kAndroidAppCheckDebugToken = 'a8f3c1d2-4b9e-4e6a-9c71-2d5f08b4e6c3';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    // Required for Firebase AI Logic after App Check enforcement.
    // Debug builds use the App Check Debug Provider so emulators / unsigned
    // APKs are not rejected by Play Integrity ("App attestation failed").
    if (kDebugMode) {
      debugPrint('');
      debugPrint('======== FIREBASE APP CHECK DEBUG TOKEN (ANDROID) ========');
      debugPrint(_kAndroidAppCheckDebugToken);
      debugPrint(
        'Register this token in Firebase Console → App Check → Apps → '
        'your Android app → overflow menu → Manage debug tokens',
      );
      debugPrint('==========================================================');
      debugPrint('');
    }

    await FirebaseAppCheck.instance.activate(
      // ignore: deprecated_member_use
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      // ignore: deprecated_member_use
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.deviceCheck,
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider(debugToken: _kAndroidAppCheckDebugToken)
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleDeviceCheckProvider(),
      providerWindows: const WindowsDebugProvider(),
    );

    if (kDebugMode) {
      try {
        await FirebaseAppCheck.instance.getToken(true);
        debugPrint('Firebase App Check debug token exchange succeeded.');
      } catch (e) {
        debugPrint(
          'Firebase App Check token exchange failed until the debug token '
          'is registered in Firebase Console: $e',
        );
      }
    }
  } catch (e) {
    debugPrint('App Check activation failed: $e');
  }

  // Clear any persisted Firebase Authentication session on fresh app start
  // so Welcome Page and Login Page appear every time the app is opened.
  try {
    await FirebaseAuth.instance.signOut();
  } catch (e) {
    debugPrint('Startup sign-out failed: $e');
  }

  runApp(const SmartFarmerApp());
}

class SmartFarmerApp extends StatelessWidget {
  const SmartFarmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Farmer',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8F3),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3E7C3A),
        ),
      ),

      // App always opens to Welcome Page
      home: const WelcomePage(),
    );
  }
}