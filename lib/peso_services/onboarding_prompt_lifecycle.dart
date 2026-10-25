import 'package:flutter/material.dart';

/// A missing-document reminder only belongs to the currently signed-in
/// applicant, never to an outgoing route or a new session.
abstract final class OnboardingPromptGuard {
  static bool sameApplicant({
    required bool mounted,
    required bool loggingOut,
    required String? dashboardUid,
    required String? currentUid,
  }) {
    return mounted &&
        !loggingOut &&
        dashboardUid != null &&
        dashboardUid.isNotEmpty &&
        dashboardUid == currentUid;
  }

  static bool canPrompt({
    required bool mounted,
    required bool loggingOut,
    required String? dashboardUid,
    required String? currentUid,
    required bool dashboardRouteIsCurrent,
    required bool welcomeFinished,
    required bool alreadyShown,
    required bool documentsLoaded,
  }) {
    return sameApplicant(
          mounted: mounted,
          loggingOut: loggingOut,
          dashboardUid: dashboardUid,
          currentUid: currentUid,
        ) &&
        dashboardRouteIsCurrent &&
        welcomeFinished &&
        !alreadyShown &&
        documentsLoaded;
  }
}

/// Keeps ownership of a particular dialog route. It can be removed on logout
/// without accidentally popping a later login or landing-page route.
class OnboardingDialogHandle<T> {
  DialogRoute<T>? _active;

  bool get isOpen => _active?.isActive == true;

  Future<T?> show({
    required BuildContext context,
    required WidgetBuilder builder,
  }) async {
    final route = DialogRoute<T>(
      context: context,
      barrierDismissible: false,
      builder: builder,
    );
    _active = route;
    try {
      return await Navigator.of(context, rootNavigator: true).push<T>(route);
    } finally {
      if (identical(_active, route)) _active = null;
    }
  }

  void dismiss() {
    final route = _active;
    _active = null;
    final navigator = route?.navigator;
    if (route != null && route.isActive && navigator?.mounted == true) {
      navigator!.removeRoute(route);
    }
  }
}
