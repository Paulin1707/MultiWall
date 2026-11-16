
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =====================================================
// CONFIGURATION SUPABASE
// =====================================================

const String supabaseUrl =
    'https://cerzkniqycnggirvfzqv.supabase.co';

// Remplace cette valeur par ta clé sb_publishable complète.
const String supabaseKey = 'sb_publishable_zxM_EQXh9qFQn88dbTAT7w_a9auV8Iu';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
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

      final sessionId = readString(
        data,
        ['session_id', 'id'],
      );

      final code = readString(data, ['code']);

      final ownerToken = readString(
        data,
        ['owner_token'],
      );

      if (sessionId.isEmpty ||
          code.isEmpty ||
          ownerToken.isEmpty) {
        throw Exception(
          'Les informations de la session sont incomplètes.',
        );
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
        title: const Text('MultiWall'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.connected_tv,
              size: 75,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            const Text(
              'Partagez vos écrans avec MultiWall',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),

            const Text(
              'Mode d’affichage',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            RadioListTile<String>(
              title: const Text('Miroir : même écran partout'),
              value: 'mirror',
              groupValue: displayMode,
              onChanged: (value) {
                setState(() => displayMode = value!);
              },
            ),

            RadioListTile<String>(
              title: const Text('Mur vidéo : écran réparti'),
              value: 'video_wall',
              groupValue: displayMode,
              onChanged: (value) {
                setState(() => displayMode = value!);
              },
            ),

            const Divider(height: 30),

            const Text(
              'Type de connexion',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            RadioListTile<String>(
              title: const Text('Wi-Fi local et Internet'),
              value: 'both',
              groupValue: connectionType,
              onChanged: (value) {
                setState(() => connectionType = value!);
              },
            ),

            RadioListTile<String>(
              title: const Text('Wi-Fi local uniquement'),
              value: 'local',
              groupValue: connectionType,
              onChanged: (value) {
                setState(() => connectionType = value!);
              },
            ),

            RadioListTile<String>(
              title: const Text('Internet uniquement'),
              value: 'internet',
              groupValue: connectionType,
              onChanged: (value) {
                setState(() => connectionType = value!);
              },
            ),

            const SizedBox(height: 15),

            ElevatedButton.icon(
              onPressed: loading ? null : createSession,
              icon: const Icon(Icons.add),
              label: const Text('Créer une session'),
            ),

            const SizedBox(height: 30),

            const Text(
              'Rejoindre une session',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Code de session',
                hintText: 'Exemple : 123456',
                border: OutlineInputBorder(),
              ),
            ),

            ElevatedButton.icon(
              onPressed: loading ? null : joinSession,
              icon: const Icon(Icons.login),
              label: const Text('Rejoindre'),
            ),

            if (loading)
              const Padding(
                padding: EdgeInsets.all(15),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// GESTION DE SESSION
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
  List<Map<String, dynamic>> participants = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    loadParticipants();
  }

  Future<void> loadParticipants() async {
    setState(() => loading = true);

    try {
      final result = await supabase.rpc(
        'get_multiwall_participants',
        params: {
          'p_session_id': widget.sessionId,
          'p_owner_token': widget.ownerToken,
        },
      );

      final rows = result as List;

      if (!mounted) return;

      setState(() {
        participants = rows
            .map(
              (item) => Map<String, dynamic>.from(item as Map),
            )
            .toList();
      });
    } catch (e) {
      showMessage('Erreur de chargement : $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> decideParticipant(
    Map<String, dynamic> participant,
    bool accept,
  ) async {
    final participantId = readString(
      participant,
      ['participant_id', 'id'],
    );

    if (participantId.isEmpty) {
      showMessage('Identifiant du participant introuvable.');
      return;
    }

    try {
      await supabase.rpc(
        'decide_multiwall_join',
        params: {
          'p_session_id': widget.sessionId,
          'p_owner_token': widget.ownerToken,
          'p_participant_id': participantId,
          'p_accept': accept,
        },
      );

      showMessage(
        accept
            ? 'Participant accepté.'
            : 'Demande refusée.',
      );

      await loadParticipants();
    } catch (e) {
      showMessage('Erreur : $e');
    }
  }

  Future<void> closeSession() async {
    try {
      await supabase.rpc(
        'close_multiwall_session',
        params: {
          'p_session_id': widget.sessionId,
          'p_owner_token': widget.ownerToken,
        },
      );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      showMessage('Impossible de fermer la session : $e');
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
    final pending = participants.where(
      (p) => p['status'] == 'pending',
    ).toList();

    final accepted = participants.where(
      (p) => p['status'] == 'accepted',
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma session MultiWall'),
        actions: [
          IconButton(
            onPressed: loading ? null : loadParticipants,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: loadParticipants,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'CODE DE SESSION',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.code,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.code),
                        );
                        showMessage('Code copié.');
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copier le code'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Demandes en attente (${pending.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (pending.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Aucune demande en attente.'),
              ),

            ...pending.map((participant) {
              final name = readString(
                participant,
                ['device_name'],
              );

              final type = readString(
                participant,
                ['device_type'],
              );

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.devices),
                  title: Text(
                    name.isEmpty ? 'Appareil inconnu' : name,
                  ),
                  subtitle: Text(type),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        onPressed: () {
                          decideParticipant(participant, true);
                        },
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                        tooltip: 'Accepter',
                      ),
                      IconButton(
                        onPressed: () {
                          decideParticipant(participant, false);
                        },
                        icon: const Icon(
                          Icons.cancel,
                          color: Colors.red,
                        ),
                        tooltip: 'Refuser',
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            Text(
              'Appareils connectés (${accepted.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (accepted.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Aucun appareil accepté pour le moment.'),
              ),

            ...accepted.map((participant) {
              final name = readString(
                participant,
                ['device_name'],
              );

              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.connected_tv,
                    color: Colors.green,
                  ),
                  title: Text(
                    name.isEmpty ? 'Appareil connecté' : name,
                  ),
                  subtitle: const Text('Connecté'),
                ),
              );
            }),

            const SizedBox(height: 30),

            OutlinedButton.icon(
              onPressed: loading ? null : loadParticipants,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser les participants'),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: closeSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close),
              label: const Text('Fermer la session'),
            ),
          ],
        ),
      ),
    );
  }
}
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
  bool loadingParticipants = false;

  final Set<String> processing = {};

  List<Map<String, dynamic>> participants = [];

  SupabaseClient get supabase =>
      Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    loadParticipants();
  }

  // ===================================================
  // CHARGER LES PARTICIPANTS
  // ===================================================

  Future<void> loadParticipants() async {
    if (loadingParticipants) return;

    setState(() => loadingParticipants = true);

    try {
      final result = await supabase.rpc(
        'get_multiwall_participants',
        params: {
          'p_session_id': widget.sessionId,
          'p_owner_token': widget.ownerToken,
        },
      );

      final data = List<Map<String, dynamic>>.from(
        (result as List).map(
          (item) =>
              Map<String, dynamic>.from(item as Map),
        ),
      );

      if (mounted) {
        setState(() => participants = data);
      }
    } on PostgrestException catch (e) {
      showMessage('Erreur Supabase : ${e.message}');
    } catch (e) {
      showMessage('Erreur de chargement : $e');
    } finally {
      if (mounted) {
        setState(() => loadingParticipants = false);
      }
    }
  }

  // ===================================================
  // ACCEPTER OU REFUSER UN APPAREIL
  // ===================================================

  Future<void> decideParticipant(
    String participantId,
    bool accept,
  ) async {
    if (processing.contains(participantId)) return;

    setState(() => processing.add(participantId));

    try {
      await supabase.rpc(
        'decide_multiwall_join',
        params: {
          'p_session_id': widget.sessionId,
          'p_owner_token': widget.ownerToken,
          'p_participant_id': participantId,
          'p_accept': accept,
        },
      );

      showMessage(
        accept
            ? 'Appareil accepté !'
            : 'Demande refusée.',
      );

      await loadParticipants();
    } on PostgrestException catch (e) {
      showMessage('Erreur Supabase : ${e.message}');
    } catch (e) {
      showMessage('Opération impossible : $e');
    } finally {
      if (mounted) {
        setState(() => processing.remove(participantId));
      }
    }
  }

  // ===================================================
  // COPIER LE CODE
  // ===================================================

  Future<void> copyCode() async {
    await Clipboard.setData(
      ClipboardData(text: widget.code),
    );

    if (!mounted) return;

    showMessage('Code copié !');
  }

  // ===================================================
  // FERMER LA SESSION
  // ===================================================

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

      showMessage('Session fermée.');
      Navigator.pop(context);
    } on PostgrestException catch (e) {
      showMessage('Erreur : ${e.message}');
    } catch (e) {
      showMessage(
        'Impossible de fermer la session : $e',
      );
    } finally {
      if (mounted) {
        setState(() => closing = false);
      }
    }
  }

  // ===================================================
  // MESSAGE
  // ===================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ===================================================
  // CARTE D'UN PARTICIPANT
  // ===================================================

  Widget participantCard(
    Map<String, dynamic> participant,
  ) {
    final id = participant['id'].toString();

    final name =
        participant['device_name']?.toString() ??
        'Appareil';

    final type =
        participant['device_type']?.toString() ??
        'unknown';

    final status =
        participant['status']?.toString() ?? '';

    final isPending = status == 'pending';
    final busy = processing.contains(id);

    return Card(
      color: const Color(0xFF102B49),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.devices,
                  color: Color(0xFF168BFF),
                  size: 30,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Type : $type',
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  isPending ? 'En attente' : 'Accepté',
                  style: TextStyle(
                    color: isPending
                        ? Colors.orangeAccent
                        : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (isPending) ...[
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () => decideParticipant(
                                id,
                                true,
                              ),
                      icon: const Icon(Icons.check),
                      label: const Text('Accepter'),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => decideParticipant(
                                id,
                                false,
                              ),
                      icon: const Icon(Icons.close),
                      label: const Text('Refuser'),
                    ),
                  ),
                ],
              ),

              if (busy)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ===================================================
  // INTERFACE DE LA SESSION
  // ===================================================

  @override
  Widget build(BuildContext context) {
    final pending = participants
        .where((p) => p['status'] == 'pending')
        .toList();

    final accepted = participants
        .where((p) => p['status'] == 'accepted')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma session MultiWall'),
        automaticallyImplyLeading: false,
        Exemple : 123456',
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
