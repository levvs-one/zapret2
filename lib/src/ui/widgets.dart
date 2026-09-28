import 'package:flutter/material.dart';

/// A quiet grouped surface used for primary app controls and settings.
class Section extends StatelessWidget {
  const Section({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 20, endIndent: 20),
            children[i],
          ],
        ],
      ),
    );
  }
}
