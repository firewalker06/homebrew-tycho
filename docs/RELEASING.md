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

5. Wait for the `brew test-bot` workflow and required bottle verification to pass.

   A green test-bot summary alone is not proof of a build: Homebrew can ignore
   failures for a new version that has no current bottle. The verification step
   requires no failed/ignored/skipped formula steps, a passed installed-formula
   test in JUnit, and a real bottle matching version, platform, and JSON SHA-256.
   Missing output fails the job. Inspect both full logs and downloaded artifacts.

   Run the guard regression checks from the tap root with:

   ```sh
   python3 test/verify_bottles_test.py
   ```

   `scripts/verify-bottles.py --version VERSION --tag BOTTLE_TAG` verifies real
   test-bot outputs and writes `bottle-verification.json`; it does not build or
   fabricate bottles. The formula selects its declared openssl@3 dependency for
   the locked Ruby OpenSSL extension through BUNDLE_BUILD__OPENSSL.

   Do not replace an operational local Tycho installation to validate a release.
   Use the existing isolated test-bot runners for build/install/test checks, then
   perform installed-bottle checks after authorized publication.

   The standard matrix builds Apple Silicon macOS and Linux bottles with
   `brew test-bot --only-formulae`. Do not add an Intel macOS job, artifact, or
   checksum: v0.11.0 is the last Tycho Intel bottle, and v0.11.1 and later
   ship no Intel macOS bottle.

   The workflow uploads temporary artifacts named `bottles_<runner>`. Confirm
   that the run contains only the Apple Silicon macOS and Linux artifacts
   before publishing.

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
