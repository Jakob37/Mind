import 'package:flutter/material.dart';

import '../../domain/task_models.dart';

class CardLayoutSpec {
  const CardLayoutSpec({
    required this.contentPadding,
    required this.listBottomSpacing,
    required this.titleScale,
    required this.previewContentPadding,
  });

  final EdgeInsets contentPadding;
  final double listBottomSpacing;
  final double titleScale;
  final EdgeInsets previewContentPadding;
}

CardLayoutSpec cardLayoutSpecForPreset(CardLayoutPreset preset) {
  return switch (preset) {
    CardLayoutPreset.compact => const CardLayoutSpec(
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        listBottomSpacing: 3,
        titleScale: 0.92,
        previewContentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      ),
    CardLayoutPreset.comfortable => const CardLayoutSpec(
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        listBottomSpacing: 6,
        titleScale: 1.08,
        previewContentPadding:
            EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    CardLayoutPreset.standard => const CardLayoutSpec(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        listBottomSpacing: 4,
        titleScale: 1,
        previewContentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
  };
}

String cardLayoutPresetLabel(CardLayoutPreset preset) {
  return switch (preset) {
    CardLayoutPreset.compact => 'Compact',
    CardLayoutPreset.standard => 'Default',
    CardLayoutPreset.comfortable => 'Comfortable',
  };
}
