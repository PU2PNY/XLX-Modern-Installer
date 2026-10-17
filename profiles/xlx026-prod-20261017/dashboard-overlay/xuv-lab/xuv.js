"use strict";

const XUV = (() => {
  const FS = 16000;
  const FRAME = 160;
  const PRE = 0.82;
  const PRED = 0.35;

  class Encoder {
    constructor() { this.reset(); }

    reset() {
      this.prevInput = 0;
      this.r1 = 0;
      this.r2 = 0;
    }

    encode(pcm, profile) {
      const y =
        new Float64Array(FRAME);

      let prevIn =
        this.prevInput;

      for (let i = 0; i < FRAME; i++) {
        const x = pcm[i];
        y[i] = x - PRE * prevIn;
        prevIn = x;
      }

      this.prevInput =
        pcm[FRAME - 1];

      let py1 = this.r1;
      let py2 = this.r2;
      let peak = 128;

      for (let i = 0; i < FRAME; i++) {
        const pred =
          py1 + PRED * (py1 - py2);

        peak =
          Math.max(
            peak,
            Math.abs(y[i] - pred)
          );

        py2 = py1;
        py1 = y[i];
      }

      peak =
        Math.min(
          32767,
          Math.max(128, peak * 1.08)
        );

      const scale =
        Math.round(peak);

      // V2: estado local usa exatamente o scale transmitido.
      const qscale = scale;

      const qmax =
        profile === "HQ128"
        ? 127
        : 7;

      const q =
        new Int16Array(FRAME);

      for (let i = 0; i < FRAME; i++) {
        const pred =
          this.r1 +
          PRED * (this.r1 - this.r2);

        const residual =
          y[i] - pred;

        let qi =
          Math.round(
            residual *
            qmax /
            qscale
          );

        qi =
          Math.max(
            -qmax,
            Math.min(qmax, qi)
          );

        const recon =
          pred +
          qi *
          qscale /
          qmax;

        this.r2 = this.r1;
        this.r1 = recon;

        q[i] = qi;
      }

      if (profile === "HQ128") {
        const payload =
          new Uint8Array(FRAME);

        for (let i = 0; i < FRAME; i++) {
          payload[i] = q[i] + 128;
        }

        return {
          profile,
          scale,
          payload
        };
      }

      const payload =
        new Uint8Array(FRAME / 2);

      for (let i = 0; i < FRAME; i += 2) {
        const a =
          (q[i] + 7) & 0x0f;

        const b =
          (q[i + 1] + 7) & 0x0f;

        payload[i / 2] =
          (a << 4) | b;
      }

      return {
        profile,
        scale,
        payload
      };
    }
  }

  class Decoder {
    constructor() { this.reset(); }

    reset() {
      this.r1 = 0;
      this.r2 = 0;
      this.prevOutput = 0;
    }

    decode(frame) {
      const qmax =
        frame.profile === "HQ128"
        ? 127
        : 7;

      const qscale =
        frame.scale;

      const out =
        new Int16Array(FRAME);

      for (let i = 0; i < FRAME; i++) {
        let qi;

        if (frame.profile === "HQ128") {
          qi =
            frame.payload[i] - 128;
        } else {
          const v =
            frame.payload[i >> 1];

          const nib =
            (i & 1)
            ? (v & 0x0f)
            : ((v >> 4) & 0x0f);

          qi =
            Math.max(
              -7,
              Math.min(7, nib - 7)
            );
        }

        const pred =
          this.r1 +
          PRED * (this.r1 - this.r2);

        const recon =
          pred +
          qi *
          qscale /
          qmax;

        this.r2 = this.r1;
        this.r1 = recon;

        let x =
          recon +
          PRE * this.prevOutput;

        this.prevOutput = x;

        x =
          Math.max(
            -32768,
            Math.min(
              32767,
              Math.round(x)
            )
          );

        out[i] = x;
      }

      return out;
    }
  }

  function encodeDecode(samples, profile) {
    const enc = new Encoder();
    const dec = new Decoder();

    const decoded = [];
    let payloadBytes = 0;

    for (
      let pos = 0;
      pos + FRAME <= samples.length;
      pos += FRAME
    ) {
      const frameIn =
        new Int16Array(FRAME);

      for (let i = 0; i < FRAME; i++) {
        frameIn[i] =
          samples[pos + i];
      }

      const f =
        enc.encode(frameIn, profile);

      const out =
        dec.decode(f);

      payloadBytes +=
        f.payload.length + 3;

      for (let i = 0; i < FRAME; i++) {
        decoded.push(out[i]);
      }
    }

    return {
      decoded:
        Int16Array.from(decoded),
      payloadBytes
    };
  }

  return {
    FS,
    FRAME,
    encodeDecode
  };
})();
