"""
Download and prepare Egyptian currency dataset from Kaggle.

Handles two dataset formats:
  A) Classification folders  (images sorted into class-named folders, no annotations)
  B) YOLO format             (images/ + labels/ folders already present)

For format A, whole-image bounding boxes are generated (works well when user
holds a note up to the camera so it fills most of the frame).
"""

import os
import shutil
import random
import zipfile
from pathlib import Path

import yaml
from PIL import Image

DATASET_SLUG = "egyptiris/egyptian-currency"
RAW_DIR      = Path("data/raw")
YOLO_DIR     = Path("data/yolo")
SPLITS       = {"train": 0.8, "val": 0.15, "test": 0.05}
SEED         = 42


# ── helpers ──────────────────────────────────────────────────────────────────

def download_dataset():
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    zip_path = RAW_DIR / "dataset.zip"
    if zip_path.exists():
        print("Zip already downloaded, skipping.")
    else:
        print(f"Downloading {DATASET_SLUG} ...")
        os.system(f'kaggle datasets download -d {DATASET_SLUG} -p "{RAW_DIR}"')
        # kaggle saves as <dataset-name>.zip
        for f in RAW_DIR.glob("*.zip"):
            f.rename(zip_path)
            break

    extract_dir = RAW_DIR / "extracted"
    if not extract_dir.exists():
        print("Extracting ...")
        with zipfile.ZipFile(zip_path, "r") as z:
            z.extractall(extract_dir)

    return extract_dir


def detect_format(extract_dir: Path):
    """Return 'yolo' or 'classification'."""
    # YOLO format: has images/ and labels/ siblings
    if any(extract_dir.rglob("labels")):
        return "yolo"
    # Classification: immediate subdirs whose names look like class labels
    subdirs = [d for d in extract_dir.iterdir() if d.is_dir()]
    if subdirs:
        return "classification"
    # Check one level deeper (zip may have a wrapper folder)
    for sub in subdirs:
        inner = [d for d in sub.iterdir() if d.is_dir()]
        if inner:
            return "classification"
    return "unknown"


def collect_classification_classes(extract_dir: Path):
    """Return {class_name: [image_paths]} from a classification-style dataset."""
    classes = {}
    # Handle optional wrapper folder
    candidates = [extract_dir]
    top_dirs = [d for d in extract_dir.iterdir() if d.is_dir()]
    if len(top_dirs) == 1:
        candidates = [top_dirs[0]]

    for root in candidates:
        for cls_dir in sorted(root.iterdir()):
            if not cls_dir.is_dir():
                continue
            imgs = [
                p for p in cls_dir.rglob("*")
                if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
            ]
            if imgs:
                classes[cls_dir.name] = imgs

    return classes


def whole_image_bbox_label(class_idx: int) -> str:
    """YOLO label line: object covers full image (x_c=0.5 y_c=0.5 w=1 h=1)."""
    return f"{class_idx} 0.500000 0.500000 1.000000 1.000000\n"


def build_yolo_from_classification(classes: dict):
    """Convert classification folders → YOLO split dirs."""
    class_names = sorted(classes.keys())
    print(f"Classes found ({len(class_names)}): {class_names}")

    random.seed(SEED)

    for split in SPLITS:
        (YOLO_DIR / split / "images").mkdir(parents=True, exist_ok=True)
        (YOLO_DIR / split / "labels").mkdir(parents=True, exist_ok=True)

    for cls_idx, cls_name in enumerate(class_names):
        imgs = classes[cls_name]
        random.shuffle(imgs)

        n       = len(imgs)
        n_train = int(n * SPLITS["train"])
        n_val   = int(n * SPLITS["val"])

        split_imgs = {
            "train": imgs[:n_train],
            "val":   imgs[n_train : n_train + n_val],
            "test":  imgs[n_train + n_val :],
        }

        for split, paths in split_imgs.items():
            for src in paths:
                dst_img = YOLO_DIR / split / "images" / src.name
                dst_lbl = YOLO_DIR / split / "labels" / (src.stem + ".txt")

                # Avoid name collisions across classes
                if dst_img.exists():
                    dst_img = dst_img.with_stem(f"{cls_name}_{src.stem}")
                    dst_lbl = dst_lbl.with_stem(f"{cls_name}_{src.stem}")

                shutil.copy2(src, dst_img)
                dst_lbl.write_text(whole_image_bbox_label(cls_idx))

        print(f"  {cls_name:30s} — {n} images")

    return class_names


def collect_yolo_classes(extract_dir: Path):
    """Read class names from an existing data.yaml or classes.txt inside the dataset."""
    for yaml_file in extract_dir.rglob("data.yaml"):
        with open(yaml_file) as f:
            cfg = yaml.safe_load(f)
        if "names" in cfg:
            return cfg["names"]

    for txt in extract_dir.rglob("classes.txt"):
        return txt.read_text().splitlines()

    return None


def copy_yolo_dataset(extract_dir: Path):
    """Copy a pre-formatted YOLO dataset into data/yolo/, creating splits if absent."""
    # Find the root that contains images/ and labels/
    images_root = None
    for p in extract_dir.rglob("images"):
        if p.is_dir():
            images_root = p.parent
            break

    if images_root is None:
        raise RuntimeError("Could not find images/ folder inside YOLO dataset.")

    # If splits already exist (train/val/test subdirs inside images/)
    split_dirs = [d for d in (images_root / "images").iterdir() if d.is_dir()]
    if split_dirs and split_dirs[0].name in {"train", "val", "test"}:
        shutil.copytree(images_root, YOLO_DIR, dirs_exist_ok=True)
        print("Copied pre-split YOLO dataset.")
    else:
        # Flat YOLO: all images in one folder — split manually
        all_imgs = list((images_root / "images").glob("*"))
        all_imgs = [p for p in all_imgs if p.suffix.lower() in {".jpg", ".jpeg", ".png"}]
        random.seed(SEED)
        random.shuffle(all_imgs)

        n       = len(all_imgs)
        n_train = int(n * SPLITS["train"])
        n_val   = int(n * SPLITS["val"])
        splits  = {
            "train": all_imgs[:n_train],
            "val":   all_imgs[n_train : n_train + n_val],
            "test":  all_imgs[n_train + n_val :],
        }

        for split, paths in splits.items():
            (YOLO_DIR / split / "images").mkdir(parents=True, exist_ok=True)
            (YOLO_DIR / split / "labels").mkdir(parents=True, exist_ok=True)
            for src in paths:
                shutil.copy2(src, YOLO_DIR / split / "images" / src.name)
                lbl_src = images_root / "labels" / (src.stem + ".txt")
                if lbl_src.exists():
                    shutil.copy2(lbl_src, YOLO_DIR / split / "labels" / lbl_src.name)

        print(f"Split flat YOLO dataset: {n} images.")

    return collect_yolo_classes(extract_dir)


def write_data_yaml(class_names: list):
    cfg = {
        "path":  str(YOLO_DIR.resolve()),
        "train": "train/images",
        "val":   "val/images",
        "test":  "test/images",
        "nc":    len(class_names),
        "names": class_names,
    }
    out = Path("data/data.yaml")
    with open(out, "w") as f:
        yaml.dump(cfg, f, allow_unicode=True, default_flow_style=False)
    print(f"\ndata.yaml written → {out}")
    print(f"Classes ({len(class_names)}): {class_names}")
    return out


def print_dataset_stats():
    for split in ["train", "val", "test"]:
        imgs = list((YOLO_DIR / split / "images").glob("*"))
        print(f"  {split:6s}: {len(imgs)} images")


# ── main ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    extract_dir = download_dataset()
    fmt = detect_format(extract_dir)
    print(f"Dataset format detected: {fmt}")

    if fmt == "classification":
        classes    = collect_classification_classes(extract_dir)
        class_names = build_yolo_from_classification(classes)
    elif fmt == "yolo":
        class_names = copy_yolo_dataset(extract_dir)
        if class_names is None:
            print("WARNING: could not auto-detect class names.")
            print("Edit data/data.yaml manually and set 'names' before training.")
            class_names = [f"class_{i}" for i in range(20)]
    else:
        raise RuntimeError(
            f"Unknown dataset format. Inspect '{extract_dir}' manually "
            "and arrange as data/yolo/train|val|test/images + labels."
        )

    write_data_yaml(class_names)
    print("\nDataset stats:")
    print_dataset_stats()
    print("\nDone. Run: python train.py")
