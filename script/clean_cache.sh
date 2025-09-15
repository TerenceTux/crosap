#!/bin/sh

project="$(dirname "$0")/.."

find "$project" -type d -name ".zig-cache" -exec rm -r {} +
find "$project" -type d -name "zig-out" -exec rm -r {} +
rm -rf "~/.cache/zig"
