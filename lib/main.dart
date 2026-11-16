
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =====================================================
// CONFIGURATION SUPABASE
// =====================================================

const String supabaseUrl =
    'https://cerzkniqycnggirvfzqv.supabase.co';

// Conserve ici ta clé sb_publishable actuelle.
const String supabaseKey = 'COLLE_TA_CLE_SB_PUBLISHABLE_ICI';

const Color navy = Color(0xFF081426);
const Color panel = Color(0xFF12233D);
const Color blue = Color(0xFF2878FF);
const Color cyan = Color(0xFF43D9FF);
const Color muted = Color(0xFF9BAEC8);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const MultiWallApp());
}

final SupabaseClient supabase = Supabase.instance.client;

// =====================================================
// OUTILS
// =====================================================

Map<String, dynamic> firstMap(dynamic result) {
  if (result is List && result.isNotEmpty) {
    return Map<String, dynamic>.from(result.first as Map);
  }

  if (result is Map) {
    return Map<String, dynamic>.from(result);
  }

  return {};
}

String readString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value != null) return value.toString();
  }
  return '';
}

// =====================================================
// APPLICATION
// =====================================================

class MultiWallApp extends StatelessWidget {
  const MultiWallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MultiWall',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: navy,
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          hintStyle: const TextStyle(color: muted),
          labelStyle: const TextStyle(color: muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF263D5D)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: cyan, width: 1.5),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// =====================================================
// COMPOSANTS GRAPHIQUES
// =====================================================

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          colors: [blue, cyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.connected_tv_rounded,
        color: Colors.white,
        size: size * 0.58,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

// =====================================================
// ACCUEIL
// =====================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController codeController =
      TextEditingController();

  String displayMode = 'mirror';
  String connectionType = 'both';
  bool loading = false;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: panel,
      ),
    );
  }

  Future<void> createSession() async {
    setState(() => loading = true);

    try {
      final result = await supabase.rpc(
        'create_multiwall_session',
        params: {
          'p_display_mode': displayMode,
          'p_connection_type': connectionType,
          'p_max_participants': 20,
        },
      );

      final data = firstMap(result);

      final sessionId = readString(data, ['session_id', 'id']);
      final code = readString(data, ['code']);
      final ownerToken = readString(data, ['owner_token']);

      if (sessionId.isEmpty ||
          code.isEmpty ||
          ownerToken.isEmpty) {
        throw Exception('Informations de session incomplètes.');
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionPage(
            sessionId: sessionId,
            code: code,
            ownerToken: ownerToken,
          ),
        ),
      );
    } catch (e) {
      showMessage('Erreur : $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> joinSession() async {
    final code = codeController.text.trim();

    if (code.length != 6) {
      showMessage('Entre un code de 6 chiffres.');
      return;
    }

    setState(() => loading = true);

    try {
      final result = await supabase.rpc(
        'request_multiwall_join',
        params: {
          'p_code': code,
          'p_device_name': 'Appareil Android',
          'p_device_type': 'phone',
        },
      );

      final data = firstMap(result);
      final status = readString(data, ['status']);

      if (!mounted) return;

      showMessage(
        status.isEmpty
            ? 'Demande de connexion envoyée.'
            : 'Demande envoyée : $status',
      );
    } catch (e) {
      showMessage('Erreur de connexion : $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget modeCard({
    required String value,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final selected = displayMode == value;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => displayMode = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF183D70) : panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? blue : const Color(0xFF263D5D),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: selected ? cyan : muted, size: 27),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(
                  color: muted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              Icon(
                selected
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: selected ? cyan : muted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget connectionChoice(String value, String label) {
    final selected = connectionType == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => connectionType = value);
      },
      selectedColor: blue,
      backgroundColor: panel,
      labelStyle: TextStyle(
        color: selected ? Colors.white : muted,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? cyan : const Color(0xFF263D5D),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [navy, Color(0xFF0B1D36), navy],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandLogo(),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MultiWall',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'VOTRE ÉCRAN, PARTOUT.',
                            style: TextStyle(
                              fontSize: 9,
                              color: cyan,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: panel,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.cast_connected,
                        color: cyan,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF164B91), Color(0xFF102747)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: const Color(0xFF367DD1),
                    ),
                  ),
                  child: Stack(
                    children: [
                      const Positioned(
                        right: -10,
                        top: 5,
                        child: Icon(
                          Icons.connected_tv_rounded,
                          size: 110,
                          color: Color(0x223DD9FF),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LE PARTAGE SANS LIMITES',
                            style: TextStyle(
                              color: cyan,
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Diffusez autrement.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 9),
                          const Text(
                            'Transformez vos appareils en un espace '
                            'd’affichage connecté.',
                            style: TextStyle(
                              color: Color(0xFFD1E2F8),
                              height: 1.5,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Icon(
                                Icons.devices,
                                color: cyan,
                                size: 17,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'Téléphones • Tablettes • Ordinateurs',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const SectionTitle(
                  title: 'Choisissez votre affichage',
                  subtitle: 'Comment voulez-vous utiliser MultiWall ?',
                ),

                const SizedBox(height: 13),

                Row(
                  children: [
                    modeCard(
                      value: 'mirror',
                      icon: Icons.screen_share_rounded,
                      title: 'Miroir',
                      description: 'Le même écran sur tous les appareils',
                    ),
                    const SizedBox(width: 12),
                    modeCard(
                      value: 'video_wall',
                      icon: Icons.grid_view_rounded,
                      title: 'Mur vidéo',
                      description: 'Un grand écran réparti',
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                const SectionTitle(
                  title: 'Type de connexion',
                  subtitle: 'Choisissez votre réseau.',
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    connectionChoice('both', 'Wi-Fi + Internet'),
                    connectionChoice('local', 'Wi-Fi local'),
                    connectionChoice('internet', 'Internet'),
                  ],
                ),

                const SizedBox(height: 27),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : createSession,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text(
                      'Créer une session',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 27),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF263D5D),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.login_rounded, color: cyan),
                          SizedBox(width: 10),
                          Text(
                            'Rejoindre une session',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Entrez le code communiqué par l’organisateur.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: '000000',
                          labelText: 'Code de session',
                        ),
                      ),
                      const SizedBox(height: 13),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                    
