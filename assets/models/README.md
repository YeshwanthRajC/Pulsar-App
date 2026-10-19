# Cactus Model Weights Directory

This directory holds the pre-bundled local offline model weights for **Pulsar (VoiceTask AI)**. Both models are packaged directly inside the application APK and run fully on-device with zero network access.

## 1. Cactus Whistle (Speech-to-Text)
- **Filename**: `whistle.cact`
- **Model Size**: ~16.9 MB (16,919,407 bytes)
- **Source**: [Hugging Face: Cactus-Compute/whistle](https://huggingface.co/Cactus-Compute/whistle)
- **Direct Download**: [Download whistle.cact](https://huggingface.co/Cactus-Compute/whistle/resolve/main/whistle.cact)
- **Engine**: Cactus speech decoder via `needle_transcribe` in `libneedle.a`.

## 2. Cactus Needle (Function-Calling Mini-LLM)
- **Filename**: `needle.cact`
- **Model Size**: ~35.3 MB (35,335,380 bytes, 20 layers)
- **Source**: [Hugging Face: Cactus-Compute/needle3](https://huggingface.co/Cactus-Compute/needle3)
- **Direct Download**: [Download needle3.cact](https://huggingface.co/Cactus-Compute/needle3/resolve/main/needle3.cact)
- **Engine**: Cactus tool-calling engine via `needle_init` and `needle_complete` in `libneedle.a`.

---

## How It Works in Pulsar:
1. **100% Bundled & Offline**: `whistle.cact` and `needle.cact` are packaged directly inside the Flutter asset bundle in the APK. At startup, the app extracts them to local app storage and memory-maps them into the native `libpulsar_needle.so` shared library. No network requests are ever made.
2. **Native C++ & Dart FFI**: Native C++ wrapper (`android/app/src/main/cpp/pulsar_needle.cpp`) links `libneedle.a` (ARM64) via CMake into `libpulsar_needle.so`. Dart FFI (`lib/ai/needle_engine.dart`) communicates directly with the engine inside background isolates to keep the UI smooth.
3. **Resilient Architecture & Graceful Fallback**: On platforms without ARM64 engine binaries (e.g. x86_64 emulator images), the native stub reports unsupported, and Pulsar automatically falls back to its built-in deterministic intent parser (`NeedleIntentParser`) so that all Action Modules and UI workflows remain fully operational.
