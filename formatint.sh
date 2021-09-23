#!/bin/bash
cat MushMatch.int.yml <(echo "build: '$1'"; echo "version: '$2'") | mustache MushMatch.int.mo | dos2unix
 