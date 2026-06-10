Bundled Stuff Finder assets live here.

Runtime files:

- `yolov8n_coco_float16.tflite`
- `coco_labels.txt`

`yolov8n_coco_float16.tflite` is the active 640x640 YOLOv8n object detector.
`coco_labels.txt` maps its 80 output class indexes to COCO object names.

The runtime detects objects with YOLO, then filters the results to the target
selected by the user. Unused bootstrap and placeholder v2 assets were removed.
