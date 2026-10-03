# Stereo Tool integration foundation — LAB ONLY

This directory contains the first, deliberately non-production stage of the XLX026 Stereo Tool integration.

## Safety boundary

This code does **not** install Stereo Tool, does **not** redistribute vendor binaries, does **not** modify XLXD/xuvd, and does **not** place any DSP in the radio audio path.

The only supported state in this stage is artifact inspection in an isolated laboratory workflow.

Production `PROCESS` is blocked until all of these are independently satisfied:

1. written vendor authorization/licensing for the XLX026 multi-user reflector use case;
2. official SDK headers/examples are available to the operator;
3. artifact static validation and isolated load/smoke tests pass;
4. PCM format/frame inventory is recorded from the actual bridge;
5. per-stream state isolation is demonstrated;
6. latency/CPU/RAM/concurrency benchmarks pass;
7. fail-open/delay-matched bypass is implemented and chaos-tested;
8. shadow soak and controlled canary gates pass;
9. complete rollback is demonstrated.

## Components in this stage

- `artifact_validator.py` — static, non-executing inspection of a directly supplied `.so` or ZIP package.
- `systemd/xlx-stereotoold.service.example` — hardening reference only; not installed automatically.
- `../../tests/test-stereotool-foundation.sh` — regression tests with a synthetic mock shared library and hostile ZIP fixtures. No proprietary vendor file is required.

## Artifact flow

```text
admin-supplied file
        |
        v
size/type checks
        |
        v
safe ZIP inspection (if needed)
        |
        v
SHA-256 + ELF/readelf inspection
        |
        v
arch/glibc/symbol checks
        |
        v
READY_FOR_SANDBOX
```

`READY_FOR_SANDBOX` is **not** production approval. It only means the artifact passed static checks and may be tested in a separate worker later.

## Required symbols used only as identity sanity checks

The static validator requires these exported symbols because current public integration examples use them to identify the library:

- `stereoTool_GetSoftwareVersion`
- `stereoTool_GetApiVersion`

The validator does not call either function. Runtime function names for initialization/processing/termination must come from the official SDK version supplied/licensed by the operator; they must not be guessed.

## No Git storage of proprietary artifacts

Never commit:

- `libStereoTool*.so`;
- Stereo Tool ZIP packages;
- license files/keys;
- proprietary SDK headers unless redistribution is explicitly permitted in writing;
- presets containing sensitive/licensed material.

The public repository contains only adapters, mocks, validators, tests, documentation and metadata needed to support an administrator-supplied artifact.
