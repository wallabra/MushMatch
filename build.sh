#!/bin/bash

source ./config.sh

cleanup() {
    rm -rv "MushMatch-$build"
}

( # Subshell to preserve original working dir
    cd ..

    ( # Subshell to exit early on error, to go right into cleanup
        set -e

        mkdir MushMatch-"$build"

        for asset in Classes Models Textures Sounds make.ini; do
            cp -rv MushMatch/"$asset" MushMatch-"$build"
        done

        # Build .u
        WINEPREFIX="$wineprefix" wine "$umake" "MushMatch-$build"

        # Build .int
        pushd MushMatch
        ./formatint.sh "$build" "$version" >"../System/MushMatch-$build.int"
        popd
    )

    # Finish up
    cleanup
)
