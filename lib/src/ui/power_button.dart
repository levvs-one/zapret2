import 'package:flutter/material.dart';

import '../core/controller.dart';

/// The one control that matters. Tonal when off, filled primary when on,
/// with a thin progress ring while the engine starts or stops.
class PowerButton extends StatefulWidget {
  const PowerButton({super.key, required this.power, required this.onPressed});

  final Power power;
  final VoidCallback? onPressed;

  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final on = widget.power == Power.on;
    final busy =
        widget.power == Power.starting || widget.power == Power.stopping;
    const size = 168.0;

    return Semantics(
      button: true,
      toggled: on,
      label: on ? 'Выключить' : 'Включить',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: MouseRegion(
          cursor: widget.onPressed == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: SizedBox.square(
              dimension: size + 20,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: busy
                        ? SizedBox.square(
                            dimension: size + 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              strokeCap: StrokeCap.round,
                              color: c.primary,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? c.primary : c.surfaceContainerHigh,
                    ),
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      size: 64,
                      color: on ? c.onPrimary : c.onSurfaceVariant,
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
