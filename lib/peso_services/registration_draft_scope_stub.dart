import 'dart:math';

final String _session = 'registration-session-' +
    Random.secure().nextInt(0x7fffffff).toRadixString(16);

String registrationDraftScope() => _session;
