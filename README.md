# homebrew-uplift

The **Uplift dashboard** for [oMLX](https://github.com/jundot/omlx) — a
companion web UI (`/uplift/`) with live request feed, model administration,
server settings and persistent metrics, installed **on top of** a vanilla
`jundot/omlx/omlx` install without touching its files.

## Install

```
brew tap jundot/omlx            # oMLX itself (if not already)
brew install omlx
brew tap zviratko/uplift
brew install --HEAD zviratko/uplift/omlx-uplift
```

Then open `http://127.0.0.1:<omlx-port>/uplift/` (port from
`~/.omlx/settings.json`, default 8000) and log in with your admin API key —
the same session works on `/admin` and `/uplift`.

## How it integrates

`omlx-uplift` brews its own Python venv (CLI + standalone viewer). One
command — `omlx-uplift install` — writes exactly **one file** into oMLX's
python: an `omlx_uplift.pth` that adds the Uplift package to `sys.path`
(via the stable `opt/` symlink) and mounts the routes plus the metrics
collector when `omlx.server` is imported. Bare `omlx serve` and the
`brew services` launchd job both pick it up, no wrapper, no copies.

* oMLX keg **files are never edited** — `brew upgrade omlx` stays clean.
* After `brew upgrade omlx` the new keg lacks the .pth: re-run
  `omlx-uplift install` and restart omlx (the caveats print the exact
  commands).
* Metrics live in `~/.omlx/uplift/metrics.sqlite3` (owned by Uplift;
  vanilla's `~/.omlx/usage.sqlite3` is only ever read, read-only).

## Install matrix

| oMLX installed via | Get Uplift |
| --- | --- |
| Homebrew (`jundot/omlx`) | this tap, as above — full integration |
| pip (`pip install omlx`) | clone the [fork](https://github.com/zviratko/omlx/tree/feat/uplift-dashboard), `pip install --no-deps projects/omlx-uplift/`, then `omlx-uplift install` |
| DMG app bundle | run the standalone viewer anywhere Python works: `omlx-uplift view --api http://<host>:<port>` — same UI over plain HTTP (no live feed on vanilla upstream; persistent charts work when run on the same machine, reading `~/.omlx` directly) |

Uninstall: `omlx-uplift uninstall` (drops the .pth from oMLX's python),
then `brew uninstall omlx-uplift`. Classic dashboard is untouched either
way.

## Status

Head-only tap while the design settles; `depends_on "jundot/omlx/omlx"`.
Dashboard development lives in the oMLX fork branch
`feat/uplift-dashboard`, directory `projects/omlx-uplift/`.
