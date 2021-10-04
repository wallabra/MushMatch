#!/bin/bash

source ./buildconfig.sh

MUSTACHE="${MUSTACHE?-mustache}"

TMP_YML="$(mktemp)"
TMP_INI="$(mktemp)"

cleanup() {
    ( cd "$utdir" && rm -r "$packagefull" )
}

( # Subshell to preserve original working dir
    packagefull="$package"-"$build"
    packagedir="."

    cat "$makeini">"$TMP_INI"
    echo EditPackages="$packagefull">>"$TMP_INI"

    cd "$utdir"

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
            "$MUSTACHE" "$package/Classes/$class" < "$TMP_YML" > "$packagefull/Classes/$class"
        done

        # Build .u
        (
            cd System
            #WINEPREFIX="$wineprefix" wine "$umake" "$package-$build"
            if [[ -f "$packagefull.u" ]]; then rm "$packagefull.u"; fi
            echo "* Invoking ucc make in $(pwd)"
            ( "$ucc" make -NoBind ini="$TMP_INI" || exit 1 ) | tee "$packagedir/make.log"

            # Ensure .u is built
            if [[ ! -f "$packagefull.u" ]]; then
                if [[ -f "$HOME/.utpg/System/$packagefull.u" ]]; then
                    mv "$HOME/.utpg/System/$packagefull.u" .

                else
                    exit 1
                fi
            fi
        ) || exit $?

        # Format .int with Mustache
        echo "Formatting: System/$package.int"
        "$MUSTACHE" "$package/$package.int" < "$TMP_YML" > "System/$packagefull.int"

        # Package up
        cp -f "$package/README.adoc" "Help/$package.adoc"
        tar cf "$packagefull.tar" "System/$packagefull.int" "System/$packagefull.u" "Help/$package.adoc"

        zip -9r "$packagefull.zip" "System/$packagefull.int" "System/$packagefull.u" "Help/$package.adoc" >/dev/null
        gzip --best -k "$packagefull.tar"
        bzip2 --best -k "$packagefull.tar"

        rm "$packagefull.tar"

        # Move to dist
        echo Packaging up...
        mkdir -pv "$dist/$package/$build"
        mv "$packagefull."{tar.*,zip} "$dist/$package/$build"

        # Update Dist/Latest
        mkdir -pv "$dist/$package/Latest"
        rm -f "$dist/$package/Latest/*"
        cp "$dist/$package/$build/"* "$dist/$package/Latest"
    )
    code=$?
    exit $?
)
code=$?

# Finish up

rm "$TMP_YML"
rm "$TMP_INI"
cleanup

exit $code