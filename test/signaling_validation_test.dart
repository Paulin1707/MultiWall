import 'package:flutter_test/flutter_test.dart';
import 'package:multiwall/signaling_validation.dart';

void main() {
  group('SignalingValidation', () {
    test('accepts only bounded SDP with the expected type', () {
      expect(SignalingValidation.isValidDescription(
        {'sdp': 'v=0\\r\\n', 'type': 'offer'}, expectedType: 'offer'), isTrue);
      expect(SignalingValidation.isValidDescription(
        {'sdp': 'v=0', 'type': 'answer'}, expectedType: 'offer'), isFalse);
      expect(SignalingValidation.isValidDescription(
        {'sdp': '', 'type': 'offer'}, expectedType: 'offer'), isFalse);
      expect(SignalingValidation.isValidDescription(
        {'sdp': List.filled(1024 * 1024 + 1, 'x').join(), 'type': 'offer'}, expectedType: 'offer'), isFalse);
    });

    test('rejects malformed and oversized ICE candidates', () {
      expect(SignalingValidation.isValidCandidate({
        'candidate': 'candidate:1 1 UDP 1 192.0.2.1 1234 typ host',
        'sdpMid': '0', 'sdpMLineIndex': 0,
      }), isTrue);
      expect(SignalingValidation.isValidCandidate({'candidate': ''}), isFalse);
      expect(SignalingValidation.isValidCandidate({'candidate': List.filled(8193, 'x').join()}), isFalse);
      expect(SignalingValidation.isValidCandidate({
        'candidate': 'candidate', 'sdpMLineIndex': double.infinity,
      }), isFalse);
    });

    test('accepts only finite wall coordinates inside a bounded grid', () {
      expect(SignalingValidation.isValidWallLayout({
        'row': 1, 'column': 2, 'rows': 3, 'columns': 4,
      }), isTrue);
      expect(SignalingValidation.isValidWallLayout({
        'row': 3, 'column': 0, 'rows': 3, 'columns': 4,
      }), isFalse);
      expect(SignalingValidation.isValidWallLayout({
        'row': double.nan, 'column': 0, 'rows': 2, 'columns': 2,
      }), isFalse);
      expect(SignalingValidation.isValidWallLayout({
        'row': 0, 'column': 0, 'rows': 9, 'columns': 2,
      }), isFalse);
    });

    test('rejects non-finite pointer coordinates', () {
      expect(SignalingValidation.isValidPointer({'x': 0.5, 'y': 1}), isTrue);
      expect(SignalingValidation.isValidPointer({'x': double.nan, 'y': 0}), isFalse);
      expect(SignalingValidation.isValidPointer({'x': 0, 'y': double.infinity}), isFalse);
      expect(SignalingValidation.isValidPointer({'x': '0.5', 'y': 0}), isFalse);
    });
  });
}
