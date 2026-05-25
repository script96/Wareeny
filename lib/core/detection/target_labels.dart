import 'package:flutter/material.dart';

class TargetLabel {
  const TargetLabel({
    required this.label,
    required this.displayName,
    required this.icon,
  });

  final String label;
  final String displayName;
  final IconData icon;
}

class TargetLabels {
  const TargetLabels._();

  static const common = <TargetLabel>[
    TargetLabel(
      label: 'cell phone',
      displayName: 'Phone',
      icon: Icons.phone_android_outlined,
    ),
    TargetLabel(label: 'cup', displayName: 'Cup', icon: Icons.local_cafe),
    TargetLabel(
      label: 'remote',
      displayName: 'Remote',
      icon: Icons.settings_remote,
    ),
    TargetLabel(
      label: 'bottle',
      displayName: 'Bottle',
      icon: Icons.local_drink_outlined,
    ),
    TargetLabel(label: 'laptop', displayName: 'Laptop', icon: Icons.laptop),
    TargetLabel(
      label: 'book',
      displayName: 'Book',
      icon: Icons.menu_book_outlined,
    ),
    TargetLabel(
      label: 'scissors',
      displayName: 'Scissors',
      icon: Icons.content_cut,
    ),
    TargetLabel(
      label: 'keyboard',
      displayName: 'Keyboard',
      icon: Icons.keyboard_outlined,
    ),
    TargetLabel(
      label: 'mouse',
      displayName: 'Mouse',
      icon: Icons.mouse_outlined,
    ),
    TargetLabel(label: 'backpack', displayName: 'Bag', icon: Icons.work),
    TargetLabel(
      label: 'handbag',
      displayName: 'Handbag',
      icon: Icons.business_center_outlined,
    ),
    TargetLabel(
      label: 'suitcase',
      displayName: 'Suitcase',
      icon: Icons.business_center,
    ),
    TargetLabel(
      label: 'umbrella',
      displayName: 'Umbrella',
      icon: Icons.umbrella,
    ),
    TargetLabel(label: 'chair', displayName: 'Chair', icon: Icons.chair),
    TargetLabel(label: 'couch', displayName: 'Couch', icon: Icons.weekend),
    TargetLabel(label: 'bed', displayName: 'Bed', icon: Icons.bed),
    TargetLabel(
      label: 'dining table',
      displayName: 'Table',
      icon: Icons.table_chart,
    ),
    TargetLabel(label: 'tv', displayName: 'TV', icon: Icons.tv),
    TargetLabel(label: 'clock', displayName: 'Clock', icon: Icons.access_time),
    TargetLabel(label: 'vase', displayName: 'Vase', icon: Icons.local_florist),
    TargetLabel(
      label: 'toothbrush',
      displayName: 'Toothbrush',
      icon: Icons.search_outlined,
    ),
    TargetLabel(label: 'spoon', displayName: 'Spoon', icon: Icons.restaurant),
    TargetLabel(label: 'fork', displayName: 'Fork', icon: Icons.restaurant),
    TargetLabel(label: 'knife', displayName: 'Knife', icon: Icons.restaurant),
    TargetLabel(label: 'bowl', displayName: 'Bowl', icon: Icons.restaurant),
  ];

  static List<String> get labels {
    return common.map((item) => item.label).toList(growable: false);
  }

  static String displayNameFor(String label) {
    final normalized = label.toLowerCase();
    for (final item in common) {
      if (item.label.toLowerCase() == normalized) {
        return item.displayName;
      }
    }
    return label;
  }
}
