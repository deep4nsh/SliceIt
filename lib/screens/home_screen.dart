import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: const Text("SliceIt Dashboard"),
        backgroundColor: AppColors.darkBlueGray,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await auth.signOut();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.oliveGreen),
          child: const Text("Sign Out",
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
        ),
      ),
    );
  }
}