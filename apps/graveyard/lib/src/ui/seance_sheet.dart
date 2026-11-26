import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/calendar_date.dart';
import '../domain/grave.dart';
import '../domain/seance/revival_step_kind.dart';
import '../domain/seance/seance_facts.dart';
import '../domain/seance/seance_result.dart';
import '../domain/seance/seance_rules.dart';
import '../domain/seance/verdict_slot_height.dart';
import 'graveyard_copy.dart';
import 'seance_ai.dart';

/// Opens the séance sheet of [grave] and waits until it closes.
///
/// The sheet shows the revival score, the three steps and a verdict line from
/// [seanceAi]. Nothing is stored.
Future<void> showSeanceSheet(
  BuildContext context, {
  required Grave grave,
  required CalendarDate today,
  required CoffinAI seanceAi,
  ValueChanged<Grave>? onRaise,
}) {
  final Brightness brightness = Theme.of(context).brightness;
  final CoffinColorTokens tokens = brightness == Brightness.dark
      ? CoffinColorTokens.night
      : CoffinColorTokens.daylight;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: tokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    routeSettings: RouteSettings(
      name: GraveyardCopy.seanceRouteName(grave.name),
    ),
    builder: (BuildContext sheetContext) => SeanceSheet(
      grave: grave,
      today: today,
      seanceAi: seanceAi,
      onRaise: onRaise,
    ),
  );
}

/// The content of the séance sheet for one [Grave].
///
/// The score, band and steps are computed once and shown at once. The verdict
/// line arrives later, or is replaced by [GraveyardCopy.safeVerdictLine] when
/// the generator fails or takes longer than [verdictWaitLimit].
class SeanceSheet extends StatefulWidget {
  /// Creates the sheet content of [grave] on [today].
  const SeanceSheet({
    super.key,
    required this.grave,
    required this.today,
    required this.seanceAi,
    this.onRaise,
  });

  /// The grave the séance is held for.
  final Grave grave;

  /// The calendar day the séance is held on.
  final CalendarDate today;

  /// The generator asked for the verdict line.
  final CoffinAI seanceAi;

  /// Called once, after the sheet has closed, when the user raises the grave.
  ///
  /// When null, the sheet shows no Raise control.
  final ValueChanged<Grave>? onRaise;

  @override
  State<SeanceSheet> createState() => _SeanceSheetState();
}

class _SeanceSheetState extends State<SeanceSheet>
    with SingleTickerProviderStateMixin {
  late final Grave _grave;
  late final SeanceResult _result;
  late final AnimationController _fade;
  late final CurvedAnimation _curve;
  bool _disposed = false;
  bool _revealStarted = false;
  bool _raised = false;
  String? _verdict;
  final GlobalKey _loaderKey = GlobalKey();
  double? _slotWidth;
  TextScaler? _slotScaler;
  double _lineHeight = 0;
  double _charsPerLine = 0;
  double _loaderHeight = 0;

  @override
  void initState() {
    super.initState();
    _grave = widget.grave;
    final SeanceFacts facts = SeanceFacts.of(
      grave: _grave,
      today: widget.today,
    );
    _result = SeanceRules.evaluate(facts);
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _curve = CurvedAnimation(parent: _fade, curve: Curves.easeInOut);
    _askForVerdict(facts);
  }

  void _askForVerdict(SeanceFacts facts) {
    final AiRequest request = buildVerdictRequest(grave: _grave, facts: facts);
    Future<AiReply> reply;
    try {
      reply = widget.seanceAi.ask(request);
    } catch (_) {
      _settle(null);
      return;
    }
    reply
        .timeout(verdictWaitLimit)
        .then(
          (AiReply r) => _settle(r.isUsableFor(request) ? r.text : null),
          onError: (Object _) => _settle(null),
        );
  }

  void _settle(String? text) {
    if (_disposed || _verdict != null) return;
    setState(() => _verdict = text ?? GraveyardCopy.safeVerdictLine);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_revealStarted) return;
    _revealStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _fade.value = 1;
    } else {
      _fade.forward();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _curve.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _raise() {
    final ValueChanged<Grave>? onRaise = widget.onRaise;
    if (_raised || onRaise == null) return;
    _raised = true;
    Navigator.of(context).pop();
    onRaise(_grave);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CoffinColorTokens tokens = theme.brightness == Brightness.dark
        ? CoffinColorTokens.night
        : CoffinColorTokens.daylight;
    final TextTheme text = theme.textTheme;
    final List<RevivalStepKind> steps = _result.steps;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints outer) =>
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(_sheetPadding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    _grave.name,
                                    style: text.titleLarge?.copyWith(
                                      color: tokens.text,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                key: const ValueKey<String>('seance-close'),
                                autofocus: true,
                                tooltip: GraveyardCopy.closeSeanceLabel,
                                onPressed: _close,
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                color: tokens.text,
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          if (widget.onRaise != null) ...<Widget>[
                            const SizedBox(height: 8),
                            _raiseControl(),
                          ],
                          const SizedBox(height: 8),
                          FadeTransition(
                            opacity: _curve,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _scoreCard(text, tokens),
                                const SizedBox(height: 16),
                                for (int i = 0; i < steps.length; i++)
                                  _stepRow(i, steps[i], text, tokens),
                                const SizedBox(height: 16),
                                _verdictArea(
                                  text,
                                  tokens,
                                  outer.maxHeight - 2 * _sheetPadding,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _raiseControl() {
    return Semantics(
      button: true,
      label: GraveyardCopy.raiseControlLabel(_grave.name),
      excludeSemantics: true,
      onTap: _raise,
      child: FilledButton(
        key: const ValueKey<String>('seance-raise'),
        onPressed: _raise,
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: const Text(
          GraveyardCopy.raiseControlText,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _scoreCard(TextTheme text, CoffinColorTokens tokens) {
    final String band = GraveyardCopy.revivalBandLabel(_result.band);
    return Semantics(
      container: true,
      label: GraveyardCopy.revivalScoreLabel(_result.score, _result.band),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: CoffinGlow.decoration(
          color: tokens.primary,
          intensity: 0.3,
          fill: tokens.raised,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                '${_result.score}',
                style: text.displaySmall?.copyWith(color: tokens.text),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  band,
                  style: text.titleMedium?.copyWith(color: tokens.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepRow(
    int index,
    RevivalStepKind kind,
    TextTheme text,
    CoffinColorTokens tokens,
  ) {
    final String stepText = GraveyardCopy.revivalStepText(kind);
    return Semantics(
      container: true,
      label: GraveyardCopy.revivalStepLabel(
        index + 1,
        _result.steps.length,
        stepText,
      ),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: _stepNumberWidth,
              child: Text(
                '${index + 1}.',
                style: text.bodyLarge?.copyWith(color: tokens.muted),
              ),
            ),
            Expanded(
              child: Text(
                stepText,
                style: text.bodyLarge?.copyWith(color: tokens.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The style of the verdict line, used both to draw and to measure it.
  TextStyle? _verdictStyle(TextTheme text, CoffinColorTokens tokens) =>
      text.bodyLarge?.copyWith(
        color: tokens.text,
        fontSize: (text.bodyLarge?.fontSize ?? 16) + _verdictSizeStep,
        fontWeight: FontWeight.w600,
      );

  /// How many logical pixels the verdict font is larger than the step text.
  static const double _verdictSizeStep = 1;

  /// The width of the step number column, in logical pixels.
  ///
  /// The step rows and the Verdict_Block start at the same left edge: the
  /// number column starts there, and so does the accent bar. Both fill the
  /// width of the same column, so neither has an extra inset.
  static const double _stepNumberWidth = 32;

  /// The width of the verdict accent bar, in logical pixels.
  static const double _accentBarWidth = 3;

  /// The gap between the accent bar and the verdict text.
  static const double _accentBarGap = 8;

  /// The Verdict_Slot: one box whose minimum height fits a verdict of
  /// [verdictMaxLength] code units and the [GhostLoader], so the sheet keeps
  /// its height when the verdict replaces the loader.
  ///
  /// The reservation never exceeds [viewportHeight], the height the scroll
  /// area shows at once. Content that tall already fills the sheet, which
  /// then stays anchored at the top, so a taller slot would only push the
  /// verdict out of view at the end of the scroll.
  Widget _verdictArea(
    TextTheme text,
    CoffinColorTokens tokens,
    double viewportHeight,
  ) {
    final TextStyle? style = _verdictStyle(text, tokens);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double reserved = _reservedSlotHeight(
          constraints.maxWidth - _accentBarWidth - _accentBarGap,
          scaler,
          style,
        );
        final double cap = viewportHeight.isFinite
            ? math.max(0, viewportHeight)
            : double.infinity;
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: math.min(reserved, cap)),
          child: _verdictContent(style, tokens.primary),
        );
      },
    );
  }

  Widget _verdictContent(TextStyle? style, Color accent) {
    final String? verdict = _verdict;
    if (verdict == null) {
      return Center(
        child: GhostLoader(
          key: _loaderKey,
          caption: GraveyardCopy.seanceThinkingCaption,
        ),
      );
    }
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Semantics(
        container: true,
        liveRegion: true,
        label: verdict,
        excludeSemantics: true,
        // The text sizes the block; the bar spans the full text height.
        child: SizedBox(
          width: double.infinity,
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: _accentBarWidth + _accentBarGap,
                ),
                child: Text(verdict, textAlign: TextAlign.start, style: style),
              ),
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: _accentBarWidth,
                child: DecoratedBox(decoration: BoxDecoration(color: accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The height of the Verdict_Slot at [width] and [scaler].
  ///
  /// The line height and the characters per line of the verdict [style] are
  /// measured once per `(width, text scale)` pair. The minimum is the
  /// rendered [GhostLoader] height, read after layout. Reading it never moves
  /// the pending state, because the loader already takes that height there.
  double _reservedSlotHeight(
    double width,
    TextScaler scaler,
    TextStyle? style,
  ) {
    if (width != _slotWidth || scaler != _slotScaler) {
      _slotWidth = width;
      _slotScaler = scaler;
      // Once the loader is gone its last height stays the minimum.
      if (_verdict == null) _loaderHeight = 0;
      _measureVerdictLine(width, scaler, style);
    }
    if (_verdict == null) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (_disposed) return;
        final Size? size = _loaderKey.currentContext?.size;
        if (size != null && size.height > _loaderHeight) {
          _loaderHeight = size.height;
        }
      });
    }
    return VerdictSlotHeight.of(
      lineHeight: _lineHeight,
      minHeight: _loaderHeight,
      maxCodeUnits: verdictMaxLength,
      charsPerLine: _charsPerLine,
    );
  }

  /// Measures the line height and the characters per line of [style] at
  /// [width] with a [TextPainter].
  void _measureVerdictLine(double width, TextScaler scaler, TextStyle? style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: _sampleText, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final double sampleWidth = painter.width;
    _lineHeight = painter.height;
    painter.dispose();
    if (!width.isFinite || width <= 0 || sampleWidth <= 0) {
      _charsPerLine = 0;
      return;
    }
    final double charWidth = sampleWidth / _sampleText.length;
    _charsPerLine = (width / charWidth * _wrapFill).floorToDouble();
  }

  /// A one-line sample of ordinary verdict text, used for the average
  /// character width.
  static const String _sampleText =
      'The spirits whisper that this project may rise again.';

  /// The padding around the sheet content.
  static const double _sheetPadding = 16;

  /// The share of a full line a wrapped line holds, because words wrap
  /// whole.
  static const double _wrapFill = 0.8;
}
