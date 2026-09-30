import 'package:flutter/material.dart';

import '../core/controller.dart';

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

  static const _size = 112.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final on = widget.power == Power.on;
    final busy =
        widget.power == Power.starting || widget.power == Power.stopping;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: true,
      toggled: on,
      label: on ? 'Выключить' : 'Включить',
      child: FocusableActionDetector(
        enabled: widget.onPressed != null,
        mouseCursor: widget.onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onShowFocusHighlight: (value) {
          if (mounted) setState(() => _focused = value);
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
            curve: Curves.easeOutCubic,
            child: SizedBox.square(
              dimension: _size + 12,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (busy)
                    SizedBox.square(
                      dimension: _size + 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colors.primary,
                      ),
                    ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
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
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: Icon(
                        Icons.power_settings_new_rounded,
                        key: ValueKey(on),
                        size: 44,
                        color: on ? colors.onPrimary : colors.onSurfaceVariant,
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
