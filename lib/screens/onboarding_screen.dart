import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
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
      "title": "Simplify Your Splits",
      "subtitle": "Easily divide expenses among friends and track payments effortlessly.",
      "image": "assets/images/SliceIt.png"
    },
    {
      "title": "Track and Settle Up",
      "subtitle": "Keep everyone’s share transparent and settle up without stress.",
      "image": "assets/images/SliceIt.png"
    },
    {
      "title": "Start Splitting Smarter",
      "subtitle": "Join SliceIt and make group spending seamless!",
      "image": "assets/images/SliceIt.png"
    },
  ];

  void _nextPage() {
    if (_currentIndex < 2) {
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
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
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
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Image.asset(pages[index]["image"]!, height: 300),
                        const SizedBox(height: 40),
                        Text(pages[index]["title"]!,
                            style: AppTextStyles.heading1,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Text(pages[index]["subtitle"]!,
                            style: AppTextStyles.body,
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sageGreen,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _nextPage,
                child: Text(
                  _currentIndex == 2 ? "Get Started" : "Next",
                  style: AppTextStyles.button,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}