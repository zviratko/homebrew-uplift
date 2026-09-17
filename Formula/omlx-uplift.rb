class OmlxUplift < Formula
  desc "Uplift dashboard: companion UI and metrics for oMLX"
  homepage "https://github.com/zviratko/omlx"
  # Development source: the projects/omlx-uplift package from the fork's
  # feature branch. Tag-free for now (head-only tap formula).
  head "https://github.com/zviratko/omlx.git", branch: "feat/uplift-dashboard", using: :git

  # Depends on the omlx formula from the upstream tap; that tap must be
  # added first (caveats say so). We do NOT patch omlx's keg files — the
  # package mounts itself at python level; a vanilla `brew upgrade omlx`
  # stays byte-identical (re-run `brew reinstall omlx-uplift` afterwards
  # to re-inject into the fresh keg).
  depends_on "python@3.11"

  def omlx_python
    (Formula["omlx"].opt_prefix/"libexec/bin/python")
  end

  def install
    odie "omlx must be installed first (brew install jundot/omlx/omlx)" unless omlx_python.exist?

    # 1) Own libexec venv: the standalone viewer + CLI (`omlx-uplift
    #    view` for DMG installs, `install`/`uninstall` pth helpers).
    system "python3.11", "-m", "venv", libexec
    system libexec/"bin/pip", "install", "fastapi", "uvicorn"
    system libexec/"bin/pip", "install", "#{buildpath}/projects/omlx-uplift"
    # pip's console-script shim, renamed into place for a predictable bin.
    bin.install libexec/"bin/omlx-uplift"

    # 2) Inject into the oMLX keg's python: bare `omlx serve` (and its
    #    launchd service) then mounts /uplift without any wrapper or file
    #    edits inside the keg. This writes into Cellar/omlx/*/libexec —
    #    the ONLY divergence point, removed by uninstall.
    system omlx_python, "-m", "pip", "install", "#{buildpath}/projects/omlx-uplift"
    system omlx_python, "-m", "omlx_uplift.cli", "install",
           "--python", omlx_python.to_s
  end

  def caveats
    <<~EOS
      Uplift is mounted into omlx's python. Visit:
        http://127.0.0.1:<omlx-port>/uplift/
      After `brew upgrade omlx` re-run:
        brew reinstall omlx-uplift
      Remove with:
        brew uninstall omlx-uplift && #{omlx_python} -m pip uninstall -y omlx-uplift
    EOS
  end

  test do
    # Package mounts into a fresh FastAPI app and serves the UI shell.
    system omlx_python, "-c", "import omlx_uplift, omlx_uplift.router"
    assert_match "Uplift", shell_output("#{bin}/omlx-uplift 2>&1", 1)
  end
end
