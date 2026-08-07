import 'package:flutter/material.dart';

/// Shared section/group header (e.g. connections grouped by member, a
/// "Pending invites" heading, a card title) — replaces per-screen ad hoc
/// `Text(..., style: ...titleSmall)` blocks.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          ?trailing,
        ],
      ),
    );
  }
}
