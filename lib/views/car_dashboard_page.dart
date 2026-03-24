import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/car_state.dart';
import '../viewmodels/car_dashboard_view_model.dart';
import 'widgets/waypoint_plot.dart';

class CarDashboardPage extends StatefulWidget {
  const CarDashboardPage({super.key});

  @override
  State<CarDashboardPage> createState() => _CarDashboardPageState();
}

class _CarDashboardPageState extends State<CarDashboardPage> {
  late final TextEditingController _endpointController;
  late final TextEditingController _promptController;
  late final FocusNode _promptFocusNode;
  String _selectedWaypointText = 'Click a waypoint to inspect coordinates';
  final List<String> _promptInputHistory = <String>[];
  int _promptHistoryCursor = -1;
  String _promptDraft = '';
  bool _programmaticPromptUpdate = false;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController();
    _promptController = TextEditingController();
    _promptFocusNode = FocusNode(debugLabel: 'prompt_input_focus');
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _promptController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CarDashboardViewModel>(
      builder: (context, vm, _) {
        if (_endpointController.text != vm.endpoint) {
          _endpointController.text = vm.endpoint;
        }

        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFFE5EDF0), Color(0xFFFBFCFD)],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _buildHeader(vm),
                        const SizedBox(height: 14),
                        _buildConnectionCard(vm),
                        const SizedBox(height: 14),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final narrow = constraints.maxWidth < 900;
                              if (narrow) {
                                return ListView(
                                  children: <Widget>[
                                    _buildImageCard(vm.state),
                                    const SizedBox(height: 12),
                                    SizedBox(height: 320, child: _buildWaypointCard(vm)),
                                    const SizedBox(height: 12),
                                    SizedBox(height: 300, child: _buildPromptHistoryCard(vm)),
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(flex: 5, child: _buildImageCard(vm.state)),
                                  const SizedBox(width: 14),
                                  Expanded(flex: 5, child: _buildWaypointCard(vm)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 3,
                                    child: _buildPromptHistoryCard(vm),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(CarDashboardViewModel vm) {
    final color = vm.connected ? const Color(0xFF1E7A4B) : const Color(0xFFC2410C);
    final label = vm.connected ? 'Connected' : 'Disconnected';

    return Row(
      children: <Widget>[
        const Expanded(
          child: Text(
            'Car Prompt Web Console',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Color(0xFF132029),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionCard(CarDashboardViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _endpointController,
                  decoration: const InputDecoration(
                    labelText: 'Node API endpoint',
                    hintText: 'http://127.0.0.1:8787',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: vm.loading
                    ? null
                    : () => vm.connectAndStartPolling(
                          endpoint: _endpointController.text,
                        ),
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Connect'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Focus(
                  focusNode: _promptFocusNode,
                  onKeyEvent: (node, event) => _handlePromptHistoryKey(node, event),
                  child: TextField(
                    controller: _promptController,
                    minLines: 1,
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    onChanged: _handlePromptTextChanged,
                    onSubmitted: (_) => _sendPrompt(vm),
                    decoration: const InputDecoration(
                      labelText: 'Prompt',
                      hintText: 'Describe what the car model should do...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: vm.submitting ? null : () => _sendPrompt(vm),
                icon: const Icon(Icons.send),
                label: Text(vm.submitting ? 'Sending...' : 'Send Prompt'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Text(
                'Dispatch mode:',
                style: TextStyle(
                  color: Color(0xFF3B4750),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              SegmentedButton<PromptDispatchMode>(
                segments: const <ButtonSegment<PromptDispatchMode>>[
                  ButtonSegment<PromptDispatchMode>(
                    value: PromptDispatchMode.single,
                    label: Text('保持现状'),
                    icon: Icon(Icons.bolt_outlined),
                  ),
                  ButtonSegment<PromptDispatchMode>(
                    value: PromptDispatchMode.repeat1hz,
                    label: Text('1Hz重发到新Prompt'),
                    icon: Icon(Icons.repeat),
                  ),
                ],
                selected: <PromptDispatchMode>{vm.promptDispatchMode},
                onSelectionChanged: vm.updatingPromptMode
                    ? null
                    : (selection) {
                        final mode = selection.first;
                        vm.updatePromptDispatchMode(mode);
                      },
              ),
              if (vm.updatingPromptMode) ...<Widget>[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  vm.message,
                  style: const TextStyle(
                    color: Color(0xFF3B4750),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'pending: ${vm.state.pendingPromptsCount}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF274457),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              vm.state.promptUuid == null
                  ? 'current prompt uuid: <none>'
                  : 'current prompt uuid: ${vm.state.promptUuid}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF52616B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard(CarState state) {
    final processedImageData = _decodeJpeg(state.imageJpegB64);
    final rawImageData = _decodeJpeg(state.rawImageJpegB64);
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Camera Streams',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: _buildCameraStreamPane(
                    title: 'Processed',
                    frameId: state.frameId,
                    imageData: processedImageData,
                    emptyHint: 'No processed stream yet',
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _buildCameraStreamPane(
                    title: 'Raw',
                    frameId: state.rawFrameId,
                    imageData: rawImageData,
                    emptyHint: 'No raw stream yet',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraStreamPane({
    required String title,
    required String frameId,
    required Uint8List? imageData,
    required String emptyHint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF24323B)),
        ),
        const SizedBox(height: 6),
        Text(
          frameId.isEmpty ? 'frame_id: <empty>' : 'frame_id: $frameId',
          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4E5964), fontSize: 12),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ColoredBox(
              color: const Color(0xFF101A20),
              child: imageData == null
                  ? Center(
                      child: Text(
                        emptyHint,
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    )
                  : Image.memory(
                      imageData,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      gaplessPlayback: true,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaypointCard(CarDashboardViewModel vm) {
    return Container(
      width: double.infinity,
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Waypoints (2D Coordinate System)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (vm.state.waypoints.isEmpty)
            const Text(
              'No waypoint updates yet.',
              style: TextStyle(color: Color(0xFF54626D), fontWeight: FontWeight.w600),
            )
          else
            Expanded(
              child: WaypointPlot(
                waypoints: vm.state.waypoints,
                onPointSelected: (selection) {
                  setState(() {
                    _selectedWaypointText =
                        '#${selection.index + 1} | plot(x=${selection.plotX.toStringAsFixed(3)}, '
                        'y=${selection.plotY.toStringAsFixed(3)}) | '
                        'raw(x=${selection.original.x.toStringAsFixed(3)}, '
                        'y=${selection.original.y.toStringAsFixed(3)}, '
                        'z=${selection.original.z.toStringAsFixed(3)})';
                  });
                },
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _selectedWaypointText,
              style: const TextStyle(fontSize: 12, color: Color(0xFF334450), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptHistoryCard(CarDashboardViewModel vm) {
    return Container(
      width: double.infinity,
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Prompt History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (vm.promptHistory.isEmpty)
            const Text(
              'No prompts sent yet.',
              style: TextStyle(color: Color(0xFF54626D), fontWeight: FontWeight.w600),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: vm.promptHistory.length,
                separatorBuilder: (_, _) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final item = vm.promptHistory[index];
                  final statusColor = _statusColor(item.status);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              item.text,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1D2A33)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              _statusText(item.status),
                              style: TextStyle(fontWeight: FontWeight.w700, color: statusColor, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'uuid: ${item.uuid}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF54616B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'sent: ${_formatDateTime(item.createdAt)}'
                        '${item.completedAt == null ? '' : ' | done: ${_formatDateTime(item.completedAt!)}'}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF54616B)),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _sendPrompt(CarDashboardViewModel vm) async {
    if (vm.submitting) {
      return;
    }
    final submitted = _promptController.text.trim();
    await vm.submitPrompt(_promptController.text);
    if (mounted && vm.message == 'Prompt queued') {
      _rememberPrompt(submitted);
      _promptController.clear();
      _promptDraft = '';
      _promptHistoryCursor = -1;
    }
  }

  KeyEventResult _handlePromptHistoryKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (_promptInputHistory.isEmpty) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_promptHistoryCursor == -1) {
        _promptDraft = _promptController.text;
        _promptHistoryCursor = 0;
      } else if (_promptHistoryCursor < _promptInputHistory.length - 1) {
        _promptHistoryCursor += 1;
      }
      _setPromptText(_promptInputHistory[_promptHistoryCursor]);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_promptHistoryCursor == -1) {
        return KeyEventResult.ignored;
      }
      if (_promptHistoryCursor > 0) {
        _promptHistoryCursor -= 1;
        _setPromptText(_promptInputHistory[_promptHistoryCursor]);
      } else {
        _promptHistoryCursor = -1;
        _setPromptText(_promptDraft);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _handlePromptTextChanged(String value) {
    if (_programmaticPromptUpdate) {
      return;
    }
    _promptDraft = value;
    if (_promptHistoryCursor != -1) {
      _promptHistoryCursor = -1;
    }
  }

  void _setPromptText(String value) {
    _programmaticPromptUpdate = true;
    _promptController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _programmaticPromptUpdate = false;
  }

  void _rememberPrompt(String prompt) {
    if (prompt.isEmpty) {
      return;
    }
    _promptInputHistory.remove(prompt);
    _promptInputHistory.insert(0, prompt);
    if (_promptInputHistory.length > 60) {
      _promptInputHistory.removeRange(60, _promptInputHistory.length);
    }
  }

  String _statusText(PromptRunStatus status) {
    switch (status) {
      case PromptRunStatus.queued:
        return 'queued';
      case PromptRunStatus.processing:
        return 'processing';
      case PromptRunStatus.completed:
        return 'completed';
      case PromptRunStatus.interrupted:
        return 'interrupted';
    }
  }

  Color _statusColor(PromptRunStatus status) {
    switch (status) {
      case PromptRunStatus.queued:
        return const Color(0xFF1B5E8A);
      case PromptRunStatus.processing:
        return const Color(0xFFC76808);
      case PromptRunStatus.completed:
        return const Color(0xFF1E7A4B);
      case PromptRunStatus.interrupted:
        return const Color(0xFFB42318);
    }
  }

  String _formatDateTime(DateTime dt) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  Uint8List? _decodeJpeg(String b64) {
    if (b64.isEmpty) {
      return null;
    }
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE1E5E8)),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x110B2F47),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    );
  }
}