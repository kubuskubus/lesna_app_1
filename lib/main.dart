import 'package:flutter/material.dart';
import 'package:lesna_app_1/app_main_page.dart';
// Import your connector screen file (adjust path if necessary based on your folder structure)
import 'package:lesna_app_1/screens/powierzchnia_details.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplikacja Leśna',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // If you want to keep PowierzchnieScreen as your home:
      home: const AppMainScreen(), // <--- Change this line
      // Alternatively, if you want to test the Bluetooth connector directly as the home screen, uncomment below:
      // home: const DigitechBrowserScreen(),
    );
  }
}