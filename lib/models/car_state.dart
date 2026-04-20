class Waypoint {
  const Waypoint({
    required this.x,
    required this.y,
    required this.z,
  });

  final double x;
  final double y;
  final double z;

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    return Waypoint(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      z: (json['z'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CarState {
  const CarState({
    required this.text,
    required this.frameId,
    required this.imageJpegB64,
    required this.rawFrameId,
    required this.rawImageJpegB64,
    required this.waypoints,
    required this.promptProcessing,
    required this.promptUuid,
    required this.promptCompleteTime,
    required this.pendingPromptsCount,
    required this.promptDispatchMode,
    required this.depthDescription,
  });

  final String text;
  final String frameId;
  final String imageJpegB64;
  final String rawFrameId;
  final String rawImageJpegB64;
  final List<Waypoint> waypoints;
  final bool promptProcessing;
  final String? promptUuid;
  final double? promptCompleteTime;
  final int pendingPromptsCount;
  final String promptDispatchMode;
  final String depthDescription;

  bool get hasImage => imageJpegB64.isNotEmpty;

  factory CarState.empty() {
    return const CarState(
      text: '',
      frameId: '',
      imageJpegB64: '',
      rawFrameId: '',
      rawImageJpegB64: '',
      waypoints: <Waypoint>[],
      promptProcessing: false,
      promptUuid: null,
      promptCompleteTime: null,
      pendingPromptsCount: 0,
      promptDispatchMode: 'single',
      depthDescription: '',
    );
  }

  factory CarState.fromJson(Map<String, dynamic> json) {
    final waypointsJson = json['waypoints'] as List<dynamic>? ?? const [];
    return CarState(
      text: (json['text'] as String?) ?? '',
      frameId: (json['frame_id'] as String?) ?? '',
      imageJpegB64: (json['image_jpeg_b64'] as String?) ?? '',
        rawFrameId: (json['raw_frame_id'] as String?) ?? '',
        rawImageJpegB64: (json['raw_image_jpeg_b64'] as String?) ?? '',
      waypoints: waypointsJson
          .whereType<Map<String, dynamic>>()
          .map(Waypoint.fromJson)
          .toList(growable: false),
      promptProcessing: json['prompt_processing'] == true,
      promptUuid: (json['prompt_uuid'] as String?)?.trim().isEmpty == true
          ? null
          : (json['prompt_uuid'] as String?),
      promptCompleteTime: (json['prompt_complete_time'] as num?)?.toDouble(),
      pendingPromptsCount: (json['pending_prompts_count'] as num?)?.toInt() ?? 0,
      promptDispatchMode: ((json['prompt_dispatch_mode'] as String?) ?? 'single').trim(),
      depthDescription: (json['depth_description'] as String?) ?? '',
    );
  }
}