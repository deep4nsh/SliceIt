import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/mesh_background.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> pages = [
    {
      "title": "Smart Debt Simplification",
      "subtitle": "Minimize transaction hassle. Our intelligent algorithm optimizes group balances so everyone pays their fair share with fewer transfers.",
      "image": "assets/screenshots/simplification_insights.png"
    },
    {
      "title": "Detailed Group Analytics",
      "subtitle": "Gain deep insights into group spending. Visual charts and category breakdowns help you track budgets and shared expenses effortlessly.",
      "image": "assets/screenshots/group_analytics.png"
    },
    {
      "title": "Offline Sync & Alerts",
      "subtitle": "Add expenses anytime, anywhere. Local data caches sync automatically when online, triggering real-time alerts and reminders.",
      "image": "assets/screenshots/push_notification.png"
    },
  ];

  void _nextPage() {
    if (_currentIndex < pages.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar with Logo & Skip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          "assets/images/SliceIt.png",
                          height: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "SliceIt",
                          style: AppTextStyles.h3.copyWith(
                            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: Text(
                        "Skip",
                        style: AppTextStyles.label.copyWith(
                          color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Slide PageView
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemCount: pages.length,
                  itemBuilder: (_, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Device mockup container
                          Expanded(
                            flex: 3,
                            child: Center(
                              child: Container(
                                margin: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isDark 
                                            ? AppColors.borderDefault 
                                            : Colors.grey.shade200,
                                        width: 3,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Image.asset(
                                      pages[index]["image"]!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ).animate(key: ValueKey('img_$index'))
                               .fade(duration: 400.ms)
                               .scale(delay: 50.ms, duration: 400.ms, curve: Curves.easeOutBack),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Title text
                          Text(
                            pages[index]["title"]!,
                            style: AppTextStyles.heading1.copyWith(
                              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ).animate(key: ValueKey('title_$index'))
                           .fade(duration: 400.ms, delay: 100.ms)
                           .slideY(begin: 0.15, end: 0.0, curve: Curves.easeOutQuad),
                          const SizedBox(height: 12),
                          // Subtitle text
                          Text(
                            pages[index]["subtitle"]!,
                            style: AppTextStyles.body.copyWith(
                              color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ).animate(key: ValueKey('sub_$index'))
                           .fade(duration: 400.ms, delay: 200.ms)
                           .slideY(begin: 0.15, end: 0.0, curve: Curves.easeOutQuad),
                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              // Dot Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (index) {
                  final isSelected = _currentIndex == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: isSelected ? 24 : 8,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                          : (isDark ? AppColors.darkSurface2 : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              
              // Next Action Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: CustomButton(
                  onPressed: _nextPage,
                  text: _currentIndex == pages.length - 1 ? "Get Started" : "Next",
                  backgroundColor: AppColors.primaryNavy,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}