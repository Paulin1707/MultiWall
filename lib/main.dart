
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'multiwall_stream.dart';

const String supabaseUrl =
    'https://cerzkniqycnggirvfzqv.supabase.co';

const String supabaseAnonKey =
    'sb_publishable_zxM_EQXh9qFQn88dbTAT7w_a9auV8Iu';

const Color navy = Color(0xFF0B1220);
const Color panel = Color(0xFF151F32);
const Color blue = Color(0xFF3478F6);
const Color cyan = Color(0xFF36C8E8);
const Color muted = Color(0xFF9AA9BF);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MultiWallApp());
}

class MultiWallApp extends StatelessWidget {
  const MultiWallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MultiWall',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
      ),
      home: const HomePage(),
    );
  }
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return {};
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is Map && value['participants'] is List) {
    value = value['participants'];
  }

  if (value is Map) {
    value = [value];
  }

  if (value is! List) {
    return [];
  }

  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String displayMode = 'mirror';
  String connectionType = 'both';
  bool loading = false;

  final TextEditingController codeController =
      TextEditingController();

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  void message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> createSession() async {
    setState(() => loading = true);

    try {
      final result = await Supabase.instance.client.rpc(
        'create_multiwall_session',
        params: {
          'p_display_mode': displayMode,
          'p_connection_type': connectionType,
          'p_max_participants': 10,
        },
      );

      final data = asMap(result);

      final sessionId = data['session_id']?.toString() ?? '';
      final code = data['code']?.toString() ?? '';
      final ownerToken = data['owner_token']?.toString() ?? '';

      if (sessionId.isEmpty ||
          code.isEmpty ||
          ownerToken.isEmpty) {
        throw Exception(
          'Les informations de la session sont incomplètes.',
        );
      }

      if (!mounted) return;

      await Navigator.push(
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
      message('Erreur de création : $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> joinSession() async {
    final code = codeController.text.trim();

    if (code.length != 6) {
      message('Le code doit contenir 6 chiffres.');
      return;
    }

    setState(() => loading = true);

    try {
      final result = await Supabase.instance.client.rpc(
        'request_multiwall_join',
        params: {
          'p_code': code,
          'p_device_name': 'Appareil Android',
          'p_device_type': 'phone',
        },
      );

      final data = asMap(result);
      final status = data['status']?.toString() ?? 'pending';
      final participantId = data['participant_id']?.toString() ?? '';
      final sessionId = data['session_id']?.toString() ?? '';
      if (participantId.isEmpty || sessionId.isEmpty) {
        throw Exception('Le serveur n’a pas retourné les identifiants nécessaires.');
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiverPage(
            sessionId: sessionId,
            participantId: participantId,
            initialStatus: status,
          ),
        ),
      );
    } catch (e) {
      message('Erreur de connexion : $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Widget heading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: muted,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget modeCard(
    String value,
    String title,
    String description,
    IconData icon,
  ) {
    final selected = displayMode == value;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() => displayMode = value);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? blue.withOpacity(0.16)
              : panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? blue : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? cyan : muted,
              size: 28,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              color: selected ? cyan : muted,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MultiWall',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: Icon(
              Icons.connected_tv,
              color: cyan,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF173B78),
                      Color(0xFF10233F),
                    ],
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.cast_connected,
                      size: 40,
                      color: cyan,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Un écran. Plusieurs appareils.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Partage ton affichage et transforme '
                      'tes appareils en un grand espace visuel.',
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              heading(
                'Créer une diffusion',
                'Choisis le mode d’affichage.',
              ),
              const SizedBox(height: 14),
              modeCard(
                'mirror',
                'Mode miroir',
                'Tous les appareils affichent le même écran.',
                Icons.content_copy,
              ),
              const SizedBox(height: 10),
              modeCard(
                'video_wall',
                'Mur vidéo',
                'Chaque appareil affiche une partie de l’image.',
                Icons.grid_view,
              ),
              const SizedBox(height: 24),
              heading(
                'Type de connexion',
                'Choisis comment connecter les appareils.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: connectionType,
                    isExpanded: true,
                    dropdownColor: panel,
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
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          connectionType = value;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : createSession,
                  icon: const Icon(Icons.rocket_launch),
                  label: Text(
                    loading
                        ? 'Patiente...'
                        : 'Créer une session',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              heading(
                'Rejoindre une diffusion',
                'Entre le code fourni par le responsable.',
              ),
              const SizedBox(height: 13),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  hintText: 'Code à 6 chiffres',
                  counterText: '',
                  prefixIcon: const Icon(Icons.vpn_key),
                  filled: true,
                  fillColor: panel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: loading ? null : joinSession,
                  icon: const Icon(Icons.login),
                  label: const Text('Rejoindre la session'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cyan,
                    side: const BorderSide(color: cyan),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Center(
                child: Text(
                  'MULTIWALL • PARTAGE SANS LIMITES',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
  bool closing = false;
  bool capturing = false;
  bool pointerEnabled = false;
  String streamStatus = 'Partage non démarré';
  MultiWallStream? stream;
  final Set<String> offeredParticipants = {};
  Timer? participantPoller;

  @override
  void initState() {
    super.initState();
    loadParticipants();
    participantPoller = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && !loading && !closing) loadParticipants();
    });
  }

  @override
  void dispose() {
    participantPoller?.cancel();
    final activeStream = stream;
    if (activeStream != null) {
      activeStream.stop();
    }
    super.dispose();
  }

  Future<void> startScreenShare() async {
    if (capturing) return;
    setState(() {
      capturing = true;
      streamStatus = 'Demande d’autorisation Android...';
    });
    try {
      final transport = MultiWallStream(
        sessionId: widget.sessionId,
        ownerToken: widget.ownerToken,
        isOwner: true,
        onStatus: (value) {
          if (mounted) setState(() => streamStatus = value);
        },
      );
      await transport.startOwnerCapture();
      stream = transport;
      await loadParticipants();
      await offerAcceptedParticipants();
    } catch (e) {
      if (mounted) setState(() => streamStatus = 'Erreur de capture : $e');
    } finally {
      if (mounted) setState(() => capturing = false);
    }
  }

  void updatePointer(Offset localPosition, Size areaSize) {
    final active = stream;
    if (active == null || !pointerEnabled || areaSize.width <= 0 || areaSize.height <= 0) return;
    final x = (localPosition.dx / areaSize.width).clamp(0.0, 1.0);
    final y = (localPosition.dy / areaSize.height).clamp(0.0, 1.0);
    active.sendPointer(x, y, true);
  }

  Widget pointerController() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Pointeur de présentation', style: TextStyle(fontWeight: FontWeight.bold))),
          Switch(value: pointerEnabled, onChanged: stream == null ? null : (value) {
            setState(() => pointerEnabled = value);
            if (!value) stream?.sendPointer(0, 0, false);
          }),
        ]),
        const Text('Active le pointeur puis touche ou fais glisser dans la zone pour montrer un élément aux appareils connectés.', style: TextStyle(color: muted, fontSize: 12)),
        if (pointerEnabled) ...[
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            final area = Size(constraints.maxWidth, 170);
            return GestureDetector(
              onPanDown: (details) => updatePointer(details.localPosition, area),
              onPanUpdate: (details) => updatePointer(details.localPosition, area),
              child: Container(
                width: double.infinity, height: area.height,
                decoration: BoxDecoration(color: const Color(0xFF080D16), borderRadius: BorderRadius.circular(10), border: Border.all(color: cyan)),
                child: const Center(child: Text('Zone de pointage', style: TextStyle(color: Colors.white54))),
              ),
            );
          }),
        ],
      ]),
    );
  }

  Future<void> stopScreenShare() async {
    final active = stream;
    if (active == null) return;
    setState(() => streamStatus = 'Arrêt du partage...');
    try {
      await active.stop();
      stream = null;
      offeredParticipants.clear();
      if (mounted) {
        setState(() => streamStatus = 'Partage arrêté');
        message('Le partage d’écran est arrêté.');
      }
    } catch (e) {
      if (mounted) setState(() => streamStatus = 'Erreur à l’arrêt : $e');
    }
  }

  Future<void> offerAcceptedParticipants() async {
    final activeStream = stream;
    if (activeStream == null) return;
    for (final participant in participants) {
      final id = participant['id']?.toString() ??
          participant['participant_id']?.toString() ?? '';
      if (id.isEmpty || participant['status']?.toString() != 'accepted' ||
          offeredParticipants.contains(id)) {
        continue;
      }
      offeredParticipants.add(id);
      try {
        await activeStream.offerTo(id);
      } catch (e) {
        offeredParticipants.remove(id);
        if (mounted) setState(() => streamStatus = 'Connexion appareil : $e');
      }
    }
  }

  void message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> loadParticipants() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final result = await Supabase.instance.client.rpc(
        'get_multiwall_participants',
        params: {
          'p_session_id': widget.sessionId,
          'p_owner_token': widget.ownerToken,
        },
      );

      participants = asMapList(result);
      await offerAcceptedParticipants();
    } catch (e) {
      message('Erreur de chargement : $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> decideParticipant(
    String participantId,
    bool accept,
  ) async {
    try {
      await Supabase.instance.client.rpc(
        'decide_multiwall_join',
        params: {
          'p_session_id': widget.sessionId,
          'p_owner_token': widget.ownerToken,
          'p_participant_id': participantId,
          'p_accept': accept,
        },
      );

      message(
        accept
            ? 'Appareil accepté.'
            : 'Demande refusée.',
      );

      await loadParticipants();
    } catch (e) {
      message('Erreur : $e');
    }
  }

  Future<void> closeSession() async {
    setState(() => closing = true);

    try {
      await Supabase.instance.client.rpc(
        'close_multiwall_session',
        params: {
          'p_session_id': widget.sessionId,
          'p_owner_token': widget.ownerToken,
        },
      );

      if (!mounted) return;
      await stream?.stop();
      stream = null;
      Navigator.pop(context);
    } catch (e) {
      message('Impossible de fermer la session : $e');
    } finally {
      if (mounted) {
        setState(() => closing = false);
      }
    }
  }

  Widget participantCard(
    Map<String, dynamic> participant,
  ) {
    final id = participant['id']?.toString() ??
        participant['participant_id']?.toString() ??
        '';

    final name =
        participant['device_name']?.toString() ??
        'Appareil connecté';

    final status =
        participant['status']?.toString() ?? 'inconnu';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.devices,
                color: cyan,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                status,
                style: const TextStyle(
                  color: muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (status == 'pending' && id.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      decideParticipant(id, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                    ),
                    child: const Text('Accepter'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      decideParticipant(id, false);
                    },
                    child: const Text('Refuser'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma session'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadParticipants,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF173B78),
                      Color(0xFF10233F),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cast_connected,
                      color: cyan,
                      size: 35,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'CODE DE CONNEXION',
                      style: TextStyle(
                        color: Colors.white70,
                        letterSpacing: 2,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      widget.code,
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.code),
                        );
                        message('Code copié.');
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copier le code'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Partage réel de l’écran',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 7),
                    Text(streamStatus,
                        style: const TextStyle(color: muted, fontSize: 12)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: capturing
                            ? null
                            : stream == null
                                ? startScreenShare
                                : stopScreenShare,
                        icon: Icon(stream == null ? Icons.screen_share : Icons.stop_circle),
                        label: Text(
                          capturing
                              ? 'Démarrage...'
                              : stream == null
                                  ? 'Démarrer le partage'
                                  : 'Arrêter le partage',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: stream == null ? blue : Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (stream != null) ...[
                const SizedBox(height: 14),
                pointerController(),
              ],
              const SizedBox(height: 25),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Appareils participants',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: loading
                        ? null
                        : loadParticipants,
                    icon: const Icon(
                      Icons.refresh,
                      color: cyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (loading && participants.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(25),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (participants.isEmpty)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.devices_other,
                        size: 35,
                        color: muted,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Aucun appareil pour le moment.',
                        style: TextStyle(color: muted),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Partage le code pour inviter des appareils.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...participants.map(participantCard),
              const SizedBox(height: 25),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: closing ? null : closeSession,
                  icon: const Icon(
                    Icons.stop_circle_outlined,
                  ),
                  label: Text(
                    closing
                        ? 'Fermeture...'
                        : 'Fermer la session',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class ReceiverPage extends StatefulWidget {
  final String sessionId;
  final String participantId;
  final String initialStatus;

  const ReceiverPage({
    super.key,
    required this.sessionId,
    required this.participantId,
    required this.initialStatus,
  });

  @override
  State<ReceiverPage> createState() => _ReceiverPageState();
}

class _ReceiverPageState extends State<ReceiverPage> {
  final RTCVideoRenderer renderer = RTCVideoRenderer();
  MultiWallStream? transport;
  String status = 'En attente de validation du propriétaire...';
  bool initialized = false;
  Offset? pointerPosition;
  bool pointerVisible = false;

  @override
  void initState() {
    super.initState();
    initializeReceiver();
  }

  Future<void> initializeReceiver() async {
    status = widget.initialStatus == 'accepted'
        ? 'Appareil accepté. Connexion au partage...'
        : 'Demande envoyée. En attente de validation...';
    try {
      await renderer.initialize();
      transport = MultiWallStream(
        sessionId: widget.sessionId,
        ownerToken: '',
        isOwner: false,
        participantId: widget.participantId,
        onPointer: (x, y, visible) {
          if (mounted) setState(() { pointerPosition = Offset(x, y); pointerVisible = visible; });
        },
        onRemoteStream: (mediaStream) {
          renderer.srcObject = mediaStream;
          if (mounted) setState(() => status = 'Écran reçu en direct');
        },
        onStatus: (value) {
          if (mounted) setState(() => status = value);
        },
      );
      await transport!.startReceiver();
      if (mounted) setState(() => initialized = true);
    } catch (e) {
      if (mounted) setState(() => status = 'Connexion impossible : $e');
    }
  }

  @override
  void dispose() {
    transport?.stop();
    renderer.srcObject = null;
    renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réception MultiWall')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: initialized && renderer.srcObject != null
                    ? LayoutBuilder(builder: (context, constraints) {
                        return Stack(children: [
                          Positioned.fill(child: RTCVideoView(renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain)),
                          if (pointerVisible && pointerPosition != null)
                            Positioned(
                              left: (pointerPosition!.dx * constraints.maxWidth - 14).clamp(0.0, constraints.maxWidth - 28),
                              top: (pointerPosition!.dy * constraints.maxHeight - 14).clamp(0.0, constraints.maxHeight - 28),
                              child: IgnorePointer(child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.95), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 5)]),
                              )),
                            ),
                        ]);
                      })
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.connected_tv, size: 54, color: cyan),
                            SizedBox(height: 14),
                            Text('En attente du partage...', style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.circle, color: cyan, size: 10),
                  const SizedBox(width: 8),
                  Expanded(child: Text(status, style: const TextStyle(color: muted))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
