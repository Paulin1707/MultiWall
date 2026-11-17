import 'dart:async';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signaling_validation.dart';

/// WebRTC transport for MultiWall. The owner captures the Android display and
/// negotiates one peer connection per accepted participant.
class MultiWallStream {
  MultiWallStream({
    required this.sessionId,
    required this.ownerToken,
    required this.isOwner,
    this.participantId,
    this.onRemoteStream,
    this.onPointer,
    this.onWallLayout,
    this.onStatus,
  });

  final String sessionId;
  final String ownerToken;
  final bool isOwner;
  final String? participantId;
  final void Function(MediaStream stream)? onRemoteStream;
  final void Function(double x, double y, bool visible)? onPointer;
  final void Function(int row, int column, int rows, int columns)? onWallLayout;
  final void Function(String status)? onStatus;

  final SupabaseClient _db = Supabase.instance.client;
  final Map<String, RTCPeerConnection> _peers = {};
  final Set<String> _handledSignals = {};
  static const int _maxRememberedSignals = 2000;
  static const int _maxQueuedIceCandidates = 256;
  final Map<String, List<RTCIceCandidate>> _pendingCandidates = {};
  final Set<String> _remoteDescriptionReady = {};
  final Map<String, Timer> _reconnectTimers = {};
  final Map<String, int> _reconnectAttempts = {};
  bool _pollInProgress = false;
  MediaStream? _localStream;
  Timer? _poller;
  bool _running = false;
  Timer? _pointerThrottle;
  Map<String, dynamic>? _latestPointer;

  static const Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'}
    ],
    'sdpSemantics': 'unified-plan',
  };

  Future<void> startOwnerCapture() async {
    if (!isOwner) throw StateError('Seul le propriétaire peut capturer l’écran.');
    if (_running) return;

    var backgroundReady = true;
    if (WebRTC.platformIsAndroid) {
      const config = FlutterBackgroundAndroidConfig(
        notificationTitle: 'MultiWall',
        notificationText: 'Partage de votre écran en cours',
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
      );
      // initialize() must be called even when permissions were granted earlier.
      backgroundReady = await FlutterBackground.initialize(androidConfig: config);
    }

    // Android requires the user's screen-capture consent before starting a
    // mediaProjection foreground service on recent Android versions.
    _localStream = await navigator.mediaDevices.getDisplayMedia({
      'video': true,
      'audio': false,
    });

    if (WebRTC.platformIsAndroid &&
        backgroundReady &&
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

  Future<void> sendWallLayout(String participant, {required int row, required int column, required int rows, required int columns}) async {
    if (!isOwner || !_running) return;
    await _sendSignal(
      recipient: participant,
      type: 'wall_layout',
      payload: {'row': row, 'column': column, 'rows': rows, 'columns': columns},
    );
  }

  Future<void> sendPointer(double x, double y, bool visible) async {
    if (!isOwner || !_running) return;
    _latestPointer = {'x': x.clamp(0.0, 1.0), 'y': y.clamp(0.0, 1.0), 'visible': visible};
    if (_pointerThrottle?.isActive ?? false) return;
    _pointerThrottle = Timer(const Duration(milliseconds: 50), () {
      final payload = _latestPointer;
      _latestPointer = null;
      if (payload == null || !_running) return;
      for (final participant in _peers.keys.toList()) {
        unawaited(_sendSignal(recipient: participant, type: 'pointer', payload: payload)
            .catchError((Object error) {
          onStatus?.call('Pointeur non transmis : $error');
        }));
      }
    });
  }

  Future<void> offerTo(String participant, {bool restart = false}) async {
    if (!isOwner || _localStream == null) {
      throw StateError('La capture du propriétaire doit être active.');
    }
    if (_peers.containsKey(participant)) {
      if (!restart) return;
      final previous = _peers.remove(participant);
      await previous?.close();
      _pendingCandidates.remove(participant);
      _remoteDescriptionReady.remove(participant);
    }

    final pc = await createPeerConnection(_rtcConfig);
    _peers[participant] = pc;
    _watchConnection(participant, pc);
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
        if (id == null || _handledSignals.contains(id)) continue;
        try {
          await _handleSignal(signal);
          _rememberHandledSignal(id);
        } catch (e) {
          // Keep failed messages eligible for the next poll instead of losing
          // negotiation messages permanently after a transient network error.
          onStatus?.call('Traitement du signal à réessayer : $e');
        }
      }
    } catch (e) {
      onStatus?.call('Signalisation : $e');
    } finally {
      _pollInProgress = false;
    }
  }

  void _rememberHandledSignal(String id) {
    _handledSignals.add(id);
    // Keep memory bounded during long-running sessions. Set preserves
    // insertion order, so the oldest processed signal can be discarded.
    if (_handledSignals.length > _maxRememberedSignals) {
      _handledSignals.remove(_handledSignals.first);
    }
  }

  RTCSessionDescription? _validatedDescription(
    Map<String, dynamic> payload, {
    required String expectedType,
  }) {
    if (!SignalingValidation.isValidDescription(
      payload,
      expectedType: expectedType,
    )) {
      return null;
    }
    return RTCSessionDescription(payload['sdp'] as String, expectedType);
  }

  RTCIceCandidate? _validatedCandidate(Map<String, dynamic> payload) {
    if (!SignalingValidation.isValidCandidate(payload)) return null;
    return RTCIceCandidate(
      payload['candidate'] as String,
      payload['sdpMid'] as String?,
      (payload['sdpMLineIndex'] as num?)?.toInt(),
    );
  }

  Future<void> _addOrQueueCandidate(String peerKey, RTCPeerConnection pc, Map<String, dynamic> payload) async {
    final candidate = _validatedCandidate(payload);
    if (candidate == null) return;
    if (_remoteDescriptionReady.contains(peerKey)) {
      await pc.addCandidate(candidate);
    } else {
      final queue = _pendingCandidates.putIfAbsent(
        peerKey,
        () => <RTCIceCandidate>[],
      );
      // ICE candidates can arrive before SDP. Bound this queue so malformed
      // or excessive signaling cannot grow memory without limit.
      if (queue.length < _maxQueuedIceCandidates) {
        queue.add(candidate);
      }
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
      if (type == 'reconnect_request') {
        await offerTo(sender, restart: true);
      } else if (type == 'answer') {
        final description = _validatedDescription(payload, expectedType: 'answer');
        if (description == null) return;
        await pc.setRemoteDescription(description);
        await _drainCandidates(sender, pc);
      } else if (type == 'ice_candidate') {
        await _addOrQueueCandidate(sender, pc, payload);
      }
      return;
    }

    if (type == 'wall_layout') {
      // Reject malformed grids before they reach receiver layout code.
      if (SignalingValidation.isValidWallLayout(payload)) {
        onWallLayout?.call(
          (payload['row'] as num).toInt(),
          (payload['column'] as num).toInt(),
          (payload['rows'] as num).toInt(),
          (payload['columns'] as num).toInt(),
        );
      }
    } else if (type == 'pointer') {
      if (SignalingValidation.isValidPointer(payload)) {
        final x = (payload['x'] as num).toDouble().clamp(0.0, 1.0).toDouble();
        final y = (payload['y'] as num).toDouble().clamp(0.0, 1.0).toDouble();
        onPointer?.call(x, y, payload['visible'] == true);
      }
    } else if (type == 'offer') {
      final previous = _peers.remove('owner');
      await previous?.close();
      // Do not clear queued ICE here: trickled candidates for this offer can
      // reach the receiver before the offer itself. They are drained only
      // after the new remote description has been installed.
      _remoteDescriptionReady.remove('owner');
      final pc = await createPeerConnection(_rtcConfig);
      _peers['owner'] = pc;
      _watchConnection('owner', pc);
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
      final description = _validatedDescription(payload, expectedType: 'offer');
      if (description == null) {
        await pc.close();
        _peers.remove('owner');
        return;
      }
      await pc.setRemoteDescription(description);
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
        final candidate = _validatedCandidate(payload);
        if (candidate != null) {
          final queue = _pendingCandidates.putIfAbsent(
            'owner',
            () => <RTCIceCandidate>[],
          );
          if (queue.length < _maxQueuedIceCandidates) {
            queue.add(candidate);
          }
        }
      }
    }
  }

  void _watchConnection(String peerKey, RTCPeerConnection pc) {
    pc.onIceConnectionState = (state) {
      if (!_running || _peers[peerKey] != pc) return;
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _reconnectTimers.remove(peerKey)?.cancel();
        _reconnectAttempts.remove(peerKey);
        onStatus?.call('Appareil connecté');
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _scheduleReconnect(peerKey, pc);
      }
    };
  }

  void _scheduleReconnect(String peerKey, RTCPeerConnection pc) {
    if (_reconnectTimers[peerKey]?.isActive ?? false) return;
    final attempt = _reconnectAttempts[peerKey] ?? 0;
    if (attempt >= 3) {
      onStatus?.call('Connexion interrompue. Reconnexion automatique épuisée.');
      return;
    }
    _reconnectTimers[peerKey] = Timer(Duration(seconds: attempt == 0 ? 3 : 5), () async {
      _reconnectTimers.remove(peerKey);
      if (!_running || _peers[peerKey] != pc) return;
      final state = await pc.getIceConnectionState();
      if (state != RTCIceConnectionState.RTCIceConnectionStateDisconnected &&
          state != RTCIceConnectionState.RTCIceConnectionStateFailed) return;
      _reconnectAttempts[peerKey] = attempt + 1;
      onStatus?.call('Tentative de reconnexion ' + (attempt + 1).toString() + '/3...');
      try {
        if (isOwner) {
          await offerTo(peerKey, restart: true);
        } else {
          // Keep requesting a fresh offer while the receiver remains
          // disconnected. The owner may miss a transient signaling request.
          await _sendSignal(type: 'reconnect_request', payload: {'attempt': attempt + 1});
          if (_running && _peers[peerKey] == pc &&
              (_reconnectAttempts[peerKey] ?? 0) < 3) {
            _scheduleReconnect(peerKey, pc);
          }
        }
      } catch (error) {
        onStatus?.call('Reconnexion impossible : ' + error.toString());
        if (_running && (_reconnectAttempts[peerKey] ?? 0) < 3) {
          _scheduleReconnect(peerKey, _peers[peerKey] ?? pc);
        }
      }
    });
  }

  /// Close and forget a receiver that is no longer accepted in the session.
  Future<void> removeParticipant(String participant) async {
    if (!isOwner || participant.isEmpty) return;
    _reconnectTimers.remove(participant)?.cancel();
    _reconnectAttempts.remove(participant);
    _pendingCandidates.remove(participant);
    _remoteDescriptionReady.remove(participant);
    final pc = _peers.remove(participant);
    await pc?.close();
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
    _pointerThrottle?.cancel();
    _pointerThrottle = null;
    _latestPointer = null;
    for (final pc in _peers.values) {
      await pc.close();
    }
    _peers.clear();
    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    _reconnectTimers.clear();
    _reconnectAttempts.clear();
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
