# Releasing Tycho Bottles

This tap publishes Homebrew bottles through GitHub Actions and GitHub Releases.

## Repository Setup

Before the first bottled release, confirm these settings in `firewalker06/homebrew-tycho`:

- GitHub Actions is enabled.
- Workflow permissions allow `GITHUB_TOKEN` to read and write repository contents.
- The `pr-pull` label exists, or create it before publishing the first bottle PR.
- Only trusted maintainers apply `pr-pull`. The publish workflow uses `pull_request_target` and has write access so it can update `main` and upload bottle assets.

## Release Flow

1. Wait until the upstream Tycho release tag exists.

   Example:

   ```sh
   git ls-remote --tags https://github.com/firewalker06/tycho.git "refs/tags/v0.1.1*"
   ```

2. Update `Formula/tycho.rb`.

   Change `url` to the new tag tarball and update `sha256`:

   ```sh
   curl -L https://github.com/firewalker06/tycho/archive/refs/tags/v0.1.1.tar.gz | shasum -a 256
   ```

3. Validate locally.

   Run these commands from the installed tap checkout:

   ```sh
   cd "$(brew --repository firewalker06/tycho)"
   ```

   ```sh
   brew audit --strict --online firewalker06/tycho/tycho
   brew install --build-from-source firewalker06/tycho/tycho
   brew test firewalker06/tycho/tycho
   brew uninstall firewalker06/tycho/tycho
   ```

4. Open a pull request in this tap.

   Use a branch name like `tycho-0.1.1` and a commit message like:

   ```text
   tycho 0.1.1
   ```

5. Wait for the `brew test-bot` workflow to pass.

   The standard matrix builds Apple Silicon macOS and Linux bottles with `brew test-bot --only-formulae`. Intel macOS is built by the separate `intel-bottle` job on `macos-15-intel`.

   The Intel job intentionally bypasses `brew test-bot --only-formulae` because the free Intel runner can skip bottle creation when dependencies do not have matching Intel bottles for that runner. It still runs:

   ```sh
   brew install --build-bottle firewalker06/tycho/tycho
   brew audit --formula firewalker06/tycho/tycho --online --git --skip-style
   brew test firewalker06/tycho/tycho
   brew linkage --test firewalker06/tycho/tycho
   brew bottle --json --root-url=...
   ```

   The workflow uploads temporary artifacts named `bottles_<runner>`. For Intel macOS, confirm the artifact `bottles_macos-15-intel` contains a bottle like `tycho--<version>.sequoia.bottle.tar.gz`. A plain `sequoia` tag means Intel macOS; Apple Silicon bottles are tagged with `arm64_`.

6. Publish the bottles.

   Add the `pr-pull` label to the pull request. The `brew pr-pull` workflow will:

   - download the bottle artifacts from the PR workflow run
   - create or update a GitHub Release named `tycho-<version>`
   - upload the bottle assets to that release
   - merge a `bottle do` block into `Formula/tycho.rb`
   - push the result to `main`

7. Verify the published bottle.

   ```sh
   brew update
   brew reinstall firewalker06/tycho/tycho
   brew test firewalker06/tycho/tycho
   brew info firewalker06/tycho/tycho
   ```

## Notes

- GitHub Actions artifacts are intermediate files and are retained for 7 days.
- GitHub Release assets are the durable bottle downloads used by `brew install`.
- Homebrew automatically chooses a matching bottle when the formula's `bottle do` block has a checksum for the user's platform.
- If a bottle build fails on one platform, fix the formula or upstream release and push to the same PR. Do not publish a partial release unless you are comfortable with unmatched platforms building from source.
