import 'package:flutter/material.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A4D69), // top background
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A4D69),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context), // 👈 back to Home
        ),
        title: const Text(
          "Expenses",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),

      // main content
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFF4F7F8),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: Text(
            "Track your expenses here 💰",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              color: Color(0xFF2A4D69),
            ),
          ),
        ),
      ),
    );
  }
}