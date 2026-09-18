import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Safari (especially Private Browsing) blocks IndexedDB, which Firebase JS
  // SDK accesses during initialization.  When that access fails it throws a
  // JavaScript exception that escapes Dart's try/catch and reaches the
  // platform dispatcher - crashing the Flutter engine silently.  The symptom
  // is "no response" on button taps (the widget tree is destroyed) and a
  // "Null check operator" error in the browser console.
  //
  // Returning `true` from onError marks the error as handled so Flutter keeps
  // running.  Our try/catch blocks in salon_auth.dart then catch the Dart-
  // level errors normally and show the correct error messages in the UI.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[Trimly] Unhandled platform error: $error');
    return true; // handled — do NOT crash the Flutter engine
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('[Trimly] Flutter error: ${details.exception}');
    // Do not call FlutterError.presentError — that would show the red error
    // overlay in debug mode which blocks the UI.  Log and continue.
  };

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Trimly',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
