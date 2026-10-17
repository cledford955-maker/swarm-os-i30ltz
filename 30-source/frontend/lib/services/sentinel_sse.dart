import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'swarm_config.dart';

/// SSE stream client for the sentinel.js /sse endpoint.
/// Emits [SseEvent] objects for real-time log and swarm events.
class SentinelSseClient {
  final String baseUrl;
  StreamSubscription<String>? _subscription;
  final _controller = StreamController<SseEvent>.broadcast();
  bool _connected = false;

  SentinelSseClient({this.baseUrl = 'http://127.0.0.1:5000'});

  /// The event stream. Listen to this for real-time updates.
  Stream<SseEvent> get events => _controller.stream;

  /// Whether we're currently connected to the SSE endpoint.
  bool get isConnected => _connected;

  /// Connect to the SSE endpoint and begin streaming events.
  Future<void> connect() async {
    if (_connected) return;

    try {
      final request = http.Request('GET', Uri.parse('$baseUrl/sse'));
      request.headers.addAll(SwarmConfig.authHeaders);
      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode != 200) return;

      _connected = true;
      _subscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.startsWith('data: ')) {
            try {
              final json =
                  jsonDecode(line.substring(6)) as Map<String, dynamic>;
              _controller.add(SseEvent(
                type: json['type'] as String? ?? 'unknown',
                data: json['data'],
              ));
            } catch (_) {
              // Skip malformed JSON
            }
          }
        },
        onDone: () {
          _connected = false;
          // Auto-reconnect after 2 seconds
          Future.delayed(const Duration(seconds: 2), connect);
        },
        onError: (error) {
          _connected = false;
          _controller.addError(error as Object);
          // Auto-reconnect after 5 seconds on error
          Future.delayed(const Duration(seconds: 5), connect);
        },
      );
    } catch (e) {
      _connected = false;
      _controller.addError(e);
      // Retry after 5 seconds
      Future.delayed(const Duration(seconds: 5), connect);
    }
  }

  /// Disconnect from the SSE endpoint.
  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _connected = false;
  }

  /// Dispose of resources.
  void dispose() {
    disconnect();
    _controller.close();
  }
}

/// A parsed SSE event from sentinel.js.
class SseEvent {
  final String type; // 'status', 'log', 'swarm_task'
  final dynamic data;
  const SseEvent({required this.type, required this.data});

  @override
  String toString() => 'SseEvent(type: $type, data: $data)';
}
