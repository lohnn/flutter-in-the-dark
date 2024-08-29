import 'package:flutter/material.dart';
import 'package:vector_graphics/vector_graphics_compat.dart';

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

final cardBackground = createCompatVectorGraphic(
  loader: const AssetBytesLoader(
    'assets/svgs/ff_card_background.svg',
    packageName: 'ff_card',
  ),
);

final kulturhuset = Image.asset(
  'assets/images/kulturhuset.png',
  package: 'ff_card',
);

final dash = Image.asset(
  'assets/photos/dash.png',
);

final ffLogo = createCompatVectorGraphic(
  loader: const AssetBytesLoader(
    'assets/svgs/ff_logo.svg',
    packageName: 'ff_card',
  ),
);
