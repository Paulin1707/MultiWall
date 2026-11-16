
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =====================================================
// CONFIGURATION SUPABASE
// =====================================================

const String supabaseUrl =
    'https://cerzkniqycnggirvfzqv.supabase.co';

// Remplace ce texte par ta clé sb_publishable complète.
const String supabasePublishableKey =
    'sb_publishable_zxM_EQXh9qFQn88dbTAT7w_a9auV8Iu';

// =====================================================
// DEMARRAGE
// =====================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabasePublishableKey,
  );

  runApp(const MultiWallApp());
}

// =====================================================
// APPLICATION
// =====================================================

class MultiWallApp extends StatelessWidget {
  const MultiWallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MultiWall',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF071426),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF168BFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// =====================================================
// PAGE D'ACCUEIL
// =====================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController deviceController =
      TextEditingController(text: 'Mon appareil');

  String displayMode = 'mirror';
  String connectionType = 'both';

  bool loading = false;

  SupabaseClient get supabase => Supabase.instance.client;

  @override
  void dispose() {
    codeController.dispose();
    deviceController.dispose();
    super.dispose();
  }

  // ===================================================
  // CREER UNE SESSION
  // ===================================================

  Future<void> createSession() async {
    if (loading) return;

    setState(() => loading = true);

    try {
      final result = await supabase.rpc(
        'create_multiwall_session',
        params: {
          'p_display_mode': displayMode,
          'p_connection_type': connectionType,
          'p_max_participants': 10,
        },
      );

      final data = Map<String, dynamic>.from(result as Map);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionPage(
            sessionId: data['session_id'].toString(),
            code: data['code'].toString(),
            ownerToken: data['owner_token'].toString(),
          ),
        ),
      );
    } on PostgrestException catch (e) {
      showMessage('Erreur Supabase : ${e.message}');
    } catch (e) {
      showMessage('Impossible de créer la session : $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ===================================================
  // REJOINDRE UNE SESSION
  // ===================================================

  Future<void> joinSession() async {
    if (loading) return;

    final code = codeController.text.trim();
    final deviceName = deviceController.text.trim();

    if (code.length != 6) {
      showMessage('Entre un code de 6 chiffres.');
      return;
    }

    if (deviceName.isEmpty) {
      showMessage('Entre le nom de ton appareil.');
      return;
    }

    setState(() => loading = true);

    try {
      final result = await supabase.rpc(
        'request_multiwall_join',
        params: {
          'p_code': code,
          'p_device_name': deviceName,
          'p_device_type': 'phone',
        },
      );

      final data = Map<String, dynamic>.from(result as Map);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Demande envoyée'),
          content: Text(
            'Ta demande a été envoyée au propriétaire de la session.\n\n'
            'Statut : ${data['status']}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
    } on PostgrestException catch (e) {
      showMessage('Erreur : ${e.message}');
    } catch (e) {
      showMessage('Impossible de rejoindre : $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ===================================================
  // INTERFACE
  // ===================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MultiWall',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 25),

              const Icon(
                Icons.connected_tv,
                size: 75,
                color: Color(0xFF168BFF),
              ),

              const SizedBox(height: 15),

              const Text(
                'Votre écran, partout.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Partagez votre écran sur plusieurs appareils.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),

              const SizedBox(height: 35),

              const Text(
                'Mode d’affichage',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: displayMode,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.screenshot_monitor),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'mirror',
                    child: Text('Miroir - même écran partout'),
                  ),
                  DropdownMenuItem(
                    value: 'video_wall',
                    child: Text('Mur vidéo - écran réparti'),
                  ),
                ],
                onChanged: loading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => displayMode = value);
                        }
                      },
              ),

              const SizedBox(height: 20),

              const Text(
                'Type de connexion',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: connectionType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wifi),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'both',
                    child: Text('Wi-Fi local et Internet'),
                  ),
                  DropdownMenuItem(
                    value: 'local',
                    child: Text('Wi-Fi local uniquement'),
                  ),
                  DropdownMenuItem(
                    value: 'internet',
                    child: Text('Internet'),
                  ),
                ],
                onChanged: loading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => connectionType = value);
                        }
                      },
              ),

              const SizedBox(height: 20),

              FilledButton.icon(
                onPressed: loading ? null : createSession,
                icon: const Icon(Icons.add_link),
                label: Text(
                  loading ? 'Connexion...' : 'Créer une session',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(17),
                ),
              ),

              const SizedBox(height: 35),

              const Divider(color: Colors.white24),

              const SizedBox(height: 20),

              const Text(
                'Rejoindre une session',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Code de session',
                  hintText: 'Exemple : 123456',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin),
                  counterText: '',
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: deviceController,
                decoration: const InputDecoration(
                  labelText: 'Nom de ton appareil',
                  hintText: 'Exemple : Téléphone de Paul',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_android),
                ),
              ),

              const SizedBox(height: 15),

              OutlinedButton.icon(
                onPressed: loading ? null : joinSession,
                icon: const Icon(Icons.login),
                label: const Text('Rejoindre une session'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(17),
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'MultiWall V1 - Connexion aux sessions',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// PAGE DE SESSION
// =====================================================

class SessionPage extends StatefulWidget {
  final String sessionId;
  final String code;
  final String ownerToken;

  const SessionPage({
    super.key,
    required this.sessionId,
    required this.code,
    required this.ownerToken,
  });

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  bool closing = false;

  SupabaseClient get supabase => Supabase.instance.client;

  Future<void> copyCode() async {
    await Clipboard.setData(
      ClipboardData(text: widget.code),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copié !'),
      ),
    );
  }

  Future<void> closeSession() async {
    if (closing) return;

    setState(() => closing = true);

    try {
      await supabase.rpc(
        'close_multiwall_session',
        params: {
          'p_session_id': widget.sessionId,
          'p_owner_token': widget.ownerToken,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session fermée.'),
        ),
      );

      Navigator.pop(context);
    } on PostgrestException catch (e) {
      showMessage('Erreur : ${e.message}');
    } catch (e) {
      showMessage('Impossible de fermer la session : $e');
    } finally {
      if (mounted) setState(() => closing = false);
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma session MultiWall'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.cast_connected,
              size: 75,
              color: Color(0xFF168BFF),
            ),

            const SizedBox(height: 25),

            const Text(
              'Ta session est créée !',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Communique ce code aux appareils que tu souhaites inviter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: const Color(0xFF102B49),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF168BFF),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'CODE DE SESSION',
                    style: TextStyle(
                      color: Colors.white70,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 12),

                  SelectableText(
                    widget.code,
                    style: const TextStyle(
                      fontSize: 39,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 7,
                    ),
                  ),

                  const SizedBox(height: 20),

                  FilledButton.icon(
                    onPressed: copyCode,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copier le code'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Les demandes de participation pourront être '
              'gérées lors de la prochaine étape.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 30),

            OutlinedButton.icon(
              onPressed: closing ? null : closeSession,
              icon: const Icon(Icons.close),
              label: Text(
                closing ? 'Fermeture...' : 'Fermer la session',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
