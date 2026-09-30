import 'package:flutter/material.dart';

/// Quiet grouped surface shared by the home screen and settings.
class Section extends StatelessWidget {
  const Section({super.key, required this.children, this.label});

  final List<Widget> children;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final section = Material(
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 18, endIndent: 18),
            children[i],
          ],
        ],
      ),
    );

    if (label == null) return section;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        section,
      ],
    );
  }
}
