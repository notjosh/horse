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
brew tap notjosh/manhorse
brew install horse
```

Or in one line:
```bash
brew install notjosh/manhorse/horse
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

Simply create a tag and release:

```bash
git tag v0.1.0
git push origin v0.1.0
gh release create v0.1.0 --generate-notes
```

The GitHub Actions workflow will automatically:
1. Download the release tarball
2. Calculate its SHA256
3. Generate/update `Formula/horse.rb`
4. Commit and push the formula

Users can then install with: `brew install notjosh/manhorse/horse`

## Credits

ASCII art courtesy of [https://www.asciiart.eu/mythology/centaurs](https://www.asciiart.eu/mythology/centaurs)
