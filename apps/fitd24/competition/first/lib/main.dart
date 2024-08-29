import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Hello World!'),
        ),
      ),
    );
  }
}

const color1 = Color(0xff3c2b79);
const color2 = Color(0xff594a8f);
final hackberryLeaf = Image.asset('assets/logos/hackberry_1.png');
final hackberryB = Image.asset('assets/logos/hackberry_2.png');
