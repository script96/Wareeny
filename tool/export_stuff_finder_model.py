#!/usr/bin/env python3
"""Export the Wareeny Stuff Finder YOLO model to int8 LiteRT/TFLite assets.

Usage:
  python tool/export_stuff_finder_model.py --force

Recommended isolated environment:
  python3.11 -m venv /tmp/wareeny-stuff-finder-export
  /tmp/wareeny-stuff-finder-export/bin/pip install --upgrade pip
  /tmp/wareeny-stuff-finder-export/bin/pip install ultralytics tensorflow
  /tmp/wareeny-stuff-finder-export/bin/python tool/export_stuff_finder_model.py --force
"""

from __future__ import annotations

import argparse
import json
import shutil
import tempfile
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WEIGHTS = ROOT.parent / "stuff finder " / "final-model.pt"
DEFAULT_DATA = ROOT.parent / "combined-stuff-finder-dataset" / "data.yaml"
DEFAULT_OUTPUT = ROOT / "assets" / "models" / "stuff_finder"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--weights", type=Path, default=DEFAULT_WEIGHTS)
    parser.add_argument("--data", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument(
        "--force",
        action="store_true",
        help="Re-export existing TFLite files instead of reusing them.",
    )
    return parser.parse_args()


def require_imports():
    try:
        from ultralytics import YOLO  # type: ignore
    except ModuleNotFoundError as exc:
        raise SystemExit(
            "Missing ultralytics. Create the export venv shown in this file and "
            "install ultralytics + tensorflow, then rerun the script."
        ) from exc

    try:
        import tensorflow as tf  # type: ignore
    except ModuleNotFoundError as exc:
        raise SystemExit(
            "Missing tensorflow. Ultralytics needs it for LiteRT/TFLite export "
            "and tensor shape inspection."
        ) from exc

    return YOLO, tf


def load_names(data_yaml: Path) -> list[str]:
    try:
        import yaml  # type: ignore
    except ModuleNotFoundError as exc:
        raise SystemExit("Missing pyyaml; it is normally installed with ultralytics.") from exc

    data = yaml.safe_load(data_yaml.read_text(encoding="utf-8"))
    names = data.get("names", {})
    if isinstance(names, dict):
        return [str(names[key]) for key in sorted(names, key=lambda item: int(item))]
    if isinstance(names, list):
        return [str(item) for item in names]
    raise SystemExit(f"Could not read class names from {data_yaml}")


def class_names_from_model(model) -> list[str]:
    names = model.names
    if isinstance(names, dict):
        return [str(names[key]) for key in sorted(names)]
    return [str(item) for item in names]


def absolute_data_yaml(data_yaml: Path, output_dir: Path) -> Path:
    try:
        import yaml  # type: ignore
    except ModuleNotFoundError as exc:
        raise SystemExit("Missing pyyaml; it is normally installed with ultralytics.") from exc

    data = yaml.safe_load(data_yaml.read_text(encoding="utf-8"))
    raw_path = Path(str(data.get("path", "."))).expanduser()
    dataset_root = raw_path if raw_path.is_absolute() else (data_yaml.parent / raw_path)
    data["path"] = str(dataset_root.resolve())

    export_yaml = output_dir / "stuff_finder_data_absolute.yaml"
    export_yaml.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
    return export_yaml


def tflite_files_near(weights: Path) -> list[Path]:
    files = list(weights.parent.rglob("*.tflite"))
    return [path for path in files if path.is_file()]


def newest_tflite(candidates: Iterable[Path]) -> Path:
    files = [path for path in candidates if path.is_file() and path.suffix == ".tflite"]
    if not files:
        raise SystemExit("Ultralytics export did not produce a .tflite file.")
    return max(files, key=lambda path: path.stat().st_mtime)


def needs_refresh(output: Path, *, inputs: Iterable[Path]) -> bool:
    if not output.exists():
        return True
    output_mtime = output.stat().st_mtime
    return any(path.stat().st_mtime > output_mtime for path in inputs if path.exists())


def inspect_tflite(tf, model_path: Path) -> dict[str, object]:
    interpreter = tf.lite.Interpreter(model_path=str(model_path))
    interpreter.allocate_tensors()
    return {
        "inputs": [
            {
                "name": item["name"],
                "shape": item["shape"].tolist(),
                "dtype": str(item["dtype"]),
            }
            for item in interpreter.get_input_details()
        ],
        "outputs": [
            {
                "name": item["name"],
                "shape": item["shape"].tolist(),
                "dtype": str(item["dtype"]),
            }
            for item in interpreter.get_output_details()
        ],
    }


def export_once(YOLO, weights: Path, kwargs: dict[str, object]) -> Path:
    before = set(tflite_files_near(weights))
    model = YOLO(str(weights))
    result = model.export(format="tflite", **kwargs)
    result_path = Path(str(result))
    if result_path.is_file() and result_path.suffix == ".tflite":
        return result_path

    after = set(tflite_files_near(weights))
    created = after - before
    return newest_tflite(created or after)


def main() -> int:
    args = parse_args()
    weights = args.weights.expanduser().resolve()
    data_yaml = args.data.expanduser().resolve()
    output_dir = args.output_dir.expanduser().resolve()

    if not weights.exists():
        raise SystemExit(f"Missing source weights: {weights}")
    if not data_yaml.exists():
        raise SystemExit(f"Missing data.yaml for labels/calibration: {data_yaml}")

    YOLO, tf = require_imports()
    output_dir.mkdir(parents=True, exist_ok=True)

    label_names = load_names(data_yaml)
    model = YOLO(str(weights))
    model_names = class_names_from_model(model)
    if model_names != label_names:
        raise SystemExit(
            "Model labels do not match calibration data labels.\n"
            f"Model: {model_names}\n"
            f"Data:  {label_names}"
        )

    labels_path = output_dir / "labels.txt"
    labels_path.write_text("\n".join(label_names) + "\n", encoding="utf-8")

    float_dest = output_dir / "stuff_finder_float32.tflite"
    float_inputs = (weights,)
    if args.force or needs_refresh(float_dest, inputs=float_inputs):
        float_path = export_once(
            YOLO,
            weights,
            {
                "imgsz": args.imgsz,
                "int8": False,
                "half": False,
                "nms": False,
                "simplify": True,
            },
        )
        shutil.copy2(float_path, float_dest)
    else:
        print(f"Reusing existing correctness model: {float_dest}")

    int8_dest = output_dir / "stuff_finder_int8.tflite"
    int8_inputs = (weights, data_yaml)
    if args.force or needs_refresh(int8_dest, inputs=int8_inputs):
        with tempfile.TemporaryDirectory(prefix="wareeny-stuff-finder-data-") as temp_dir:
            export_data_yaml = absolute_data_yaml(data_yaml, Path(temp_dir))
            int8_path = export_once(
                YOLO,
                weights,
                {
                    "imgsz": args.imgsz,
                    "int8": True,
                    "data": str(export_data_yaml),
                    "nms": False,
                    "simplify": True,
                },
            )
        shutil.copy2(int8_path, int8_dest)
    else:
        print(f"Reusing existing int8 model: {int8_dest}")

    metadata = {
        "source_weights": str(weights),
        "data_yaml": str(data_yaml),
        "runtime": "LiteRT/TensorFlow Lite",
        "optimization": "int8",
        "imgsz": args.imgsz,
        "labels": label_names,
        "float32": {
            "path": str(float_dest.relative_to(ROOT)),
            **inspect_tflite(tf, float_dest),
        },
        "int8": {
            "path": str(int8_dest.relative_to(ROOT)),
            **inspect_tflite(tf, int8_dest),
        },
    }
    (output_dir / "stuff_finder_model_export.json").write_text(
        json.dumps(metadata, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(metadata, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
