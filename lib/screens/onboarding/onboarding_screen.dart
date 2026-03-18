import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  static const _pageCount = 3;
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_index < _pageCount - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _OnboardingPage(
        title: context.tr('Welcome to Video Contest'),
        subtitle: context.tr(
          'Show your talent with 30–45s videos and win amazing prizes.',
        ),
        highlight: context.tr('Create • Upload • Shine'),
      ),
      _OnboardingPage(
        title: context.tr('Vote & Compete'),
        subtitle: context.tr(
          'Vote for your favorite creators and climb the leaderboard.',
        ),
        highlight: context.tr('Fair • Secure • Fast'),
      ),
      _OnboardingPage(
        title: context.tr('Sponsors & Rewards'),
        subtitle: context.tr(
          'Sponsored contests bring bigger rewards and more visibility.',
        ),
        highlight: context.tr('Grow • Earn • Celebrate'),
      ),
    ];
    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: LanguageMenuButton(compact: true),
                  ),
                ),
                const SizedBox(height: 24),
                const _LogoHero(),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: pages.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, index) => pages[index],
                  ),
                ),
                _DotsIndicator(activeIndex: _index, count: pages.length),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GradientButton(
                    label: _index == pages.length - 1
                        ? context.tr('Get Started')
                        : context.tr('Next'),
                    onPressed: _goNext,
                  ),
                ),
                const SizedBox(height: 18),
                if (_index != pages.length - 1)
                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/login'),
                    child: Text(context.tr('Skip')),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.highlight,
  });

  final String title;
  final String subtitle;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GradientCard(
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.hotPink, AppColors.magenta],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66F64AC9),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Text(
                    highlight,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoHero extends StatelessWidget {
  const _LogoHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _LogoGlow(),
        const SizedBox(height: 10),
        Text(
          context.tr('Video Contest'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          context.tr('Showtime Arena'),
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.activeIndex, required this.count});

  final int activeIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: isActive ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.hotPink : AppColors.border,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}

class _SpaceBackground extends StatelessWidget {
  const _SpaceBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.2,
              colors: [AppColors.cosmicPurple, AppColors.deepSpace],
            ),
          ),
        ),
        Image.asset(
          'assets/images/onboarding_bg.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xAA18003A), Color(0x88140032), Color(0xCC050018)],
            ),
          ),
        ),
        const Positioned(
          top: -120,
          left: -40,
          child: _GlowOrb(size: 220, color: AppColors.hotPink),
        ),
        const Positioned(
          top: 140,
          right: -60,
          child: _GlowOrb(size: 220, color: AppColors.neonGreen),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.6), color.withOpacity(0.0)],
        ),
      ),
    );
  }
}

class _LogoGlow extends StatelessWidget {
  const _LogoGlow();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 170,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: RadialGradient(
              colors: [
                AppColors.hotPink.withOpacity(0.35),
                AppColors.hotPink.withOpacity(0.0),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 90,
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
        ),
      ],
    );
  }
}

class _GradientCard extends StatelessWidget {
  const _GradientCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [AppColors.hotPink, AppColors.cosmicPurple],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 26),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 28,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
