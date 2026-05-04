# Currency Model Training

Train a YOLOv8s model on Egyptian currency and export to TFLite for the app.

---

## Running on a Different Machine (Recommended for Better GPU)

Clone the repo on the target machine, run training there, copy back only the `.tflite` file.

```bash
# On the training machine
git clone https://github.com/script96/Wareeny.git
cd Wareeny/training

# Set up Python 3.11 venv
python3.11 -m venv venv
source venv/bin/activate          # Linux/Mac
# venv\Scripts\activate           # Windows

# Install PyTorch with CUDA (check your CUDA version with nvidia-smi first)
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu124

pip install -r requirements.txt
```

Set up `kaggle.json` (see Prerequisites below), then run the full pipeline:

```bash
python prepare_dataset.py
python train.py
python export_tflite.py
```

After export, **copy only this one file back** to your dev machine:
```
training/runs/currency/train/weights/best.pt   ← optional, keep as backup
assets/models/currency_yolov8m.tflite          ← copy this to your dev machine
```

The export script also prints a Dart snippet — paste it into `lib/detector.dart` on your dev machine (see Step 4 below).

---

## Prerequisites

### 1. CUDA-enabled PyTorch

Check your CUDA version first:
```
nvidia-smi
```

Then install matching PyTorch (**do this before pip install -r requirements.txt**):

| CUDA version | Command |
|---|---|
| 12.1+ | `pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121` |
| 11.8 | `pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118` |
| No GPU | `pip install torch torchvision` |

Verify:
```python
python -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"
```

### 2. Other dependencies

```bash
pip install -r requirements.txt
```

### 3. Kaggle API key

1. Go to kaggle.com → Account → Create New Token → downloads `kaggle.json`
2. Place it at:
   - Windows: `C:\Users\<you>\.kaggle\kaggle.json`
   - Linux/Mac: `~/.kaggle/kaggle.json`

---

## Steps

All commands run from the `training/` folder.

### Step 1 — Prepare dataset

```bash
python prepare_dataset.py
```

Downloads the dataset, detects its format, converts to YOLO layout, splits into train/val/test, writes `data/data.yaml`.

### Step 2 — Train

```bash
python train.py
```

Trains YOLOv8m for 150 epochs with currency-tuned augmentation. Watches for early stopping (patience=30). Best weights saved to `runs/currency/train/weights/best.pt`.

Training time estimates (GPU, YOLOv8m):
- RTX 3060 / 4060: ~60–90 min
- RTX 3080 / 4080: ~30–50 min
- CPU only: many hours (not recommended)

Monitor progress: `runs/currency/train/results.png` updates live.

### Step 3 — Export to TFLite

```bash
python export_tflite.py
```

Exports `best.pt` → TFLite fp16, copies to `assets/models/currency_yolov8m.tflite`, and prints the Dart class-mapping snippet to paste into `lib/detector.dart`.

### Step 4 — Update detector.dart

The export script prints something like:
```dart
final Map<String, String> _currencyArabicNames = {
  '0': 'عشرة جنيه',  // 10egp
  '1': 'عشرون جنيه', // 20egp
  ...
};
```

Paste that into `lib/detector.dart` replacing the existing `_currencyArabicNames` map.

### Step 5 — Rebuild app

```bash
cd ..
flutter run --release
```

---

## Troubleshooting

**CUDA out of memory**: Edit `train.py` and set `BATCH = 8` (or lower).

**`kaggle: command not found`**: Run `pip install kaggle` and set up `kaggle.json`.

**Export fails with TFLite error**: Make sure TensorFlow is installed:
```bash
pip install tensorflow
```
Some ultralytics versions need it for TFLite int8 export.

**Low mAP after training**: Dataset may be classification-only (no tight bounding boxes). The whole-image bbox approach works for use cases where the user holds a single note up to the camera. If you need multi-note detection, the dataset will need manual annotation with tight boxes.
