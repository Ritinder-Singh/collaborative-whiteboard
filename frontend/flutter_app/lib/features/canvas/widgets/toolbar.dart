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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Drawing tools group
              _ToolGroup(
                children: [
                  _ToolButton(
                    icon: Icons.edit,
                    tooltip: 'Pen (P)',
                    isSelected: selectedTool == DrawingTool.pen,
                    onTap: () => onToolChanged(DrawingTool.pen),
                  ),
                  _ToolButton(
                    icon: Icons.auto_fix_high,
                    tooltip: 'Eraser (E)',
                    isSelected: selectedTool == DrawingTool.eraser,
                    onTap: () => onToolChanged(DrawingTool.eraser),
                  ),
                ],
              ),

              _ToolDivider(),

              // Shape tools group
              _ToolGroup(
                children: [
                  _ToolButton(
                    icon: Icons.crop_square,
                    tooltip: 'Rectangle (R)',
                    isSelected: selectedTool == DrawingTool.rectangle,
                    onTap: () => onToolChanged(DrawingTool.rectangle),
                  ),
                  _ToolButton(
                    icon: Icons.circle_outlined,
                    tooltip: 'Circle (C)',
                    isSelected: selectedTool == DrawingTool.circle,
                    onTap: () => onToolChanged(DrawingTool.circle),
                  ),
                  _ToolButton(
                    icon: Icons.horizontal_rule,
                    tooltip: 'Line (L)',
                    isSelected: selectedTool == DrawingTool.line,
                    onTap: () => onToolChanged(DrawingTool.line),
                  ),
                  _ToolButton(
                    icon: Icons.arrow_forward,
                    tooltip: 'Arrow (A)',
                    isSelected: selectedTool == DrawingTool.arrow,
                    onTap: () => onToolChanged(DrawingTool.arrow),
                  ),
                ],
              ),

              _ToolDivider(),

              // Text and select tools
              _ToolGroup(
                children: [
                  _ToolButton(
                    icon: Icons.text_fields,
                    tooltip: 'Text (T)',
                    isSelected: selectedTool == DrawingTool.text,
                    onTap: () => onToolChanged(DrawingTool.text),
                  ),
                  _ToolButton(
                    icon: Icons.near_me,
                    tooltip: 'Select (V)',
                    isSelected: selectedTool == DrawingTool.select,
                    onTap: () => onToolChanged(DrawingTool.select),
                  ),
                ],
              ),

              _ToolDivider(),

              // Color picker
              _ColorButton(
                color: selectedColor,
                onTap: () => _showColorPicker(context),
              ),
              const SizedBox(width: 8),

              // Quick colors
              _QuickColorPalette(
                selectedColor: selectedColor,
                onColorSelected: onColorChanged,
              ),

              _ToolDivider(),

              // Stroke size
              SizedBox(
                width: 120,
                child: _StrokeSizeSlider(
                  value: strokeSize,
                  onChanged: onStrokeSizeChanged,
                  color: selectedColor,
                ),
              ),

              _ToolDivider(),

              // Undo/Redo
              _ToolGroup(
                children: [
                  _ToolButton(
                    icon: Icons.undo,
                    tooltip: 'Undo (Ctrl+Z)',
                    isSelected: false,
                    enabled: canUndo,
                    onTap: onUndo,
                  ),
                  _ToolButton(
                    icon: Icons.redo,
                    tooltip: 'Redo (Ctrl+Y)',
                    isSelected: false,
                    enabled: canRedo,
                    onTap: onRedo,
                  ),
                ],
              ),

              _ToolDivider(),

              // Clear canvas
              _ToolButton(
                icon: Icons.delete_outline,
                tooltip: 'Clear Canvas',
                isSelected: false,
                onTap: () => _showClearConfirmation(context),
                color: Colors.red,
              ),
            ],
          ),
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
            enableAlpha: true,
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
          'This action can be undone.',
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

class _ToolGroup extends StatelessWidget {
  final List<Widget> children;

  const _ToolGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _ToolDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 1,
        height: 28,
        color: Colors.grey.withOpacity(0.3),
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
  final Color? color;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    this.enabled = true,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttonColor = color ?? colorScheme.onSurface;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: enabled
                  ? (isSelected ? colorScheme.onPrimaryContainer : buttonColor)
                  : colorScheme.onSurface.withOpacity(0.3),
              size: 20,
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
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.grey.shade400,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
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

class _QuickColorPalette extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  static const _quickColors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
  ];

  const _QuickColorPalette({
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _quickColors.map((color) {
        final isSelected = selectedColor.value == color.value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: GestureDetector(
            onTap: () => onColorSelected(color),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.shade400,
                  width: isSelected ? 2 : 1,
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value,
              min: 1,
              max: 50,
              divisions: 49,
              onChanged: onChanged,
            ),
          ),
        ),
        Container(
          width: 16,
          height: 16,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                const SizedBox(width: 6),
                Text(
                  isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
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
                  fontSize: 11,
                ),
              ),

            // User count
            Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '$userCount online',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
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
