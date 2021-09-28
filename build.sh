#!/bin/bash

source ./config.sh

cleanup() {
    rm -rv "MushMatch-$build"
}

( # Subshell to preserve original working dir
    cd ..

    TMP_YML="$(mktemp)"

    ( # Subshell to exit early on error, to go right into cleanup
        set -e

        mkdir MushMatch-"$build"

        # Build temporary YAML file
        echo "build: '$build'" > "$TMP_YML"
        echo "version: '$version'" >> "$TMP_YML"
        echo >> "$TMP_YML"
        cat "MushMatch/MushMatch.yml" >> "$TMP_YML"

        # Copy assets
        for asset in Models Textures Sounds make.ini; do
            cp -rv MushMatch/"$asset" MushMatch-"$build"
        done

        # Format classes with Mustache
        mkdir MushMatch-"$build"/Classes

        for class in MushMatch/Classes/*; do
            class="$(basename "$class")"
            echo "Formatting: MushMatch-$build/Classes/$class"
            mustache "MushMatch/Classes/$class" < "$TMP_YML" > "MushMatch-$build/Classes/$class"
        done

        sem --id="formatint" --wait

        # Build .u
        WINEPREFIX="$wineprefix" wine "$umake" "MushMatch-$build"

        # Format .int with Mustache
        mustache MushMatch/MushMatch.int.mo < "$TMP_YML" | dos2unix > "System/MushMatch-$build.int"

        # Package up
        tar cvf "MushMatch-$build.tar" "System/MushMatch-$build.int" "System/MushMatch-$build.u" Help/MushMatch.adoc

        sem -j4 --id=mushmatch-pkg -- zip -9vr "MushMatch-$build.zip" "System/MushMatch-$build.int" "System/MushMatch-$build.u" Help/MushMatch.adoc
        sem -j4 --id=mushmatch-pkg -- zstd -19 -T0 -v "MushMatch-$build.tar" -o "MushMatch-$build.tar.zst"
        sem -j4 --id=mushmatch-pkg -- gzip --best -k "MushMatch-$build.tar"
        sem -j4 --id=mushmatch-pkg -- bzip2 --best -k "MushMatch-$build.tar"
        sem -j4 --id=mushmatch-pkg -- xz -9 --extreme -k "MushMatch-$build.tar"
        sem --id=mushmatch-pkg --wait

        rm "MushMatch-$build.tar"

        # Move to Dist
        mkdir -pv "$dist/MushMatch/$build"
        mv "MushMatch-$build."{tar.*,zip} "$dist/MushMatch/$build"
    )

    # Finish up
    rm "$TMP_YML"
    cleanup
)
