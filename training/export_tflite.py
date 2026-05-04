"""
Export trained YOLOv8 weights → TFLite fp16.

Copies the result to assets/models/currency_yolov8m.tflite and prints
the updated Dart class-mapping snippet to paste into detector.dart.
"""

import shutil
import yaml
from pathlib import Path
from ultralytics import YOLO

WEIGHTS     = Path("runs/currency/train/weights/best.pt")
DATA_YAML   = Path("data/data.yaml")
ASSETS_DST  = Path("../assets/models/currency_yolov8m.tflite")


def export():
    if not WEIGHTS.exists():
        raise FileNotFoundError(f"{WEIGHTS} not found. Run train.py first.")

    print(f"Exporting {WEIGHTS} → TFLite int8 ...")
    model = YOLO(str(WEIGHTS))

    # int8 requires calibration data — point at training images
    model.export(
        format   = "tflite",
        imgsz    = 640,
        int8     = True,
        data     = str(DATA_YAML),   # calibration dataset reference
        nms      = False,            # flutter_vision does NMS itself
    )

    # ultralytics saves next to the .pt file
    tflite_candidates = list(WEIGHTS.parent.glob("*.tflite"))
    if not tflite_candidates:
        tflite_candidates = list(WEIGHTS.parent.glob("**/*.tflite"))

    if not tflite_candidates:
        raise FileNotFoundError("TFLite file not found after export. Check ultralytics output above.")

    tflite_src = tflite_candidates[0]
    print(f"Exported: {tflite_src}  ({tflite_src.stat().st_size / 1e6:.1f} MB)")

    dst = ASSETS_DST.resolve()
    shutil.copy2(tflite_src, dst)
    print(f"Copied → {dst}")

    return tflite_src


def print_dart_mapping():
    """Print the Dart snippet to update detector.dart with new class mapping."""
    with open(DATA_YAML) as f:
        cfg = yaml.safe_load(f)

    names = cfg.get("names", [])
    print("\n" + "=" * 60)
    print("Update detector.dart — replace _currencyArabicNames with:")
    print("=" * 60)
    print("final Map<String, String> _currencyArabicNames = {")
    for i, name in enumerate(names):
        # Try to map known denominations to Arabic; fall back to transliteration
        arabic = KNOWN_ARABIC.get(name.lower().strip(), f"'{name}'  // TODO: add Arabic")
        print(f"  '{i}': '{arabic}',  // {name}")
    print("};")
    print("=" * 60)


KNOWN_ARABIC = {
    # Common denomination name variants → Egyptian Arabic
    "1":   "جنيه واحد",
    "1egp": "جنيه واحد",
    "1_egp": "جنيه واحد",
    "5":   "خمسة جنيه",
    "5egp": "خمسة جنيه",
    "5_egp": "خمسة جنيه",
    "10":  "عشرة جنيه",
    "10egp": "عشرة جنيه",
    "10_egp": "عشرة جنيه",
    "20":  "عشرون جنيه",
    "20egp": "عشرون جنيه",
    "20_egp": "عشرون جنيه",
    "25":  "خمسة وعشرون جنيه",
    "50":  "خمسون جنيه",
    "50egp": "خمسون جنيه",
    "50_egp": "خمسون جنيه",
    "100": "مية جنيه",
    "100egp": "مية جنيه",
    "100_egp": "مية جنيه",
    "200": "ميتين جنيه",
    "200egp": "ميتين جنيه",
    "200_egp": "ميتين جنيه",
}


if __name__ == "__main__":
    export()
    print_dart_mapping()
    print("\nDone. Rebuild the app: flutter run --release")
