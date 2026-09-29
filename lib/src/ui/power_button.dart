import 'package:flutter/material.dart';

import '../core/controller.dart';

/// The primary control. It stays visually quiet when off and gains one clear
/// accent when active. Busy states add a thin progress ring, nothing more.
class PowerButton extends StatefulWidget {
  const PowerButton({super.key, required this.power, required this.onPressed});

  final Power power;
  final VoidCallback? onPressed;

  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton> {
  bool _pressed = false;
  bool _focused = false;

  static const _size = 128.0;
  static const _halo = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final on = widget.power == Power.on;
    final busy =
        widget.power == Power.starting || widget.power == Power.stopping;
    const curve = Curves.easeOutCubic;
    const duration = Duration(milliseconds: 280);

    return Semantics(
      button: true,
      toggled: on,
      label: on ? 'Выключить' : 'Включить',
      child: FocusableActionDetector(
        enabled: widget.onPressed != null,
        mouseCursor: widget.onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onShowFocusHighlight: (focused) {
          if (mounted) setState(() => _focused = focused);
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTapDown: widget.onPressed == null
              ? null
              : (_) => setState(() => _pressed = true),
          onTapCancel: widget.onPressed == null
              ? null
              : () => setState(() => _pressed = false),
          onTapUp: widget.onPressed == null
              ? null
              : (_) => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: SizedBox.square(
              dimension: _size + _halo * 2,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: duration,
                    curve: curve,
                    width: on ? _size + _halo * 2 : _size,
                    height: on ? _size + _halo * 2 : _size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on
                          ? colors.primary.withValues(alpha: 0.10)
                          : Colors.transparent,
                    ),
                  ),
                  if (busy)
                    SizedBox.square(
                      dimension: _size + 12,
                      child: CircularProgressIndicator(
                        color: colors.primary,
                        strokeWidth: 2.5,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                  AnimatedContainer(
                    duration: duration,
                    curve: curve,
                    width: _size,
                    height: _size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                      border: Border.all(
                        color: _focused
                            ? colors.primary
                            : on
                            ? colors.primary
                            : colors.outlineVariant,
                        width: _focused ? 3 : 1,
                      ),
                    ),
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        end: on ? colors.onPrimary : colors.onSurfaceVariant,
                      ),
                      duration: duration,
                      builder: (_, color, _) => Icon(
                        Icons.power_settings_new_rounded,
                        size: 52,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
