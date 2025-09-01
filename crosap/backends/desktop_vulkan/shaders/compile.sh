#!/bin/sh

cd "$(dirname "$0")"
glslc -fshader-stage=vertex -O vertex.glsl -o vertex.spv
glslc -fshader-stage=fragment -O fragment.glsl -o fragment.spv
