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

1. Update the version in `Cargo.toml`
2. Commit the change
3. Run the release script:

```bash
./scripts/release.sh
```

## Credits

ASCII art courtesy of [https://www.asciiart.eu/mythology/centaurs](https://www.asciiart.eu/mythology/centaurs)
