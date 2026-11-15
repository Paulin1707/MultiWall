
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MultiWallApp());
}

class MultiWallApp extends StatelessWidget {
  const MultiWallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MultiWall',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101827),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2878FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void createSession(BuildContext context) {
    final random = Random();
    final code = (100000 + random.nextInt(900000)).toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionPage(code: code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 35),
              const Icon(Icons.connected_tv,
                  size: 75, color: Color(0xFF4D91FF)),
              const SizedBox(height: 15),
              const Text(
                'MultiWall',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Un écran. Plusieurs appareils. Une seule image.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 55),
              const Text(
                'Bienvenue sur MultiWall',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Partagez votre écran ou rejoignez une session.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => createSession(context),
                icon: const Icon(Icons.cast),
                label: const Text('Créer une session'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 58),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('La connexion sera disponible prochainement.'),
                    ),
                  );
                },
                icon: const Icon(Icons.devices),
                label: const Text('Rejoindre une session'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 58),
                ),
              ),
              const SizedBox(height: 35),
              const Text(
                'MODES D’AFFICHAGE',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: modeCard(Icons.content_copy, 'Miroir', 'Même écran'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: modeCard(Icons.grid_view, 'Mur vidéo', 'Écran divisé'),
                  ),
                ],
              ),
              const Spacer(),
              const Text(
                'MULTIWALL • VERSION 1',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget modeCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1D2A40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: const Color(0xFF4D91FF)),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.white60)),
        ],
      ),
    );
  }
}

class SessionPage extends StatelessWidget {
  final String code;

  const SessionPage({super.key, required this.code});

  void copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copié !')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle session'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.connected_tv,
                size: 75,
                color: Color(0xFF4D91FF),
              ),
              const SizedBox(height: 25),
              const Text(
                'Votre session est créée',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              const Text(
                'Communiquez ce code aux appareils que vous souhaitez connecter.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 35),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D2A40),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    const Text(
                      'CODE DE SESSION',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      code,
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        color: Color(0xFF4D91FF),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () => copyCode(context),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copier le code'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'La connexion des autres appareils sera activée dans une prochaine étape.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 30),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Retour à l’accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
