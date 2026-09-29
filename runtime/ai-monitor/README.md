# XLX AI Monitor

Purpose: expose a truthful, sanitized AI/DSP status to the public TX box without putting an API key in the dashboard.

## Secret location

The OpenAI key belongs only in:

`/etc/xlx-ai-monitor.env`

Permissions: `root:root 0600`.

Use `sudo xlx-ai-key` after installing this component. The prompt does not echo the key and the helper does not print it.

## Token policy

V1 does **not** send TX audio or make inference requests. It validates API connectivity with the authenticated Models endpoint and publishes only sanitized state to `/var/lib/xlx-ai-monitor/public.json`.

Future analysis must remain exception-driven: local DSP/telemetry first, API only for aggregated anomalies. The browser never receives the secret.

## Public states

- `ready`: local monitoring active, API not configured;
- `monitoring`: API key validated; local telemetry remains the continuous monitor;
- `analyzing`: AI analysis in progress;
- `recommendation`: AI recommendation exists;
- `ai_applied`: an AI-guided action was actually applied by a bounded local controller;
- `error`: configured but API validation failed.

Local adaptive DSP is displayed separately as **DSP ajustando**, never mislabeled as an AI action.
