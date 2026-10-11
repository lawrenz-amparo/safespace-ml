# safespace-ml

Harassment detection model (BERT + RNN) behind the AI analysis on
https://uplb-oash.netlify.app/report.

## Run it and connect it to the live site (Windows)

Requirements: Python 3.10–3.13, Git, and the [GitHub CLI](https://cli.github.com/)
signed in as an account with push access to `lawrenz-amparo/safespace` (`gh auth login`).

```
git clone https://github.com/lawrenz-amparo/safespace-ml.git
cd safespace-ml
run.bat
```

`run.bat` does everything:

1. Creates `.venv` and installs dependencies (first run only).
2. Downloads the model checkpoint from the `model-v1` release (first run only).
3. Starts a Cloudflare tunnel, which gives this PC a public `https://….trycloudflare.com` URL.
4. Updates `netlify.toml` in `lawrenz-amparo/safespace` so the live site's `/api/predict`
   goes to that URL. Netlify redeploys within about 30 seconds.
5. Runs the model. Keep the window open; press Ctrl+C to stop.

The tunnel URL changes on every run; step 4 handles that automatically.
AI analysis on the live site only works while `run.bat` is running.
Reports still submit without it, saved as "Not Available".

Model only, no tunnel: `run.bat -NoTunnel` → http://localhost:7860

## API

`POST /predict` with `{"description": "..."}` returns the offense type
(Physical, Verbal, Non-Verbal, Cyber Sexual, or Not Harassment) and severity
(Light, Less Grave, Grave, None) with probabilities. `GET /health` reports status.
