const customStuffFinderClasses = <String>['wallet', 'glasses', 'keys'];

/// A short, screen-reader-friendly shortlist of the objects blind/low-vision
/// users search for most often. Shown first in the picker so TalkBack/VoiceOver
/// users reach common targets in a few swipes; the full [stuffFinderClasses]
/// list stays reachable via the picker's "More objects" action.
const commonStuffFinderClasses = <String>[
  'wallet',
  'glasses',
  'keys',
  'cell phone',
  'remote',
  'bottle',
  'cup',
  'backpack',
  'handbag',
  'book',
  'laptop',
  'chair',
  'umbrella',
  'scissors',
  'toothbrush',
];

const popularCocoClasses = <String>[
  // Personal items and electronics.
  'bottle',
  'cell phone',
  'backpack',
  'handbag',
  'suitcase',
  'umbrella',
  'book',
  'laptop',
  'remote',
  'mouse',
  'keyboard',
  'tv',
  'clock',

  // Food, drink, and kitchen items.
  'cup',
  'wine glass',
  'fork',
  'knife',
  'spoon',
  'bowl',
  'banana',
  'apple',
  'sandwich',
  'orange',
  'broccoli',
  'carrot',
  'hot dog',
  'pizza',
  'donut',
  'cake',
  'microwave',
  'oven',
  'toaster',
  'sink',
  'refrigerator',

  // Furniture, home, care, and useful tools.
  'chair',
  'couch',
  'potted plant',
  'bed',
  'dining table',
  'toilet',
  'bench',
  'vase',
  'scissors',
  'hair drier',
  'toothbrush',
  'teddy bear',

  // Clothing, recreation, and everyday transport.
  'tie',
  'sports ball',
  'bicycle',
  'car',
  'motorcycle',
  'bus',
  'train',
];

const cocoClasses = <String>[
  'person',
  'bicycle',
  'car',
  'motorcycle',
  'airplane',
  'bus',
  'train',
  'truck',
  'boat',
  'traffic light',
  'fire hydrant',
  'stop sign',
  'parking meter',
  'bench',
  'bird',
  'cat',
  'dog',
  'horse',
  'sheep',
  'cow',
  'elephant',
  'bear',
  'zebra',
  'giraffe',
  'backpack',
  'umbrella',
  'handbag',
  'tie',
  'suitcase',
  'frisbee',
  'skis',
  'snowboard',
  'sports ball',
  'kite',
  'baseball bat',
  'baseball glove',
  'skateboard',
  'surfboard',
  'tennis racket',
  'bottle',
  'wine glass',
  'cup',
  'fork',
  'knife',
  'spoon',
  'bowl',
  'banana',
  'apple',
  'sandwich',
  'orange',
  'broccoli',
  'carrot',
  'hot dog',
  'pizza',
  'donut',
  'cake',
  'chair',
  'couch',
  'potted plant',
  'bed',
  'dining table',
  'toilet',
  'tv',
  'laptop',
  'mouse',
  'remote',
  'keyboard',
  'cell phone',
  'microwave',
  'oven',
  'toaster',
  'sink',
  'refrigerator',
  'book',
  'clock',
  'vase',
  'scissors',
  'teddy bear',
  'hair drier',
  'toothbrush',
];

final stuffFinderClasses = List<String>.unmodifiable([
  ...customStuffFinderClasses,
  ...popularCocoClasses.where(
    (label) => !customStuffFinderClasses.contains(label),
  ),
  ...cocoClasses.where(
    (label) =>
        !customStuffFinderClasses.contains(label) &&
        !popularCocoClasses.contains(label),
  ),
]);

bool isCustomStuffFinderClass(String label) {
  return customStuffFinderClasses.contains(label.trim().toLowerCase());
}

bool isPopularStuffFinderClass(String label) {
  final normalized = label.trim().toLowerCase();
  return customStuffFinderClasses.contains(normalized) ||
      popularCocoClasses.contains(normalized);
}
