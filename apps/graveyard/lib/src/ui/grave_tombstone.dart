import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import '../domain/calendar_date.dart';
import '../domain/grave.dart';
import '../domain/grave_source.dart';
import '../domain/repo_info.dart';
import '../domain/scene/crack_generator.dart';
import '../domain/scene/description_cleaner.dart';
import '../domain/scene/keep_out_rect.dart';
import '../domain/scene/tombstone_facts.dart';
import '../domain/scene/tombstone_fragment_kind.dart';
import '../domain/scene/weathering.dart';
import '../domain/scene/weathering_result.dart';
import 'arch_epitaph.dart';
import 'crack_painter.dart';
import 'graveyard_copy.dart';

/// One weathered tombstone for a [Grave], with its delete button below it.
///
/// The stone is a `TombstoneCard` without its own epitaph, an `ArchEpitaph`
/// and, for a grave older than 1825 days, a layer of cracks. The whole stone
/// tilts around the middle of its base and fades with age. The age comes from
/// [today] and the grave's date of death. Screen readers get one label.
class GraveTombstone extends StatelessWidget {
  /// Creates a tombstone for [grave], counted to [today].
  ///
  /// [riseProgress] is the progress of the Rise, from 0 to 1. At 1 the stone
  /// rests in place.
  const GraveTombstone({
    super.key,
    required this.grave,
    required this.today,
    required this.onDelete,
    this.riseProgress = 1,
  });

  /// The grave to show.
  final Grave grave;

  /// The current day.
  final CalendarDate today;

  /// Called when the delete button is pressed.
  final VoidCallback onDelete;

  /// Progress of the Rise, from 0 (below the ground) to 1 (at rest).
  final double riseProgress;

  /// Widest a stone gets, equal to the width of `TombstoneCard`.
  static const double maxStoneWidth = 300;

  /// How far below its resting place a stone starts its Rise.
  static const double riseDistance = 24;

  static const double _contentInset = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.brightness == Brightness.dark
        ? CoffinColorTokens.night
        : CoffinColorTokens.daylight;
    final textTheme = theme.textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final dayCount = math.max(0, grave.dateOfDeath.daysUntil(today));
    final weathering = Weathering.of(dayCount: dayCount, graveId: grave.id);
    final RepoInfo? repo = grave.source == GraveSource.github
        ? grave.repo
        : null;
    final facts = TombstoneFacts.of(
      grave: grave,
      today: today,
      dateLine: GraveyardCopy.dateLine(grave.dateOfDeath),
    );
    String textOf(TombstoneFragmentKind kind) =>
        facts.firstWhere((f) => f.kind == kind).text;
    final deadFor = textOf(TombstoneFragmentKind.deadFor);
    final fullNameFragments = facts.where(
      (f) => f.kind == TombstoneFragmentKind.fullName,
    );
    final cleaned = repo?.description == null
        ? ''
        : DescriptionCleaner.clean(repo!.description!);

    final label = repo == null
        ? GraveyardCopy.manualGraveLabel(name: grave.name, deadForText: deadFor)
        : GraveyardCopy.githubGraveLabel(
            name: grave.name,
            deadForText: deadFor,
            fullName: repo.fullName,
            stars: repo.stars,
            archived: repo.archived,
            description: repo.description,
          );

    final card = TombstoneCard(
      title: textOf(TombstoneFragmentKind.title),
      dateLine: textOf(TombstoneFragmentKind.dateLine),
      showEpitaph: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(deadFor, textAlign: TextAlign.center),
          if (repo == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                GraveyardCopy.buriedByHand,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall,
              ),
            )
          else ...<Widget>[
            if (fullNameFragments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  fullNameFragments.first.text,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      GraveyardCopy.stars(repo.stars, archived: repo.archived),
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 4),
                  ExcludeSemantics(
                    child: Icon(Icons.star, size: 16, color: tokens.tertiary),
                  ),
                ],
              ),
            ),
            if (cleaned.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  cleaned,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );

    final stone = Stack(
      children: <Widget>[
        if (weathering.fade > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _FadeHaloPainter(
                    color: tokens.background.withValues(alpha: weathering.fade),
                  ),
                ),
              ),
            ),
          ),
        card,
        const Positioned.fill(child: ArchEpitaph()),
        if (dayCount > CrackGenerator.ageThresholdDays)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    return RepaintBoundary(
                      child: CustomPaint(
                        key: ValueKey<String>('cracks-${grave.id}'),
                        painter: CrackPainter(
                          cracks: CrackGenerator.generate(
                            dayCount: dayCount,
                            graveId: grave.id,
                            stoneWidth: width,
                            stoneHeight: height,
                            keepOut: <KeepOutRect>[
                              KeepOutRect(
                                left: _contentInset,
                                top: 0,
                                right: width - _contentInset,
                                bottom: height - _contentInset,
                              ),
                              ArchEpitaph.rectFor(
                                width: width,
                                textScaler: scaler,
                              ),
                            ],
                          ),
                          color: tokens.background.withValues(alpha: 0.7),
                          strokeWidth: CrackGenerator.strokeWidth,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );

    final progress = riseProgress.clamp(0.0, 1.0).toDouble();
    // One semantic group per tombstone, so a screen reader reads the stone and
    // its Delete button together, in grave order, at every width.
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxStoneWidth),
              child: Transform.translate(
                offset: Offset(0, (1 - progress) * riseDistance),
                child: Opacity(
                  opacity: progress,
                  child: Semantics(
                    container: true,
                    label: label,
                    child: ExcludeSemantics(
                      child: _Tilted(weathering: weathering, child: stone),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: GraveyardCopy.deleteLabel(grave.name),
            excludeSemantics: true,
            onTap: onDelete,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text(GraveyardCopy.delete),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rotates [child] around the middle of its base.
class _Tilted extends StatelessWidget {
  const _Tilted({required this.weathering, required this.child});

  final WeatheringResult weathering;
  final Widget child;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: weathering.tiltRadians,
    alignment: Alignment.bottomCenter,
    child: child,
  );
}

/// Paints the soft, ground-colored fringe of the Fade behind the stone.
class _FadeHaloPainter extends CustomPainter {
  const _FadeHaloPainter({required this.color});

  static const double _archRise = 140;
  static const double _bottomRadius = 16;
  static const double _inflate = 6;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final rise = math.min(_archRise, h);
    final path = Path()
      ..moveTo(0, rise)
      ..arcTo(Rect.fromLTRB(0, 0, w, rise * 2), math.pi, math.pi, false)
      ..lineTo(w, h - _bottomRadius)
      ..quadraticBezierTo(w, h, w - _bottomRadius, h)
      ..lineTo(_bottomRadius, h)
      ..quadraticBezierTo(0, h, 0, h - _bottomRadius)
      ..close();
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.scale((w + _inflate * 2) / w, (h + _inflate * 2) / h);
    canvas.translate(-w / 2, -h / 2);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _inflate),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FadeHaloPainter oldDelegate) =>
      oldDelegate.color != color;
}
