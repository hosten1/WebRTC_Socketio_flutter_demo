import 'package:flutter/material.dart';

class LDApp extends StatefulWidget {
  const LDApp({super.key});

  @override
  State<LDApp> createState() => _LDAppState();
}

class _LDAppState extends State<LDApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Demo Home Page'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'You have pushed the button this many times:',
              ),
              Text(
                '0',
                style: Theme.of(context).textTheme.headlineMedium,
             ),
    ],
    ),
    )

    ),
    );
  }
}
