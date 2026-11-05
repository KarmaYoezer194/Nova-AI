import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../services/device_prefs.dart';
import 'chat_shell.dart';
import 'onboarding_screen.dart';
import 'sign_in_screen.dart';

/// Where the app goes after the splash.
enum StartRoute { chat, onboarding, signIn }

/// Signed in → chats. Signed out → the welcome tour on a first visit,
/// otherwise sign-in.
StartRoute startRouteFor({
  required bool signedIn,
  required bool onboardingSeen,
}) {
  if (signedIn) return StartRoute.chat;
  return onboardingSeen ? StartRoute.signIn : StartRoute.onboarding;
}

/// Decides what to show: the app, the welcome tour or sign-in.
///
/// It listens to Firebase Auth, so signing in or out switches screens
/// automatically; no screen has to navigate by hand.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.services,
    this.signInChecked = false,
    this.initialUser,
    this.onboardingSeen = true,
    this.prefs,
  });

  final AppServices services;

  /// True when the splash already waited for Firebase's first sign-in
  /// answer ([initialUser]), so there's nothing left to wait for here.
  final bool signInChecked;
  final User? initialUser;

  /// Whether this device has seen the welcome tour (device only).
  final bool onboardingSeen;

  /// Where "tour seen" is saved. Null in tests: nothing is saved.
  final DevicePrefs? prefs;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // One stream for the gate's whole life (not a new one per rebuild).
  late final Stream<User?> _authChanges = widget.services.auth
      .authStateChanges();

  late bool _onboardingSeen = widget.onboardingSeen;

  /// "Create an account" in the tour opens sign-in in registration mode.
  bool _startRegistering = false;

  void _finishTour(OnboardingExit exit) {
    unawaited(widget.prefs?.setOnboardingSeen());
    setState(() {
      _onboardingSeen = true;
      _startRegistering = exit == OnboardingExit.createAccount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authChanges,
      initialData: widget.initialUser,
      builder: (context, snapshot) {
        // Firebase is still checking for a saved sign-in.
        if (!widget.signInChecked &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        final route = startRouteFor(
          signedIn: user != null,
          onboardingSeen: _onboardingSeen,
        );
        switch (route) {
          case StartRoute.chat:
            return ChatShell(
              // A different account gets a completely fresh screen.
              key: ValueKey(user!.uid),
              services: widget.services,
              uid: user.uid,
              email: user.email,
              displayName: user.displayName,
            );
          case StartRoute.onboarding:
            return OnboardingScreen(onFinish: _finishTour);
          case StartRoute.signIn:
            return SignInScreen(
              key: ValueKey(_startRegistering),
              authService: widget.services.auth,
              startRegistering: _startRegistering,
            );
        }
      },
    );
  }
}
