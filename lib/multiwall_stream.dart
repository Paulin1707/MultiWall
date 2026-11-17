import 'dart:async';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// WebRTC transport for MultiWall. The owner captures the Android display and
/// negotiates one peer connection per accepted participant.
class MultiWallStream {
  MultiWallStream({
    required this.sessionId,
    required this.ownerToken,
    required this.isOwner,
    this.participantId,
    this.onRemoteStream,
    this.onStatus,
  });

  final String sessionId;
  final String ownerToken;
  final bool isOwner;
  final String? participantId;
  final void Function(MediaStream stream)? onRemoteStream;
  final void Function(String status)? onStatus;

  final SupabaseClient _db = Supabase.instance.client;
  final Map<String, RTCPeerConnection> _peers = {};
  final Set<String> _handledSignals = {};
  final Map<String, List<RTCIceCandidate>> _pendingCandidates = {};
  final Set<String> _remoteDescriptionReady = {};
  bool _pollInProgress = false;
  MediaStream? _localStream;
  Timer? _poller;
  bool _running = false;

  static const Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'}
    ],
    'sdpSemantics': 'unified-plan',
  };

  Future<void> startOwnerCapture() async {
    if (!isOwner) throw StateError('Seul le propriétaire peut capturer l’écran.');
    if (_running) return;

    var permitted = true;
    if (WebRTC.platformIsAndroid) {
      const config = FlutterBackgroundAndroidConfig(
        notificationTitle: 'MultiWall',
        notificationText: 'Partage de votre écran en cours',
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
      );
      permitted = await FlutterBackground.hasPermissions;
      if (!permitted) {
        permitted = await FlutterBackground.initialize(androidConfig: config);
      }
    }

    // Android requires the user's screen-capture consent before starting a
    // mediaProjection foreground service on recent Android versions.
    _localStream = await navigator.mediaDevices.getDisplayMedia({
      'video': true,
      'audio': false,
    });

    if (WebRTC.platformIsAndroid &&
        permitted &&
        !FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.enableBackgroundExecution();
    }

    _running = true;
    _poller = Timer.periodic(const Duration(seconds: 1), (_) => _pollSignals());
    onStatus?.call('Capture d’écran active');
  }

  Future<void> startReceiver() async {
    if (isOwner || participantId == null || participantId!.isEmpty) {
      throw StateError('Identifiant du participant manquant.');
    }
    if (_running) return;
    _running = true;
    _poller = Timer.periodic(const Duration(seconds: 1), (_) => _pollSignals());
    await _pollSignals();
  }

  Future<void> offerTo(String participant) async {
    if (!isOwner || _localStream == null) {
      throw StateError('La capture du propriétaire doit être active.');
    }
    if (_peers.containsKey(participant)) return;

    final pc = await createPeerConnection(_rtcConfig);
    _peers[participant] = pc;
    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        unawaited(_sendSignal(
          recipient: participant,
          type: 'ice_candidate',
          payload: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        ));
      }
    };

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await _sendSignal(
      recipient: participant,
      type: 'offer',
      payload: {'sdp': offer.sdp, 'type': offer.type},
    );
    onStatus?.call('Connexion proposée à un appareil');
  }

  Future<void> _pollSignals() async {
    if (!_running || _pollInProgress) return;
    _pollInProgress = true;
    try {
      final result = await _db.rpc(
        'get_multiwall_signals',
        params: {
          'p_session_id': sessionId,
          'p_owner_token': isOwner ? ownerToken : null,
          'p_participant_id': isOwner ? null : participantId,
        },
      );
      final signals = result is List
          ? result.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : result is Map && result['signals'] is List
              ? (result['signals'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
              : <Map<String, dynamic>>[];

      for (final signal in signals) {
        final id = signal['id']?.toString();
        if (id == null || !_handledSignals.add(id)) continue;
        await _handleSignal(signal);
      }
    } catch (e) {
      onStatus?.call('Signalisation : $e');
    } finally {
      _pollInProgress = false;
    }
  }

  Future<void> _addOrQueueCandidate(String peerKey, RTCPeerConnection pc, Map<String, dynamic> payload) async {
    final candidate = RTCIceCandidate(
      payload['candidate']?.toString(),
      payload['sdpMid']?.toString(),
      payload['sdpMLineIndex'] is num ? (payload['sdpMLineIndex'] as num).toInt() : null,
    );
    if (_remoteDescriptionReady.contains(peerKey)) {
      await pc.addCandidate(candidate);
    } else {
      (_pendingCandidates[peerKey] ??= <RTCIceCandidate>[]).add(candidate);
    }
  }

  Future<void> _drainCandidates(String peerKey, RTCPeerConnection pc) async {
    _remoteDescriptionReady.add(peerKey);
    final queued = _pendingCandidates.remove(peerKey) ?? <RTCIceCandidate>[];
    for (final candidate in queued) {
      await pc.addCandidate(candidate);
    }
  }

  Future<void> _handleSignal(Map<String, dynamic> signal) async {
    final type = signal['message_type']?.toString() ?? '';
    final payload = signal['payload'] is Map
        ? Map<String, dynamic>.from(signal['payload'] as Map)
        : <String, dynamic>{};

    if (isOwner) {
      final sender = signal['sender_participant_id']?.toString();
      if (sender == null || sender.isEmpty) return;
      final pc = _peers[sender];
      if (pc == null) return;
      if (type == 'answer') {
        await pc.setRemoteDescription(RTCSessionDescription(
          payload['sdp']?.toString(),
          payload['type']?.toString(),
        ));
        await _drainCandidates(sender, pc);
      } else if (type == 'ice_candidate') {
        await _addOrQueueCandidate(sender, pc, payload);
      }
      return;
    }

    if (type == 'offer') {
      final pc = await createPeerConnection(_rtcConfig);
      _peers['owner'] = pc;
      pc.onIceCandidate = (candidate) {
        if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
          unawaited(_sendSignal(
            type: 'ice_candidate',
            payload: {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
          ));
        }
      };
      pc.onTrack = (event) {
        if (event.streams.isNotEmpty) onRemoteStream?.call(event.streams.first);
      };
      await pc.setRemoteDescription(RTCSessionDescription(
        payload['sdp']?.toString(),
        payload['type']?.toString(),
      ));
      await _drainCandidates('owner', pc);
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      await _sendSignal(
        type: 'answer',
        payload: {'sdp': answer.sdp, 'type': answer.type},
      );
      onStatus?.call('Réponse envoyée au propriétaire');
    } else if (type == 'ice_candidate') {
      final pc = _peers['owner'];
      if (pc != null) {
        await _addOrQueueCandidate('owner', pc, payload);
      } else {
        final candidate = RTCIceCandidate(
          payload['candidate']?.toString(),
          payload['sdpMid']?.toString(),
          payload['sdpMLineIndex'] is num ? (payload['sdpMLineIndex'] as num).toInt() : null,
        );
        (_pendingCandidates['owner'] ??= <RTCIceCandidate>[]).add(candidate);
      }
    }
  }

  Future<void> _sendSignal({
    String? recipient,
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    await _db.rpc(
      'send_multiwall_signal',
      params: {
        'p_session_id': sessionId,
        'p_owner_token': isOwner ? ownerToken : null,
        'p_sender_participant_id': isOwner ? null : participantId,
        'p_recipient_participant_id': isOwner ? recipient : null,
        'p_message_type': type,
        'p_payload': payload,
      },
    );
  }

  Future<void> stop() async {
    _running = false;
    _poller?.cancel();
    _poller = null;
    for (final pc in _peers.values) {
      await pc.close();
    }
    _peers.clear();
    _pendingCandidates.clear();
    _remoteDescriptionReady.clear();
    _handledSignals.clear();
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }
    if (WebRTC.platformIsAndroid && FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.disableBackgroundExecution();
    }
    onStatus?.call('Partage arrêté');
  }
}
