PACKAGE_NAME ?= MushMatch

PACKAGE_ROOT ?= .
BUILD_DIR ?= build
DIR_DEPS ?= $(BUILD_DIR)/deps
DIR_TARG = $(BUILD_DIR)/ut-server
DIR_TARG_PACKAGE = $(DIR_TARG)/$(PACKAGE_NAME)
BUILD_LOG ?= ./build.log
MUSTACHE ?= mustache
MUSTACHE_VER ?= 1.3.0
DIR_DIST = $(BUILD_DIR)/dist
CAN_DOWNLOAD ?= 1
DESTDIR ?= ..
SHELL = bash

CMDS_EXPECTED = curl tar gzip bzip2 zip bash

BUILD_NUM := $(shell source ./buildconfig.sh; echo $$build)

all: build

expect-cmd-%:
	if ! which "${*}" 2>&1 >/dev/null; then \
	echo "----.">&2; \
	echo "   Command '${*}' not found! It is required for build!">&2; \
	echo >&2; \
	echo "   Please install it, with your system's package manager or">&2; \
	echo "   some other build dependency install method.">&2; \
	echo >&2; \
	echo "   Here is a list of commands expected: $(CMDS_EXPECTED)">&2; \
	echo "----'">&2; \
	exit 2; fi

find-mustache: | expect-cmd-curl expect-cmd-tar expect-cmd-gunzip expect-cmd-realpath
	$(eval MUSTACHE_BIN=$(shell if [ -f "$(MUSTACHE)" ]; then \
	  echo "$(MUSTACHE)" ;\
	elif which "$(MUSTACHE)" >/dev/null 2>/dev/null ; then \
	  which $(MUSTACHE) ;\
	else \
	  echo "* Mustache not installed; setting up automatically" >&2 ;\
	  if [ -f $(DIR_DEPS)/mustache ] ; then \
	    echo '* Already downloaded Mustache; using that' >&2 ;\
	  else \
	    echo '=== Downloading mustache ${MUSTACHE_VER} to $(DIR_DEPS)/mustache_${MUSTACHE_VER}_linux_amd64.tar.gz...'>&2 ;\
		mkdir -p "$(DIR_DEPS)" ;\
		curl 'https://github.com/cbroglie/mustache/releases/download/v${MUSTACHE_VER}/mustache_${MUSTACHE_VER}_linux_amd64.tar.gz' -LC- -o"$(DIR_DEPS)/mustache_${MUSTACHE_VER}_linux_amd64.tar.gz" ;\
		echo '=== Extracting mustache...'>&2 ;\
	    tar xzf "$(DIR_DEPS)/mustache_${MUSTACHE_VER}_linux_amd64.tar.gz" -C "$(DIR_DEPS)" mustache >&2 ;\
	  fi ;\
	  realpath "${DIR_DEPS}/mustache" ;\
	fi))

$(DIR_DEPS)/ut-server-linux-436.tar.gz: | expect-cmd-curl
	mkdir -p "$(DIR_DEPS)" ;\
	echo '=== Downloading UT Linux v436 bare server...' ;\
	curl 'http://ut-files.com/index.php?dir=Entire_Server_Download/&file=ut-server-linux-436.tar.gz' -LC- -o"$(DIR_DEPS)/ut-server-linux-436.tar.gz"
	
$(DIR_DEPS)/OldUnreal-UTPatch469d-Linux.tar.bz2: | expect-cmd-curl
	mkdir -p "$(DIR_DEPS)" ;\
	echo '=== Downloading UT Linux v469 patch...' ;\
	curl 'https://github.com/OldUnreal/UnrealTournamentPatches/releases/download/v469d/OldUnreal-UTPatch469d-Linux.tar.bz2' -LC- -o"$(DIR_DEPS)/OldUnreal-UTPatch469d-Linux.tar.bz2"

cannot-download:
ifeq ($(filter 1 true,$(CAN_DOWNLOAD)),)
ifneq ($(wildcard $(DIR_DEPS)/OldUnreal-UTPatch469d-Linux.tar.bz2)_$(wildcard $(DIR_DEPS)/ut-server-linux-436.tar.gz),$(DIR_DEPS)/OldUnreal-UTPatch469d-Linux.tar.bz2_$(DIR_DEPS)/ut-server-linux-436.tar.gz)
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
	echo "        https://github.com/OldUnreal/UnrealTournamentPatches/releases/download/v469d/OldUnreal-UTPatch469d-Linux.tar.bz2">&2; \
	echo >&2; \
	echo "    If you insist on a manual download, download them like so. If done properly,">&2; \
	echo "	  Make should be able to find them and deem an auto-download unnecessary anyway.">&2; \
	echo >&2; \
	echo "----'">&2; \
	exit 1
else
endif
else
endif

auto-download: $(if $(filter 1 true,$(CAN_DOWNLOAD)), $(DIR_DEPS)/ut-server-linux-436.tar.gz $(DIR_DEPS)/OldUnreal-UTPatch469d-Linux.tar.bz2 find-mustache, cannot-download)

generate-deps-lockfile: | auto-download
	echo '=== Generating lockfile of downloaded dependencies...' ;\
	sha512sum "$(DIR_DEPS)/"* >"$(PACKAGE_ROOT)"/deps.lock ;\
	echo Done.

$(DIR_TARG)/System/ucc-bin: | generate-deps-lockfile expect-cmd-tar expect-cmd-gunzip expect-cmd-bunzip2
	echo '=== Extracting and setting up...' ;\
	[[ -d "$(DIR_TARG)" ]] && rm -rv "$(DIR_TARG)" ;\
	mkdir -p "$(DIR_TARG)" ;\
	tar xzmvf "$(DIR_DEPS)/ut-server-linux-436.tar.gz" --overwrite -C "$(BUILD_DIR)" ;\
	tar xjpmvf "$(DIR_DEPS)/OldUnreal-UTPatch469d-Linux.tar.bz2" --overwrite -C "$(DIR_TARG)" ;\
	ln -sf -T "$(shell realpath $(PACKAGE_ROOT))" "$(DIR_TARG)/$(PACKAGE_NAME)" ;\
	echo Done.

$(DIR_DIST)/$(PACKAGE_NAME)/$(BUILD_NUM)/$(PACKAGE_NAME)-$(BUILD_NUM).zip: $(DIR_TARG)/System/ucc-bin Classes/*.uc template.int template-options.yml buildconfig.sh | expect-cmd-tar expect-cmd-gzip expect-cmd-bzip2 expect-cmd-zip expect-cmd-bash
	echo '=== Starting build!' ;\
	[[ -d "$(DIR_TARG)"/"$(PACKAGE_NAME)" ]] || ln -sv \
			"$$(realpath "$(PACKAGE_ROOT)")" \
			"$(DIR_TARG)"/"$(PACKAGE_NAME)" ;\
	cd "$(DIR_TARG)"/"$(PACKAGE_NAME)" >/dev/null ;\
	if MUSTACHE="$(MUSTACHE_BIN)" bash ./_build.sh 2>&1; then\
		echo "Build finished: see $(DIR_DIST)/$(PACKAGE_NAME)/latest" 2>&1 ; exit 0 ;\
	else\
		echo "Build errored: see $(BUILD_LOG)" 2>&1 ; exit 1 ;\
	fi

$(DESTDIR)/System/$(PACKAGE_NAME)-$(BUILD_NUM).u: $(DIR_DIST)/$(PACKAGE_NAME)/$(BUILD_NUM)/$(PACKAGE_NAME)-$(BUILD_NUM).zip | expect-cmd-unzip
	echo '=== Installing to Unreal Tournament at $(shell realpath "$(DESTDIR)")' ;\
	unzip "$(DIR_DIST)/$(PACKAGE_NAME)/$(BUILD_NUM)/$(PACKAGE_NAME)-$(BUILD_NUM).zip" -d "$(DESTDIR)" &&\
	echo Done.

#-- Entrypoint rules

download: $(DIR_DEPS)/ut-server-linux-436.tar.gz $(DIR_DEPS)/OldUnreal-UTPatch469d-Linux.tar.bz2 find-mustache

configure: $(DIR_TARG)/System/ucc-bin

build: find-mustache $(DIR_DIST)/$(PACKAGE_NAME)/$(BUILD_NUM)/$(PACKAGE_NAME)-$(BUILD_NUM).zip

install: $(DESTDIR)/System/$(PACKAGE_NAME)-$(BUILD_NUM).u

clean-downloads:
	rm $(DIR_DEPS)/*

clean-tree:
	rm -rv $(DIR_TARG)

clean: clean-downloads clean-tree

genlock: generate-deps-lockfile

.PHONY: configure build download install auto-download cannot-download expect-cmd-% clean clean-downloads clean-tree
.SILENT:
