#!/bin/sh

function usage {
  echo "Usage example:"
  echo "$0 1.2.3 ./my_project ./another_project"
  exit 1
}

function validate_ruby_project_dir {
  if [ ! -d "$1" ]; then
    echo "$1 is not a directory!"
    exit 1
  fi

  if [ ! -e "$1/Gemfile" ]; then
    echo "$1 does not contain a Gemfile..."
    exit 1
  fi
}

function validate_ruby_version_format {
  if [ -z $1 ] ; then
    echo "Please supply the Ruby version to upgrade to!"
    usage
  fi

  # Validate Ruby version format X.Y.Z
  if [[ ! "$1" =~ ^[0-9]\.[0-9]\.[0-9]$ ]] ; then
    echo "Invalid Ruby version format. Expected X.Y.Z, got: $1"
    usage
  fi
}

function validate_dependencies_exist {
  if ! type rbenv > /dev/null; then
    echo "Please install rbenv (and ruby-build) to upgrade Ruby versions!"
    exit 1
  fi

  if ! type brew > /dev/null; then
    echo "Please install Homebrew to upgrade Ruby versions!"
    exit 1
  fi

  if ! type gh > /dev/null; then
    echo "Please install GitHub CLI (and login) to auto-create PRs!"
    echo "brew install gh"
    echo "gh auth login"
    exit 1
  fi
}

validate_ruby_version_format $1
required_ruby_version=$1

# Remove the first (Ruby version) arg, leaving only dirs to iterate through
shift

if [ -z $1 ] ; then
  echo "Please supply at least one project directory to upgrade!"
  usage
fi

for dirname in "$@"
do
  validate_ruby_project_dir $dirname
done

validate_dependencies_exist

function prepare_global_ruby_env {
  echo "Updating ruby-build (to check for updates)..."
  brew upgrade ruby-build

  # Install Ruby version if not already installed
  if ! rbenv versions | grep -q $required_ruby_version; then
    echo "Installing Ruby $required_ruby_version..."
    rbenv install $required_ruby_version
  fi

  # Set Ruby version globally
  rbenv global $required_ruby_version

  # Install bundler if not already installed
  if ! gem list bundler -i; then
    echo "Installing bundler..."
    gem install bundler
  fi
}

function update_gemfile_ruby_version {
  # Replace ruby line in Gemfile with value of $required_ruby_version
  sed -i '' "s/^ruby .*/ruby '$required_ruby_version'/" $1/Gemfile

  # Return an error if no replacement was made
  if ! grep -q "^ruby '$required_ruby_version'" $1/Gemfile; then
    echo "Failed to update Ruby version in $1/Gemfile!"
    exit 1
  fi
}

function update_rubocop_ruby_version {
  if [ ! -e "$1/.rubocop.yml" ]; then
    echo "No RuboCop config found in $1; skipping..."
    return
  fi

  # Extract Ruby major and minor version from X.Y.Z
  ruby_major_version=$(echo $required_ruby_version | cut -d. -f1)
  ruby_minor_version=$(echo $required_ruby_version | cut -d. -f2)

  echo "Updating RuboCop target in $1/.rubocop.yml (to $ruby_major_version.$ruby_minor_version)"

  # Update Ruby version in Rubocop config
  sed -i '' "s/TargetRubyVersion: .*/TargetRubyVersion: $ruby_major_version.$ruby_minor_version/" $1/.rubocop.yml

  # Check that file was updated
  if ! grep -q "TargetRubyVersion: $ruby_major_version.$ruby_minor_version" $1/.rubocop.yml; then
    echo "Failed to update RuboCop config in $1/.rubocop.yml!"
    exit 1
  fi

  # Add RuboCop config to git
  git -C $1 add .rubocop.yml
}

function update_ruby_version_file {
  echo "Updating .ruby-version in $1..."

  # Update Ruby version in .ruby-version file
  echo $required_ruby_version > $1/.ruby-version

  # Add .ruby-version file to git
  git -C $1 add .ruby-version
}

function update_docker_ruby_version {
  if [ -e "$1/Dockerfile" ]; then
    echo "No Dockerfile found in $1; skipping..."
    return
  fi

  echo "Updating Ruby version in $1/Dockerfile"

  # Update Ruby version in Dockerfile
  sed -i '' "s/^FROM ruby:.*/FROM ruby:$required_ruby_version/" $1/Dockerfile

  # Add Dockerfile to git
  git -C $1 add Dockerfile
}

function update_ruby {
  echo "Upgrading $1 project to Ruby $required_ruby_version ..."

  # Get current Ruby version from Gemfile
  current_ruby_version=$(grep "^ruby " $1/Gemfile | cut -d\' -f2)

  # Check if Gemfile already has this version
  if [ "$current_ruby_version" == "$required_ruby_version" ]; then
    echo "Gemfile already has Ruby $required_ruby_version; skipping..."
    return
  fi

  update_gemfile_ruby_version $1

  update_rubocop_ruby_version $1

  update_ruby_version_file $1

  update_docker_ruby_version $1

  # run bundler to update Gemfile.lock
  echo "Running bundle install in $1..."
  sleep 2
  bundle install --gemfile=$1/Gemfile

  # Change branch and commit changes
  git -C $1 checkout -b chore/ruby-$required_ruby_version
  git -C $1 add Gemfile Gemfile.lock
  git -C $1 commit -m "Upgrade Ruby to $required_ruby_version"

  # Run `gh` command from inside project directory
  pushd $1

  # Push branch to GitHub
  git push --set-upstream origin chore/ruby-$required_ruby_version

  # Create PR using GitHub CLI
  echo "Creating PR for $1..."
  gh pr create --title "Upgrade Ruby to $required_ruby_version" --body "Upgrade Ruby from $current_ruby_version to $required_ruby_version - Automated by [Ruby Upgrader](https://github.com/olliebennett/ruby_upgrader/)" --head chore/ruby-$required_ruby_version

  # Return to original directory
  popd
}

prepare_global_ruby_env

for dirname in "$@"
do
  update_ruby $dirname
done
