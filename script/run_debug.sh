#!/bin/sh

if [ -z "$1" ]; then
    echo "Provide the app path"
    exit
fi

if [ -z "$2" ]; then
    echo "Provide the backend"
    exit
fi

clear;
project="$(dirname "$0")/.."
zig build -Dapp="$1" -Dbackend="$2" run -freference-trace=10
