# safespace-ml

Harassment detection model (BERT + RNN) behind the AI analysis on
https://uplb-oash.netlify.app/report.

## Run it (Windows)

Requirements: Python 3.10–3.13 and Git.

```
git clone https://github.com/lawrenz-amparo/safespace-ml.git
cd safespace-ml
run.bat
```

The first run installs dependencies and downloads the model (~2 GB). It's ready when
you see `Running on http://127.0.0.1:7860`. Keep the window open; Ctrl+C stops it.

The site (`lawrenz-amparo/safespace`) calls `http://127.0.0.1:7860/predict` from the
browser, so AI analysis works in a browser **on the same computer** that runs `run.bat`.
On other devices, reports still submit, with the AI fields saved as "Not Available".
Chrome may ask once to allow the site to access your local network: click Allow.

`run.bat -Tunnel` also exposes the model publicly through a Cloudflare tunnel and
updates `netlify.toml` (needs the GitHub CLI and a Netlify redeploy each run).

## API

`POST /predict` with `{"description": "..."}` returns the offense type
(Physical, Verbal, Non-Verbal, Cyber Sexual, or Not Harassment) and severity
(Light, Less Grave, Grave, None) with probabilities. `GET /health` reports status.
