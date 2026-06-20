class Tycho < Formula
  desc "Local-first coding agent orchestration and Kamal dashboard"
  homepage "https://github.com/firewalker06/tycho"
  url "https://github.com/firewalker06/tycho/archive/refs/tags/v0.5.0.tar.gz"
  sha256 "2313d68fd46bd00071290c38eae5845ede2fb6693910dfc9a1f4e66d7010b919"
  license "MIT"
  head "https://github.com/firewalker06/tycho.git", branch: "main"

  bottle do
    root_url "https://github.com/firewalker06/homebrew-tycho/releases/download/tycho-0.5.0"
    sha256 cellar: :any, arm64_tahoe:  "bbab9f8e91fb2278a66520a250bfd12a2a53e24b22858f85153ed0f151afb145"
    sha256 cellar: :any, sequoia:      "6062d901a806a4408971bc1bc2b8aec6198ab6f181b4661e49543411983ed2c8"
    sha256 cellar: :any, x86_64_linux: "d90e45ad3ad084bc638420822c03b6f5ebf1c1b46a2e333a477cf204c08cc852"
  end

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

    env = {
      GEM_HOME: ENV["GEM_HOME"],
      GEM_PATH: ENV["GEM_PATH"],
      PATH:     "#{Formula["ruby"].opt_bin}:$PATH",
    }
    (bin/"tycho").write_env_script libexec/"bin/tycho", env
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
