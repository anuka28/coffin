import 'dart:async';

import 'package:coffin_core/src/ai/ai_fallback_error.dart';
import 'package:coffin_core/src/ai/ai_issue.dart';
import 'package:coffin_core/src/ai/ai_issue_kind.dart';
import 'package:coffin_core/src/ai/ai_reply.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:coffin_core/src/ai/coffin_ai.dart';
import 'package:coffin_core/src/ai/fallback_coffin_ai.dart';
import 'package:coffin_core/src/ai/offline_coffin_ai.dart';
import 'package:coffin_core/src/ai/reply_source.dart';
import 'package:flutter_test/flutter_test.dart'
    show TestFailure, expect, group, isTrue;
import 'package:glados/glados.dart' hide expect, group;

import 'support/ai_generators.dart';
import 'support/fake_clock.dart';
import 'support/scripted_ai.dart';
import 'support/test_texts.dart';

/// Runs per property for Properties 18 to 22.
const int _numRuns = 200;

/// How long the primary may take in these tests (fake time).
const Duration _timeout = Duration(milliseconds: 100);

/// How many microtask turns a pump lets pass.
const int _pumpTurns = 50;

/// The scripted primary outcomes of Property 18.
enum PrimaryKind {
  /// A usable reply with a generated source.
  usable,

  /// `ask` throws synchronously.
  syncThrow,

  /// `ask` returns a failed future.
  asyncError,

  /// `ask` returns a future that never completes.
  never,

  /// A reply that arrives after the timeout.
  lateReply,

  /// An error that arrives after the timeout.
  lateError,

  /// An empty or whitespace-only reply.
  blank,

  /// A reply longer than `maxLength`.
  overlong,
}

/// One step of a generated sequence: a request and a scripted primary outcome.
final class SequenceStep {
  /// Creates a step. [sourceChoice] and [textChoice] are small integers that
  /// the driver turns into a source and a reply text.
  const SequenceStep(
    this.request,
    this.kind,
    this.sourceChoice,
    this.textChoice,
  );

  /// The request asked at this step.
  final AiRequest request;

  /// The scripted primary outcome.
  final PrimaryKind kind;

  /// Picks `offline`, `remote` or a custom valid name.
  final int sourceChoice;

  /// Picks the length and the filler of the reply text.
  final int textChoice;

  /// True for outcomes that only resolve after the clock reaches the timeout.
  bool get needsTimeout =>
      kind == PrimaryKind.never ||
      kind == PrimaryKind.lateReply ||
      kind == PrimaryKind.lateError;

  /// The source the scripted primary uses at this step.
  ReplySource get source {
    switch (sourceChoice % 4) {
      case 0:
        return ReplySource.offline;
      case 1:
        return ReplySource('remote');
      default:
        return ReplySource('custom_$sourceChoice');
    }
  }

  /// A reply text that is usable for [request]: non-blank and at most
  /// `maxLength` units long.
  String get usableText {
    const String filler = 'abc dEf!é-7';
    final int length = 1 + textChoice % request.maxLength;
    final StringBuffer buffer = StringBuffer('p');
    for (int i = 1; i < length; i++) {
      buffer.write(filler[(i * 7 + textChoice) % filler.length]);
    }
    return buffer.toString();
  }

  /// An empty or whitespace-only text chosen by [textChoice].
  String get blankText {
    const List<String> blanks = <String>['', ' ', '\u3000', '\n\t', '\u00A0 '];
    return blanks[textChoice % blanks.length];
  }

  @override
  String toString() => '${kind.name}@${source.name}';
}

/// What the driver saw at one step.
final class StepResult {
  /// Creates a result.
  StepResult({
    required this.step,
    required this.expectedReply,
    required this.reply,
    required this.error,
    required this.completed,
    required this.issuesAtCompletion,
    required this.issuesAfter,
    required this.pendingTimersAfter,
    required this.primaryCallsAfter,
    required this.secondaryCallsAfter,
  });

  /// The step that ran.
  final SequenceStep step;

  /// For a usable outcome, the exact reply object the primary returned.
  final AiReply? expectedReply;

  /// The reply, when the call completed with a value.
  final AiReply? reply;

  /// The error, when the call completed with an error.
  final Object? error;

  /// False when the future had not completed after the pump.
  final bool completed;

  /// How many issues the reporter held when the completion handler ran.
  final int issuesAtCompletion;

  /// How many issues the reporter held after the step.
  final int issuesAfter;

  /// Active timers on the fake clock after the step was pumped.
  final int pendingTimersAfter;

  /// Total primary calls after this step.
  final int primaryCallsAfter;

  /// Total secondary calls after this step.
  final int secondaryCallsAfter;
}

/// A [CoffinAI] that counts the calls it forwards to [inner].
final class CountingCoffinAI implements CoffinAI {
  /// Wraps [inner].
  CountingCoffinAI(this.inner);

  /// The wrapped secondary.
  final CoffinAI inner;

  /// How many times `ask` was called.
  int calls = 0;

  @override
  Future<AiReply> ask(AiRequest request) {
    calls++;
    return inner.ask(request);
  }
}

/// Everything one run of a sequence produced.
final class SequenceRun {
  /// Creates a run record.
  SequenceRun({
    required this.results,
    required this.issues,
    required this.zoneErrors,
    required this.primary,
    required this.secondary,
    required this.clock,
    required this.pendingTimersAtEnd,
  });

  /// One result per step.
  final List<StepResult> results;

  /// Every issue the reporter received, in order.
  final List<AiIssue> issues;

  /// Errors that reached the zone as unhandled.
  final List<Object> zoneErrors;

  /// The scripted primary of this run.
  final ScriptedCoffinAI primary;

  /// The counting secondary of this run.
  final CountingCoffinAI secondary;

  /// The clock of this run.
  final FakeClock clock;

  /// Active timers after the final pump.
  final int pendingTimersAtEnd;
}

/// Pumps the microtask queue with a fixed loop. Never uses `Future.delayed`.
Future<void> pump([int turns = _pumpTurns]) async {
  for (int i = 0; i < turns; i++) {
    await Future<void>.value();
  }
}

/// Generates one step.
Generator<SequenceStep> get anySequenceStep =>
    any.combine4<AiRequest, int, int, int, SequenceStep>(
      anyAiRequest,
      anyIntBetween(0, PrimaryKind.values.length),
      anyIntBetween(0, 1000),
      anyIntBetween(0, 1000),
      (AiRequest request, int kind, int sourceChoice, int textChoice) =>
          SequenceStep(
            request,
            PrimaryKind.values[kind],
            sourceChoice,
            textChoice,
          ),
    );

/// Generates sequences of 0 to 8 steps.
Generator<List<SequenceStep>> get anySequence =>
    anyListBetween<SequenceStep>(0, 9, anySequenceStep);

/// A readable description of the outcome sequence for failure messages.
String describeOutcomes(List<SequenceStep> steps) =>
    '[${steps.map((SequenceStep s) => s.toString()).join(', ')}]';

/// Runs [steps] through one fresh [FallbackCoffinAI] with an offline
/// secondary (or the one [makeSecondary] returns), a recording reporter and a
/// fresh [FakeClock], inside `runZonedGuarded`.
///
/// For outcomes that need the timeout the driver advances the clock by the
/// timeout, completes the late completer, and pumps microtasks. It collects
/// per-step results, the issues and the zone errors. Every run owns all of
/// its objects, because glados re-runs a failed body without awaiting it.
Future<SequenceRun> runSequence(
  List<SequenceStep> steps, {
  CoffinAI Function()? makeSecondary,
}) async {
  final List<Object> zoneErrors = <Object>[];
  final Future<SequenceRun>? future = runZonedGuarded<Future<SequenceRun>>(
    () async {
      final FakeClock clock = FakeClock();
      final List<AiIssue> issues = <AiIssue>[];
      final List<Completer<AiReply>> completers = <Completer<AiReply>>[];
      final List<AiReply?> expected = <AiReply?>[];
      final List<ScriptedOutcome> outcomes = <ScriptedOutcome>[];
      for (final SequenceStep step in steps) {
        final ReplySource source = step.source;
        switch (step.kind) {
          case PrimaryKind.usable:
            // A completed completer lets the test keep the exact reply
            // object and check that the wrapper returns it unchanged.
            final AiReply reply = AiReply(
              text: step.usableText,
              source: source,
            );
            final Completer<AiReply> done = Completer<AiReply>()
              ..complete(reply);
            expected.add(reply);
            completers.add(done);
            outcomes.add(ScriptedOutcome.lateReply(done));
          case PrimaryKind.syncThrow:
            expected.add(null);
            completers.add(Completer<AiReply>());
            outcomes.add(ScriptedOutcome.syncThrow());
          case PrimaryKind.asyncError:
            expected.add(null);
            completers.add(Completer<AiReply>());
            outcomes.add(ScriptedOutcome.asyncError());
          case PrimaryKind.never:
            expected.add(null);
            completers.add(Completer<AiReply>());
            outcomes.add(ScriptedOutcome.never());
          case PrimaryKind.lateReply:
            final Completer<AiReply> late = Completer<AiReply>();
            expected.add(null);
            completers.add(late);
            outcomes.add(ScriptedOutcome.lateReply(late));
          case PrimaryKind.lateError:
            final Completer<AiReply> late = Completer<AiReply>();
            expected.add(null);
            completers.add(late);
            outcomes.add(ScriptedOutcome.lateError(late));
          case PrimaryKind.blank:
            expected.add(null);
            completers.add(Completer<AiReply>());
            outcomes.add(ScriptedOutcome.blank(step.blankText));
          case PrimaryKind.overlong:
            expected.add(null);
            completers.add(Completer<AiReply>());
            outcomes.add(ScriptedOutcome.overlong(source: source));
        }
      }
      final ScriptedCoffinAI primary = ScriptedCoffinAI(outcomes);
      final CountingCoffinAI secondary = CountingCoffinAI(
        makeSecondary == null ? const OfflineCoffinAI() : makeSecondary(),
      );
      final FallbackCoffinAI wrapper = FallbackCoffinAI(
        primary: primary,
        secondary: secondary,
        timeout: _timeout,
        reporter: issues.add,
        timerFactory: clock.create,
      );

      final List<StepResult> results = <StepResult>[];
      for (int i = 0; i < steps.length; i++) {
        final SequenceStep step = steps[i];
        AiReply? reply;
        Object? error;
        bool completed = false;
        int issuesAtCompletion = -1;
        final Future<void> tracked = wrapper
            .ask(step.request)
            .then(
              (AiReply value) {
                reply = value;
                issuesAtCompletion = issues.length;
                completed = true;
              },
              onError: (Object e, StackTrace _) {
                error = e;
                issuesAtCompletion = issues.length;
                completed = true;
              },
            );
        if (step.needsTimeout) {
          clock.advance(_timeout);
          if (step.kind == PrimaryKind.lateReply) {
            completers[i].complete(
              AiReply(text: 'late ${step.usableText}', source: step.source),
            );
          } else if (step.kind == PrimaryKind.lateError) {
            completers[i].completeError(StateError('late failure'));
          }
        }
        await pump();
        // `tracked` never fails: both handlers are installed above.
        unawaited(tracked);
        results.add(
          StepResult(
            step: step,
            expectedReply: expected[i],
            reply: reply,
            error: error,
            completed: completed,
            issuesAtCompletion: issuesAtCompletion,
            issuesAfter: issues.length,
            pendingTimersAfter: clock.pendingTimers,
            primaryCallsAfter: primary.callCount,
            secondaryCallsAfter: secondary.calls,
          ),
        );
      }
      await pump();
      return SequenceRun(
        results: results,
        issues: List<AiIssue>.unmodifiable(issues),
        zoneErrors: zoneErrors,
        primary: primary,
        secondary: secondary,
        clock: clock,
        pendingTimersAtEnd: clock.pendingTimers,
      );
    },
    (Object error, StackTrace stack) => zoneErrors.add(error),
  );
  return future!;
}

final RunCounter _property18Runs = RunCounter();
final RunCounter _property18Calls = RunCounter();

/// Checks Property 18 for one run. Throws [TestFailure] on a violation.
void checkProperty18(List<SequenceStep> steps, SequenceRun run) {
  if (run.results.length != steps.length) {
    throw TestFailure(
      'expected ${steps.length} results, got ${run.results.length}',
    );
  }
  int previousSecondary = 0;
  for (int i = 0; i < run.results.length; i++) {
    final StepResult r = run.results[i];
    final SequenceStep step = r.step;
    try {
      if (!r.completed) throw TestFailure('the call did not complete');
      if (r.error != null) {
        throw TestFailure('the call completed with an error: ${r.error}');
      }
      final AiReply reply = r.reply!;
      if (isTestBlank(reply.text)) {
        throw TestFailure('reply is empty or whitespace only');
      }
      if (reply.text.length > step.request.maxLength) {
        throw TestFailure(
          'reply length ${reply.text.length} exceeds '
          'maxLength ${step.request.maxLength}',
        );
      }
      if (r.primaryCallsAfter != i + 1) {
        throw TestFailure(
          'primary was called ${r.primaryCallsAfter} times after '
          'step ${i + 1}, expected ${i + 1}',
        );
      }
      if (!identical(run.primary.requests[i], step.request)) {
        throw TestFailure('primary did not get the same request object');
      }
      final int secondaryDelta = r.secondaryCallsAfter - previousSecondary;
      previousSecondary = r.secondaryCallsAfter;
      if (step.kind == PrimaryKind.usable) {
        if (!identical(reply, r.expectedReply)) {
          throw TestFailure('the primary reply was not returned unchanged');
        }
        if (reply.source != step.source) {
          throw TestFailure(
            'source is ${reply.source.name}, expected ${step.source.name}',
          );
        }
        if (secondaryDelta != 0) {
          throw TestFailure('the secondary was called on a usable reply');
        }
      } else {
        if (reply.source != ReplySource.offline) {
          throw TestFailure('source is ${reply.source.name}, expected offline');
        }
        if (secondaryDelta != 1) {
          throw TestFailure('the secondary was called $secondaryDelta times');
        }
      }
    } on TestFailure catch (e) {
      throw _failure(i, step, steps, e.message ?? 'check failed');
    } on Object catch (e) {
      throw _failure(i, step, steps, 'unexpected error: $e');
    }
  }
}

TestFailure _failure(
  int index,
  SequenceStep step,
  List<SequenceStep> steps,
  String what,
) => TestFailure(
  'step $index: $what\n'
  '  ${describeRequest(step.request)}\n'
  '  outcomes: ${describeOutcomes(steps)}',
);

final RunCounter _property19Runs = RunCounter();
final RunCounter _property19Calls = RunCounter();

/// A step whose usable reply text starts with a distinctive marker, so the
/// no-leak check of Property 19 can recognise a leaked reply.
final class _MarkedStep extends SequenceStep {
  const _MarkedStep(
    super.request,
    super.kind,
    super.sourceChoice,
    super.textChoice,
  );

  static const String marker = 'zzreply_';

  @override
  String get usableText {
    final String base = super.usableText;
    // Keep the length: the text must still fit `maxLength`.
    if (base.length < marker.length) return base;
    return marker + base.substring(marker.length);
  }
}

/// Copies [steps] with a marked fact string and a long marked number added to
/// every request, and marked reply texts.
List<SequenceStep> _markSteps(List<SequenceStep> steps) => <SequenceStep>[
  for (int i = 0; i < steps.length; i++)
    _MarkedStep(
      AiRequest(
        purpose: steps[i].request.purpose,
        facts: <String, Object?>{
          ...steps[i].request.facts,
          'zzfact_key': 'zzfact_value_$i',
          'zzfact_number': 918273645 + i,
        },
        maxLength: steps[i].request.maxLength,
        seed: steps[i].request.seed,
      ),
      steps[i].kind,
      steps[i].sourceChoice,
      steps[i].textChoice,
    ),
];

/// Collects the String values and the numbers of [value], recursively.
void _collectFactValues(Object? value, List<String> out) {
  if (value is String) {
    out.add(value);
  } else if (value is num) {
    final String text = value.toString();
    final int digits = text.codeUnits
        .where((int u) => u >= 48 && u <= 57)
        .length;
    if (digits >= 3) out.add(text);
  } else if (value is List<Object?>) {
    for (final Object? item in value) {
      _collectFactValues(item, out);
    }
  } else if (value is Map<Object?, Object?>) {
    for (final Object? item in value.values) {
      _collectFactValues(item, out);
    }
  }
}

/// The issue kind Property 19 expects for [kind], or null for no issue.
AiIssueKind? _expectedKind(PrimaryKind kind) {
  switch (kind) {
    case PrimaryKind.usable:
      return null;
    case PrimaryKind.syncThrow:
    case PrimaryKind.asyncError:
      return AiIssueKind.threw;
    case PrimaryKind.never:
    case PrimaryKind.lateReply:
    case PrimaryKind.lateError:
      return AiIssueKind.timedOut;
    case PrimaryKind.blank:
      return AiIssueKind.emptyReply;
    case PrimaryKind.overlong:
      return AiIssueKind.invalidReply;
  }
}

/// Checks Property 19 for one run. Throws [TestFailure] on a violation.
void checkProperty19(List<SequenceStep> steps, SequenceRun run) {
  if (run.results.length != steps.length) {
    throw TestFailure(
      'expected ${steps.length} results, got ${run.results.length}',
    );
  }
  int expectedIssues = 0;
  for (int i = 0; i < steps.length; i++) {
    final StepResult r = run.results[i];
    final SequenceStep step = steps[i];
    try {
      if (!r.completed) throw TestFailure('the call did not complete');
      final AiIssueKind? kind = _expectedKind(step.kind);
      if (kind != null) expectedIssues++;
      if (r.issuesAtCompletion != expectedIssues) {
        throw TestFailure(
          'reporter held ${r.issuesAtCompletion} issues when the completion '
          'handler ran, expected $expectedIssues',
        );
      }
      if (r.issuesAfter != expectedIssues) {
        throw TestFailure(
          'reporter held ${r.issuesAfter} issues after the step, '
          'expected $expectedIssues',
        );
      }
      if (kind == null) continue;
      if (run.issues.length < expectedIssues) {
        throw TestFailure('the issue of this step is missing');
      }
      final AiIssue issue = run.issues[expectedIssues - 1];
      if (issue.kind != kind) {
        throw TestFailure(
          'issue kind is ${issue.kind.name}, expected ${kind.name}',
        );
      }
      final String fixed = AiIssue.forKind(kind).message;
      if (issue.message != fixed) {
        throw TestFailure('message "${issue.message}" is not "$fixed"');
      }
      // Strings shorter than 3 units are skipped: a 1 or 2 unit text such as
      // "a" or "e " would match the fixed wording by chance, and that is not
      // a leak.
      final List<String> secrets = <String>[];
      for (final Object? v in step.request.facts.values) {
        _collectFactValues(v, secrets);
      }
      final String usable = step.usableText;
      secrets
        ..add(usable)
        ..add('late $usable')
        ..add('x' * (step.request.maxLength + 1))
        ..add(step.blankText);
      for (final String secret in secrets) {
        if (secret.length >= 3 && issue.message.contains(secret)) {
          throw TestFailure(
            'message leaks ${escapeForReport(secret)}: ${issue.message}',
          );
        }
      }
    } on TestFailure catch (e) {
      throw _failure(i, step, steps, e.message ?? 'check failed');
    } on Object catch (e) {
      throw _failure(i, step, steps, 'unexpected error: $e');
    }
  }
  if (run.issues.length != expectedIssues) {
    throw TestFailure(
      'reporter received ${run.issues.length} issues, expected '
      '$expectedIssues\n  outcomes: ${describeOutcomes(steps)}',
    );
  }
}

final RunCounter _property20Runs = RunCounter();
final RunCounter _property20RunsWithLateError = RunCounter();
final RunCounter _property20LateErrorSteps = RunCounter();

/// Checks Property 20 for one run. Throws [TestFailure] on a violation.
void checkProperty20(List<SequenceStep> steps, SequenceRun run) {
  if (run.results.length != steps.length) {
    throw TestFailure(
      'expected ${steps.length} results, got ${run.results.length}',
    );
  }
  for (int i = 0; i < run.results.length; i++) {
    final StepResult r = run.results[i];
    if (!r.completed) {
      throw _failure(i, r.step, steps, 'the call did not complete');
    }
    if (r.pendingTimersAfter != 0) {
      throw _failure(
        i,
        r.step,
        steps,
        '${r.pendingTimersAfter} timers pending after the call completed',
      );
    }
  }
  if (run.pendingTimersAtEnd != 0) {
    throw TestFailure(
      '${run.pendingTimersAtEnd} timers pending at the end\n'
      '  outcomes: ${describeOutcomes(steps)}',
    );
  }
  if (run.zoneErrors.isNotEmpty) {
    throw TestFailure(
      '${run.zoneErrors.length} unhandled errors: ${run.zoneErrors}\n'
      '  outcomes: ${describeOutcomes(steps)}',
    );
  }
}

/// One generated case of Property 21.
final class FailingSecondaryCase {
  /// Creates a case: a failing primary [step] and a secondary [mode].
  const FailingSecondaryCase(this.step, this.mode);

  /// A single step with a failing primary outcome and marked texts.
  final SequenceStep step;

  /// How the secondary misbehaves.
  final SecondaryMode mode;

  @override
  String toString() => '${step.kind.name} then ${mode.name}';
}

/// The failing primary outcomes, in a fixed order.
final List<PrimaryKind> _failingKinds = PrimaryKind.values
    .where((PrimaryKind k) => k != PrimaryKind.usable)
    .toList(growable: false);

/// Generates a failing primary outcome combined with a secondary mode.
Generator<FailingSecondaryCase> get anyFailingSecondaryCase =>
    any.combine4<AiRequest, int, int, int, FailingSecondaryCase>(
      anyAiRequest,
      anyIntBetween(0, _failingKinds.length),
      anyIntBetween(0, SecondaryMode.values.length),
      anyIntBetween(0, 1000),
      (AiRequest request, int kind, int mode, int choice) =>
          FailingSecondaryCase(
            _markSteps(<SequenceStep>[
              SequenceStep(request, _failingKinds[kind], choice, choice),
            ]).single,
            SecondaryMode.values[mode],
          ),
    );

/// The issue kind the secondary mode must produce (Property 21).
AiIssueKind _expectedSecondaryKind(SecondaryMode mode) {
  switch (mode) {
    case SecondaryMode.throwsSync:
    case SecondaryMode.throwsAsync:
      return AiIssueKind.threw;
    case SecondaryMode.empty:
      return AiIssueKind.emptyReply;
    case SecondaryMode.overlong:
      return AiIssueKind.invalidReply;
  }
}

/// Text of the secondary's misbehaving reply; carries a marker.
const String _secondaryMarker = 'zzsecondary_';

/// A failing secondary whose reply texts and error carry a marker.
final class _MarkedSecondary implements CoffinAI {
  _MarkedSecondary(this.mode);

  final SecondaryMode mode;

  @override
  Future<AiReply> ask(AiRequest request) {
    switch (mode) {
      case SecondaryMode.throwsSync:
        throw StateError('${_secondaryMarker}sync');
      case SecondaryMode.throwsAsync:
        return Future<AiReply>.error(StateError('${_secondaryMarker}async'));
      case SecondaryMode.empty:
        return Future<AiReply>.value(
          AiReply(text: '', source: ReplySource.offline),
        );
      case SecondaryMode.overlong:
        final int length = request.maxLength + 1;
        final String text = (_secondaryMarker + 'z' * length).substring(
          0,
          length,
        );
        return Future<AiReply>.value(
          AiReply(text: text, source: ReplySource.offline),
        );
    }
  }
}

final RunCounter _property21Runs = RunCounter();
final List<RunCounter> _property21Modes = <RunCounter>[
  for (final SecondaryMode _ in SecondaryMode.values) RunCounter(),
];
final List<RunCounter> _property21Kinds = <RunCounter>[
  for (final PrimaryKind _ in PrimaryKind.values) RunCounter(),
];

/// Checks Property 21 for one run. Throws [TestFailure] on a violation.
void checkProperty21(FailingSecondaryCase c, SequenceRun run) {
  final List<SequenceStep> steps = <SequenceStep>[c.step];
  try {
    if (run.results.length != 1) {
      throw TestFailure('expected 1 result, got ${run.results.length}');
    }
    final StepResult r = run.results.single;
    if (!r.completed) throw TestFailure('the call did not complete');
    if (r.reply != null) throw TestFailure('the call returned a reply');
    final Object? error = r.error;
    if (error is! AiFallbackError) {
      throw TestFailure('error is ${error.runtimeType}, not AiFallbackError');
    }
    final AiIssueKind? primaryKind = _expectedKind(c.step.kind);
    if (error.primaryFailure != primaryKind) {
      throw TestFailure(
        'primaryFailure is ${error.primaryFailure.name}, '
        'expected ${primaryKind?.name}',
      );
    }
    final AiIssueKind secondaryKind = _expectedSecondaryKind(c.mode);
    if (error.secondaryFailure != secondaryKind) {
      throw TestFailure(
        'secondaryFailure is ${error.secondaryFailure.name}, '
        'expected ${secondaryKind.name}',
      );
    }
    if (r.secondaryCallsAfter != 1) {
      throw TestFailure('the secondary was called ${r.secondaryCallsAfter}x');
    }
    if (r.issuesAtCompletion != 1 || run.issues.length != 1) {
      throw TestFailure(
        'reporter held ${r.issuesAtCompletion} issues at completion and '
        '${run.issues.length} at the end, expected exactly 1',
      );
    }
    final AiIssue issue = run.issues.single;
    if (issue.kind != primaryKind) {
      throw TestFailure('issue kind is ${issue.kind.name}');
    }
    if (issue.message != AiIssue.forKind(issue.kind).message) {
      throw TestFailure('issue message is not the fixed message');
    }
    // Strings shorter than 3 units are skipped, as in Property 19.
    final List<String> secrets = <String>[];
    for (final Object? v in c.step.request.facts.values) {
      _collectFactValues(v, secrets);
    }
    final String usable = c.step.usableText;
    secrets
      ..add(usable)
      ..add('late $usable')
      ..add('x' * (c.step.request.maxLength + 1))
      ..add(c.step.blankText)
      ..add(_secondaryMarker)
      ..add(_secondaryMarker + 'z' * (c.step.request.maxLength + 1));
    final String shown = error.toString();
    for (final String secret in secrets) {
      if (secret.length < 3) continue;
      if (shown.contains(secret)) {
        throw TestFailure('toString leaks ${escapeForReport(secret)}: $shown');
      }
      if (issue.message.contains(secret)) {
        throw TestFailure(
          'issue message leaks ${escapeForReport(secret)}: ${issue.message}',
        );
      }
    }
    if (run.zoneErrors.isNotEmpty) {
      throw TestFailure(
        '${run.zoneErrors.length} unhandled errors: ${run.zoneErrors}',
      );
    }
  } on TestFailure catch (e) {
    throw _failure(0, c.step, steps, '${e.message} [secondary ${c.mode.name}]');
  } on Object catch (e) {
    throw _failure(0, c.step, steps, 'unexpected error: $e');
  }
}

/// The scripted primary outcomes of one call in Property 22.
enum OverlapOutcome {
  /// A usable reply that carries the call's marker.
  usable,

  /// A failed future.
  asyncError,

  /// An empty reply.
  empty,

  /// A reply longer than `maxLength`.
  overlong,

  /// A future that never completes.
  never,
}

/// One generated case of Property 22: two overlapping calls.
final class OverlapCase {
  /// Creates a case. [late1] and [late2] say the primary completes after the
  /// timeout. [secondFirst] completes primary 2 before primary 1.
  const OverlapCase({
    required this.request1,
    required this.request2,
    required this.outcome1,
    required this.outcome2,
    required this.late1,
    required this.late2,
    required this.secondFirst,
  });

  /// The request of the first call.
  final AiRequest request1;

  /// The request of the second call.
  final AiRequest request2;

  /// The primary outcome of the first call.
  final OverlapOutcome outcome1;

  /// The primary outcome of the second call.
  final OverlapOutcome outcome2;

  /// True when the first primary completes after the timeout.
  final bool late1;

  /// True when the second primary completes after the timeout.
  final bool late2;

  /// True when the second primary completes before the first one.
  final bool secondFirst;

  @override
  String toString() =>
      'call1=${outcome1.name}${late1 ? '/late' : '/early'} '
      'call2=${outcome2.name}${late2 ? '/late' : '/early'} '
      'order=${secondFirst ? '2-then-1' : '1-then-2'}';
}

/// What one overlapping call showed.
final class _OverlapCall {
  AiReply? reply;
  Object? error;
  bool completed = false;
  List<AiIssueKind> kindsAtCompletion = const <AiIssueKind>[];
}

/// An offline secondary that records the request objects it receives.
final class _RecordingSecondary implements CoffinAI {
  final List<AiRequest> requests = <AiRequest>[];

  @override
  Future<AiReply> ask(AiRequest request) {
    requests.add(request);
    return const OfflineCoffinAI().ask(request);
  }
}

/// Everything one run of Property 22 produced.
final class OverlapRun {
  /// Creates a run record.
  OverlapRun({
    required this.replies,
    required this.errors,
    required this.completed,
    required this.kindsAtCompletion,
    required this.expectedReplies,
    required this.issues,
    required this.zoneErrors,
    required this.primaryRequests,
    required this.secondaryRequests,
    required this.pendingTimersAtEnd,
  });

  /// The reply of each call, or null.
  final List<AiReply?> replies;

  /// The error of each call, or null.
  final List<Object?> errors;

  /// Whether each call completed.
  final List<bool> completed;

  /// The kinds the reporter held when each call's handler ran.
  final List<List<AiIssueKind>> kindsAtCompletion;

  /// The exact reply each usable primary returned, else null.
  final List<AiReply?> expectedReplies;

  /// Every issue, in report order.
  final List<AiIssue> issues;

  /// Errors that reached the zone as unhandled.
  final List<Object> zoneErrors;

  /// The request objects the primary received.
  final List<AiRequest> primaryRequests;

  /// The request objects the secondary received.
  final List<AiRequest> secondaryRequests;

  /// Active timers after the last pump.
  final int pendingTimersAtEnd;
}

/// Generates two overlapping calls with different requests.
Generator<OverlapCase> get anyOverlapCase =>
    any.combine5<AiRequest, AiRequest, int, int, int, OverlapCase>(
      anyAiRequest,
      anyAiRequest,
      anyIntBetween(0, 10),
      anyIntBetween(0, 10),
      anyIntBetween(0, 2),
      (AiRequest a, AiRequest b, int code1, int code2, int order) {
        // Equal purpose and seed would make equal offline replies likely, so
        // the second request gets the next seed in that case.
        final AiRequest second = a.purpose == b.purpose && a.seed == b.seed
            ? AiRequest(
                purpose: b.purpose,
                facts: b.facts,
                maxLength: b.maxLength,
                seed: (b.seed + 1) % 4294967296,
              )
            : b;
        return OverlapCase(
          request1: a,
          request2: second,
          outcome1: OverlapOutcome.values[code1 % 5],
          outcome2: OverlapOutcome.values[code2 % 5],
          late1: code1 >= 5,
          late2: code2 >= 5,
          secondFirst: order == 1,
        );
      },
    );

/// The issue kind of a call, or null when its primary reply is returned.
AiIssueKind? _overlapKind(OverlapOutcome outcome, bool late) {
  if (outcome == OverlapOutcome.never || late) return AiIssueKind.timedOut;
  switch (outcome) {
    case OverlapOutcome.usable:
      return null;
    case OverlapOutcome.asyncError:
      return AiIssueKind.threw;
    case OverlapOutcome.empty:
      return AiIssueKind.emptyReply;
    case OverlapOutcome.overlong:
      return AiIssueKind.invalidReply;
    case OverlapOutcome.never:
      return AiIssueKind.timedOut;
  }
}

/// Runs the two overlapping calls of [c] through one wrapper and one primary.
///
/// Both calls start before any primary completes. Primaries that complete
/// before the timeout do so first, in the generated order. Then the clock
/// advances by the timeout, and the remaining primaries complete in the
/// generated order.
Future<OverlapRun> runOverlap(OverlapCase c) async {
  final List<Object> zoneErrors = <Object>[];
  final Future<OverlapRun>? future = runZonedGuarded<Future<OverlapRun>>(
    () async {
      final FakeClock clock = FakeClock();
      final List<AiIssue> issues = <AiIssue>[];
      final List<AiRequest> requests = <AiRequest>[c.request1, c.request2];
      final List<OverlapOutcome> outcomes = <OverlapOutcome>[
        c.outcome1,
        c.outcome2,
      ];
      final List<bool> late = <bool>[c.late1, c.late2];
      final List<Completer<AiReply>> completers = <Completer<AiReply>>[
        Completer<AiReply>(),
        Completer<AiReply>(),
      ];
      final List<AiReply?> expected = <AiReply?>[
        for (int i = 0; i < 2; i++)
          outcomes[i] == OverlapOutcome.usable
              ? AiReply(
                  text: 'zzcall${i + 1}_ok',
                  source: ReplySource('remote${i + 1}'),
                )
              : null,
      ];
      final ScriptedCoffinAI primary = ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.lateReply(completers[0]),
        ScriptedOutcome.lateReply(completers[1]),
      ]);
      final _RecordingSecondary secondary = _RecordingSecondary();
      final FallbackCoffinAI wrapper = FallbackCoffinAI(
        primary: primary,
        secondary: secondary,
        timeout: _timeout,
        reporter: issues.add,
        timerFactory: clock.create,
      );

      final List<_OverlapCall> calls = <_OverlapCall>[
        _OverlapCall(),
        _OverlapCall(),
      ];
      final List<Future<void>> tracked = <Future<void>>[];
      for (int i = 0; i < 2; i++) {
        final _OverlapCall call = calls[i];
        tracked.add(
          wrapper
              .ask(requests[i])
              .then(
                (AiReply value) {
                  call.reply = value;
                  call.kindsAtCompletion = <AiIssueKind>[
                    for (final AiIssue issue in issues) issue.kind,
                  ];
                  call.completed = true;
                },
                onError: (Object e, StackTrace _) {
                  call.error = e;
                  call.kindsAtCompletion = <AiIssueKind>[
                    for (final AiIssue issue in issues) issue.kind,
                  ];
                  call.completed = true;
                },
              ),
        );
      }

      void complete(int i) {
        final int maxLength = requests[i].maxLength;
        switch (outcomes[i]) {
          case OverlapOutcome.usable:
            completers[i].complete(expected[i]);
          case OverlapOutcome.asyncError:
            completers[i].completeError(StateError('failure ${i + 1}'));
          case OverlapOutcome.empty:
            completers[i].complete(
              AiReply(text: ' ', source: ReplySource('remote${i + 1}')),
            );
          case OverlapOutcome.overlong:
            completers[i].complete(
              AiReply(
                text: 'zzcall${i + 1}_${'x' * maxLength}',
                source: ReplySource('remote${i + 1}'),
              ),
            );
          case OverlapOutcome.never:
            break;
        }
      }

      final List<int> order = c.secondFirst ? <int>[1, 0] : <int>[0, 1];
      for (final int i in order) {
        if (!late[i] && outcomes[i] != OverlapOutcome.never) {
          complete(i);
          await pump();
        }
      }
      clock.advance(_timeout);
      await pump();
      for (final int i in order) {
        if (late[i] && outcomes[i] != OverlapOutcome.never) {
          complete(i);
          await pump();
        }
      }
      await pump();
      // `tracked` never fails: both handlers are installed above.
      unawaited(Future.wait(tracked));
      return OverlapRun(
        replies: <AiReply?>[calls[0].reply, calls[1].reply],
        errors: <Object?>[calls[0].error, calls[1].error],
        completed: <bool>[calls[0].completed, calls[1].completed],
        kindsAtCompletion: <List<AiIssueKind>>[
          calls[0].kindsAtCompletion,
          calls[1].kindsAtCompletion,
        ],
        expectedReplies: expected,
        issues: List<AiIssue>.unmodifiable(issues),
        zoneErrors: zoneErrors,
        primaryRequests: primary.requests,
        secondaryRequests: List<AiRequest>.of(secondary.requests),
        pendingTimersAtEnd: clock.pendingTimers,
      );
    },
    (Object error, StackTrace stack) => zoneErrors.add(error),
  );
  return future!;
}

final RunCounter _property22Runs = RunCounter();
final RunCounter _property22FirstFirst = RunCounter();
final RunCounter _property22SecondFirst = RunCounter();
final RunCounter _property22MixedKinds = RunCounter();
final List<RunCounter> _property22Outcomes = <RunCounter>[
  for (final OverlapOutcome _ in OverlapOutcome.values) RunCounter(),
];
final RunCounter _property22Early = RunCounter();
final RunCounter _property22Late = RunCounter();

/// Checks Property 22 for one run. Throws [TestFailure] on a violation.
Future<void> checkProperty22(OverlapCase c, OverlapRun run) async {
  final List<AiRequest> requests = <AiRequest>[c.request1, c.request2];
  final List<AiIssueKind?> kinds = <AiIssueKind?>[
    _overlapKind(c.outcome1, c.late1),
    _overlapKind(c.outcome2, c.late2),
  ];
  for (int i = 0; i < 2; i++) {
    final String name = 'call ${i + 1}';
    if (!run.completed[i]) throw TestFailure('$name did not complete');
    if (run.errors[i] != null) {
      throw TestFailure('$name completed with an error: ${run.errors[i]}');
    }
    final AiReply reply = run.replies[i]!;
    final AiIssueKind? kind = kinds[i];
    if (kind == null) {
      if (!identical(reply, run.expectedReplies[i])) {
        throw TestFailure('$name did not get its own primary reply object');
      }
    } else {
      final AiReply offline = await const OfflineCoffinAI().ask(requests[i]);
      if (reply.text != offline.text || reply.source != offline.source) {
        throw TestFailure(
          '$name did not get the offline reply of its own request: '
          '"${escapeForReport(reply.text)}" vs '
          '"${escapeForReport(offline.text)}"',
        );
      }
      if (!run.kindsAtCompletion[i].contains(kind)) {
        throw TestFailure(
          '$name completed before its ${kind.name} issue was reported: '
          '${run.kindsAtCompletion[i].map((AiIssueKind k) => k.name)}',
        );
      }
    }
  }
  if (run.primaryRequests.length != 2 ||
      !identical(run.primaryRequests[0], c.request1) ||
      !identical(run.primaryRequests[1], c.request2)) {
    throw TestFailure('the primary did not get both request objects');
  }
  final List<AiIssueKind> expectedKinds = <AiIssueKind>[
    for (final AiIssueKind? k in kinds) ?k,
  ];
  if (run.issues.length != expectedKinds.length) {
    throw TestFailure(
      '${run.issues.length} issues reported, expected ${expectedKinds.length}',
    );
  }
  final List<String> seen = <String>[
    for (final AiIssue issue in run.issues) issue.kind.name,
  ]..sort();
  final List<String> want = <String>[
    for (final AiIssueKind k in expectedKinds) k.name,
  ]..sort();
  if (seen.join(',') != want.join(',')) {
    throw TestFailure('issue kinds $seen, expected $want');
  }
  for (final AiIssue issue in run.issues) {
    if (issue.message != AiIssue.forKind(issue.kind).message) {
      throw TestFailure('issue message is not the fixed message');
    }
  }
  // The order of the issues is not asserted: design.md does not say in which
  // order two overlapping calls report, only that each issue belongs to the
  // call that produced it.
  final List<AiRequest> expectedSecondary = <AiRequest>[
    for (int i = 0; i < 2; i++)
      if (kinds[i] != null) requests[i],
  ];
  if (run.secondaryRequests.length != expectedSecondary.length) {
    throw TestFailure(
      'secondary asked ${run.secondaryRequests.length} times, '
      'expected ${expectedSecondary.length}',
    );
  }
  for (final AiRequest r in expectedSecondary) {
    if (run.secondaryRequests.where((AiRequest s) => identical(s, r)).length !=
        1) {
      throw TestFailure('the secondary did not get each failed request once');
    }
  }
  if (run.zoneErrors.isNotEmpty) {
    throw TestFailure(
      '${run.zoneErrors.length} unhandled errors: ${run.zoneErrors}',
    );
  }
  if (run.pendingTimersAtEnd != 0) {
    throw TestFailure('${run.pendingTimersAtEnd} timers pending at the end');
  }
}

void main() {
  group('Property 18: A wrapper with an offline secondary always answers', () {
    // Feature: coffin-ai, Property 18: A wrapper with an offline secondary always answers, from the right source
    // Validates: Requirements 9.4, 9.5, 9.12, 9.14, 10.8, 12.1, 12.2, 14.1, 14.2, 14.3
    Glados(anySequence, ExploreConfig(numRuns: _numRuns)).test(
      'every step gets a usable reply from the right source',
      (List<SequenceStep> steps) async {
        _property18Runs.increment();
        for (int i = 0; i < steps.length; i++) {
          _property18Calls.increment();
        }
        final SequenceRun run;
        try {
          run = await runSequence(steps);
        } on Object catch (e) {
          throw TestFailure(
            'driver failed: $e\n  outcomes: ${describeOutcomes(steps)}',
          );
        }
        checkProperty18(steps, run);
        if (run.primary.callCount != steps.length) {
          throw TestFailure(
            'primary called ${run.primary.callCount} times for '
            '${steps.length} steps\n  outcomes: ${describeOutcomes(steps)}',
          );
        }
      },
    );

    test('ran exactly $_numRuns times', () {
      expect(_property18Runs.runs > 0, isTrue);
      expect(_property18Runs.runs, _numRuns);
      expect(_property18Calls.runs > 0, isTrue);
    });
  });

  group('Property 19: Exactly one fixed issue per fallback', () {
    // Feature: coffin-ai, Property 19: Exactly one fixed issue per fallback
    // Validates: Requirements 9.6, 9.7, 9.8, 9.9, 9.10, 9.11, 11.3, 14.4, 14.5
    Glados(anySequence, ExploreConfig(numRuns: _numRuns)).test(
      'one fixed issue for every fallback and none for a usable reply',
      (List<SequenceStep> generated) async {
        _property19Runs.increment();
        final List<SequenceStep> steps = _markSteps(generated);
        for (int i = 0; i < steps.length; i++) {
          _property19Calls.increment();
        }
        final SequenceRun run;
        try {
          run = await runSequence(steps);
        } on Object catch (e) {
          throw TestFailure(
            'driver failed: $e\n  outcomes: ${describeOutcomes(steps)}',
          );
        }
        checkProperty19(steps, run);
      },
    );

    test('ran exactly $_numRuns times', () {
      expect(_property19Runs.runs > 0, isTrue);
      expect(_property19Runs.runs, _numRuns);
      expect(_property19Calls.runs > 0, isTrue);
    });
  });

  group('Property 20: No timer and no unhandled error is left behind', () {
    // Feature: coffin-ai, Property 20: No timer and no unhandled error is left behind
    // Validates: Requirements 10.1, 10.10, 14.6
    test(
      'control: the driver zone records a deliberately unhandled error',
      () async {
        // Same mechanism as `runSequence`: the completer is created inside
        // the guarded zone, and the pump uses microtask turns only.
        final List<Object> zoneErrors = <Object>[];
        final Future<void>? done = runZonedGuarded<Future<void>>(() async {
          final Completer<AiReply> late = Completer<AiReply>();
          late.completeError(StateError('deliberate'));
          await pump();
        }, (Object error, StackTrace stack) => zoneErrors.add(error));
        await done;
        expect(zoneErrors.length, 1);
      },
    );

    Glados(anySequence, ExploreConfig(numRuns: _numRuns)).test(
      'no pending timer after a call and no unhandled zone error',
      (List<SequenceStep> steps) async {
        _property20Runs.increment();
        final int lateErrors = steps
            .where((SequenceStep s) => s.kind == PrimaryKind.lateError)
            .length;
        if (lateErrors > 0) _property20RunsWithLateError.increment();
        for (int i = 0; i < lateErrors; i++) {
          _property20LateErrorSteps.increment();
        }
        final SequenceRun run;
        try {
          run = await runSequence(steps);
        } on Object catch (e) {
          throw TestFailure(
            'driver failed: $e\n  outcomes: ${describeOutcomes(steps)}',
          );
        }
        checkProperty20(steps, run);
      },
    );

    test('ran exactly $_numRuns times and saw late-error steps', () {
      expect(_property20Runs.runs > 0, isTrue);
      expect(_property20Runs.runs, _numRuns);
      expect(_property20RunsWithLateError.runs > 0, isTrue);
      expect(_property20LateErrorSteps.runs > 0, isTrue);
      // ignore: avoid_print
      print(
        'Property 20: runs=${_property20Runs.runs} '
        'runsWithLateError=${_property20RunsWithLateError.runs} '
        'lateErrorSteps=${_property20LateErrorSteps.runs}',
      );
    });
  });

  group('Property 21: A failing secondary gives a typed error and still one '
      'issue', () {
    // Feature: coffin-ai, Property 21: A failing secondary gives a typed error and still one issue
    // Validates: Requirements 10.6, 10.7
    Glados(anyFailingSecondaryCase, ExploreConfig(numRuns: _numRuns)).test(
      'a typed error with kinds only and exactly one issue',
      (FailingSecondaryCase c) async {
        _property21Runs.increment();
        _property21Modes[c.mode.index].increment();
        _property21Kinds[c.step.kind.index].increment();
        final SequenceRun run;
        try {
          run = await runSequence(<SequenceStep>[
            c.step,
          ], makeSecondary: () => _MarkedSecondary(c.mode));
        } on Object catch (e) {
          throw TestFailure('driver failed: $e\n  case: $c');
        }
        checkProperty21(c, run);
      },
    );

    test('ran exactly $_numRuns times and saw every mode and kind', () {
      expect(_property21Runs.runs > 0, isTrue);
      expect(_property21Runs.runs, _numRuns);
      for (final SecondaryMode mode in SecondaryMode.values) {
        expect(
          _property21Modes[mode.index].runs > 0,
          isTrue,
          reason: 'secondary mode ${mode.name} never occurred',
        );
      }
      for (final PrimaryKind kind in _failingKinds) {
        expect(
          _property21Kinds[kind.index].runs > 0,
          isTrue,
          reason: 'primary kind ${kind.name} never occurred',
        );
      }
      // ignore: avoid_print
      print(
        'Property 21: runs=${_property21Runs.runs} modes='
        '${<String>[for (final SecondaryMode m in SecondaryMode.values) '${m.name}=${_property21Modes[m.index].runs}']} kinds='
        '${<String>[for (final PrimaryKind k in _failingKinds) '${k.name}=${_property21Kinds[k.index].runs}']}',
      );
    });
  });

  group('Property 22: Overlapping calls do not mix results', () {
    // Feature: coffin-ai, Property 22: Overlapping calls do not mix results
    // Validates: Requirements 9.13, 10.9
    Glados(anyOverlapCase, ExploreConfig(numRuns: _numRuns)).test(
      'each call gets its own result and its own issue',
      (OverlapCase c) async {
        _property22Runs.increment();
        (c.secondFirst ? _property22SecondFirst : _property22FirstFirst)
            .increment();
        _property22Outcomes[c.outcome1.index].increment();
        _property22Outcomes[c.outcome2.index].increment();
        (c.late1 ? _property22Late : _property22Early).increment();
        (c.late2 ? _property22Late : _property22Early).increment();
        final AiIssueKind? k1 = _overlapKind(c.outcome1, c.late1);
        final AiIssueKind? k2 = _overlapKind(c.outcome2, c.late2);
        if (k1 != null && k2 != null && k1 != k2) {
          _property22MixedKinds.increment();
        }
        final OverlapRun run;
        try {
          run = await runOverlap(c);
        } on Object catch (e) {
          throw TestFailure('driver failed: $e\n  case: $c');
        }
        try {
          await checkProperty22(c, run);
        } on TestFailure catch (e) {
          throw TestFailure('${e.message}\n  case: $c');
        }
      },
    );

    test('ran exactly $_numRuns times and saw both orders', () {
      expect(_property22Runs.runs > 0, isTrue);
      expect(_property22Runs.runs, _numRuns);
      expect(_property22FirstFirst.runs > 0, isTrue);
      expect(_property22SecondFirst.runs > 0, isTrue);
      expect(_property22MixedKinds.runs > 0, isTrue);
      expect(_property22Early.runs > 0, isTrue);
      expect(_property22Late.runs > 0, isTrue);
      for (final OverlapOutcome o in OverlapOutcome.values) {
        expect(
          _property22Outcomes[o.index].runs > 0,
          isTrue,
          reason: 'outcome ${o.name} never occurred',
        );
      }
      // ignore: avoid_print
      print(
        'Property 22: runs=${_property22Runs.runs} '
        '1-then-2=${_property22FirstFirst.runs} '
        '2-then-1=${_property22SecondFirst.runs} '
        'mixedKinds=${_property22MixedKinds.runs} '
        'early=${_property22Early.runs} late=${_property22Late.runs} '
        'outcomes=${<String>[for (final OverlapOutcome o in OverlapOutcome.values) '${o.name}=${_property22Outcomes[o.index].runs}']}',
      );
    });
  });
}
