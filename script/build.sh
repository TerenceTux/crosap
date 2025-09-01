#!/bin/sh

if [ -z "$1" ]; then
    echo "Provide the app path"
    exit
fi

if [ -z "$2" ]; then
    echo "Provide the backend"
    exit
fi

target="$3"
if [ -z "$3" ]; then
    target="native"
fi

project="$(dirname "$0")/.."
"$project/zig/master/files/zig" build -Dapp="$1" -Dbackend="$2" -Dtarget="$target" -Doptimize=ReleaseFast -freference-trace=10
