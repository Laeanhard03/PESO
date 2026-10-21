import 'dart:async';

import 'package:flutter/material.dart';

import '../peso_ui/Reusable_Designs/design_tokens.dart';

/// The one visual language for PESO success, error, warning and info notices.
enum AppToastKind { success, error, warning, info }

/// A compact, dismissible notification above the current page (and dialogs).
///
/// All messages share the same white card, status accent, accessible heading,
/// subtle entrance/exit, and timeout indicator. New notices replace old ones,
/// so rapid API results never build up an unreadable queue.
abstract final class AppToast {
  static OverlayEntry? _current;
  static int _generation = 0;

  static void success(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
  }) => show(
    context,
    message,
    kind: AppToastKind.success,
    title: title,
    duration: duration,
  );

  static void error(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
  }) => show(
    context,
    message,
    kind: AppToastKind.error,
    title: title,
    duration: duration,
  );

  static void warning(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
  }) => show(
    context,
    message,
    kind: AppToastKind.warning,
    title: title,
    duration: duration,
  );

  static void info(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
  }) => show(
    context,
    message,
    kind: AppToastKind.info,
    title: title,
    duration: duration,
  );

  /// Legacy callers can keep passing an icon and tint during migration.
  static void show(
    BuildContext context,
    String message, {
    AppToastKind kind = AppToastKind.success,
    String? title,
    IconData? icon,
    Color? color,
    Duration? duration,
  }) {
    if (!context.mounted) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    showInOverlay(
      overlay,
      message,
      kind: kind,
      title: title,
      icon: icon,
      color: color,
      duration: duration,
    );
  }

  /// A safe handoff when navigation replaces the widget that showed a notice.
  static void showInOverlay(
    OverlayState overlay,
    String message, {
    AppToastKind kind = AppToastKind.info,
    String? title,
    IconData? icon,
    Color? color,
    Duration? duration,
  }) {
    if (!overlay.mounted || message.trim().isEmpty) return;
    dismiss();
    final generation = _generation;
    final style = _ToastStyle.fromKind(kind);
    final entry = OverlayEntry(
      builder: (_) => _ToastCard(
        message: message.trim(),
        title: title ?? style.title,
        icon: icon ?? style.icon,
        accent: color ?? style.accent,
        duration: duration ?? style.duration,
        onDismissed: () {
          if (_generation == generation) dismiss();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  /// Removes a notification without affecting the page or navigation stack.
  static void dismiss() {
    ++_generation;
    final old = _current;
    _current = null;
    if (old != null) {
      old.remove();
      old.dispose();
    }
  }
}

class _ToastStyle {
  const _ToastStyle(this.title, this.icon, this.accent, this.duration);

  final String title;
  final IconData icon;
  final Color accent;
  final Duration duration;

  static _ToastStyle fromKind(AppToastKind kind) => switch (kind) {
    AppToastKind.success => const _ToastStyle(
      'All set',
      Icons.check_circle_rounded,
      PesoTokens.brandGreen,
      Duration(seconds: 5),
    ),
    AppToastKind.error => const _ToastStyle(
      'Something went wrong',
      Icons.error_outline_rounded,
      Color(0xFFC23B3B),
      Duration(seconds: 8),
    ),
    AppToastKind.warning => const _ToastStyle(
      'Heads up',
      Icons.warning_amber_rounded,
      Color(0xFFAB701C),
      Duration(seconds: 7),
    ),
    AppToastKind.info => const _ToastStyle(
      'Just so you know',
      Icons.info_outline_rounded,
      Color(0xFF2563A7),
      Duration(seconds: 5),
    ),
  };
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.title,
    required this.message,
    required this.icon,
    required this.accent,
    required this.duration,
    required this.onDismissed,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color accent;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 170),
    );
    final eased = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _opacity = eased;
    _slide = Tween<Offset>(
      begin: const Offset(0.05, 0.24),
      end: Offset.zero,
    ).animate(eased);
    _controller.forward();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final compact = screen.width < 640;
    final cardWidth = compact ? screen.width - 24 : 420.0;
    final bottomInset =
        keyboardInset + (padding.bottom > 0 ? padding.bottom : 0) + 16;

    return Positioned(
      right: compact ? 12 : 24,
      left: compact ? 12 : null,
      bottom: bottomInset,
      width: compact ? null : cardWidth,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _opacity,
          child: Semantics(
            container: true,
            liveRegion: true,
            label: '${widget.title}. ${widget.message}',
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (screen.height * 0.48).clamp(100.0, 280.0),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE0E9E4)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x260B2920),
                        blurRadius: 26,
                        offset: Offset(0, 12),
                      ),
                      BoxShadow(
                        color: Color(0x0F0B2920),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 15, 10, 17),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: widget.accent.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(
                                      widget.icon,
                                      color: widget.accent,
                                      size: 23,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          widget.title,
                                          style: const TextStyle(
                                            color: PesoTokens.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            height: 1.22,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          widget.message,
                                          style: const TextStyle(
                                            color: PesoTokens.textSecondary,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _close,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 19,
                                  ),
                                  tooltip: 'Dismiss notification',
                                  color: const Color(0xFF687D71),
                                  splashRadius: 19,
                                  padding: const EdgeInsets.all(7),
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: ExcludeSemantics(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 1, end: 0),
                              duration: widget.duration,
                              builder: (context, remaining, child) => Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: remaining.clamp(0.0, 1.0),
                                  child: Container(
                                    height: 3,
                                    color: widget.accent.withValues(
                                      alpha: 0.84,
                                    ),
                                  ),
                                ),
                              ),
                            ),
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
      ),
    );
  }
}
