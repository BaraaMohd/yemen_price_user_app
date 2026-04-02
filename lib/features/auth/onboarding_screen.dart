// #6 - Onboarding Flow
// Shown only on first app launch. Uses PageView for 3 intro slides.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/l10n/app_localizations.dart';
import '../products/screens/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardPage> _pages = [
    _OnboardPage(
      icon: Icons.price_check_rounded,
      color: const Color(0xFF0D5D8C),
      title: 'راقب الأسعار لحظة بلحظة',
      body: 'تتبع أسعار آلاف السلع الأساسية في اليمن\nومقارنتها بالسعر الرسمي للوزارة.',
    ),
    _OnboardPage(
      icon: Icons.report_problem_outlined,
      color: const Color(0xFFD62828),
      title: 'بلّغ عن المخالفات',
      body: 'اكتشفت متجراً يبيع بسعر مرتفع؟\nأرسل بلاغاً فورياً بالصورة والموقع.',
    ),
    _OnboardPage(
      icon: Icons.shopping_basket_rounded,
      color: const Color(0xFF2E7D6B),
      title: 'سلة العائلة الذكية',
      body: 'أدخل احتياجاتك الشهرية وسيجد النظام\nأرخص متجر يوفر لك كل ما تحتاج.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) => _buildPage(_pages[i]),
              ),
            ),
            _buildBottom(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 60, color: page.color),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 15,
              height: 1.8,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottom() {
    final isLast = _currentPage == _pages.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          // Dots indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _currentPage ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _currentPage
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (!isLast)
                TextButton(
                  onPressed: _finish,
                  child: Text(
                    context.tr('تخطي'),
                    style: GoogleFonts.cairo(color: Theme.of(context).hintColor),
                  ),
                ),
              const Spacer(),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: isLast
                      ? _finish
                      : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                          ),
                  child: Text(
                    isLast ? context.tr('ابدأ الآن') : context.tr('التالي'),
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardPage {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _OnboardPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}
