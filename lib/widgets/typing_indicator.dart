import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/constants.dart';

/// Three softly bouncing dots, shown before the first word of an answer.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, this.label});

  /// What screen readers say. Default: "Nova is typing".
  final String? label;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Semantics(
      label: widget.label ?? '${AppConstants.assistantName} is typing',
      child: SizedBox(
        height: 24,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Opacity(
                    opacity: _dotOpacity(i),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Each dot pulses a little after the one before it.
  double _dotOpacity(int index) {
    final t = (_controller.value - index * 0.2) % 1.0;
    return 0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
  }
}
