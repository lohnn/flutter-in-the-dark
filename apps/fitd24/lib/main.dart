import 'package:fitd24/challenges/final/final_card.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        HomeScreen.path: (_) => const HomeScreen(),
        Final.path: (_) => const Final(),
      },
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  static const path = "/home";

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool finalFinal = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 100),
        child: ListView(
          children: [
            Center(
              child: InkWell(
                onTap: () {
                  setState(() {
                    finalFinal = !finalFinal;
                  });
                },
                child: const Text(
                  "Challenges:",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, Final.path),
              child: const Text("Final 🎉"),
            ),
            // if (finalFinal) ...[
            //   const SizedBox(height: 16),
            //   ElevatedButton(
            //     style: ButtonStyle(
            //         backgroundColor: MaterialStateColor.resolveWith(
            //               (states) => Colors.pink,
            //         )),
            //     onPressed: () => Navigator.pushNamed(context, FinalFinal.path),
            //     child: const Text("Lukas vs Alek 💪"),
            //   ),
            // ]
          ],
        ),
      ),
    );
  }
}
