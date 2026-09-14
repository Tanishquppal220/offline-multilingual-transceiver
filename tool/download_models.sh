#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="assets/models/stt/whisper"
ARCHIVE_NAME="sherpa-onnx-whisper-tiny.tar.bz2"
DOWNLOAD_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/${ARCHIVE_NAME}"

echo "=========================================================="
echo " SIH-21673 Whisper Multilingual Model Downloader"
echo " Target: ${TARGET_DIR}"
echo "=========================================================="

mkdir -p "${TARGET_DIR}"

if [ -f "${TARGET_DIR}/tiny-encoder.int8.onnx" ] && \
   [ -f "${TARGET_DIR}/tiny-decoder.int8.onnx" ] && \
   [ -f "${TARGET_DIR}/tiny-tokens.txt" ]; then
    echo "✅ Whisper Tiny int8 models already exist in ${TARGET_DIR}."
    ls -lh "${TARGET_DIR}"
    exit 0
fi

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

echo "⬇️  Downloading ${ARCHIVE_NAME} (~40MB compressed)..."
curl -L --progress-bar "${DOWNLOAD_URL}" -o "${TEMP_DIR}/${ARCHIVE_NAME}"

echo "📦 Extracting model assets..."
tar -xjf "${TEMP_DIR}/${ARCHIVE_NAME}" -C "${TEMP_DIR}"

EXTRACTED_DIR=$(find "${TEMP_DIR}" -maxdepth 2 -type d -name "*whisper-tiny*" | head -n 1)

if [ -z "${EXTRACTED_DIR}" ] || [ ! -d "${EXTRACTED_DIR}" ]; then
    echo "❌ Error: Failed to find extracted whisper-tiny directory."
    exit 1
fi

echo "🚚 Moving models to ${TARGET_DIR}..."
cp "${EXTRACTED_DIR}/tiny-encoder.int8.onnx" "${TARGET_DIR}/"
cp "${EXTRACTED_DIR}/tiny-decoder.int8.onnx" "${TARGET_DIR}/"
cp "${EXTRACTED_DIR}/tiny-tokens.txt" "${TARGET_DIR}/"

echo "✅ Whisper Tiny int8 model installation complete!"
ls -lh "${TARGET_DIR}"
