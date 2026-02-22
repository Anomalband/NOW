import "package:flutter/material.dart";

import "../features/home/now_home_screen.dart";
import "now_theme.dart";

class NowApp extends StatelessWidget {
  const NowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "NOW",
      debugShowCheckedModeBanner: false,
      theme: NowTheme.light(),
      home: const NowHomeScreen(),
    );
  }
}
