PACKAGE_NAME ?= MushMatch
PACKAGE_ROOT ?= .
MUSHMATCH_BUILD ?= build
DIR_DEPS ?= $(MUSHMATCH_BUILD)/deps
DIR_TARG = $(MUSHMATCH_BUILD)/ut-server
DIR_TARG_PACKAGE = $(DIR_TARG)/$(PACKAGE_NAME)
BUILD_LOG ?= ./build.log
DIR_DIST = $(DIR_TARG)/Dist
CAN_DOWNLOAD ?= 1

CMDS_EXPECTED = curl tar gzip bzip2 zip bash mustache

all: build

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
	echo "   when formatting the .int, as well as the UnrealScript">&2; \
	echo "	 classes to be built, to provide slight environment-awareness..">&2; \
	echo >&2; \
	echo "	 It must be installed via Go, but assuming Go is already installed,">&2; \
	echo "	 install it with the following command:">&2; \
	echo "	 	go install github.com/cbroglie/mustache/...@latest"; \
	echo "----'">&2; \
	exit 2; fi

download:
	mkdir -p "$(DIR_DEPS)" ;\
	echo '=== Downloading UT Linux v436 bare server...' ;\
	curl 'http://ut-files.com/index.php?dir=Entire_Server_Download/&file=ut-server-linux-436.tar.gz' -LC- -o"$(DIR_DEPS)/ut-server-linux-436.tar.gz" ;\
	echo '=== Downloading UT Linux v469 patch...' ;\
	curl 'https://github.com/OldUnreal/UnrealTournamentPatches/releases/download/v469b/OldUnreal-UTPatch469b-Linux.tar.bz2' -LC- -o"$(DIR_DEPS)/OldUnreal-UTPatch469b-Linux.tar.bz2" ;\
	echo Done. ;\

cannot-download:
	echo "----.">&2; \
	echo "    Building this mod requires downloading some files that are">&2; \
	echo "    used to setup a build environment. Those files can be downloaded">&2; \
	echo "    automatically, but CAN_DOWNLOAD is set to 0, which is useful for">&2; \
	echo "    build environments that are restrained of network availability for">&2; \
	echo "    security (such as NixOS), but requires those files to be downloaded or.">&2; \
	echo "    copied beforehand, either manually or via 'make download'">&2; \
	echo >&2; \
	echo "    Either set CAN_DOWNLOAD to 1 so they may be downloaded automatically, or">&2; \
	echo "    run 'make download'.">&2; \
	echo >&2; \
	echo "    More specifically, 'make download' places the following two remote files">&2; \
	echo "    inside build/dist without renaming from their remote names:">&2; \
	echo "        http://ut-files.com/index.php?dir=Entire_Server_Download/&file=ut-server-linux-436.tar.gz">&2; \
	echo "        https://github.com/OldUnreal/UnrealTournamentPatches/releases/download/v469b/OldUnreal-UTPatch469b-Linux.tar.bz2">&2; \
	echo >&2; \
	echo "    If you insist on a manual download, download them like so. If done properly,">&2; \
	echo "	  Make should be able to find them and deem an auto-download unnecessary anyway.">&2; \
	echo >&2; \
	echo "----'">&2; \
	exit 1

auto-download: $(if $(filter 1 true,$(CAN_DOWNLOAD)), download, cannot-download)

#-- Entrypoint rules

$(DIR_DEPS)/ut-server-linux-436.tar.gz $(DIR_DEPS)/OldUnreal-UTPatch469b-Linux.tar.bz2: auto-download

configure: $(DIR_DEPS)/ut-server-linux-436.tar.gz $(DIR_DEPS)/OldUnreal-UTPatch469b-Linux.tar.bz2 expect-cmd-tar expect-cmd-gunzip expect-cmd-bunzip2
	mkdir -p "$(DIR_DEPS)" ;\
	echo '=== Extracting and setting up...' ;\
	tar xzf "$(DIR_DEPS)/ut-server-linux-436.tar.gz" -C "$(MUSHMATCH_BUILD)" ;\
	tar xjpf "$(DIR_DEPS)/OldUnreal-UTPatch469b-Linux.tar.bz2" --overwrite -C "$(DIR_TARG)" ;\
	ln -s "../../$(PACKAGE_ROOT)" "$(DIR_TARG)/$(PACKAGE_NAME)" ;\
	echo Done.

$(DIR_TARG_PACKAGE)/_build.sh: configure

build: $(DIR_TARG_PACKAGE)/_build.sh expect-cmd-tar expect-cmd-gzip expect-cmd-bzip2 expect-cmd-zip expect-cmd-bash expect-mustache
	echo '=== Starting build!' ;\
	pushd "$(DIR_TARG)"/"$(PACKAGE_NAME)" >/dev/null ;\
	if bash ./_build.sh 2>&1 | tee $(BUILD_LOG); then\
		echo "Build finished: see $(DIR_DIST)" 2>&1 ;\
	else\
		echo "Build errored: see $(BUILD_LOG)" 2>&1 ;\
	fi;\
	popd >/dev/null

clean-downloads:
	rm deps/*

clean-tree:
	rm -rv ut-server

clean: clean-downloads clean-tree

.PHONY: download configure build expect-cmd-% expect-mustache clean clean-downloads clean-tree \
		.ut-server-linux-436.tar.gz .OldUnreal-UTPatch469b-Linux.tar.bz2
.SILENT:
