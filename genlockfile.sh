#!/bin/sh
builddir="$(mktemp -d)"
BUILD_DIR="$builddir" DIR_DEPS="$builddir"/deps PACKAGE_ROOT=. make generate-deps-lockfile
rm -rf "$builddir"
