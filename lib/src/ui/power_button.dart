import 'package:flutter/material.dart';

import '../core/controller.dart';

/// The one control that matters. Neutral when off; filled with a soft halo
/// when on; a thin ring spins around it while the engine starts or stops.
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

  static const _size = 140.0;
  static const _halo = 20.0;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final on = widget.power == Power.on;
    final busy =
        widget.power == Power.starting || widget.power == Power.stopping;
    const curve = Curves.easeOutCubic;
    const duration = Duration(milliseconds: 320);

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
            scale: _pressed ? 0.95 : 1,
            duration: const Duration(milliseconds: 140),
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
                          ? c.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                    ),
                  ),
                  if (busy)
                    const SizedBox.square(
                      dimension: _size + 12,
                      child: CircularProgressIndicator(
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
                      color: on ? c.primary : c.surfaceContainerLowest,
                      border: Border.all(
                        color: _focused
                            ? on
                                  ? c.onPrimary
                                  : c.primary
                            : on
                            ? c.primary
                            : c.outlineVariant,
                        width: _focused ? 3 : 1,
                      ),
                    ),
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        end: on ? c.onPrimary : c.onSurfaceVariant,
                      ),
                      duration: duration,
                      builder: (_, color, _) => Icon(
                        Icons.power_settings_new_rounded,
                        size: 56,
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
