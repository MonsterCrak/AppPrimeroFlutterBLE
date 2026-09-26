// Placeholder temporal para WU-0. Será reemplazado por HomeScreen en WU-3+.
// Por ahora solo necesitamos que el smoke test verifique que la app arranca.

import 'package:flutter/material.dart';

void main() {
  runApp(const AppPrimeroFlutterBleApp());
}

class AppPrimeroFlutterBleApp extends StatelessWidget {
  const AppPrimeroFlutterBleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emulador BLE Indoor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _BootstrapScreen(),
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emulador BLE Indoor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bluetooth, size: 64),
              SizedBox(height: 16),
              Text(
                'Bootstrap OK — esperando WU-1 (modelos)',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}