import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/car_state.dart';

class PromptSubmitResult {
  const PromptSubmitResult({
    required this.uuid,
    required this.text,
    required this.clientTimestamp,
  });

  final String uuid;
  final String text;
  final double clientTimestamp;
}

class PromptModeResult {
  const PromptModeResult({required this.mode});

  final String mode;
}

class RecvPromptApiService {
  RecvPromptApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> healthCheck(Uri baseUri) async {
    final response = await _client.get(baseUri.resolve('/api/health'));
    if (response.statusCode != 200) {
      throw Exception('Health check failed (${response.statusCode})');
    }
  }

  Future<CarState> fetchState(Uri baseUri) async {
    final response = await _client.get(baseUri.resolve('/api/state'));
    if (response.statusCode != 200) {
      throw Exception('State request failed (${response.statusCode})');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return CarState.fromJson(body);
  }

  Future<PromptSubmitResult> sendPrompt(Uri baseUri, String prompt) async {
    final clientTimestamp = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final response = await _client.post(
      baseUri.resolve('/api/prompt'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(<String, Object>{
        'text': prompt,
        'timestamp': clientTimestamp,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Prompt post failed (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final ok = body['ok'] == true;
    if (!ok) {
      throw Exception((body['error'] as String?) ?? 'Prompt rejected');
    }

    final uuid = (body['uuid'] as String?)?.trim();
    if (uuid == null || uuid.isEmpty) {
      throw Exception('Prompt response missing uuid');
    }

    return PromptSubmitResult(
      uuid: uuid,
      text: prompt,
      clientTimestamp: clientTimestamp,
    );
  }

  Future<PromptModeResult> fetchPromptMode(Uri baseUri) async {
    final response = await _client.get(baseUri.resolve('/api/prompt_mode'));
    if (response.statusCode != 200) {
      throw Exception('Prompt mode request failed (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final ok = body['ok'] == true;
    if (!ok) {
      throw Exception((body['error'] as String?) ?? 'Prompt mode query failed');
    }

    final mode = (body['mode'] as String?)?.trim();
    if (mode == null || mode.isEmpty) {
      throw Exception('Prompt mode response missing mode');
    }

    return PromptModeResult(mode: mode);
  }

  Future<PromptModeResult> setPromptMode(Uri baseUri, String mode) async {
    final response = await _client.post(
      baseUri.resolve('/api/prompt_mode'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(<String, Object>{'mode': mode}),
    );
    if (response.statusCode != 200) {
      throw Exception('Prompt mode update failed (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final ok = body['ok'] == true;
    if (!ok) {
      throw Exception((body['error'] as String?) ?? 'Prompt mode update rejected');
    }

    final nextMode = (body['mode'] as String?)?.trim();
    if (nextMode == null || nextMode.isEmpty) {
      throw Exception('Prompt mode update response missing mode');
    }

    return PromptModeResult(mode: nextMode);
  }
}