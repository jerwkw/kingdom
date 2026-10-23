import 'package:firebase_core/firebase_core.dart';

/// Public web client config per Firebase project. Select with
/// `--dart-define=FIREBASE_ENV=staging`; anything else builds for production.
const firebaseEnv = String.fromEnvironment('FIREBASE_ENV', defaultValue: 'prod');

const _prodWebOptions = FirebaseOptions(
  apiKey: "AIzaSyD1egObGqHZAge1XmiOIjkqtkgz1ClSPi4",
  appId: "1:3839328656:web:59dd7194795f24c222f315",
  messagingSenderId: "3839328656",
  projectId: "church-app-f8a55",
  authDomain: "church-app-f8a55.firebaseapp.com",
  storageBucket: "church-app-f8a55.firebasestorage.app",
);

const _stagingWebOptions = FirebaseOptions(
  apiKey: "AIzaSyCD9IqSYCL3-ETD4VXiQpqCiI6wGNHfZCM",
  appId: "1:1030504830885:web:b1d0b26d0d8b456bb7ba4c",
  messagingSenderId: "1030504830885",
  projectId: "church-app-staging-f8a55",
  authDomain: "church-app-staging-f8a55.firebaseapp.com",
  storageBucket: "church-app-staging-f8a55.firebasestorage.app",
);

const webFirebaseOptions =
    firebaseEnv == 'staging' ? _stagingWebOptions : _prodWebOptions;
