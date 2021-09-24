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

        # Package up
        tar cvf "MushMatch-$build.tar" "System/MushMatch-$build.int" "System/MushMatch-$build.u" Help/MushMatch.adoc

        sem -j4 --id=mushmatch-pkg -- zip -9vr "MushMatch-$build.zip" "System/MushMatch-$build.int" "System/MushMatch-$build.u" Help/MushMatch.adoc
        sem -j4 --id=mushmatch-pkg -- zstd -19 -T0 -v "MushMatch-$build.tar" -o "MushMatch-$build.tar.zst"
        sem -j4 --id=mushmatch-pkg -- gzip --best -k "MushMatch-$build.tar"
        sem -j4 --id=mushmatch-pkg -- bzip2 --best -k "MushMatch-$build.tar"
        sem -j4 --id=mushmatch-pkg -- xz -9 --extreme -k "MushMatch-$build.tar"
        sem --id=mushmatch-pkg --wait

        rm "MushMatch-$build.tar"

        mkdir -pv $dist/MushMatch/$build
        mv MushMatch-$build.{tar.*,zip} $dist/MushMatch/$build
    )

    # Finish up
    cleanup
)
