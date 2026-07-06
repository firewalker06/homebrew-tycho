class Tycho < Formula
  desc "Local-first coding agent supervisor and scheduler"
  homepage "https://github.com/firewalker06/tycho"
  url "https://github.com/firewalker06/tycho/archive/refs/tags/v0.7.3.tar.gz"
  sha256 "88f55162563465f2010e7a59952b41da4eaf0f55b309850c47d2f5db758bae8a"
  license "MIT"
  head "https://github.com/firewalker06/tycho.git", branch: "main"

  bottle do
    root_url "https://github.com/firewalker06/homebrew-tycho/releases/download/tycho-0.7.3"
    sha256 cellar: :any, arm64_tahoe:  "79af3a3df617086e15def58bf9436d2c7158c314af75296bfd6e6d7ef891388a"
    sha256 cellar: :any, sequoia:      "2c8a4e9a222ec468881f230678e5b47bac3905c235fdf24007f83ed885997035"
    sha256 cellar: :any, x86_64_linux: "18c43c21dcb8a5fd204a784d4a4576a5ea2b47f7423ba5d48f2198ee528f2251"
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
