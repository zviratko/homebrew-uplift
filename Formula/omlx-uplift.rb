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
    # pip's console-script shim, into a predictable bin.
    bin.install libexec/"bin/omlx-uplift"

    # Mount into the oMLX keg's python: bare `omlx serve` (and its
    # launchd service) then serves /uplift with zero wrapper and zero
    # file edits inside the keg. Done here rather than post_install:
    # brew's *post-install* sandbox denies writes into other kegs, while
    # the install-phase sandbox permits site-packages (bins stay denied,
    # hence file copy instead of pip — the keg invokes the CLI as
    # `-m omlx_uplift.cli` and never needs a console-script shim).
    return odie("omlx not installed (brew install jundot/omlx/omlx)") unless omlx_python.exist?

    require "fileutils"
    src = purelib(libexec/"bin/python")
    dst = purelib(omlx_python)
    FileUtils.rm_rf Dir["#{dst}/omlx_uplift", "#{dst}/omlx_uplift-*.dist-info", "#{dst}/omlx_uplift.pth"]
    FileUtils.cp_r "#{src}/omlx_uplift", "#{dst}/omlx_uplift"
    Dir["#{src}/omlx_uplift-*.dist-info"].each { |d| FileUtils.cp_r d, "#{dst}/#{File.basename(d)}" }
    File.write "#{dst}/omlx_uplift.pth", "import omlx_uplift.autopatch\n"
  end

  def purelib(python)
    Utils.safe_popen_read(python, "-c",
      "import sysconfig; print(sysconfig.get_paths()['purelib'])").strip
  end

  def uninstall
    # Runs before our own keg is removed (unsandboxed). If omlx was
    # already removed there is nothing to clean; never fail the uninstall
    # over it.
    require "fileutils"
    return unless omlx_python.exist?

    dst = purelib(omlx_python)
    FileUtils.rm_rf Dir["#{dst}/omlx_uplift", "#{dst}/omlx_uplift-*.dist-info", "#{dst}/omlx_uplift.pth"]
  rescue StandardError => e
    opoo "could not clean uplift mount from omlx python: #{e.message}"
  end

  def caveats
    <<~EOS
      Uplift is mounted into omlx's python. Open:
        http://127.0.0.1:<omlx-port>/uplift/
      After `brew upgrade omlx` re-run:
        brew reinstall omlx-uplift
      Remove with:
        brew uninstall omlx-uplift   (also drops the mount from omlx's python)
    EOS
  end

  test do
    system omlx_python, "-c", "import omlx_uplift, omlx_uplift.router"
    assert_match "Uplift", shell_output("#{bin}/omlx-uplift 2>&1", 1)
  end
end
