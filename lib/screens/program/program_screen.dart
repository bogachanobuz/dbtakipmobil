import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/site_session.dart';
import '../../demo/demo_account.dart';
import '../../demo/demo_week.dart';
import '../../screens/account/account_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../theme/db_theme.dart';
import '../../widgets/db_logo.dart';
import '../../widgets/welcome_line.dart';
import 'mission_panel.dart';
import 'shortcut_screens.dart';

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key, this.live = false});

  final bool live;

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  late List<DayPlan> _days;
  late final PageController _page;
  var _loading = false;
  String? _loadError;
  String? _hello;
  late int _index;
  PageController? _travel;
  int? _travelFrom;
  int? _travelTo;
  bool _lock = false;

  @override
  void initState() {
    super.initState();
    _index = DateTime.now().weekday - 1;
    _page = PageController(initialPage: 1);
    if (widget.live) {
      _days = [for (var i = 0; i < 7; i++) DayPlan(quests: [])];
      _loading = true;
      _loadLive();
      _loadHello();
    } else {
      _days = DemoWeek.build();
      _hello = DemoAccount.firstName;
    }
  }

  Future<void> _loadHello() async {
    final profile = await SiteSession.instance.profile();
    if (!mounted) return;
    final name = profile?.firstName ?? '';
    setState(() => _hello = name.isEmpty ? 'Öğrenci' : name);
  }

  Future<void> _loadLive() async {
    try {
      final days = await SiteSession.instance.weekly();
      if (!mounted) return;
      setState(() {
        _days = days;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is SiteException ? error.message : 'Program alınamadı.';
      if (message.startsWith('Oturum kapanmış')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(DemoAccount.sessionKey);
        await prefs.remove(SiteSession.liveKey);
        await SiteSession.instance.clear();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (_) => false,
        );
        return;
      }
      setState(() {
        _loading = false;
        _loadError = message;
      });
    }
  }

  @override
  void dispose() {
    _page.dispose();
    _travel?.dispose();
    super.dispose();
  }

  Future<void> _go(int index) async {
    if (_lock || index == _index || index < 0 || index >= _days.length) return;
    final delta = index - _index;
    if (delta.abs() == 1) {
      await _page.animateToPage(
        delta > 0 ? 2 : 0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    final forward = delta > 0;
    final travel = PageController(initialPage: forward ? 0 : 1);
    setState(() {
      _lock = true;
      _travel = travel;
      _travelFrom = _index;
      _travelTo = index;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await travel.animateToPage(
      forward ? 1 : 0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    setState(() {
      _index = index;
      _travel = null;
      _travelFrom = null;
      _travelTo = null;
      _lock = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_page.hasClients) _page.jumpToPage(1);
      travel.dispose();
    });
  }

  Future<void> _open(Quest quest) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MissionPanel(
          lesson: quest.lesson,
          color: quest.color,
          lessonId: quest.lessonId,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(DemoAccount.sessionKey);
    await prefs.remove(SiteSession.liveKey);
    await SiteSession.instance.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  const DbLogo(height: 32),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => AccountScreen(live: widget.live)),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: DbColors.navy,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Hesabım',
                      style: DbText.style(size: 15, weight: FontWeight.w800, color: DbColors.navy),
                    ),
                  ),
                  IconButton(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, color: DbColors.navy),
                    tooltip: 'Çıkış',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _hello == null
                  ? const SizedBox(height: 28)
                  : WelcomeLine(key: ValueKey(_hello), name: _hello!),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _shortcut('Raporlar', Icons.bar_chart_rounded, ReportsScreen(live: widget.live)),
                  _shortcut('Hata Defteri', Icons.menu_book_rounded, const ErrorBookScreen()),
                  _shortcut('Denemeler', Icons.fact_check_rounded, const ExamsScreen()),
                  _shortcut('Program düzenleme', Icons.edit_calendar_rounded, const ProgramEditScreen()),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _dayHeader(),
            const SizedBox(height: 14),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _shortcut(String label, IconData icon, Widget page) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => page),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: DbColors.navy),
                const SizedBox(width: 8),
                Text(label, style: DbText.style(size: 14, weight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayHeader() {
    final controller = _travel ?? _page;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final motion = _motion(controller);
        final heading = motion.from == motion.to || motion.t < 0.08
            ? motion.from
            : motion.to;
        final day = _days[heading];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                DemoWeek.fullDays[heading],
                style: DbText.style(size: 32, weight: FontWeight.w900, height: 1.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: Text(
                '${day.quests.length} görev · ${day.doneCount} bitti',
                style: DbText.style(size: 16, weight: FontWeight.w700, color: DbColors.muted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    for (var index = 0; index < DemoWeek.shortDays.length; index++) ...[
                      if (index > 0) const SizedBox(width: 6),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _go(index),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                Colors.white,
                                DbColors.navy,
                                _chipWeight(index, motion),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                DemoWeek.shortDays[index],
                                style: DbText.style(
                                  size: 12,
                                  weight: FontWeight.w800,
                                  color: Color.lerp(
                                    DbColors.ink,
                                    Colors.white,
                                    _chipWeight(index, motion),
                                  )!,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  ({int from, int to, double t}) _motion(PageController controller) {
    if (_travel != null &&
        identical(controller, _travel) &&
        _travelFrom != null &&
        _travelTo != null) {
      final forward = _travelTo! > _travelFrom!;
      final page = controller.hasClients
          ? (controller.page ?? (forward ? 0.0 : 1.0))
          : (forward ? 0.0 : 1.0);
      final t = (forward ? page : 1 - page).clamp(0.0, 1.0);
      return (from: _travelFrom!, to: _travelTo!, t: t);
    }

    final last = _days.length - 1;
    final page = controller.hasClients ? (controller.page ?? 1.0) : 1.0;
    var delta = page - 1;
    if (_index <= 0 && delta < 0) delta = 0;
    if (_index >= last && delta > 0) delta = 0;
    if (delta >= 0) {
      final next = (_index + 1).clamp(0, last);
      if (next == _index) return (from: _index, to: _index, t: 1);
      return (from: _index, to: next, t: delta.clamp(0.0, 1.0));
    }
    final prev = (_index - 1).clamp(0, last);
    return (from: _index, to: prev, t: (-delta).clamp(0.0, 1.0));
  }

  double _chipWeight(int index, ({int from, int to, double t}) motion) {
    if (motion.from == motion.to) return index == motion.from ? 1 : 0;
    if (index == motion.to) return motion.t;
    if (index == motion.from) return 1 - motion.t;
    return 0;
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: DbColors.navy));
    }
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: DbText.style(size: 16, weight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _loadError = null;
                });
                _loadLive();
              },
              style: FilledButton.styleFrom(backgroundColor: DbColors.navy),
              child: Text('Yeniden dene', style: DbText.style(size: 15, weight: FontWeight.w800, color: Colors.white)),
            ),
          ],
        ),
      );
    }
    return _pager();
  }

  Widget _pager() {
    if (_travel != null && _travelFrom != null && _travelTo != null) {
      final forward = _travelTo! > _travelFrom!;
      final pages = forward
          ? [_travelFrom!, _travelTo!]
          : [_travelTo!, _travelFrom!];
      return PageView(
        controller: _travel,
        physics: const NeverScrollableScrollPhysics(),
        clipBehavior: Clip.hardEdge,
        children: [
          for (var slot = 0; slot < pages.length; slot++)
            _faded(_travel!, slot.toDouble(), _dayPage(pages[slot], 'trip-$slot')),
        ],
      );
    }

    final left = _index > 0 ? _index - 1 : _index;
    final right = _index < _days.length - 1 ? _index + 1 : _index;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) _settle();
        return false;
      },
      child: PageView(
        controller: _page,
        clipBehavior: Clip.hardEdge,
        children: [
          _faded(_page, 0, _dayPage(left, 'left')),
          _faded(_page, 1, _dayPage(_index, 'center')),
          _faded(_page, 2, _dayPage(right, 'right')),
        ],
      ),
    );
  }

  void _settle() {
    if (_lock || !_page.hasClients || _page.page == null) return;
    final page = _page.page!.round();
    if (page == 1) return;
    final next = _index + (page - 1);
    _lock = true;
    if (next >= 0 && next < _days.length && next != _index) {
      setState(() => _index = next);
    }
    _page.jumpToPage(1);
    _lock = false;
  }

  Widget _faded(PageController controller, double slot, Widget child) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final page = controller.hasClients ? (controller.page ?? slot) : slot;
        final distance = (page - slot).abs().clamp(0.0, 1.0);
        final opacity = (1 - distance * 0.45).clamp(0.55, 1.0);
        return Opacity(opacity: opacity, child: child);
      },
      child: child,
    );
  }

  Widget _dayPage(int dayIndex, String slot) {
    return _DayQuests(
      key: ValueKey<String>('$slot-$dayIndex'),
      quests: _days[dayIndex].quests,
      onOpen: _open,
      onToggle: (quest) => setState(() => quest.done = !quest.done),
    );
  }
}

class _DayQuests extends StatelessWidget {
  const _DayQuests({
    super.key,
    required this.quests,
    required this.onOpen,
    required this.onToggle,
  });

  final List<Quest> quests;
  final Future<void> Function(Quest quest) onOpen;
  final ValueChanged<Quest> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: quests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final quest = quests[index];
        return _QuestCard(
          quest: quest,
          onOpen: () => onOpen(quest),
          onToggle: () => onToggle(quest),
        );
      },
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.onOpen,
    required this.onToggle,
  });

  final Quest quest;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 52,
                decoration: BoxDecoration(
                  color: quest.color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.lesson,
                      style: DbText.style(size: 18, weight: FontWeight.w900, height: 1.1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      quest.title,
                      style: DbText.style(
                        size: 15,
                        weight: FontWeight.w700,
                        color: DbColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: quest.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        quest.kindLabel,
                        style: DbText.style(
                          size: 12,
                          weight: FontWeight.w800,
                          color: quest.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onToggle,
                icon: Icon(
                  quest.done ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: quest.done ? DbColors.navy : const Color(0xFFC5CDD8),
                  size: 30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
