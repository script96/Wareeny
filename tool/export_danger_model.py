#!/usr/bin/env python3
"""Export the Wareeny Danger Mode YOLO model to Android TFLite and iOS Core ML assets.

Usage:
  python tool/export_danger_model.py

The script performs two exports:
  1. Float32 TFLite for correctness checks.
  2. Optimized TFLite, FP16 by default, for the Flutter runtime.
  3. Core ML `.mlpackage.zip` for the iOS Flutter runtime.

Install dependencies in a throwaway Python 3.11 environment before running:
  python3.11 -m venv /tmp/wareeny-danger-export
  /tmp/wareeny-danger-export/bin/pip install --upgrade pip
  /tmp/wareeny-danger-export/bin/pip install ultralytics tensorflow coremltools
  /tmp/wareeny-danger-export/bin/python tool/export_danger_model.py
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WEIGHTS = ROOT.parent / "Danger mode" / "Danger-model.pt"
DEFAULT_DATA = ROOT.parent / "Danger-model" / "combined-danger-dataset" / "data.yaml"
DEFAULT_OUTPUT = ROOT / "assets" / "models" / "danger"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--weights", type=Path, default=DEFAULT_WEIGHTS)
    parser.add_argument("--data", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument(
        "--optimized",
        choices=("int8", "fp16"),
        default="fp16",
        help="Final optimized runtime format. Use int8 to attempt full calibration.",
    )
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
            "Missing ultralytics. Create the export venv shown in this file and install "
            "ultralytics + tensorflow, then rerun the script."
        ) from exc

    try:
        import tensorflow as tf  # type: ignore
    except ModuleNotFoundError as exc:
        raise SystemExit(
            "Missing tensorflow. Ultralytics needs it for TFLite export and tensor "
            "shape inspection."
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


def absolute_data_yaml(data_yaml: Path, output_dir: Path) -> Path:
    try:
        import yaml  # type: ignore
    except ModuleNotFoundError as exc:
        raise SystemExit("Missing pyyaml; it is normally installed with ultralytics.") from exc

    data = yaml.safe_load(data_yaml.read_text(encoding="utf-8"))
    raw_path = Path(str(data.get("path", "."))).expanduser()
    dataset_root = raw_path if raw_path.is_absolute() else (data_yaml.parent / raw_path)
    data["path"] = str(dataset_root.resolve())

    export_yaml = output_dir / "danger_data_absolute.yaml"
    export_yaml.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
    return export_yaml


def newest_tflite(candidates: Iterable[Path]) -> Path:
    files = [path for path in candidates if path.is_file() and path.suffix == ".tflite"]
    if not files:
        raise SystemExit("Ultralytics export did not produce a .tflite file.")
    return max(files, key=lambda path: path.stat().st_mtime)


def tflite_files_near(weights: Path) -> list[Path]:
    search_roots = [
        weights.parent,
        *[path for path in weights.parent.glob("*") if path.is_dir()],
    ]
    files: list[Path] = []
    for root in search_roots:
        files.extend(root.glob("*.tflite"))
    return files


def mlpackage_dirs_near(weights: Path) -> list[Path]:
    search_roots = [
        weights.parent,
        *[path for path in weights.parent.glob("*") if path.is_dir()],
    ]
    packages: list[Path] = []
    for root in search_roots:
        packages.extend(
            path for path in root.glob("*.mlpackage") if path.is_dir()
        )
    return packages


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


def newest_mlpackage(candidates: Iterable[Path]) -> Path:
    packages = [path for path in candidates if path.is_dir() and path.suffix == ".mlpackage"]
    if not packages:
        raise SystemExit("Ultralytics export did not produce a .mlpackage directory.")
    return max(packages, key=lambda path: path.stat().st_mtime)


def export_coreml_once(YOLO, weights: Path, kwargs: dict[str, object]) -> Path:
    before = set(mlpackage_dirs_near(weights))
    model = YOLO(str(weights))
    result = model.export(format="coreml", **kwargs)
    result_path = Path(str(result))
    if result_path.is_dir() and result_path.suffix == ".mlpackage":
        return result_path
    after = set(mlpackage_dirs_near(weights))
    created = after - before
    return newest_mlpackage(created or after)


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

    labels = load_names(data_yaml)
    (output_dir / "danger_labels.txt").write_text(
        "\n".join(labels) + "\n", encoding="utf-8"
    )

    float_dest = output_dir / "danger_model_float32.tflite"
    if args.force or not float_dest.exists():
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

    optimized_kwargs: dict[str, object] = {
        "imgsz": args.imgsz,
        "nms": False,
        "simplify": True,
    }
    optimized_name = "danger_model.tflite"
    optimized_dest = output_dir / optimized_name
    if args.force or not optimized_dest.exists():
        with tempfile.TemporaryDirectory(prefix="wareeny-danger-data-") as temp_dir:
            export_data_yaml = absolute_data_yaml(data_yaml, Path(temp_dir))
            if args.optimized == "int8":
                optimized_kwargs.update({"int8": True, "data": str(export_data_yaml)})
            else:
                optimized_kwargs.update({"half": True, "int8": False})

            optimized_path = export_once(YOLO, weights, optimized_kwargs)
        shutil.copy2(optimized_path, optimized_dest)
    else:
        print(f"Reusing existing optimized model: {optimized_dest}")

    coreml_dir = output_dir / "danger_model.mlpackage"
    coreml_archive = output_dir / "danger_model.mlpackage.zip"
    if args.force or not coreml_archive.exists():
        coreml_path = export_coreml_once(
            YOLO,
            weights,
            {
                "imgsz": args.imgsz,
                "nms": False,
                "simplify": True,
            },
        )
        if coreml_dir.exists():
            shutil.rmtree(coreml_dir)
        shutil.copytree(coreml_path, coreml_dir)
        archive_base = coreml_archive.with_suffix("")
        if coreml_archive.exists():
            coreml_archive.unlink()
        shutil.make_archive(
            str(archive_base),
            "zip",
            root_dir=output_dir,
            base_dir=coreml_dir.name,
        )
    else:
        print(f"Reusing existing iOS Core ML archive: {coreml_archive}")

    metadata = {
        "source_weights": str(weights),
        "data_yaml": str(data_yaml),
        "imgsz": args.imgsz,
        "labels": labels,
        "float32": {
            "path": str(float_dest.relative_to(ROOT)),
            **inspect_tflite(tf, float_dest),
        },
        "optimized": {
            "format": args.optimized,
            "path": str(optimized_dest.relative_to(ROOT)),
            **inspect_tflite(tf, optimized_dest),
        },
        "runtime": {
            "format": args.optimized,
            "path": str(optimized_dest.relative_to(ROOT)),
            **inspect_tflite(tf, optimized_dest),
        },
        "ios_runtime": {
            "format": "coreml",
            "path": str(coreml_archive.relative_to(ROOT)),
        },
    }
    (output_dir / "danger_model_export.json").write_text(
        json.dumps(metadata, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(metadata, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
