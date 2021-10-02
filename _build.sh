#!/bin/bash

source ./buildconfig.sh

cleanup() {
    pushd "$utdir">/dev/null
    rm -r "$packagefull"
    popd>/dev/null
}

( # Subshell to preserve original working dir
    packagefull="$package"-"$build"
    packagedir="."

    TMPINI="$(mktemp)"
    cat "$makeini">"$TMPINI"
    echo EditPackages="$packagefull">>"$TMPINI"

    pushd "$utdir">/dev/null

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

        # Build .u
        pushd System>/dev/null
        #WINEPREFIX="$wineprefix" wine "$umake" "$package-$build"
        if [[ -f "$packagefull.u" ]]; then rm "$packagefull.u"; fi
        echo "* Invoking ucc make in $(pwd)"
        "$ucc" make -NoBind ini="$TMPINI" | tee "$packagedir/make.log"

        # Ensure .u is built
        if [[ ! -f "$packagefull.u" ]]; then
            if [[ -f "$HOME/.utpg/System/$packagefull.u" ]]; then
                mv "$HOME/.utpg/System/$packagefull.u" .

            else
                popd>/dev/null
                exit 1
            fi
        fi
        
        popd>/dev/null

        # Format .int with Mustache
        echo "Formatting: System/$package.int"
        mustache "$package/$package.int" < "$TMP_YML" > "System/$packagefull.int"

        # Package up
        cp -f "$package/README.adoc" "Help/$package.adoc"
        tar cf "$packagefull.tar" "System/$packagefull.int" "System/$packagefull.u" "Help/$package.adoc"

        zip -9r "$packagefull.zip" "System/$packagefull.int" "System/$packagefull.u" "Help/$package.adoc" >/dev/null
        gzip --best -k "$packagefull.tar"
        bzip2 --best -k "$packagefull.tar"

        rm "$packagefull.tar"

        # Move to Dist
        echo Packaging up...
        mkdir -pv "$dist/$package/$build"
        mv "$packagefull."{tar.*,zip} "$dist/$package/$build"

        # Update Dist/Latest
        mkdir -pv "$dist/$package/Latest"
        rm -f "$dist/$package/Latest/*"
        cp "$dist/$package/$build/"* "$dist/$package/Latest"
    )

    # Finish up
    popd>/dev/null

    rm "$TMP_YML"
    cleanup
)
