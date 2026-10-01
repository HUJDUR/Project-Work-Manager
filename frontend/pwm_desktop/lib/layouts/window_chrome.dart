import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/app_theme.dart';

/// The app draws its own title bar: `main` hides the OS one, so minimise,
/// maximise and close live here, and the bar they sit in is what moves the
/// window.
///
/// Every call into `window_manager` is guarded, because a widget test has no
/// window behind the platform channel and the top bar must still build.
Future<void> _window(Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    // No window to talk to — a test, or a platform without the plugin.
  }
}

/// Lays [child] over a layer that drags the window.
///
/// The drag layer goes **behind** the bar's contents rather than around them.
/// Wrapping them would put an `onDoubleTap` recogniser above every button in the
/// bar, and the gesture arena then holds each tap until the double-click timeout
/// expires — so Save, the bell and the account chip would all answer a beat
/// late, or not at all. Text and icons do not absorb pointers, so almost all of
/// the bar still drags.
class DraggableBar extends StatelessWidget {
  const DraggableBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: AppDragArea(child: SizedBox.expand())),
        child,
      ],
    );
  }
}

/// Drags the window, and maximises it on a double click, the way a native title
/// bar does. Put it behind a bar's contents with [DraggableBar] rather than
/// around them.
class AppDragArea extends StatelessWidget {
  const AppDragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => _window(windowManager.startDragging),
      onDoubleTap: () => _window(() async {
        await windowManager.isMaximized()
            ? windowManager.unmaximize()
            : windowManager.maximize();
      }),
      child: child,
    );
  }
}

/// Minimise, maximise/restore and close, in that order. They run the full
/// height of the bar they sit in rather than hugging the corner, so the bar
/// reads as one row instead of a strip with a hole punched in it.
class WindowControls extends StatefulWidget {
  const WindowControls({super.key, this.height = 40});

  /// Match the height of the bar hosting them.
  final double height;

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _readState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  /// The window can be maximised without a button being pressed — a snap, or a
  /// double click on the drag area — so the glyph is read back rather than
  /// toggled.
  @override
  void onWindowMaximize() => _readState();

  @override
  void onWindowUnmaximize() => _readState();

  Future<void> _readState() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (mounted && maximized != _maximized) {
        setState(() => _maximized = maximized);
      }
    } catch (_) {
      // No window behind the channel; the restore glyph stays as it is.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CaptionButton(
          height: widget.height,
          icon: Icons.remove,
          tooltip: 'Minimise',
          onPressed: () => _window(windowManager.minimize),
        ),
        _CaptionButton(
          height: widget.height,
          icon: _maximized ? Icons.filter_none : Icons.crop_square,
          // The restore glyph is two stacked squares, which reads upside down
          // at this size unless it is turned over.
          flipIcon: _maximized,
          tooltip: _maximized ? 'Restore' : 'Maximise',
          onPressed: () => _window(
            _maximized ? windowManager.unmaximize : windowManager.maximize,
          ),
        ),
        _CaptionButton(
          height: widget.height,
          icon: Icons.close,
          tooltip: 'Close',
          danger: true,
          onPressed: () => _window(windowManager.close),
        ),
      ],
    );
  }
}

/// The bar a full-window screen wears in place of `MasterScreen`'s: it drags
/// the window, and it carries the caption buttons, because a route pushed on the
/// root navigator covers the top bar that would otherwise have them.
class AppWindowBar extends StatelessWidget {
  const AppWindowBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.height = 60,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: AppColors.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DraggableBar(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (leading != null) ...[leading!, const SizedBox(width: 8)],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (actions.isNotEmpty) const SizedBox(width: 16),
                    ...actions,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(width: 1, child: ColoredBox(color: AppColors.border)),
          ),
          WindowControls(height: height),
        ],
      ),
    );
  }
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.height,
    this.danger = false,
    this.flipIcon = false,
  });

  static const double width = 46;

  /// Windows 11's own close-button red, and what it turns the glyph.
  static const Color _closeHover = Color(0xFFC42B1C);

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double height;

  /// Close goes red on hover rather than grey.
  final bool danger;

  final bool flipIcon;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = !_hovered
        ? Colors.transparent
        : widget.danger
            ? _CaptionButton._closeHover
            : AppColors.canvas;
    final foreground = _hovered && widget.danger
        ? AppColors.surface
        : AppColors.textSecondary;

    final icon = Icon(widget.icon, size: 15, color: foreground);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: _CaptionButton.width,
            height: widget.height,
            alignment: Alignment.center,
            color: background,
            child: widget.flipIcon
                ? Transform.rotate(angle: 3.14159, child: icon)
                : icon,
          ),
        ),
      ),
    );
  }
}
