class Tycho < Formula
  desc "Local-first coding agent supervisor and scheduler"
  homepage "https://github.com/firewalker06/tycho"
  url "https://github.com/firewalker06/tycho/archive/refs/tags/v0.9.0.tar.gz"
  sha256 "4762d682b90390c87cce2d39ac14cd2dc1836f11a846a1bff89409a2874524ca"
  license "MIT"
  head "https://github.com/firewalker06/tycho.git", branch: "main"

  bottle do
    root_url "https://github.com/firewalker06/homebrew-tycho/releases/download/tycho-0.9.0"
    sha256 cellar: :any, arm64_tahoe:  "1c65dcd167fb6d02ecb51633eb558e88d2d4406f1474c92fb57a1538c4912073"
    sha256 cellar: :any, sequoia:      "f5a9b23fe4165fa0084caf19c0c622c1f32e844fc9dc4577247a87af079484b6"
    sha256 cellar: :any, x86_64_linux: "b3e6ca6ac70e6570738dc26af1f95ffc0c7758907e1504eb4a2f5a6b1c0a72a7"
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
      PATH:     "#{formula_opt_bin("ruby")}:$PATH",
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
    assert_match "No agents found.", shell_output("#{bin}/tycho agent list")
    assert_match "No schedules", shell_output("#{bin}/tycho schedule list")
    assert_path_exists state/"runtime/tycho" if OS.mac?
  end
end
