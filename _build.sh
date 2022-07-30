#!/bin/bash

source ./buildconfig.sh

MUSTACHE="${MUSTACHE?-mustache}"

TMP_YML="$(mktemp)"
TMP_INI="$(mktemp)"

packagefull="$package"-"$build"
packagedir="."

cleanup() {
    ( cd "$utdir" && rm -r "$packagefull" )
}

( # Subshell to preserve original working dir
    cat "$makeini">"$TMP_INI"
    echo EditPackages="$packagefull">>"$TMP_INI"

    cd "$utdir"

    ( # Subshell to exit early on error, to go right into cleanup
        set -e

        mkdir "$packagefull"

        # Build temporary YAML file
        echo "build: '$build'" > "$TMP_YML"
        echo "name: '$name'" > "$TMP_YML"
        echo "version: '$version'" >> "$TMP_YML"
        echo "package: '$packagefull'" >> "$TMP_YML"
        echo "debug: '$debug'" >> "$TMP_YML"

        if [[ "$debug" == 1 ]]; then
            echo "namesuffix: ' ($build)'" >> "$TMP_YML"
        else
            echo "namesuffix: ''" >> "$TMP_YML"
        fi

        echo >> "$TMP_YML"
        cat "$package/template-options.yml" >> "$TMP_YML"

        # Copy assets
        for asset in Models/ Textures/ Sounds/; do
            if [[ -d "$package"/"$asset" ]]; then
            cp -rv "$package"/"$asset" "$packagefull"
            fi
        done

        # Format classes with Mustache
        mkdir "$packagefull"/Classes

        for class in "$package"/Classes/**; do
            class="$(basename "$class")"
            echo "Formatting: $packagefull/Classes/$class"
            "$MUSTACHE" "$package/Classes/$class" < "$TMP_YML" > "$packagefull/Classes/$class"
        done

        # Include extra assets (map, sound and texture packages)
        # Do this before building because extra packages here may be referenced by the code.
        x_array=()
        
        for x_asset in "Maps" "Sounds" "Textures" "Music"; do
            if [[ -d "Extra/$x_asset" ]]; then
                for fname in Extra/"$x_asset"/*; do
                    if [[ "$fname" == ".gitignore" ]]; then
                        continue
                    fi

                    cp -vf "$fname" "$x_asset"
                    x_array+=("$x_asset/$fname")
                done
            fi
        done

        # Build .u
        (
            cd System
            #WINEPREFIX="$wineprefix" wine "$umake" "$package-$build"
            if [[ -f "$packagefull.u" ]]; then rm "$packagefull.u"; fi
            echo "* Invoking ucc make in $(pwd)"
            "$ucc" make -NoBind ini="$TMP_INI" | tee "$packagedir/make.log"

            # Ensure .u is built
            if [[ ! -f "$packagefull.u" ]]; then
                if [[ -f "$HOME/.utpg/System/$packagefull.u" ]]; then
                    mv "$HOME/.utpg/System/$packagefull.u" .

                else
                    exit 1
                fi
            fi
        )
        code=$?; [[ $code == 0 ]] || exit $code

        pkg_members=("System/$packagefull.u" "${x_array[@]}")

        # Format .int with Mustache
        if [[ "$makeint" == "1" ]]; then
            echo "Formatting: System/$package.int"
            "$MUSTACHE" "$package/template.int" < "$TMP_YML" > "System/$packagefull.int"
            pkg_members+=("System/$packagefull.int")
        fi

        # Include readme inside Help/
        if [[ "$incl_readme" == "1" ]]; then
            cp -f "$package/README.adoc" "Help/$package.adoc"
            pkg_members+=("Help/$package.adoc")
        fi

        # Package up
        tar cf "$packagefull.tar" "${pkg_members[@]}"

        zip -9r "$packagefull.zip" "${pkg_members[@]}" >/dev/null
        gzip --best -k "$packagefull.tar"
        bzip2 --best -k "$packagefull.tar"

        rm "$packagefull.tar"

        # Move to dist
        echo Packaging up...
        mkdir -p "$dist/$package/$build"
        mv "$packagefull."{tar.*,zip} "$dist/$package/$build"

        # Update dist/latest
        echo Organizing dist directory...
        mkdir -p "$dist/$package/latest"
        rm -f "$dist/$package/latest/"*
        cp "$dist/$package/$build/"* "$dist/$package/latest"
    )
    exit $?
)
code=$?

# Finish up

rm "$TMP_YML"
rm "$TMP_INI"

echo
echo Cleaning up...
cleanup

exit $code
