"""
Train YOLOv8s on the Egyptian currency dataset.

Outputs:
  runs/currency/train/weights/best.pt   ← use this for export
"""

import torch
from pathlib import Path
from ultralytics import YOLO

DATA_YAML   = Path("data/data.yaml")
MODEL       = "yolov8s.pt"   # small > nano for currency detail recognition
EPOCHS      = 150
IMG_SIZE    = 640
BATCH       = 16             # reduce to 8 if VRAM < 6 GB
PROJECT     = "runs/currency"
RUN_NAME    = "train"


def check_cuda():
    if not torch.cuda.is_available():
        print("WARNING: CUDA not available — training on CPU (very slow).")
        print("Install CUDA-enabled PyTorch: https://pytorch.org/get-started/locally/")
        return "cpu"
    gpu = torch.cuda.get_device_name(0)
    vram = torch.cuda.get_device_properties(0).total_memory / 1e9
    print(f"GPU: {gpu}  |  VRAM: {vram:.1f} GB")
    if vram < 6:
        print(f"Low VRAM ({vram:.1f} GB) — setting batch=8")
        global BATCH
        BATCH = 8
    return 0  # device index 0


if __name__ == "__main__":
    if not DATA_YAML.exists():
        raise FileNotFoundError("data/data.yaml not found. Run prepare_dataset.py first.")

    device = check_cuda()

    model = YOLO(MODEL)

    results = model.train(
        data      = str(DATA_YAML),
        epochs    = EPOCHS,
        imgsz     = IMG_SIZE,
        batch     = BATCH,
        device    = device,
        project   = PROJECT,
        name      = RUN_NAME,
        exist_ok  = True,

        # Augmentation — important for currency (varied lighting, angles, wear)
        hsv_h     = 0.02,   # hue jitter (small — notes have specific colors)
        hsv_s     = 0.5,    # saturation
        hsv_v     = 0.4,    # brightness (handles bad/good lighting)
        degrees   = 15,     # rotation (held at angles)
        translate = 0.1,
        scale     = 0.4,    # zoom in/out
        shear     = 5.0,
        perspective=0.0005,
        flipud    = 0.0,    # don't flip vertically (notes have orientation)
        fliplr    = 0.5,
        mosaic    = 1.0,
        mixup     = 0.1,

        # Training settings
        optimizer = "AdamW",
        lr0       = 0.001,
        lrf       = 0.01,
        warmup_epochs = 5,
        patience  = 30,     # early stopping
        save_period = 10,
        val       = True,
        plots     = True,
    )

    best_weights = Path(PROJECT) / RUN_NAME / "weights" / "best.pt"
    print(f"\nTraining complete.")
    print(f"Best weights: {best_weights}")
    print(f"mAP50: {results.results_dict.get('metrics/mAP50(B)', 'N/A')}")
    print(f"\nNext: python export_tflite.py")
