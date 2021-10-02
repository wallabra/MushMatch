#!/bin/sh
export PATH="$HOME/go/bin:$PATH"
cd /opt/ut-server/MushMatch && ( ( git checkout docker && git pull ); ./build.sh )
