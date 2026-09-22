import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// What a toast is telling the user - all that changes is the top line's
/// colour, green or the app's one red.
enum ToastType { success, error }

/// The toast currently on screen, if any - tracked so a second one replaces
/// the first rather than stacking on top of it, the same swap
/// `ScaffoldMessenger.hideCurrentSnackBar()` used to make.
OverlayEntry? _currentToast;

/// A corner popup - a card with a coloured line across the top that drains
/// over [duration] and then dismisses itself, or an "x" dismisses it early.
/// Floats on the [Overlay] rather than a `Scaffold`'s `ScaffoldMessenger`, so
/// it reads the same from any screen and never queues behind another one.
void showAppToast(
  BuildContext context, {
  required String message,
  ToastType type = ToastType.success,
  Duration duration = const Duration(seconds: 4),
}) {
  _currentToast?.remove();
  _currentToast = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _ToastCard(
      message: message,
      type: type,
      duration: duration,
      onDismiss: () {
        entry.remove();
        if (identical(_currentToast, entry)) {
          _currentToast = null;
        }
      },
    ),
  );

  _currentToast = entry;
  Overlay.of(context).insert(entry);
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _dismiss();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final lineColor =
        widget.type == ToastType.success ? AppColors.success : AppColors.danger;

    return Positioned(
      right: 16,
      bottom: 16,
      child: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Full width when shown, empty by the time the toast
                    // dismisses itself - the countdown, drawn rather than timed.
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (1 - _controller.value).clamp(0.0, 1.0),
                          child: Container(height: 3, color: lineColor),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                widget.message,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _dismiss,
                            tooltip: 'Dismiss',
                            icon: Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                            splashRadius: 16,
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
    );
  }
}
