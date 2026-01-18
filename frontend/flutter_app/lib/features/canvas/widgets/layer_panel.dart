import 'package:flutter/material.dart';
import 'package:collaborative_whiteboard/data/models/layer.dart';

/// Panel for managing canvas layers
class LayerPanel extends StatelessWidget {
  final List<CanvasLayer> layers;
  final String activeLayerId;
  final ValueChanged<String> onLayerSelected;
  final ValueChanged<String> onLayerVisibilityToggled;
  final ValueChanged<String> onLayerLockToggled;
  final ValueChanged<String> onLayerDeleted;
  final VoidCallback onLayerAdded;
  final Function(int oldIndex, int newIndex) onLayerReordered;
  final Function(String layerId, double opacity) onLayerOpacityChanged;
  final Function(String layerId, String newName) onLayerRenamed;

  const LayerPanel({
    super.key,
    required this.layers,
    required this.activeLayerId,
    required this.onLayerSelected,
    required this.onLayerVisibilityToggled,
    required this.onLayerLockToggled,
    required this.onLayerDeleted,
    required this.onLayerAdded,
    required this.onLayerReordered,
    required this.onLayerOpacityChanged,
    required this.onLayerRenamed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Sort layers by index (highest first for display)
    final sortedLayers = List<CanvasLayer>.from(layers)
      ..sort((a, b) => b.index.compareTo(a.index));

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.layers,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Layers',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                // Add layer button
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: onLayerAdded,
                  tooltip: 'Add Layer',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
          ),
          // Layer list
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: sortedLayers.length,
              onReorder: (oldIndex, newIndex) {
                // Convert display index to actual layer indices
                final movedLayer = sortedLayers[oldIndex];
                final targetLayer = newIndex < sortedLayers.length
                    ? sortedLayers[newIndex > oldIndex ? newIndex - 1 : newIndex]
                    : sortedLayers.last;

                final oldLayerIndex = layers.indexOf(movedLayer);
                var newLayerIndex = layers.indexOf(targetLayer);
                if (oldIndex < newIndex) newLayerIndex++;

                onLayerReordered(oldLayerIndex, newLayerIndex);
              },
              itemBuilder: (context, index) {
                final layer = sortedLayers[index];
                final isActive = layer.id == activeLayerId;

                return _LayerTile(
                  key: ValueKey(layer.id),
                  layer: layer,
                  isActive: isActive,
                  onTap: () => onLayerSelected(layer.id),
                  onVisibilityToggled: () => onLayerVisibilityToggled(layer.id),
                  onLockToggled: () => onLayerLockToggled(layer.id),
                  onDelete: layers.length > 1 ? () => onLayerDeleted(layer.id) : null,
                  onOpacityChanged: (opacity) => onLayerOpacityChanged(layer.id, opacity),
                  onRenamed: (name) => onLayerRenamed(layer.id, name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerTile extends StatefulWidget {
  final CanvasLayer layer;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onVisibilityToggled;
  final VoidCallback onLockToggled;
  final VoidCallback? onDelete;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<String> onRenamed;

  const _LayerTile({
    super.key,
    required this.layer,
    required this.isActive,
    required this.onTap,
    required this.onVisibilityToggled,
    required this.onLockToggled,
    this.onDelete,
    required this.onOpacityChanged,
    required this.onRenamed,
  });

  @override
  State<_LayerTile> createState() => _LayerTileState();
}

class _LayerTileState extends State<_LayerTile> {
  bool _isHovered = false;
  bool _showOpacity = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: widget.isActive
              ? colorScheme.primaryContainer.withOpacity(0.5)
              : (_isHovered ? colorScheme.surfaceContainerHighest : Colors.transparent),
          borderRadius: BorderRadius.circular(6),
          border: widget.isActive
              ? Border.all(color: colorScheme.primary.withOpacity(0.5))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: widget.onTap,
              onDoubleTap: () => _showRenameDialog(context),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    // Drag handle
                    ReorderableDragStartListener(
                      index: 0,
                      child: Icon(
                        Icons.drag_indicator,
                        size: 16,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Visibility toggle
                    GestureDetector(
                      onTap: widget.onVisibilityToggled,
                      child: Icon(
                        widget.layer.isVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 16,
                        color: widget.layer.isVisible
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurfaceVariant.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Layer name
                    Expanded(
                      child: Text(
                        widget.layer.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.layer.isVisible
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withOpacity(0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Lock toggle
                    if (_isHovered || widget.layer.isLocked)
                      GestureDetector(
                        onTap: widget.onLockToggled,
                        child: Icon(
                          widget.layer.isLocked ? Icons.lock : Icons.lock_open,
                          size: 14,
                          color: widget.layer.isLocked
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                      ),
                    const SizedBox(width: 4),
                    // Opacity indicator (click to show slider)
                    if (_isHovered)
                      GestureDetector(
                        onTap: () => setState(() => _showOpacity = !_showOpacity),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '${(widget.layer.opacity * 100).round()}%',
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    // Delete button
                    if (_isHovered && widget.onDelete != null)
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: Icon(
                          Icons.delete_outline,
                          size: 14,
                          color: colorScheme.error.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Opacity slider
            if (_showOpacity)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Opacity:',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5,
                          ),
                        ),
                        child: Slider(
                          value: widget.layer.opacity,
                          min: 0,
                          max: 1,
                          onChanged: widget.onOpacityChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.layer.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Layer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Layer name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                widget.onRenamed(controller.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}
