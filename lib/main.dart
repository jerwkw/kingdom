import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'config/firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      if (kIsWeb) {
        await Firebase.initializeApp(options: webFirebaseOptions);
      } else {
        await Firebase.initializeApp();
      }
    }

    // Emulator use is opt-in so localhost can also exercise the real project.
    const useFirebaseEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
    if (useFirebaseEmulators) {
      debugPrint(
        '[Firebase]: Localhost detected. Connecting to local Firebase Emulators...',
      );
      try {
        await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
        FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      } catch (e) {
        debugPrint('[Firebase Emulator Warning]: $e');
      }
    }
  } catch (e) {
    debugPrint('[Firebase Init Warning]: $e');
  }

  runApp(const ProviderScope(child: KingdomApp()));
}

class KingdomApp extends ConsumerWidget {
  const KingdomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    // Get current authenticated user (with fallback to FirebaseAuth singleton instance)
    final currentUser =
        authState.value ?? ref.read(authInstanceProvider).currentUser;

    return MaterialApp(
      title: 'Kingdom — Church Accountability App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
      ),
      home: () {
        // 1. If no user is authenticated at all, show OnboardingScreen (Sign-in view)
        if (currentUser == null) {
          return const OnboardingScreen();
        }

        // 2. User is authenticated. Evaluate profile state.
        final previousProfile = userProfileAsync.valueOrNull;

        return userProfileAsync.when(
          data: (profile) {
            if (profile != null || previousProfile != null) {
              return const MainShell();
            }
            // User signed in but profile not set up yet
            return const OnboardingScreen();
          },
          loading: () {
            if (previousProfile != null) {
              return const MainShell();
            }
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
          error: (err, _) {
            if (previousProfile != null) {
              return const MainShell();
            }
            return Scaffold(body: Center(child: Text('Profile Error: $err')));
          },
        );
      }(),
    );
  }
}
