import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/car_state.dart';
import '../services/recv_prompt_api_service.dart';

enum PromptRunStatus {
  queued,
  processing,
  completed,
  interrupted,
}

enum PromptDispatchMode {
  single,
  repeat1hz,
}

PromptDispatchMode parsePromptDispatchMode(String mode) {
  final normalized = mode.trim().toLowerCase();
  if (normalized == 'repeat_1hz') {
    return PromptDispatchMode.repeat1hz;
  }
  return PromptDispatchMode.single;
}

String promptDispatchModeWireValue(PromptDispatchMode mode) {
  switch (mode) {
    case PromptDispatchMode.single:
      return 'single';
    case PromptDispatchMode.repeat1hz:
      return 'repeat_1hz';
  }
}

class PromptHistoryItem {
  const PromptHistoryItem({
    required this.uuid,
    required this.text,
    required this.createdAt,
    required this.status,
    this.completedAt,
  });

  final String uuid;
  final String text;
  final DateTime createdAt;
  final PromptRunStatus status;
  final DateTime? completedAt;

  PromptHistoryItem copyWith({
    PromptRunStatus? status,
    DateTime? completedAt,
  }) {
    return PromptHistoryItem(
      uuid: uuid,
      text: text,
      createdAt: createdAt,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class CarDashboardViewModel extends ChangeNotifier {
  CarDashboardViewModel({
    RecvPromptApiService? api,
    Duration pollInterval = const Duration(milliseconds: 900),
  })  : _api = api ?? RecvPromptApiService(),
        _pollInterval = pollInterval;

  final RecvPromptApiService _api;
  final Duration _pollInterval;

  Timer? _pollTimer;

  CarState _state = CarState.empty();
  String _endpoint = '';
  bool _loading = true;
  bool _connected = false;
  bool _submitting = false;
  String _message = '';
  PromptDispatchMode _promptDispatchMode = PromptDispatchMode.single;
  bool _updatingPromptMode = false;
  final List<PromptHistoryItem> _promptHistory = <PromptHistoryItem>[];
  String? _lastSeenPromptUuid;
  double? _lastSeenCompleteTimeSec;

  CarState get state => _state;
  String get endpoint => _endpoint;
  bool get loading => _loading;
  bool get connected => _connected;
  bool get submitting => _submitting;
  String get message => _message;
  PromptDispatchMode get promptDispatchMode => _promptDispatchMode;
  bool get updatingPromptMode => _updatingPromptMode;
  List<PromptHistoryItem> get promptHistory =>
      List<PromptHistoryItem>.unmodifiable(_promptHistory);

  Future<void> initialize() async {
    _endpoint = _buildDefaultEndpoint();
    notifyListeners();
    await connectAndStartPolling();
  }

  Future<void> connectAndStartPolling({String? endpoint}) async {
    if (endpoint != null) {
      _endpoint = endpoint.trim();
    }

    _loading = true;
    _message = '';
    notifyListeners();

    _pollTimer?.cancel();

    try {
      await _api.healthCheck(_safeUri);
      final modeResult = await _api.fetchPromptMode(_safeUri);
      _promptDispatchMode = parsePromptDispatchMode(modeResult.mode);
      _connected = true;
      _message = 'Connected';
      await refreshState();
      _pollTimer = Timer.periodic(_pollInterval, (_) {
        refreshState(silent: true);
      });
    } catch (e) {
      _connected = false;
      _message = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshState({bool silent = false}) async {
    try {
      final next = await _api.fetchState(_safeUri);
      _state = next;
      _reconcilePromptStates(next);
      _connected = true;
      if (!silent) {
        _message = 'State updated';
      }
    } catch (e) {
      _connected = false;
      _message = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> submitPrompt(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty) {
      _message = 'Prompt is empty';
      notifyListeners();
      return;
    }

    _submitting = true;
    _message = '';
    notifyListeners();

    try {
      final result = await _api.sendPrompt(_safeUri, text);
      _upsertPromptHistory(
        PromptHistoryItem(
          uuid: result.uuid,
          text: result.text,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            (result.clientTimestamp * 1000).round(),
          ),
          status: PromptRunStatus.queued,
        ),
      );
      _message = 'Prompt queued';
      await refreshState(silent: true);
    } catch (e) {
      _message = e.toString();
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> updatePromptDispatchMode(PromptDispatchMode mode) async {
    if (_updatingPromptMode || mode == _promptDispatchMode) {
      return;
    }

    _updatingPromptMode = true;
    _message = '';
    notifyListeners();

    try {
      final result = await _api.setPromptMode(_safeUri, promptDispatchModeWireValue(mode));
      _promptDispatchMode = parsePromptDispatchMode(result.mode);
      _message = 'Prompt mode updated';
      await refreshState(silent: true);
    } catch (e) {
      _message = e.toString();
    } finally {
      _updatingPromptMode = false;
      notifyListeners();
    }
  }

  Uri get _safeUri {
    final uri = Uri.tryParse(_endpoint);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw Exception('Invalid endpoint. Example: http://localhost:8787');
    }
    return uri;
  }

  String _buildDefaultEndpoint() {
    final host = kIsWeb ? Uri.base.host : '';
    if (host.isEmpty) {
      return 'http://127.0.0.1:8787';
    }
    return 'http://$host:8787';
  }

  void _reconcilePromptStates(CarState nextState) {
    final currentUuid = nextState.promptUuid;

    if (_lastSeenPromptUuid != null &&
        currentUuid != null &&
        currentUuid.isNotEmpty &&
        _lastSeenPromptUuid != currentUuid) {
      _updateStatus(_lastSeenPromptUuid!, PromptRunStatus.interrupted);
    }

    if (currentUuid != null && currentUuid.isNotEmpty) {
      _updateStatus(currentUuid, PromptRunStatus.processing);
      _lastSeenPromptUuid = currentUuid;
    }

    final transitionedToIdle =
        _lastSeenPromptUuid != null && !nextState.promptProcessing && (currentUuid == null || currentUuid.isEmpty);

    if (transitionedToIdle) {
      final latestComplete = nextState.promptCompleteTime;
      final hasNewCompleteSignal = latestComplete != null &&
          (_lastSeenCompleteTimeSec == null || latestComplete > _lastSeenCompleteTimeSec! + 1e-9);

      final finishedStatus =
          hasNewCompleteSignal ? PromptRunStatus.completed : PromptRunStatus.interrupted;
      _updateStatus(
        _lastSeenPromptUuid!,
        finishedStatus,
        completedAt: hasNewCompleteSignal
            ? DateTime.fromMillisecondsSinceEpoch((latestComplete * 1000).round())
            : null,
      );
      _lastSeenPromptUuid = null;
    }

    if (nextState.promptCompleteTime != null &&
        (_lastSeenCompleteTimeSec == null ||
            nextState.promptCompleteTime! > _lastSeenCompleteTimeSec!)) {
      _lastSeenCompleteTimeSec = nextState.promptCompleteTime;
    }

    _promptDispatchMode = parsePromptDispatchMode(nextState.promptDispatchMode);
  }

  void _upsertPromptHistory(PromptHistoryItem item) {
    final idx = _promptHistory.indexWhere((e) => e.uuid == item.uuid);
    if (idx >= 0) {
      _promptHistory[idx] = item;
      return;
    }
    _promptHistory.insert(0, item);
    if (_promptHistory.length > 120) {
      _promptHistory.removeRange(120, _promptHistory.length);
    }
  }

  void _updateStatus(
    String uuid,
    PromptRunStatus status, {
    DateTime? completedAt,
  }) {
    final idx = _promptHistory.indexWhere((e) => e.uuid == uuid);
    if (idx < 0) {
      return;
    }
    _promptHistory[idx] = _promptHistory[idx].copyWith(
      status: status,
      completedAt: completedAt,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}