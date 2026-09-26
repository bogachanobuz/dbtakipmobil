import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/db_theme.dart';
import '../../widgets/db_logo.dart';
import '../../widgets/lip_button.dart';
import '../auth/login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  final _page = PageController();
  late final AnimationController _enter;
  int _index = 0;
  var _precached = false;

  static const _slides = [
    _Slide(
      asset: 'assets/welcome/program.png',
      title: 'Günün programı\nhazır.',
      body: 'Konu, test ve deneme tek listede. Her gün bir basamak.',
    ),
    _Slide(
      asset: 'assets/welcome/score.png',
      title: 'Çözdükçe\nyükselirsin.',
      body: 'Doğru, yanlış ve süren birikir. Koçun da aynı günü görür.',
    ),
    _Slide(
      asset: 'assets/welcome/summit.png',
      title: 'Zirve buradan\ngeçer.',
      body: 'Programı koçun kurar, sen uygularsın. İlerlemen kayıt altında.',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    precacheImage(const AssetImage('assets/brand/db_mark.png'), context);
    for (final slide in _slides) {
      precacheImage(AssetImage(slide.asset), context);
    }
  }

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
  }

  @override
  void dispose() {
    _page.dispose();
    _enter.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _slides.length - 1) {
      _finish();
      return;
    }
    _page.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_welcome_v3', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const LoginScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enter = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: enter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Column(
              children: [
                const DbLogo(),
                Expanded(
                  child: PageView(
                    controller: _page,
                    onPageChanged: (value) => setState(() => _index = value),
                    children: [
                      for (final slide in _slides) _SlidePage(slide: slide),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Dots(
                  count: _slides.length,
                  index: _index,
                  onSelect: (value) {
                    _page.animateToPage(
                      value,
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
                const SizedBox(height: 18),
                LipButton(
                  label: _index == _slides.length - 1
                      ? 'HADİ BAŞLAYALIM'
                      : 'DEVAM',
                  onPressed: _next,
                ),
                TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    foregroundColor: DbColors.navy,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    'ZATEN HESABIM VAR',
                    style: DbText.style(
                      size: 14,
                      weight: FontWeight.w900,
                      color: DbColors.navy,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.asset,
    required this.title,
    required this.body,
  });

  final String asset;
  final String title;
  final String body;
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.biggest.shortestSide * 0.82;
              return Center(
                child: SizedBox(
                  width: side,
                  height: side,
                  child: Image.asset(
                    slide.asset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              );
            },
          ),
        ),
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: DbText.style(
            size: 34,
            weight: FontWeight.w900,
            height: 1.05,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            slide.body,
            textAlign: TextAlign.center,
            style: DbText.style(
              size: 16,
              weight: FontWeight.w600,
              color: DbColors.muted,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({
    required this.count,
    required this.index,
    required this.onSelect,
  });

  final int count;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == index ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? DbColors.navy : const Color(0xFFD7DEE8),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }
}
