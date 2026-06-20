class Tycho < Formula
  desc "Local-first coding agent orchestration and Kamal dashboard"
  homepage "https://github.com/firewalker06/tycho"
  url "https://github.com/firewalker06/tycho/archive/refs/tags/v0.6.0.tar.gz"
  sha256 "e8b56e705c99d6d10ccaedf1b041291edf719aba681385aa22a57aa6e598801e"
  license "MIT"
  head "https://github.com/firewalker06/tycho.git", branch: "main"

  depends_on "go" => :build
  depends_on "openssl@3"
  depends_on "ruby"

  def install
    ENV["BUNDLE_VERSION"] = "system"
    ENV["BUNDLE_WITHOUT"] = "development test"
    ENV["GEM_HOME"] = libexec
    ENV["GEM_PATH"] = libexec

    system "bundle", "install", "--jobs", ENV.make_jobs.to_s
    system "gem", "build", "hq.gemspec"
    system "gem", "install", "hq-#{version}.gem", "--no-document"

    # Remove native-extension build logs to avoid shims references in bottles.
    rm Dir["#{libexec}/extensions/*/*/*/mkmf.log"]

    (bin/"tycho").write <<~SH
      #!/bin/bash
      for key in ${!BUNDLE@} ${!BUNDLER@}; do
        unset "$key"
      done
      unset GEM_HOME GEM_PATH RUBYLIB RUBYOPT
      export GEM_HOME="#{ENV["GEM_HOME"]}"
      export GEM_PATH="#{ENV["GEM_PATH"]}"
      export PATH="#{Formula["ruby"].opt_bin}:$PATH"
      exec "#{libexec}/bin/tycho" "$@"
    SH
    chmod 0755, bin/"tycho"
  end

  def caveats
    <<~EOS
      Tycho stores user config and runtime state under ~/.tycho by default:
        ~/.tycho/config/hq.yml
        ~/.tycho/config/system_prompts.yml
        ~/.tycho/config/schedules.yml
        ~/.tycho/config/hooks.yml
        ~/.tycho/logs/

      Optional integrations are not installed by this formula. Install and
      configure any tools you use, such as mise, kamal, codex, claude,
      tailscale, or custom Claude-compatible harnesses.

      Remote UI is local-first. Set TYCHO_REMOTE_TOKEN before binding
      `tycho serve` to a non-loopback interface.
    EOS
  end

  test do
    config = testpath/"config"
    state = testpath/"state"
    schedules = testpath/"schedules"
    config.mkpath
    schedules.mkpath

    (config/"hq.yml").write("---\nprojects: []\n")
    (config/"system_prompts.yml").write("---\ncustom: \"\"\n")
    (config/"schedules.yml").write("---\nschedules: []\n")
    (config/"hooks.yml").write("---\nhooks: {}\n")

    ENV["TYCHO_CONFIG_PATH"] = config/"hq.yml"
    ENV["TYCHO_SYSTEM_PROMPTS_PATH"] = config/"system_prompts.yml"
    ENV["TYCHO_SCHEDULES_PATH"] = config/"schedules.yml"
    ENV["TYCHO_HOOKS_PATH"] = config/"hooks.yml"
    ENV["TYCHO_SCHEDULES_ROOT"] = schedules
    ENV["TYCHO_LOGS_ROOT"] = state

    assert_match "Usage:", shell_output("#{bin}/tycho --help 2>&1")
    assert_match "Tycho doctor: ok", shell_output("#{bin}/tycho doctor")
    assert_match "No projects", shell_output("#{bin}/tycho app list")
    assert_match "No schedules", shell_output("#{bin}/tycho schedule list")
    assert_path_exists state/"runtime/tycho" if OS.mac?
  end
end
