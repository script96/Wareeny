#!/usr/bin/env python3
from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

ARABIC_RE = re.compile(r"[\u0600-\u06FF]")
ARABIC_LETTER_RE = re.compile(r"[ء-ي]")
STRING_RE = re.compile(
    r"""
    '(?P<single>(?:\\.|[^'\\])*)'
    |
    "(?P<double>(?:\\.|[^"\\])*)"
    """,
    re.VERBOSE,
)

ROOT = Path(__file__).resolve().parents[1]
LIB_DIR = ROOT / "lib"
ASSET_DIR = ROOT / "assets" / "audio" / "tts"
CLIP_DIR = ASSET_DIR / "clips"
INDEX_PATH = ASSET_DIR / "egyptian_phrase_index.json"
INVENTORY_PATH = ROOT / "tool" / "generated" / "arabic_phrase_inventory.json"
REFERENCE_DIR = ROOT / "tool" / "tts_reference"
REFERENCE_PATH = REFERENCE_DIR / "egyptian_female_reference.mp3"
EDGE_VOICE = "ar-EG-SalmaNeural"

STUFF_FINDER_ITEMS = [
    "محفظة",
    "نظارة",
    "موبايل",
    "زجاجة",
    "كوب",
    "كرسي",
    "مفاتيح",
    "شنطة",
    "كتاب",
    "ميكروويف",
]

MODE_NAMES = [
    "الرئيسية",
    "التنقل",
    "البحث عن الأشياء",
    "في اليد",
    "القراءة",
    "الإعدادات",
]

HOME_OBJECT_LABELS = [
    "شخص",
    "كرسي",
    "كنبة",
    "مقعد",
    "طاولة",
    "زجاجة",
    "كوب",
    "كتاب",
    "شنطة",
    "حقيبة",
    "موبايل",
    "لاب توب",
    "تلفزيون",
    "ريموت",
    "كيبورد",
    "ماوس",
    "محفظة",
    "نظارة",
    "مفاتيح",
]

EGYPTIAN_REVIEW_OVERRIDES = {
    "مرحباً بك في ويرني. مرّر بإصبعين للتنقل بين الأوضاع.": (
        "أهلا بيك في ويرني. مرر بإصبعين عشان تتنقل بين الأوضاع."
    ),
    "لم يُعثر على نص. وجّه الكاميرا نحو مستند وحاول مرة أخرى.": (
        "ملقتش نص. وجّه الكاميرا على مستند وحاول تاني."
    ),
    "مسمعتش الأمر بوضوح، حاول تاني": "مسمعتش الكلام بوضوح، حاول تاني",
    "العنصر ده مش متاح حاليًا. المتاح: ": "الحاجة دي مش متاحة دلوقتي. المتاح: ",
    "لازم تسمح لوريني باستخدام الميكروفون والتعرف على الكلام": (
        "لازم تسمح لوريني يستخدم الميكروفون ويتعرف على الكلام"
    ),
    "اختار حاجة علشان أبدأ أدور عليها": "اختار حاجة عشان أبدأ أدور عليها",
}


@dataclass(frozen=True)
class PhraseRecord:
    text: str
    reviewed_text: str
    file: str
    line: int
    kind: str


def normalize_text(text: str) -> str:
    collapsed = re.sub(r"\s+", " ", text).strip()
    return collapsed.replace(" ...", "...").replace(" ،", "،")


def review_egyptian_text(text: str) -> str:
    normalized = normalize_text(text)
    return EGYPTIAN_REVIEW_OVERRIDES.get(normalized, normalized)


def is_phrase_candidate(text: str) -> bool:
    normalized = normalize_text(text)
    if not normalized:
        return False
    if not ARABIC_RE.search(normalized):
        return False
    if not ARABIC_LETTER_RE.search(normalized):
        return False
    if any(char in normalized for char in "[]{}\\^|*+"):
        return False
    if normalized in {"،", "؟", "؛", "..."}:
        return False
    return True


def extract_arabic_literals() -> list[PhraseRecord]:
    records: list[PhraseRecord] = []
    for path in sorted(LIB_DIR.rglob("*.dart")):
        content = path.read_text(encoding="utf-8")
        for match in STRING_RE.finditer(content):
            value = match.group("single") or match.group("double") or ""
            normalized = normalize_text(value)
            if not is_phrase_candidate(normalized):
                continue
            line = content.count("\n", 0, match.start()) + 1
            records.append(
                PhraseRecord(
                    text=normalized,
                    reviewed_text=review_egyptian_text(normalized),
                    file=str(path.relative_to(ROOT)),
                    line=line,
                    kind="literal",
                )
            )
    return records


def build_dynamic_runtime_phrases() -> set[str]:
    phrases = {
        "اتكلم",
        "عايز تدور على إيه؟",
        "مسمعتش الكلام بوضوح، حاول تاني",
        "الحاجة دي مش متاحة دلوقتي. المتاح: " + "، ".join(STUFF_FINDER_ITEMS),
        "لازم تسمح لوريني يستخدم الميكروفون ويتعرف على الكلام",
        "أهلا بيك في ويرني. مرر بإصبعين عشان تتنقل بين الأوضاع.",
        "ملقتش نص. وجّه الكاميرا على مستند وحاول تاني.",
    }

    for mode in MODE_NAMES:
        phrases.add(f"تمام، فتحت وضع {mode}")

    for item in STUFF_FINDER_ITEMS:
        phrases.add(f"تمام، هدور على {item}")
        phrases.add(f"بجهز البحث عن {item}")
        phrases.add(f"بدور على {item}")
        phrases.add(f"لقيت {item}")
        for count in range(2, 11):
            phrases.add(f"لقيت {item} في {count} أماكن")

    for label in HOME_OBJECT_LABELS:
        phrases.add(f"أقرب حاجة {label}")

    return {review_egyptian_text(phrase) for phrase in phrases}


def build_audio_phrase_list(inventory: Iterable[PhraseRecord]) -> list[str]:
    phrases = {
        record.reviewed_text
        for record in inventory
        if "${" not in record.text and "$" not in record.text
    }
    phrases.update(build_dynamic_runtime_phrases())
    return sorted(phrases)


async def bootstrap_reference_voice(reference_path: Path) -> None:
    import edge_tts

    sample_text = (
        "أهلا، أنا الصوت المصري اللي هيقرأ رسائل تطبيق ويرني بصياغة واضحة "
        "وطبيعية عشان تكون سهلة ومفهومة."
    )
    communicate = edge_tts.Communicate(sample_text, voice="ar-EG-SalmaNeural")
    await communicate.save(str(reference_path))


def phrase_asset_name(text: str, extension: str) -> str:
    digest = hashlib.sha1(text.encode("utf-8")).hexdigest()[:16]
    return f"clips/{digest}.{extension}"


def synthesize_assets_with_xtts(
    phrases: list[str],
    reference_path: Path,
) -> list[dict[str, str]]:
    from TTS.api import TTS

    CLIP_DIR.mkdir(parents=True, exist_ok=True)
    tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2", gpu=False)
    entries: list[dict[str, str]] = []
    total = len(phrases)
    for index, phrase in enumerate(phrases, start=1):
        asset = phrase_asset_name(phrase, "wav")
        output_path = ASSET_DIR / asset
        output_path.parent.mkdir(parents=True, exist_ok=True)
        if not output_path.exists():
            print(f"[{index}/{total}] generating {output_path.name}", flush=True)
            tts.tts_to_file(
                text=phrase,
                file_path=str(output_path),
                speaker_wav=str(reference_path),
                language="ar",
            )
        entries.append({"text": phrase, "asset": f"audio/tts/{asset}"})
    return entries


async def synthesize_assets_with_edge(
    phrases: list[str],
    voice: str,
) -> list[dict[str, str]]:
    import edge_tts

    CLIP_DIR.mkdir(parents=True, exist_ok=True)
    entries: list[dict[str, str]] = []
    total = len(phrases)
    for index, phrase in enumerate(phrases, start=1):
        asset = phrase_asset_name(phrase, "mp3")
        output_path = ASSET_DIR / asset
        output_path.parent.mkdir(parents=True, exist_ok=True)
        if not output_path.exists():
            print(f"[{index}/{total}] generating {output_path.name}", flush=True)
            communicate = edge_tts.Communicate(phrase, voice=voice)
            await communicate.save(str(output_path))
        entries.append({"text": phrase, "asset": f"audio/tts/{asset}"})
    return entries


def write_inventory(inventory: list[PhraseRecord], audio_phrases: list[str]) -> None:
    INVENTORY_PATH.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "inventory": [
            {
                "text": record.text,
                "reviewed_text": record.reviewed_text,
                "file": record.file,
                "line": record.line,
                "kind": record.kind,
            }
            for record in inventory
        ],
        "audio_phrase_count": len(audio_phrases),
        "audio_phrases": audio_phrases,
    }
    INVENTORY_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def write_index(
    entries: list[dict[str, str]],
    *,
    engine: str,
    reference_path: Path | None,
    edge_voice: str,
) -> None:
    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "engine": engine,
        "model": (
            "tts_models/multilingual/multi-dataset/xtts_v2"
            if engine == "xtts"
            else edge_voice
        ),
        "reference": (
            str(reference_path.relative_to(ROOT))
            if reference_path is not None
            else None
        ),
        "phrases": entries,
    }
    INDEX_PATH.parent.mkdir(parents=True, exist_ok=True)
    INDEX_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--reference",
        type=Path,
        default=REFERENCE_PATH,
        help="Reference clip used by XTTS-v2 for one-shot cloning.",
    )
    parser.add_argument(
        "--bootstrap-reference",
        action="store_true",
        help="Generate a starter Egyptian-female reference clip with edge-tts if needed.",
    )
    parser.add_argument(
        "--skip-audio",
        action="store_true",
        help="Only build the reviewed phrase inventory and JSON index skeleton.",
    )
    parser.add_argument(
        "--engine",
        choices=("xtts", "edge"),
        default="xtts",
        help="Speech engine to use for clip generation.",
    )
    parser.add_argument(
        "--edge-voice",
        default=EDGE_VOICE,
        help="Edge TTS voice used when --engine edge is selected.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    inventory = extract_arabic_literals()
    audio_phrases = build_audio_phrase_list(inventory)
    write_inventory(inventory, audio_phrases)

    reference_path = args.reference
    if args.bootstrap_reference and not reference_path.exists():
        reference_path.parent.mkdir(parents=True, exist_ok=True)
        asyncio.run(bootstrap_reference_voice(reference_path))

    if args.skip_audio:
        write_index(
            [
                {
                    "text": phrase,
                    "asset": (
                        f"audio/tts/{phrase_asset_name(phrase, 'wav')}"
                        if args.engine == "xtts"
                        else f"audio/tts/{phrase_asset_name(phrase, 'mp3')}"
                    ),
                }
                for phrase in audio_phrases
            ],
            engine=args.engine,
            reference_path=reference_path if args.engine == "xtts" else None,
            edge_voice=args.edge_voice,
        )
        return

    if args.engine == "xtts" and not reference_path.exists():
        raise FileNotFoundError(
            f"Reference voice not found: {reference_path}. "
            "Pass --bootstrap-reference or provide your own Egyptian female clip."
        )

    if args.engine == "xtts":
        entries = synthesize_assets_with_xtts(audio_phrases, reference_path)
    else:
        entries = asyncio.run(synthesize_assets_with_edge(audio_phrases, args.edge_voice))
    write_index(
        entries,
        engine=args.engine,
        reference_path=reference_path if args.engine == "xtts" else None,
        edge_voice=args.edge_voice,
    )


if __name__ == "__main__":
    main()
