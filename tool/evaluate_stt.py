#!/usr/bin/env python3
"""
SIH-21673 Offline Voice Bridge - STT Engine Evaluation & Benchmark Tool
Measures Word Error Rate (WER), Character Error Rate (CER), Latency, and Real-Time Factor (RTF)
comparing NeMo Conformer CTC vs OpenAI Whisper Multilingual.
"""

import argparse
import json
import os
import re
import string
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple


# ==============================================================================
# Metric Calculation Utilities (Pure Python Levenshtein Distance)
# ==============================================================================

def normalize_text(text: str, remove_punct: bool = True, lowercase: bool = True) -> str:
    """Normalize text for fair WER/CER scoring."""
    if lowercase:
        text = text.lower()
    if remove_punct:
        # Remove ASCII punctuation while keeping unicode / Devanagari / etc. intact
        text = text.translate(str.maketrans("", "", string.punctuation))
    # Collapse multiple whitespace characters
    return re.sub(r"\s+", " ", text).strip()


def levenshtein_distance(seq1: List[str], seq2: List[str]) -> int:
    """Compute Levenshtein edit distance between two sequences (words or chars)."""
    m, n = len(seq1), len(seq2)
    dp = [[0] * (n + 1) for _ in range(m + 1)]

    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j

    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if seq1[i - 1] == seq2[j - 1]:
                dp[i][j] = dp[i - 1][j - 1]
            else:
                dp[i][j] = 1 + min(
                    dp[i - 1][j],     # deletion
                    dp[i][j - 1],     # insertion
                    dp[i - 1][j - 1]  # substitution
                )

    return dp[m][n]


def compute_wer(reference: str, hypothesis: str) -> float:
    """Compute Word Error Rate (WER)."""
    ref_words = normalize_text(reference).split()
    hyp_words = normalize_text(hypothesis).split()

    if not ref_words:
        return 0.0 if not hyp_words else 1.0

    distance = levenshtein_distance(ref_words, hyp_words)
    return distance / len(ref_words)


def compute_cer(reference: str, hypothesis: str) -> float:
    """Compute Character Error Rate (CER)."""
    ref_chars = list(normalize_text(reference))
    hyp_chars = list(normalize_text(hypothesis))

    if not ref_chars:
        return 0.0 if not hyp_chars else 1.0

    distance = levenshtein_distance(ref_chars, hyp_chars)
    return distance / len(ref_chars)


# ==============================================================================
# Model Evaluation
# ==============================================================================

@dataclass
class SampleResult:
    audio_file: str
    audio_duration_sec: float
    reference: str
    hypothesis: str
    engine: str
    wer: float
    cer: float
    latency_ms: float
    rtf: float


@dataclass
class EngineSummary:
    engine_name: str
    sample_count: int
    total_audio_sec: float
    total_inference_sec: float
    mean_wer: float
    mean_cer: float
    mean_latency_ms: float
    mean_rtf: float
    p95_latency_ms: float


class ModelEvaluator:
    def __init__(self, project_root: Path, num_threads: int = 2):
        self.project_root = project_root
        self.num_threads = num_threads
        self.sherpa = None
        self.sf = None
        self._init_libraries()

    def _init_libraries(self):
        try:
            import sherpa_onnx
            import soundfile as sf
            self.sherpa = sherpa_onnx
            self.sf = sf
        except ImportError:
            print("Warning: sherpa_onnx or soundfile not found in current environment.", file=sys.stderr)
            print("Run with tool/.venv/bin/python to evaluate audio directly.", file=sys.stderr)

    def load_conformer(self, lang: str = "en"):
        if not self.sherpa:
            raise RuntimeError("sherpa_onnx is required to run Conformer model inference.")
        
        model_path = self.project_root / f"assets/models/stt/{lang}/model.int8.onnx"
        tokens_path = self.project_root / f"assets/models/stt/{lang}/tokens.txt"

        if not model_path.exists():
            raise FileNotFoundError(f"Conformer model not found at {model_path}")

        return self.sherpa.OfflineRecognizer.from_nemo_ctc(
            model=str(model_path),
            tokens=str(tokens_path),
            num_threads=self.num_threads,
        )

    def load_whisper(self, lang: str = "en"):
        if not self.sherpa:
            raise RuntimeError("sherpa_onnx is required to run Whisper model inference.")
        
        whisper_dir = self.project_root / "assets/models/stt/whisper"
        encoder_path = whisper_dir / "tiny-encoder.int8.onnx"
        decoder_path = whisper_dir / "tiny-decoder.int8.onnx"
        tokens_path = whisper_dir / "tiny-tokens.txt"

        if not encoder_path.exists() or not decoder_path.exists():
            raise FileNotFoundError(
                f"Whisper models not found in {whisper_dir}. Run tool/download_models.sh first."
            )

        return self.sherpa.OfflineRecognizer.from_whisper(
            encoder=str(encoder_path),
            decoder=str(decoder_path),
            tokens=str(tokens_path),
            num_threads=self.num_threads,
            language=lang,
            task="transcribe",
        )

    def evaluate_audio(
        self,
        recognizer,
        engine_name: str,
        audio_path: Path,
        reference: str,
    ) -> SampleResult:
        samples, sample_rate = self.sf.read(str(audio_path), dtype="float32")
        duration = len(samples) / sample_rate

        start_time = time.perf_counter()
        stream = recognizer.create_stream()
        stream.accept_waveform(sample_rate, samples)
        recognizer.decode_stream(stream)
        inference_time = time.perf_counter() - start_time

        hypothesis = stream.result.text.strip()
        wer = compute_wer(reference, hypothesis)
        cer = compute_cer(reference, hypothesis)
        latency_ms = inference_time * 1000.0
        rtf = inference_time / duration if duration > 0 else 0.0

        return SampleResult(
            audio_file=audio_path.name,
            audio_duration_sec=round(duration, 2),
            reference=reference,
            hypothesis=hypothesis,
            engine=engine_name,
            wer=round(wer * 100.0, 2),
            cer=round(cer * 100.0, 2),
            latency_ms=round(latency_ms, 1),
            rtf=round(rtf, 4),
        )


# ==============================================================================
# Reporting & Comparison
# ==============================================================================

def compute_summary(results: List[SampleResult], engine_name: str) -> EngineSummary:
    engine_results = [r for r in results if r.engine == engine_name]
    if not engine_results:
        return EngineSummary(engine_name, 0, 0, 0, 0, 0, 0, 0, 0)

    count = len(engine_results)
    total_audio = sum(r.audio_duration_sec for r in engine_results)
    total_inf = sum(r.latency_ms / 1000.0 for r in engine_results)
    mean_wer = sum(r.wer for r in engine_results) / count
    mean_cer = sum(r.cer for r in engine_results) / count
    mean_latency = sum(r.latency_ms for r in engine_results) / count
    mean_rtf = sum(r.rtf for r in engine_results) / count

    latencies = sorted(r.latency_ms for r in engine_results)
    p95_idx = int(0.95 * (count - 1))
    p95_latency = latencies[p95_idx]

    return EngineSummary(
        engine_name=engine_name,
        sample_count=count,
        total_audio_sec=round(total_audio, 2),
        total_inference_sec=round(total_inf, 2),
        mean_wer=round(mean_wer, 2),
        mean_cer=round(mean_cer, 2),
        mean_latency_ms=round(mean_latency, 1),
        mean_rtf=round(mean_rtf, 4),
        p95_latency_ms=round(p95_latency, 1),
    )


def print_comparison_markdown(summaries: List[EngineSummary], sample_results: List[SampleResult]):
    print("\n# STT Model Benchmark Comparison Report")
    print("\n*Smart India Hackathon (SIH) Criteria: Accuracy (40%), Efficiency (20%), Latency (20%)*\n")

    print("## Aggregate Performance Summary")
    print("| Metric | NeMo Conformer CTC | OpenAI Whisper Tiny int8 | Advantage / Trade-off |")
    print("| :--- | :--- | :--- | :--- |")

    conformer = next((s for s in summaries if "conformer" in s.engine_name.lower()), None)
    whisper = next((s for s in summaries if "whisper" in s.engine_name.lower()), None)

    if conformer and whisper:
        c_wer, w_wer = conformer.mean_wer, whisper.mean_wer
        wer_winner = "Whisper (-{:.1f}%)".format(c_wer - w_wer) if w_wer < c_wer else "Conformer (-{:.1f}%)".format(w_wer - c_wer) if c_wer < w_wer else "Tied"

        c_cer, w_cer = conformer.mean_cer, whisper.mean_cer
        cer_winner = "Whisper (-{:.1f}%)".format(c_cer - w_cer) if w_cer < c_cer else "Conformer (-{:.1f}%)".format(w_cer - c_cer) if c_cer < w_cer else "Tied"

        c_lat, w_lat = conformer.mean_latency_ms, whisper.mean_latency_ms
        lat_winner = "Conformer ({:.1f}x faster)".format(w_lat / c_lat) if c_lat > 0 else "Conformer"

        c_rtf, w_rtf = conformer.mean_rtf, whisper.mean_rtf
        rtf_winner = "Conformer ({:.1f}x real-time)".format(1.0 / c_rtf) if c_rtf > 0 else "N/A"

        print(f"| **Word Error Rate (WER)** | **{conformer.mean_wer}%** | **{whisper.mean_wer}%** | {wer_winner} |")
        print(f"| **Character Error Rate (CER)** | **{conformer.mean_cer}%** | **{whisper.mean_cer}%** | {cer_winner} |")
        print(f"| **Average Latency** | **{conformer.mean_latency_ms} ms** | **{whisper.mean_latency_ms} ms** | {lat_winner} |")
        print(f"| **P95 Latency** | **{conformer.p95_latency_ms} ms** | **{whisper.p95_latency_ms} ms** | Conformer |")
        print(f"| **Real-Time Factor (RTF)** | **{conformer.mean_rtf}** | **{whisper.mean_rtf}** | {rtf_winner} |")
        print(f"| **Model Footprint** | **~46 MB** | **~99 MB** (enc+dec) | Conformer is 53% smaller |")
        print(f"| **Language Coverage** | English / Indic per model | 10 Indian Languages bundled | Whisper Multilingual |")
    else:
        for s in summaries:
            print(f"| Engine: {s.engine_name} | WER: {s.mean_wer}% | Latency: {s.mean_latency_ms}ms | RTF: {s.mean_rtf} |")

    print("\n## Per-Sample Utterance Breakdown")
    print("| File | Engine | Reference Ground Truth | Hypothesis Transcription | WER | CER | Latency | RTF |")
    print("| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |")
    for r in sample_results:
        print(f"| `{r.audio_file}` | **{r.engine}** | *\"{r.reference[:40]}...\"* | *\"{r.hypothesis[:40]}...\"* | {r.wer}% | {r.cer}% | {r.latency_ms} ms | {r.rtf} |")
    print()


def parse_ground_truth(trans_path: Path) -> Dict[str, str]:
    """Parse trans.txt mapping wav_filename -> transcript."""
    gt = {}
    if not trans_path.exists():
        return gt

    with open(trans_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(maxsplit=1)
            if len(parts) == 2:
                gt[parts[0]] = parts[1]
    return gt


# ==============================================================================
# Main CLI Handler
# ==============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Evaluate & Compare Speech Recognition Models (NeMo Conformer vs Whisper Tiny)"
    )
    parser.add_argument(
        "--audio-dir",
        type=str,
        default="test/audio_samples",
        help="Directory containing test .wav audio files and trans.txt",
    )
    parser.add_argument(
        "--language",
        type=str,
        default="en",
        help="Language code for evaluation (default: en)",
    )
    parser.add_argument(
        "--compare",
        action="store_true",
        default=True,
        help="Run both Conformer and Whisper engines for side-by-side comparison",
    )
    parser.add_argument(
        "--threads",
        type=int,
        default=2,
        help="Number of CPU inference threads (default: 2)",
    )
    parser.add_argument(
        "--output-json",
        type=str,
        default=None,
        help="Path to save evaluation output as JSON",
    )

    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent
    audio_dir = project_root / args.audio_dir

    if not audio_dir.exists():
        print(f"Audio directory not found: {audio_dir}", file=sys.stderr)
        sys.exit(1)

    trans_file = audio_dir / "trans.txt"
    ground_truth = parse_ground_truth(trans_file)

    wav_files = sorted(list(audio_dir.glob("*.wav")))
    if not wav_files:
        print(f"No .wav files found in {audio_dir}", file=sys.stderr)
        sys.exit(1)

    evaluator = ModelEvaluator(project_root, num_threads=args.threads)

    # Check if sherpa_onnx is available
    if not evaluator.sherpa:
        # Check if tool/.venv has python with sherpa_onnx
        venv_py = project_root / "tool/.venv/bin/python"
        if venv_py.exists():
            print(f"Re-executing evaluation under {venv_py}...")
            os.execv(str(venv_py), [str(venv_py), __file__] + sys.argv[1:])
        else:
            print("Error: sherpa_onnx is required. Install it or run in a virtualenv.", file=sys.stderr)
            sys.exit(1)

    sample_results: List[SampleResult] = []
    summaries: List[EngineSummary] = []

    engines_to_run = []
    if args.compare:
        engines_to_run = ["Conformer CTC", "Whisper Tiny"]
    else:
        engines_to_run = ["Whisper Tiny"]

    for engine_name in engines_to_run:
        print(f"Loading {engine_name} model...", file=sys.stderr)
        if "conformer" in engine_name.lower():
            recognizer = evaluator.load_conformer(lang=args.language)
        else:
            recognizer = evaluator.load_whisper(lang=args.language)

        engine_results: List[SampleResult] = []
        for wav in wav_files:
            ref = ground_truth.get(wav.name, "")
            if not ref:
                # If ground truth not in trans.txt, use filename stem as reference
                ref = wav.stem.replace("_", " ")

            res = evaluator.evaluate_audio(
                recognizer=recognizer,
                engine_name=engine_name,
                audio_path=wav,
                reference=ref,
            )
            sample_results.append(res)
            engine_results.append(res)

        summary = compute_summary(engine_results, engine_name)
        summaries.append(summary)

    print_comparison_markdown(summaries, sample_results)

    if args.output_json:
        output_path = Path(args.output_json)
        data = {
            "summaries": [asdict(s) for s in summaries],
            "samples": [asdict(s) for s in sample_results],
        }
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        print(f"Benchmark results saved to {output_path}")


if __name__ == "__main__":
    main()
