# Ruby Upgrader

This script runs through your projects updating Ruby to the specified version.

It requires Mac OS, [Homebrew](https://brew.sh/), [GitHub CLI](https://cli.github.com/) and that each project uses [rbenv](https://github.com/rbenv/rbenv).

## Behaviour

The script;

- Updates the available system rubies (via `rbenv`).
- Sets the global Ruby version
- For each project dir specified;
  - Update Ruby version in various places;
    - the Gemfile
    - local `.ruby-version` file
    - RuboCop `TargetRubyVersion` config (if present)
    - `Dockerfile` (if present)
  - Run bundle
  - Commit to new branch
  - Push to remote
  - Create new PR on GitHub

## Usage

```sh
./ruby_upgrader/upgrade_ruby.sh 1.2.3 project1 ./path/to/project2 ./etc
```

... where `1.2.3` is the new Ruby version you'd like to use.
