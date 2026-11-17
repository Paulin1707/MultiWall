/// Pure validation helpers for untrusted MultiWall signaling payloads.
/// Kept independent from Flutter/WebRTC so the rules can be unit tested.
class SignalingValidation {
  static bool isValidDescription(
    Map<String, dynamic> payload, {
    required String expectedType,
  }) {
    final sdp = payload['sdp'];
    return sdp is String &&
        sdp.isNotEmpty &&
        sdp.length <= 1024 * 1024 &&
        payload['type'] == expectedType;
  }

  static bool isValidCandidate(Map<String, dynamic> payload) {
    final candidate = payload['candidate'];
    final mid = payload['sdpMid'];
    final line = payload['sdpMLineIndex'];
    return candidate is String &&
        candidate.isNotEmpty &&
        candidate.length <= 8192 &&
        (mid == null || (mid is String && mid.length <= 256)) &&
        (line == null ||
            (line is num && line.isFinite && line >= 0 && line <= 1000));
  }

  static bool isValidWallLayout(Map<String, dynamic> payload) {
    final row = payload['row'];
    final column = payload['column'];
    final rows = payload['rows'];
    final columns = payload['columns'];
    return row is num &&
        column is num &&
        rows is num &&
        columns is num &&
        row.isFinite &&
        column.isFinite &&
        rows.isFinite &&
        columns.isFinite &&
        rows >= 1 &&
        rows <= 8 &&
        columns >= 1 &&
        columns <= 8 &&
        row >= 0 &&
        row < rows &&
        column >= 0 &&
        column < columns;
  }

  static bool isValidPointer(Map<String, dynamic> payload) {
    final x = payload['x'];
    final y = payload['y'];
    return x is num && y is num && x.isFinite && y.isFinite;
  }
}
