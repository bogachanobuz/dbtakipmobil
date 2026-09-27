import 'dart:async';

import 'package:flutter/material.dart';

import '../../demo/demo_week.dart';
import '../../theme/db_theme.dart';

Future<void> showQuestSheet(BuildContext context, Quest quest) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _QuestSheet(quest: quest),
  );
}

class _QuestSheet extends StatefulWidget {
  const _QuestSheet({required this.quest});

  final Quest quest;

  @override
  State<_QuestSheet> createState() => _QuestSheetState();
}

class _QuestSheetState extends State<_QuestSheet> {
  late final TextEditingController _note;
  Timer? _timer;

  Quest get quest => widget.quest;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: quest.note);
  }

  @override
  void dispose() {
    _timer?.cancel();
    quest.note = _note.text;
    _note.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    if (_timer != null) {
      _timer?.cancel();
      _timer = null;
      setState(() {});
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => quest.seconds += 1);
    });
    setState(() {});
  }

  String get _clock {
    final minutes = (quest.seconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (quest.seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DbColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            quest.lesson,
            style: DbText.style(size: 14, weight: FontWeight.w800, color: quest.color),
          ),
          const SizedBox(height: 4),
          Text(
            quest.title,
            style: DbText.style(size: 26, weight: FontWeight.w900, height: 1.1),
          ),
          const SizedBox(height: 6),
          Text(
            quest.kindLabel,
            style: DbText.style(size: 14, weight: FontWeight.w700, color: DbColors.muted),
          ),
          const SizedBox(height: 18),
          _Row(
            label: 'Tamamlandı',
            child: Switch(
              value: quest.done,
              activeThumbColor: Colors.white,
              activeTrackColor: DbColors.navy,
              onChanged: (value) => setState(() => quest.done = value),
            ),
          ),
          const SizedBox(height: 8),
          _Row(
            label: _clock,
            child: FilledButton(
              onPressed: _toggleTimer,
              style: FilledButton.styleFrom(
                backgroundColor: _timer == null ? DbColors.navy : DbColors.red,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _timer == null ? 'Süreyi başlat' : 'Durdur',
                style: DbText.style(size: 14, weight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 4,
            style: DbText.style(size: 16, weight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'Bu göreve not bırak',
              hintStyle: DbText.style(size: 15, weight: FontWeight.w600, color: const Color(0xFF9AA3B2)),
              filled: true,
              fillColor: const Color(0xFFF6F3EE),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: DbText.style(size: 18, weight: FontWeight.w800)),
        ),
        child,
      ],
    );
  }
}
