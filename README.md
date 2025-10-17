# horse 🐴

A simple CLI tool that displays an animated ASCII art carousel of horses in your terminal.

## Features

- 5 different ASCII art horse animations
- Continuous carousel loop
- Centaur ASCII art in the manpage (`man horse`)
- Clean exit with Ctrl+C

## Installation

### Via Homebrew

```bash
brew tap notjosh/tap
brew install horse
```

Or in one line:

```bash
brew install notjosh/tap/horse
```

Then run:

```bash
horse           # Run the animation
man horse       # View the manpage with centaur art
```

### Building from Source

```bash
cargo build --release
./target/release/horse
```

## Making a Release (for maintainers)

1. Update the version in `Cargo.toml`
2. Commit the change
3. Create a draft release (this triggers bottle building):

   ```bash
   ./scripts/release-draft.sh
   ```

4. Wait for GitHub Actions to build bottles for all platforms (~5-10 minutes)

   - Check progress: https://github.com/notjosh/horse/actions/workflows/build-bottles.yml

5. Publish the release and update the Homebrew formula:

   ```bash
   ./scripts/release-publish.sh
   ```

The release process automatically:

- Builds bottles for multiple macOS versions
- Uploads bottles to the GitHub release
- Updates the Homebrew formula with bottle information
- Publishes the release

## Credits

ASCII art courtesy of [https://www.asciiart.eu/mythology/centaurs](https://www.asciiart.eu/mythology/centaurs)
