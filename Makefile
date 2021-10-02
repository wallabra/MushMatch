
MUSHMATCH_ROOT ?= .
DIR_BUILD ?= build
DIR_DEPS ?= $(DIR_BUILD)/deps
DIR_TARG ?= $(DIR_BUILD)/ut-server
CURLFLAGS ?=

CMDS_EXPECTED = curl tar gzip bzip2 zip mustache

expect-cmd-%:
	if ! which "${*}" >/dev/null; then \
	echo "----.">&2; \
	echo "   Command '${*}' not found! It is required for build!">&2; \
	echo >&2; \
	echo "   Please install it, with your system's package manager or">&2; \
	echo "   some other build dependency install method.">&2; \
	echo >&2; \
	echo "   Here is a list of commands expected: $(CMDS_EXPECTED)">&2; \
	echo "   • Note. mustache has to be installed via Go: https://github.com/cbroglie/mustache"; \
	echo "----'">&2; \
	exit 2; fi

expect-mustache:
	if ! which "mustache" >/dev/null; then \
	echo "----.">&2; \
	echo "   Command 'mustache' not found! It is required for build!">&2; \
	echo >&2; \
	echo "   mustache is a formatting tool used by the build process">&2; \
	echo "   when formatting MushMatch-*.int, as well as the UnrealScript">&2; \
	echo "	 classes to be built, to provide slight environment-awareness..">&2; \
	echo >&2; \
	echo "	 It must be installed via Go, but assuming Go is already installed,">&2; \
	echo "	 install it with the following command:">&2; \
	echo "	 	go install github.com/cbroglie/mustache/...@latest"; \
	echo "----'">&2; \
	exit 2; fi

deps/ut-server-linux-436.tar.gz: expect-cmd-curl
	pushd "$(DIR_BUILD)" >/dev/null
	echo '=== Downloading UT Linux v436 bare server...'
	curl 'http://ut-files.com/index.php?dir=Entire_Server_Download/&file=ut-server-linux-436.tar.gz' -LC- -o'deps/ut-server-linux-436.tar.gz'
	popd >/dev/null

deps/OldUnreal-UTPatch469b-Linux.tar.bz2: expect-cmd-curl
	pushd "$(DIR_BUILD)" >/dev/null
	echo '=== Downloading UT Linux v469 patch...'
	curl 'https://github.com/OldUnreal/UnrealTournamentPatches/releases/download/v469b/OldUnreal-UTPatch469b-Linux.tar.bz2' -LC- -o'deps/OldUnreal-UTPatch469b-Linux.tar.bz2' "$(CURLFLAGS)"
	popd >/dev/null

#-- Entrypoint rules

download: deps/ut-server-linux-436.tar.gz deps/OldUnreal-UTPatch469b-Linux.tar.bz2

configure: download deps/ut-server-linux-436.tar.gz deps/OldUnreal-UTPatch469b-Linux.tar.bz2 expect-cmd-tar expect-cmd-gunzip expect-cmd-bunzip2
	pushd "$(DIR_BUILD)" >/dev/null
	echo '=== Extracting and setting up...'
	tar -xzf "$(DIR_DEPS)/ut-server-linux-436.tar.gz"-C "$(DIR_BUILD)"
	tar -xjpf "$(DIR_DEPS)/OldUnreal-UTPatch469b-Linux.tar.bz2" -C "$(DIR_TARG)"
	ln -sv "../../$(MUSHMATCH_ROOT)" "$(DIR_TARG)/MushMatch"
	popd >/dev/null

build: configure ut-server/System/ucc-bin ut-server/System/UnrealTournament.ini expect-cmd-tar expect-cmd-gzip expect-cmd-bzip2 expect-cmd-zip expect-mustache
	pushd "$(DIR_TARG)"/MushMatch >/dev/null; ./_build.sh; popd >/dev/null

clean-downloads:
	rm deps/*

clean-tree:
	rm -rv ut-server

clean: clean-downloads clean-tree


.PHONY: download configure build expect-cmd-% expect-mustache clean clean-downloads clean-tree
.SILENT:
