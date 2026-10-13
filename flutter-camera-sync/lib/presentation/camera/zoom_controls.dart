import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'camera_cubit.dart';
import 'camera_state.dart';

/// The current zoom readout and the 0.5x/1x/2x preset chips. Pure UI driven
/// by [CameraCubit] via context, with no dependency on the live camera
/// preview itself, so it's directly widget-testable without a platform
/// channel.
class ZoomControls extends StatelessWidget {
  const ZoomControls({super.key, required this.state});

  final CameraReady state;

  static const _presets = [0.5, 1.0, 2.0];

  String _labelFor(double preset) {
    return preset == preset.roundToDouble() ? '${preset.toInt()}x' : '${preset}x';
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CameraCubit>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${state.zoomLevel.toStringAsFixed(1)}x',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final preset in _presets)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _PresetChip(
                  label: _labelFor(preset),
                  selected: (state.zoomLevel - preset).abs() < 0.05,
                  onTap: () => cubit.setZoomPreset(preset),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? Colors.white : Colors.white24,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
