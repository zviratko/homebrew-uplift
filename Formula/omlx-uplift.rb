class OmlxUplift < Formula
  desc "Uplift dashboard: companion UI and metrics for oMLX"
  homepage "https://github.com/zviratko/omlx"
  # Development source: the projects/omlx-uplift package from the fork's
  # feature branch. Tag-free for now (head-only tap formula).
  head "https://github.com/zviratko/omlx.git", branch: "feat/uplift-dashboard", using: :git

  # Depends on the omlx formula from the upstream tap; brew resolves
  # cross-tap deps by full name. We do NOT patch omlx's keg files — the
  # package mounts itself at python level; a vanilla `brew upgrade omlx`
  # stays byte-identical (re-run `brew reinstall omlx-uplift` afterwards
  # to re-inject into the fresh keg).
  depends_on "jundot/omlx/omlx"
  depends_on "python@3.11"

  def omlx_python
    (formula_opt_prefix("omlx")/"libexec/bin/python")
  end

  def install
    # Own libexec venv: standalone viewer + CLI (`omlx-uplift view` for
    # DMG installs; `install`/`uninstall` manage the .pth anywhere).
    # Everything sandbox-writable stays here; the cross-keg injection
    # runs in post_install (the install phase is sandboxed and denies
    # writes into Cellar/omlx).
    system "python3.11", "-m", "venv", libexec
    system libexec/"bin/pip", "install", "fastapi", "uvicorn"
    # --no-deps: the package declares `omlx` (no PyPI distribution); this
    # venv is the HTTP viewer and does not import omlx at all.
    system libexec/"bin/pip", "install", "--no-deps", "#{buildpath}/projects/omlx-uplift"
    # Keep a copy for post_install's keg injection (buildpath is cleaned
    # after install; libexec persists in the Cellar).
    libexec.mkpath
    cp_r "#{buildpath}/projects/omlx-uplift", libexec/"src"
    # pip's console-script shim, into a predictable bin.
    bin.install libexec/"bin/omlx-uplift"
  end

  def post_install
    # Mount into the oMLX keg's python: bare `omlx serve` (and its
    # launchd service) then serves /uplift without any wrapper or file
    # edits inside the keg. `requirement`-style guard keeps --HEAD
    # rebuilds from hard-failing when omlx was removed in between.
    return odie("omlx not installed (brew install jundot/omlx/omlx)") unless omlx_python.exist?

    system omlx_python, "-m", "pip", "install", "--no-deps", "#{libexec}/src"
    system omlx_python, "-m", "omlx_uplift.cli", "install",
           "--python", omlx_python.to_s
  end

  def caveats
    <<~EOS
      Uplift is mounted into omlx's python. Open:
        http://127.0.0.1:<omlx-port>/uplift/
      After `brew upgrade omlx` re-run:
        brew reinstall omlx-uplift
      Remove with:
        brew uninstall omlx-uplift
        #{omlx_python} -m pip uninstall -y omlx-uplift   (if omlx is kept)
    EOS
  end

  test do
    system omlx_python, "-c", "import omlx_uplift, omlx_uplift.router"
    assert_match "Uplift", shell_output("#{bin}/omlx-uplift 2>&1", 1)
  end
end
