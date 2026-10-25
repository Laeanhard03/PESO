import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'design_tokens.dart';

/// One real widget to highlight. The widget must carry [target] and remain
/// mounted during this step. No screenshot coordinates are hard-coded.
class SpotlightStep {
  const SpotlightStep({
    required this.target,
    required this.title,
    required this.description,
    this.actionHint = 'Tap the highlighted area or choose Next.',
  });

  final GlobalKey target;
  final String title;
  final String description;
  final String actionHint;
}

/// Stores only whether a public walkthrough was completed or skipped.
/// No form fields, identities or applicant records are stored by this feature.
abstract final class SpotlightTourProgress {
  static const _storage = FlutterSecureStorage();
  static final Set<String> _doneInSession = <String>{};

  static String _key(String id) => 'peso.spotlight.completed.$id';

  static Future<bool> isDone(String id) async {
    if (_doneInSession.contains(id)) return true;
    try {
      final result = await _storage.read(key: _key(id));
      if (result == '1') {
        _doneInSession.add(id);
        return true;
      }
    } catch (_) {
      // When secure browser storage is unavailable, show at most once
      // per running session and leave form/account functions unaffected.
    }
    return false;
  }

  static Future<void> markDone(String id) async {
    _doneInSession.add(id);
    try {
      await _storage.write(key: _key(id), value: '1');
    } catch (_) {
      // A missing browser encryption key must not interrupt navigation.
    }
  }
}

/// Reusable, real-time guided tour with a click-through spotlight cutout.
///
/// Attach [SpotlightStep.target] to real Flutter controls. The dark quadrants
/// block unrelated touches, while the highlighted control remains tappable.
/// Steps automatically scroll to their targets on compact and wide layouts.
class SpotlightTour extends StatefulWidget {
  const SpotlightTour({
    super.key,
    required this.tourId,
    required this.steps,
    required this.child,
    this.autoStart = true,
  });

  final String tourId;
  final List<SpotlightStep> steps;
  final Widget child;
  final bool autoStart;

  @override
  State<SpotlightTour> createState() => SpotlightTourState();
}

class SpotlightTourState extends State<SpotlightTour>
    with WidgetsBindingObserver {
  OverlayEntry? _entry;
  ScrollPosition? _scrollPosition;
  int _index = 0;
  int _generation = 0;
  bool _showing = false;

  bool get isShowing => _showing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(start());
      });
    }
  }

  @override
  void didUpdateWidget(covariant SpotlightTour oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tourId != widget.tourId) {
      dismiss();
      if (widget.autoStart) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(start());
        });
      }
    } else if (_showing) {
      // Inherited widget updates can arrive while the parent page is building.
      // Defer overlay invalidation to the end of that frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showing) _entry?.markNeedsBuild();
      });
    }
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entry?.markNeedsBuild();
    });
  }

  Future<void> start({bool replay = false}) async {
    final generation = ++_generation;
    if (widget.steps.isEmpty || !mounted) return;
    if (!replay && await SpotlightTourProgress.isDone(widget.tourId)) return;
    if (!mounted || generation != _generation) return;
    _removeEntry();
    _showing = true;
    await _showStep(0, generation);
  }

  Future<void> next() => _showStep(_index + 1, ++_generation);

  Future<void> previous() => _showStep(_index - 1, ++_generation);

  Future<void> _showStep(int index, int generation) async {
    if (!mounted || !_showing || generation != _generation) return;
    if (index >= widget.steps.length) {
      finish();
      return;
    }
    if (index < 0) return;

    final contextForTarget = widget.steps[index].target.currentContext;
    if (contextForTarget == null) {
      // Navigation can replace targets. Never show an overlay pointing to a
      // control from a previous route or a vanished conditional section.
      dismiss();
      return;
    }
    _index = index;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    _scrollPosition?.removeListener(_refresh);
    _scrollPosition = null;

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    await Scrollable.ensureVisible(
      contextForTarget,
      alignment: 0.32,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    if (!mounted ||
        !contextForTarget.mounted ||
        generation != _generation ||
        !_showing) {
      return;
    }
    final scroller = Scrollable.maybeOf(contextForTarget);
    _scrollPosition = scroller?.position;
    _scrollPosition?.addListener(_refresh);

    // The scroll animation has already completed. Insert immediately: a
    // post-frame callback alone does not schedule a new frame on replay.
    _entry = OverlayEntry(builder: _overlayBuilder);
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _refresh() => _entry?.markNeedsBuild();

  void dismiss() {
    _generation++;
    _showing = false;
    _removeEntry();
  }

  void finish() {
    if (!_showing) return;
    final id = widget.tourId;
    dismiss();
    unawaited(SpotlightTourProgress.markDone(id));
  }

  void _removeEntry() {
    _scrollPosition?.removeListener(_refresh);
    _scrollPosition = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    dismiss();
    super.dispose();
  }

  Widget _overlayBuilder(BuildContext overlayContext) {
    if (!_showing || _index >= widget.steps.length) {
      return const SizedBox.shrink();
    }
    final targetContext = widget.steps[_index].target.currentContext;
    final overlayRender = Overlay.of(
      context,
      rootOverlay: true,
    ).context.findRenderObject();
    final targetRender = targetContext?.findRenderObject();
    if (overlayRender is! RenderBox ||
        targetRender is! RenderBox ||
        !overlayRender.attached ||
        !targetRender.attached ||
        !targetRender.hasSize) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (!size.width.isFinite || !size.height.isFinite) {
            return const SizedBox.shrink();
          }
          final origin = targetRender.localToGlobal(
            Offset.zero,
            ancestor: overlayRender,
          );
          final bounds = Rect.fromLTWH(0, 0, size.width, size.height);
          final focus = (origin & targetRender.size)
              .inflate(6)
              .intersect(bounds);
          if (focus.isEmpty) return const SizedBox.shrink();

          const shadow = Color(0xC913271F);
          final safe = MediaQuery.paddingOf(context);
          final compact = size.width < 600;
          final bubbleWidth = math.min(size.width - 32, 448.0);
          final bubbleHeight = math.min(
            compact ? 236.0 : 204.0,
            size.height * 0.54,
          );
          final below = focus.bottom + 12;
          final above = focus.top - bubbleHeight - 12;
          final minTop = safe.top + 8;
          final maxTop = math.max(
            minTop,
            size.height - safe.bottom - bubbleHeight - 8,
          );
          final bubbleTop = below + bubbleHeight <= size.height - safe.bottom
              ? below
              : above >= minTop
              ? above
              : below.clamp(minTop, maxTop).toDouble();
          final bubbleLeft = (size.width - bubbleWidth) / 2;

          Widget barrier(Rect area) => Positioned.fromRect(
            rect: area,
            child: ColoredBox(
              color: shadow,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
              ),
            ),
          );

          final step = widget.steps[_index];
          return Stack(
            children: [
              if (focus.top > 0)
                barrier(Rect.fromLTRB(0, 0, size.width, focus.top)),
              if (focus.bottom < size.height)
                barrier(
                  Rect.fromLTRB(0, focus.bottom, size.width, size.height),
                ),
              if (focus.left > 0)
                barrier(Rect.fromLTRB(0, focus.top, focus.left, focus.bottom)),
              if (focus.right < size.width)
                barrier(
                  Rect.fromLTRB(
                    focus.right,
                    focus.top,
                    size.width,
                    focus.bottom,
                  ),
                ),
              Positioned.fromRect(
                rect: focus,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFE7C77E),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Color(0x99E7C77E), blurRadius: 12),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: bubbleTop,
                left: bubbleLeft,
                width: bubbleWidth,
                child: Semantics(
                  label:
                      'Guided tour step ${_index + 1} of ${widget.steps.length}. ${step.title}',
                  container: true,
                  child: Material(
                    elevation: 14,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.max(140, bubbleHeight),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GUIDED TOUR  ·  ${_index + 1}/${widget.steps.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: PesoTokens.brandGreenDark,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              step.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: PesoTokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              step.description,
                              style: const TextStyle(
                                fontSize: 13,
                                color: PesoTokens.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              step.actionHint,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: PesoTokens.brandGreenDark,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: finish,
                                  child: const Text('Skip'),
                                ),
                                if (_index > 0)
                                  OutlinedButton(
                                    onPressed: () => unawaited(previous()),
                                    child: const Text('Back'),
                                  ),
                                FilledButton(
                                  onPressed: () => unawaited(next()),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: PesoTokens.brandGreenDark,
                                  ),
                                  child: Text(
                                    _index == widget.steps.length - 1
                                        ? 'Finish'
                                        : 'Next',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
