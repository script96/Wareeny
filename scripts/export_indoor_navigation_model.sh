#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_MODEL="$ROOT_DIR/indoor nav/yolov8n.pt"
OUTPUT_DIR="$ROOT_DIR/Wareeny/assets/models/indoor_navigation"

if ! command -v yolo >/dev/null 2>&1; then
  echo "Ultralytics CLI was not found. Activate the prototype venv or run:"
  echo "  pip install -r \"$ROOT_DIR/indoor nav/requirements.txt\""
  exit 1
fi

yolo export model="$SOURCE_MODEL" format=tflite imgsz=640 int8=False

EXPORTED_DIR="$ROOT_DIR/indoor nav/yolov8n_saved_model"
if [ -f "$EXPORTED_DIR/yolov8n_full_integer_quant.tflite" ]; then
  cp "$EXPORTED_DIR/yolov8n_full_integer_quant.tflite" "$OUTPUT_DIR/model.tflite"
elif [ -f "$EXPORTED_DIR/yolov8n_float32.tflite" ]; then
  cp "$EXPORTED_DIR/yolov8n_float32.tflite" "$OUTPUT_DIR/model.tflite"
else
  echo "Could not find exported TFLite model in $EXPORTED_DIR"
  exit 1
fi

echo "Exported $OUTPUT_DIR/model.tflite"
