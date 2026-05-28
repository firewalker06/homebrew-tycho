# Homebrew Tycho

Homebrew tap for [Tycho](https://github.com/firewalker06/tycho), a local-first terminal dashboard for Kamal projects and managed coding agents.

## Install

```sh
brew tap firewalker06/tycho
brew install tycho
```

## Bottle Automation

This tap uses Homebrew's standard `brew test-bot` and `brew pr-pull` workflow for bottles, plus a narrow Intel macOS bottle job.

- `.github/workflows/tests.yml` runs on pull requests, validates the tap, builds bottles for changed formulae, and stores the generated bottle files as short-lived GitHub Actions artifacts.
- The normal `brew test-bot --only-formulae` matrix builds Apple Silicon macOS and Linux bottles. Intel macOS uses a separate `macos-15-intel` job that runs `brew install --build-bottle`, audit, test, linkage, and `brew bottle` directly. This bypasses `test-bot`'s bottle dependency gate on the free Intel runner while still validating the installed formula before uploading `bottles_macos-15-intel`.
- `.github/workflows/publish.yml` runs when a maintainer adds the `pr-pull` label to a pull request. It downloads the bottle artifacts, uploads them to GitHub Releases, updates the formula's `bottle do` block, pushes the resulting commits to `main`, and deletes the PR branch when it belongs to this repository.

See [docs/RELEASING.md](docs/RELEASING.md) for the full release process.
