#!/bin/sh

usage() {
  echo "Usage example:"
  echo "$0 1.2.3 ./my_project ./another_project"
  exit 1
}

validate_ruby_project_dir() {
  if [ ! -d "$1" ]; then
    echo "$1 is not a directory!"
    exit 1
  fi

  if [ ! -e "$1/Gemfile" ]; then
    echo "$1 does not contain a Gemfile..."
    exit 1
  fi
}

validate_ruby_version_format() {
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

for dirname in "$@"
do
  echo "Upgrading $dirname project to Ruby version $required_ruby_version..."
done
