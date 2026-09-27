import 'package:flutter/material.dart';

import '../theme/db_theme.dart';

class WelcomeLine extends StatefulWidget {
  const WelcomeLine({super.key, required this.name});

  final String name;

  @override
  State<WelcomeLine> createState() => _WelcomeLineState();
}

class _WelcomeLineState extends State<WelcomeLine>
    with SingleTickerProviderStateMixin {
  static const _prefix = 'Hoş geldin, ';
  late final String _full;
  late final AnimationController _tick;

  @override
  void initState() {
    super.initState();
    _full = '$_prefix${widget.name}';
    _tick = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 46 * _full.length),
    )..forward();
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: AnimatedBuilder(
        animation: _tick,
        builder: (context, _) {
          final count = (_tick.value * _full.length).round().clamp(0, _full.length);
          final shown = _full.substring(0, count);
          final split = shown.length < _prefix.length ? shown.length : _prefix.length;
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: shown.substring(0, split),
                  style: DbText.style(
                    size: 20,
                    weight: FontWeight.w800,
                    color: DbColors.muted,
                    height: 1.1,
                  ),
                ),
                TextSpan(
                  text: shown.substring(split),
                  style: DbText.style(
                    size: 20,
                    weight: FontWeight.w900,
                    color: DbColors.ink,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.fade,
          );
        },
      ),
    );
  }
}
