/// Represents a layer in the canvas
class CanvasLayer {
  final String id;
  final String name;
  final bool isVisible;
  final bool isLocked;
  final double opacity;
  final int index; // z-order (higher = on top)

  const CanvasLayer({
    required this.id,
    required this.name,
    this.isVisible = true,
    this.isLocked = false,
    this.opacity = 1.0,
    this.index = 0,
  });

  CanvasLayer copyWith({
    String? id,
    String? name,
    bool? isVisible,
    bool? isLocked,
    double? opacity,
    int? index,
  }) =>
      CanvasLayer(
        id: id ?? this.id,
        name: name ?? this.name,
        isVisible: isVisible ?? this.isVisible,
        isLocked: isLocked ?? this.isLocked,
        opacity: opacity ?? this.opacity,
        index: index ?? this.index,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_visible': isVisible,
        'is_locked': isLocked,
        'opacity': opacity,
        'index': index,
      };

  factory CanvasLayer.fromJson(Map<String, dynamic> json) => CanvasLayer(
        id: json['id'] as String,
        name: json['name'] as String,
        isVisible: json['is_visible'] as bool? ?? true,
        isLocked: json['is_locked'] as bool? ?? false,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        index: json['index'] as int? ?? 0,
      );

  /// Create a default layer
  factory CanvasLayer.defaultLayer() => const CanvasLayer(
        id: 'default',
        name: 'Layer 1',
        index: 0,
      );
}

/// Actions that can be performed on layers for undo/redo
enum LayerActionType {
  add,
  delete,
  update,
  reorder,
}

/// Represents a layer action for undo/redo
class LayerAction {
  final LayerActionType type;
  final CanvasLayer layer;
  final CanvasLayer? previousState;
  final int? previousIndex;

  const LayerAction({
    required this.type,
    required this.layer,
    this.previousState,
    this.previousIndex,
  });
}
