#!/bin/sh
## author: A. Camilleri - EDRLab/Readium
## description: This script will generate the public API documentation of the
## R2Streamer XCode project.

echo "[This script will generate the public API documentation for the Streamer project.]"

# 1 - Check jazzy installation. (https://github.com/realm/jazzy for infos).

command -v jazzy >/dev/null 2>&1 || { echo >&2 "Jazzy is required to generate the documentation. \nInstall it using `gem install Jazzy`."; exit 1; }
echo "Jazzy found, starting doc generation."

# 2 - Generate documentation using Jazzy.

jazzy \
  --clean \
  --author Readium \
  --author_url http://readium.github.io/ \
  --github_url https://github.com/readium/r2-streamer-swift \
  --xcodebuild-arguments -scheme,R2Streamer \
  --min-acl public \
  --module R2Streamer
