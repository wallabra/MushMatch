#!/bin/bash

source ./config.sh

cleanup() {
    pushd "$utdir"
    rm -rv "$packagefull"
    popd
}

( # Subshell to preserve original working dir
    packagefull="$package"-"$build"
    packagedir="$(realpath .)"

    utdir="$(realpath "$utdir")"
    TMPINI="$(mktemp)"
    cat "$makeini">"$TMPINI"
    echo EditPackages="$packagefull">>"$TMPINI"

    pushd "$utdir"

    TMP_YML="$(mktemp)"

    ( # Subshell to exit early on error, to go right into cleanup
        set -e

        mkdir "$packagefull"

        # Build temporary YAML file
        echo "build: '$build'" > "$TMP_YML"
        echo "version: '$version'" >> "$TMP_YML"
        echo "package: '$packagefull'" >> "$TMP_YML"

        if [[ "$debug" == 1 ]]; then
            echo "namesuffix: ' ($build)'" >> "$TMP_YML"
        else
            echo "namesuffix: ''" >> "$TMP_YML"
        fi

        echo >> "$TMP_YML"
        cat "$package/$package.yml" >> "$TMP_YML"

        # Copy assets
        for asset in Models Textures Sounds make.ini; do
            cp -rv "$package"/"$asset" "$packagefull"
        done

        # Format classes with Mustache
        mkdir "$packagefull"/Classes

        for class in "$package"/Classes/*; do
            class="$(basename "$class")"
            echo "Formatting: $packagefull/Classes/$class"
            mustache "$package/Classes/$class" < "$TMP_YML" > "$packagefull/Classes/$class"
        done

        sem --id="formatint" --wait

        # Build .u
        pushd System
        #WINEPREFIX="$wineprefix" wine "$umake" "$package-$build"
        if [[ -f "$packagefull.u" ]]; then rm "$packagefull.u"; fi
        "$ucc" make ini="$TMPINI" | tee "$packagedir/make.log"

        # Ensure .u is built
        if [[ ! -f "$packagefull.u" ]]; then
            if [[ -f "$HOME/.utpg/System/$packagefull.u" ]]; then
                mv "$HOME/.utpg/System/$packagefull.u" .

            else
                popd
                exit 1
            fi
        fi
        
        popd

        # Format .int with Mustache
        echo "Formatting: System/$package.int"
        mustache "$package/$package.int" < "$TMP_YML" > "System/$packagefull.int"

        # Package up
        cp -f "$package/README.adoc" "Help/$package.adoc"
        tar cvf "$packagefull.tar" "System/$packagefull.int" "System/$packagefull.u" "Help/$package.adoc"

        sem -j4 --id=mushmatch-pkg -- zip -9vr "$packagefull.zip" "System/$packagefull.int" "System/$packagefull.u" "Help/$package.adoc"
        sem -j4 --id=mushmatch-pkg -- zstd -19 -T0 -v "$packagefull.tar" -o "$packagefull.tar.zst"
        sem -j4 --id=mushmatch-pkg -- gzip --best -k "$packagefull.tar"
        sem -j4 --id=mushmatch-pkg -- bzip2 --best -k "$packagefull.tar"
        sem -j4 --id=mushmatch-pkg -- xz -9 --extreme -k "$packagefull.tar"
        sem --id=mushmatch-pkg --wait

        rm "$packagefull.tar"

        # Move to Dist
        dist="$(realpath "$utdir/$dist")"
        mkdir -pv "$dist/$package/$build"
        mv "$packagefull."{tar.*,zip} "$dist/$package/$build"

        # Update Dist/Latest
        mkdir -p "$dist/$package/Latest"
        rm -f "$dist/$package/Latest/*"
        cp "$dist/$package/$build/*" "$dist/$package/Latest"
    )

    # Finish up
    popd

    rm "$TMP_YML"
    cleanup
)
