import 'dart:async';

/// How the fallback wrapper starts its timeout timer. Tests pass a fake clock.
typedef AiTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);
