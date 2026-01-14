import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:collaborative_whiteboard/data/models/stroke.dart';

/// Toolbar widget for drawing tools and settings.
class CanvasToolbar extends StatelessWidget {
  final DrawingTool selectedTool;
  final Color selectedColor;
  final double strokeSize;
  final ValueChanged<DrawingTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeSizeChanged;
  final VoidCallback onClearCanvas;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;

  const CanvasToolbar({
    super.key,
    required this.selectedTool,
    required this.selectedColor,
    required this.strokeSize,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onStrokeSizeChanged,
    required this.onClearCanvas,
    this.onUndo,
    this.onRedo,
    this.canUndo = false,
    this.canRedo = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Drawing tools
            _ToolButton(
              icon: Icons.edit,
              tooltip: 'Pen',
              isSelected: selectedTool == DrawingTool.pen,
              onTap: () => onToolChanged(DrawingTool.pen),
            ),
            _ToolButton(
              icon: Icons.auto_fix_high,
              tooltip: 'Eraser',
              isSelected: selectedTool == DrawingTool.eraser,
              onTap: () => onToolChanged(DrawingTool.eraser),
            ),
            const SizedBox(width: 8),
            const VerticalDivider(width: 1),
            const SizedBox(width: 8),

            // Color picker
            _ColorButton(
              color: selectedColor,
              onTap: () => _showColorPicker(context),
            ),
            const SizedBox(width: 16),

            // Stroke size slider
            Expanded(
              child: _StrokeSizeSlider(
                value: strokeSize,
                onChanged: onStrokeSizeChanged,
                color: selectedColor,
              ),
            ),

            const SizedBox(width: 8),
            const VerticalDivider(width: 1),
            const SizedBox(width: 8),

            // Undo/Redo
            _ToolButton(
              icon: Icons.undo,
              tooltip: 'Undo',
              isSelected: false,
              enabled: canUndo,
              onTap: onUndo,
            ),
            _ToolButton(
              icon: Icons.redo,
              tooltip: 'Redo',
              isSelected: false,
              enabled: canRedo,
              onTap: onRedo,
            ),

            const SizedBox(width: 8),
            const VerticalDivider(width: 1),
            const SizedBox(width: 8),

            // Clear canvas
            _ToolButton(
              icon: Icons.delete_outline,
              tooltip: 'Clear Canvas',
              isSelected: false,
              onTap: () => _showClearConfirmation(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: selectedColor,
            onColorChanged: onColorChanged,
            enableAlpha: false,
            displayThumbColor: true,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Canvas'),
        content: const Text(
          'Are you sure you want to clear the entire canvas? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onClearCanvas();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final bool enabled;
  final VoidCallback? onTap;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: enabled
                  ? (isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface)
                  : colorScheme.onSurface.withOpacity(0.3),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _ColorButton({
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Color',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade400,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StrokeSizeSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final Color color;

  const _StrokeSizeSlider({
    required this.value,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 1,
            max: 50,
            divisions: 49,
            label: '${value.round()}px',
            onChanged: onChanged,
          ),
        ),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

/// Status bar showing connection info and user count.
class ConnectionStatusBar extends StatelessWidget {
  final bool isConnected;
  final int userCount;
  final String? boardId;

  const ConnectionStatusBar({
    super.key,
    required this.isConnected,
    required this.userCount,
    this.boardId,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Connection status
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            // Board ID
            if (boardId != null)
              Text(
                'Board: $boardId',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),

            // User count
            Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '$userCount user${userCount != 1 ? 's' : ''} online',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
