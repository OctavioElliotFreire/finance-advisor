import 'package:flutter/material.dart';

/// The small colored square used to mark member identity next to a group
/// header (account groups on Contas · Saldos/Extrato) — a plain colored
/// square, not `ConnectionHealthRow`'s circular status dot, which is a
/// different, unrelated indicator (connection health, not member identity).
class MemberDot extends StatelessWidget {
  const MemberDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(width: size, height: size, color: color);
  }
}
