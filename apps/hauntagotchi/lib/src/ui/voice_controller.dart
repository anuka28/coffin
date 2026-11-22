import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/foundation.dart';

import '../domain/haunting.dart';
import '../domain/voice_policy.dart';
import '../domain/voice_snapshot.dart';
import '../domain/voice_trigger.dart';
import 'home_controller.dart';
import 'home_status.dart';
import 'voice_ai.dart';
import 'voice_announcement.dart';
import 'voice_copy.dart';
import 'voice_request.dart';

/// Gives the ghost a short line that changes on four triggers only: app open,
/// a check-off, a mood change and a resurrection.
///
/// It listens to a [HomeController] and never writes to it. The AI call is
/// never awaited by the listener. Only the latest answer is shown, and any
/// failure, timeout, blank or over-long answer gives [VoiceCopy.safeLine].
class VoiceController extends ChangeNotifier {
  /// Creates a controller on [home].
  ///
  /// [ai] defaults to [defaultVoiceAi]. An answer that takes longer than
  /// [askTimeout] is replaced by the safe line.
  VoiceController({
    required this._home,
    CoffinAI? ai,
    this.askTimeout = const Duration(seconds: 4),
  }) : _ai = ai ?? defaultVoiceAi() {
    _home.addListener(_onHomeChanged);
    _onHomeChanged();
  }

  /// How long to wait for an answer before using the safe line.
  final Duration askTimeout;

  final HomeController _home;
  final CoffinAI _ai;

  VoiceSnapshot? _last;
  String? _line;
  VoiceAnnouncement? _announcement;
  int _generation = 0;
  int _announcementKey = 0;
  bool _disposed = false;

  /// The current line, or null until the first answer.
  String? get line => _line;

  /// The latest line to announce, set only for a check-off or a resurrection
  /// with a changed text. Null until the first one.
  VoiceAnnouncement? get announcement => _announcement;

  void _onHomeChanged() {
    if (_disposed) {
      return;
    }
    final Haunting? haunting = _home.haunting;
    final VoiceSnapshot snapshot = VoiceSnapshot(
      state: _home.status == HomeStatus.ready ? haunting?.state : null,
      checkOffs: _home.checkOffCount,
      resurrections: _home.resurrectionCount,
    );
    final VoiceTrigger? trigger = VoicePolicy.decide(_last, snapshot);
    _last = snapshot;
    if (trigger == null || haunting == null || snapshot.state == null) {
      return;
    }
    final int generation = ++_generation;
    final AiRequest request = buildVoiceRequest(
      trigger: trigger,
      state: snapshot.state!,
      streak: haunting.streak,
      completedToday: haunting.book.completedCountOn(haunting.today),
      ghostName: haunting.ghost.name,
      epochDay: haunting.today.epochDay,
    );
    _ask(request, trigger, generation);
  }

  Future<void> _ask(
    AiRequest request,
    VoiceTrigger trigger,
    int generation,
  ) async {
    String text = VoiceCopy.safeLine;
    try {
      final AiReply reply = await _ai.ask(request).timeout(askTimeout);
      if (reply.isUsableFor(request)) {
        text = reply.text;
      }
    } on Object {
      text = VoiceCopy.safeLine;
    }
    if (_disposed || generation != _generation || text == _line) {
      return;
    }
    _line = text;
    if (trigger == VoiceTrigger.checkedOff ||
        trigger == VoiceTrigger.resurrected) {
      _announcement = VoiceAnnouncement(key: ++_announcementKey, text: text);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _home.removeListener(_onHomeChanged);
    super.dispose();
  }
}
