import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'viewmodels/car_dashboard_view_model.dart';
import 'views/car_dashboard_page.dart';

class CarApp extends StatelessWidget {
  const CarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CarDashboardViewModel()..initialize(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Car Prompt Dashboard',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            brightness: Brightness.light,
            seedColor: const Color(0xFF104E64),
          ),
          scaffoldBackgroundColor: const Color(0xFFF3F4F6),
          textTheme: GoogleFonts.spaceGroteskTextTheme(),
        ),
        home: const CarDashboardPage(),
      ),
    );
  }
}