# Cut down from Matrix Time's: one edition (Lite, manifest.xml), so no EDITION, no
# stamp and no beta id (#1).
# CIQ_HOME and SDK_BIN are macOS defaults read from the SDK manager's own pointer; on
# another platform, or for a pinned SDK, pass SDK_BIN=/path/to/sdk/bin.
## The SDK manager's directory: SDK_BIN's default, and the devices sideload knows
CIQ_HOME ?= $(HOME)/Library/Application Support/Garmin/ConnectIQ
## The Connect IQ SDK's bin directory, for every target that runs the SDK locally
SDK_BIN  ?= $(shell sed -e 's:/*$$::' "$(CIQ_HOME)/current-sdk.cfg" 2>/dev/null)/bin
## The developer key every local build signs with
DEV_KEY  ?= ../garmin-keys/developer_key
## The product to build for, one of manifest.xml's
DEVICE   ?= epix2pro47mm
## The port the simulator listens on
SIM_PORT ?= 1234
APP      := ClimberTime
MANIFEST := manifest.xml
OUTPUT   := $(APP).prg
# Held in a variable so that make -n does not run the sub-make (playbook, testing.md).
SUBMAKE  := $(MAKE)

# make sideload does not give up on a watch that is slow to show up. A watch just
# plugged in or restarted can take tens of seconds to offer MTP: it may be absent from
# the bus, or present as Garmin 091e:0003 rather than its MTP id, and the first MTP
# access right after it appears can fail ("Could not read GarminDevice.xml").
#   WAIT, EVERY     wait up to WAIT seconds for a watch to appear, looking every EVERY
#                   seconds (tools/sideload.sh wait; WAIT=0 does not wait)
#   TRIES, BACKOFF  attempts at each of detect and install, BACKOFF seconds before the
#                   second, doubling after each failure (5+10+20+40+80 s by default)
## Seconds sideload waits for a watch to appear
WAIT    ?= 300
## Seconds between sideload's looks for a watch
EVERY   ?= 5
## Attempts at detecting the watch, and at installing
TRIES   ?= 6
## Seconds before the second attempt, doubled each time
BACKOFF ?= 5
## The Chrome make golden runs headless to compute the simulator's values
CHROME  ?= /Applications/Google Chrome.app/Contents/MacOS/Google Chrome

# The store bundle export writes, named by manifest.xml's version
# (wkusnierczyk/garmin-matrix-time#216):
# export/ClimberTime-0.1.0.iq. Only MAJOR.MINOR.PATCH from exactly one <iq:application>
# start tag is taken, so the name never splits in the shell; anything else reads as no
# version, which export refuses. override, so the manifest stays the one record of it.
override APP_VERSION = $(shell tr '\n\r\t' '   ' < "$(MANIFEST)" \
  | grep -oE '<iq:application[[:space:]][^>]*>' \
  | awk '{ tag = $$0 } END { if (NR == 1) print tag }' \
  | sed -nE 's/.*[[:space:]]version="((0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*))".*/\1/p')
EXPORT_DIR := export
EXPORT = $(EXPORT_DIR)/$(APP)-$(APP_VERSION).iq
# monkeyc names the .prg files inside a bundle after the bundle, so it is built as
# <app>.iq here and renamed after, keeping the inner names <app>.prg
# (wkusnierczyk/garmin-matrix-time#221).
EXPORT_STAGE = $(EXPORT_DIR)/.stage/$(APP)

MONKEYC   = "$(SDK_BIN)/monkeyc"
MONKEYDO  = "$(SDK_BIN)/monkeydo"
CONNECTIQ = "$(SDK_BIN)/connectiq"

# Fail with a readable message rather than "No such file or directory". Checked in the
# recipes, so clean, help and check-help work on a machine without an SDK.
define require_sdk
@test -x "$(SDK_BIN)/monkeyc" || { \
  echo "Connect IQ SDK not found at \"$(SDK_BIN)\"."; \
  echo "Open the SDK manager and select an SDK, or override:"; \
  echo "  make $@ SDK_BIN=/path/to/sdk/bin"; \
  exit 1; }
endef

# -w: warn, -y: private key, -d: device, -f: jungle file, -o: output. export packages
# every product in the manifest (-e, no -d) and strips debug information (-r).
BUILD_FLAGS  := -w -y "$(DEV_KEY)" -d $(DEVICE) -f monkey.jungle
TEST_FLAGS   := $(BUILD_FLAGS) --unit-test
EXPORT_FLAGS := -e -r -w -y "$(DEV_KEY)" -f monkey.jungle

.PHONY: all build sim run test golden sideload export fonts check-fonts check-ttf2bmp install-ttf2bmp \
  check-garmin-font-scaler install-garmin-font-scaler check-garmin-graphics-generator \
  install-garmin-graphics-generator graphics preview icons check-icons clean help check-help

## The default: build [DEVICE DEV_KEY]
all: build

## Build the .prg for DEVICE [DEVICE DEV_KEY]
build:
	$(require_sdk)
	@echo "Building for $(DEVICE)..."
	@$(MONKEYC) $(BUILD_FLAGS) -o $(OUTPUT)
	@echo "Build complete: $(OUTPUT)"

## Start the simulator unless it is running [SIM_PORT]
sim:
	$(require_sdk)
	@if nc -z 127.0.0.1 $(SIM_PORT) 2>/dev/null; then echo "Simulator already running."; else \
	  test -x $(CONNECTIQ) || { echo "Simulator launcher not found at $(CONNECTIQ)."; exit 1; }; \
	  $(CONNECTIQ) & n=0; until nc -z 127.0.0.1 $(SIM_PORT) 2>/dev/null; do \
	    n=$$((n+1)); test $$n -lt 60 || { echo "Simulator did not start."; exit 1; }; sleep 1; done; \
	  echo "Simulator ready."; fi

## Build and load into the simulator (stays attached; Ctrl-C to stop) [DEVICE DEV_KEY SIM_PORT]
run: build sim
	@$(MONKEYDO) $(OUTPUT) $(DEVICE)

# monkeydo exits 1 whether the suite passes or fails (SDK 9.2.0), so its status carries
# nothing: the summary line in the first column, "PASSED (passed=N, ...)", is the signal
# (wkusnierczyk/garmin-matrix-time#23). The output is printed rather than piped into grep, which would hide
# a real failure behind grep's bare "Error 1". With no (:test) functions monkeydo prints
# nothing at all (SDK 9.3.0), which fails too: an empty run is not a passing one. The
# simulator is started after the test build, through SUBMAKE, so that a build that fails
# does not open it, and make -n stays dry. printf, since sh's echo reads backslashes.
## Run the (:test) functions in the simulator [DEVICE DEV_KEY SIM_PORT]
test:
	$(require_sdk)
	@echo "Running unit tests..."
	@$(MONKEYC) $(TEST_FLAGS) -o test_build.prg
	@$(SUBMAKE) --no-print-directory sim
	@output=$$($(MONKEYDO) test_build.prg $(DEVICE) -t 2>&1); \
	  test -n "$$output" || { \
	    echo "No tests ran: the build has no (:test) functions, or the simulator did not answer."; exit 1; }; \
	  printf '%s\n' "$$output"; \
	  printf '%s\n' "$$output" | grep -qE '^PASSED \(' || { echo "Unit tests did not report PASSED."; exit 1; }

# The tests compare the watch with the browser simulator (design/), never with the watch's
# own output: this recomputes source/tests/ClimbGolden.mc from the simulator in headless Chrome.
## Regenerate the tests' golden values from the browser simulator [CHROME]
golden:
	@python3 tools/make-golden.py "$(CHROME)"

## Build for the connected watch and copy it over USB, retrying with backoff (MTP; brew install libmtp) [DEV_KEY WAIT EVERY TRIES BACKOFF CIQ_HOME]
sideload:
	$(require_sdk)
	@tools/sideload.sh wait "$(WAIT)" "$(EVERY)" || exit 1
	@n=1; gap=$(BACKOFF); \
	until watch=$$(CIQ_HOME="$(CIQ_HOME)" tools/sideload.sh detect); do \
	  test $$n -lt $(TRIES) || { echo "The watch did not answer after $(TRIES) attempts."; exit 1; }; \
	  echo "Detect attempt $$n of $(TRIES) failed; trying again in $${gap}s."; \
	  sleep $$gap; n=$$((n+1)); gap=$$((gap*2)); \
	done; \
	echo "Watch detected: $$watch"; \
	grep -q '<iq:product id="'"$$watch"'"/>' $(MANIFEST) || { echo "$(MANIFEST) does not list $$watch."; exit 1; }; \
	$(SUBMAKE) --no-print-directory build DEVICE=$$watch || exit 1; \
	n=1; gap=$(BACKOFF); \
	until tools/sideload.sh install $(OUTPUT); do \
	  test $$n -lt $(TRIES) || { echo "Install failed after $(TRIES) attempts."; exit 1; }; \
	  echo "Install attempt $$n of $(TRIES) failed; trying again in $${gap}s."; \
	  sleep $$gap; n=$$((n+1)); gap=$$((gap*2)); \
	done

# "export" with a colon is an ordinary rule, not GNU make's directive, since 3.81.
# monkeyc's progress lines, "<n> OUT OF <total> DEVICES BUILT", are padded so the column
# stands still. Its exit status crosses the pipe as a sentinel awk exits with (pipefail
# is not portable), matched anywhere in a line, since monkeyc's last line may lack a
# newline; stderr stays out of the pipe; awk flushes per line.
EXPORT_STATUS := __monkeyc_status__:

## Build the signed .iq store bundle [DEV_KEY]
export:
	@test -n "$(APP_VERSION)" || { echo "No MAJOR.MINOR.PATCH application version found in $(MANIFEST)."; exit 1; }
	@rm -f $(EXPORT)
	$(require_sdk)
	@echo "Exporting $(EXPORT) for every product in $(MANIFEST)..."
	@rm -rf "$(EXPORT_STAGE)" && mkdir -p "$(EXPORT_STAGE)"
	@{ $(MONKEYC) $(EXPORT_FLAGS) -o "$(EXPORT_STAGE)/$(APP).iq"; echo "$(EXPORT_STATUS)$$?"; } | awk -v s='$(EXPORT_STATUS)' '\
	  (i = index($$0, s)) > 0 { if (i > 1) print substr($$0, 1, i - 1); \
	    status = substr($$0, i + length(s)); fflush(); next } \
	  $$0 ~ /^[0-9]+ OUT OF [0-9]+ DEVICES BUILT$$/ { \
	    printf "%*d OUT OF %s DEVICES BUILT\n", length($$4), $$1, $$4; fflush(); next } \
	  { print; fflush() } \
	  END { exit status + 0 }'
	@mkdir -p $(dir $(EXPORT)) && mv "$(EXPORT_STAGE)/$(APP).iq" $(EXPORT)
	@echo "Export complete: $(EXPORT)"

# The font tools (#17): ttf2bmp turns a TTF into bitmap fonts, garmin-font-scaler drives
# it once per resolution. Neither comes with the SDK. The check looks on PATH, where
# garmin-font-scaler looks too; the install puts each in BIN_DIR, which must be on PATH.
## Where the install targets put the font tools; must be on PATH
BIN_DIR ?= $(HOME)/.local/bin
# The lowest ttf2bmp the fonts build with (--stroke came in 0.3.0), and the release
# install-ttf2bmp fetches (#31). Each release carries a .tar.gz of one binary for
# darwin-arm64, darwin-amd64 and linux-amd64; the binary's name inside varies (linux-amd64
# holds ttf2bmp-linux), so the install takes the one file the archive holds.
TTF2BMP_VERSION := 0.3.0
TTF2BMP_RELEASES := https://github.com/wkusnierczyk/ttf2bmp/releases/download

# Exits 1 when $(1)'s version, MAJOR.MINOR.PATCH, is below $(2)'s, or is not one.
version_at_least = awk -v have="$(1)" -v need="$(2)" 'BEGIN { \
  if (have !~ /^[0-9]+\.[0-9]+\.[0-9]+$$/) exit 1; split(have, h, "."); split(need, n, "."); \
  for (i = 1; i <= 3; i++) { if (h[i] + 0 != n[i] + 0) exit (h[i] + 0 < n[i] + 0) } }'

# "ttf2bmp --version" prints "ttf2bmp version v0.3.0".
define require_ttf2bmp
@have=$$(ttf2bmp --version 2>/dev/null | head -n 1 | sed -nE 's/.*version v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'); \
  $(call version_at_least,$$have,$(TTF2BMP_VERSION)) || { \
  if command -v ttf2bmp >/dev/null; then \
    echo "make $@ needs ttf2bmp $(TTF2BMP_VERSION) or newer; $$(command -v ttf2bmp) is $${have:-of no known version}."; \
  else echo "make $@ needs ttf2bmp $(TTF2BMP_VERSION) or newer, and there is none on PATH."; fi; \
  echo "Install it into $(BIN_DIR) with: make install-ttf2bmp"; exit 1; }
endef

## Check that PATH has ttf2bmp, new enough for the fonts
check-ttf2bmp:
	$(require_ttf2bmp)
	@echo "ttf2bmp $$(ttf2bmp --version | sed -nE 's/.*version v?//p') at $$(command -v ttf2bmp)."

# Replaces a ttf2bmp already in BIN_DIR, even a newer one, but only with a binary that runs and
# reports TTF2BMP_VERSION or newer. curl and tar are on macOS and on the CI image.
## Install ttf2bmp's release binary into BIN_DIR [BIN_DIR]
install-ttf2bmp:
	@os=$$(uname -s | tr '[:upper:]' '[:lower:]'); arch=$$(uname -m); \
	case $$arch in x86_64|amd64) arch=amd64 ;; arm64|aarch64) arch=arm64 ;; esac; \
	case $$os-$$arch in darwin-arm64|darwin-amd64|linux-amd64) ;; \
	  *) echo "ttf2bmp $(TTF2BMP_VERSION) has no release binary for $$os-$$arch."; exit 1 ;; esac; \
	url="$(TTF2BMP_RELEASES)/v$(TTF2BMP_VERSION)/ttf2bmp-$$os-$$arch.tar.gz"; \
	tmp=$$(mktemp -d) || exit 1; trap 'rm -rf "$$tmp"' EXIT; \
	echo "Downloading $$url..."; \
	curl -fsSL -o "$$tmp/ttf2bmp.tar.gz" "$$url" || { echo "Download failed."; exit 1; }; \
	mkdir "$$tmp/x" && tar -xzf "$$tmp/ttf2bmp.tar.gz" -C "$$tmp/x" || exit 1; \
	set -- "$$tmp"/x/*; test $$# -eq 1 && test -f "$$1" || { \
	  echo "The archive does not hold one file: $$(ls "$$tmp/x" | tr '\n' ' ')"; exit 1; }; \
	chmod 755 "$$1"; got=$$("$$1" --version 2>/dev/null | head -n 1 | sed -nE 's/.*version v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'); \
	$(call version_at_least,$$got,$(TTF2BMP_VERSION)) || { \
	  echo "The downloaded file does not run as ttf2bmp $(TTF2BMP_VERSION); nothing installed."; exit 1; }; \
	mkdir -p "$(BIN_DIR)" && install -m 755 "$$1" "$(BIN_DIR)/ttf2bmp" || exit 1; \
	echo "Installed $$("$(BIN_DIR)/ttf2bmp" --version) at $(BIN_DIR)/ttf2bmp."; \
	case ":$$PATH:" in *":$(BIN_DIR):"*) ;; \
	  *) echo "$(BIN_DIR) is not on PATH: add it, or make check-ttf2bmp will not find ttf2bmp." ;; esac

# The lowest garmin-font-scaler the fonts build with (stroke="W" came in 0.3.0), and the
# tag install-garmin-font-scaler installs (#32). It is not on PyPI, so pip takes it from
# the tag, into a virtual environment of its own, linked into BIN_DIR.
FONT_SCALER_VERSION := 0.3.0
FONT_SCALER_REPO := https://github.com/wkusnierczyk/garmin-font-scaler.git
## The scaler's virtual environment, which install-garmin-font-scaler replaces
FONT_SCALER_VENV ?= $(HOME)/.local/share/venvs/garmin-font-scaler
# Not whichever python3 is first on PATH: on the owner's Mac, Homebrew's (3.13, 3.15)
# cannot bootstrap pip in a new environment, as platform.mac_ver() returns empty strings
# there and pip's vendored truststore fails parsing them (#32). Apple's /usr/bin/python3
# (3.9, older pip) works, so it is tried first, then python3 on PATH (Linux, where
# /usr/bin/python3 may lack venv); the first that makes an environment with pip is kept.
# pip is not upgraded in the environment, which would bring truststore back. On macOS
# /usr/bin/python3 is tried only with the developer tools installed, or it opens a dialog.
## The Python to build the scaler's environment on; empty tries /usr/bin/python3, then python3
FONT_SCALER_PYTHON ?=

# "garmin-font-scaler --version" prints "garmin-font-scaler 0.3.0".
define require_font_scaler
@have=$$(garmin-font-scaler --version 2>/dev/null | head -n 1 | sed -nE 's/^garmin-font-scaler v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'); \
  $(call version_at_least,$$have,$(FONT_SCALER_VERSION)) || { \
  if command -v garmin-font-scaler >/dev/null; then \
    echo "make $@ needs garmin-font-scaler $(FONT_SCALER_VERSION) or newer; $$(command -v garmin-font-scaler) is $${have:-of no known version}."; \
  else echo "make $@ needs garmin-font-scaler $(FONT_SCALER_VERSION) or newer, and there is none on PATH."; fi; \
  echo "Install it into $(BIN_DIR) with: make install-garmin-font-scaler"; exit 1; }
endef

## Check that PATH has garmin-font-scaler, new enough for the fonts
check-garmin-font-scaler:
	$(require_font_scaler)
	@echo "$$(garmin-font-scaler --version) at $$(command -v garmin-font-scaler)."

# A working environment is moved aside, not deleted, and put back if the new one fails or the
# run is interrupted; an environment left aside by an interrupted run stays the backup. The
# environment's path is made absolute, so the link into BIN_DIR resolves from anywhere.
# make_venv is that shell, shared with install-garmin-graphics-generator (#39): $(1) the
# environment, $(2) the Python to build it on (empty tries /usr/bin/python3, then python3),
# $(3) that Python's variable. It leaves $$venv made, with pip, and the traps set; restore
# puts the previous one back. After the install is checked: trap - INT TERM; rm -rf "$$old".
make_venv = venv="$(1)"; case $$venv in /*) ;; *) venv="$$PWD/$$venv" ;; esac; old="$$venv.old"; \
  nodev=; if test "$$(uname -s)" = Darwin && ! xcode-select -p >/dev/null 2>&1; then nodev=1; fi; \
  if test -e "$$venv"; then rm -rf "$$old" && mv "$$venv" "$$old" || exit 1; fi; \
  restore() { rm -rf "$$venv"; if test -e "$$old"; then mv "$$old" "$$venv"; echo "Kept the previous $$venv."; fi; }; \
  trap 'restore; exit 1' INT TERM; \
  try() { p=$$(command -v "$$1") || { echo "No $$1."; return 1; }; \
    if test -n "$$nodev" && test "$$p" = /usr/bin/python3; then \
      echo "Skipping $$p: without the developer tools it opens their install dialog."; return 1; fi; \
    echo "Making $$venv with $$p ($$("$$p" --version 2>&1))..."; \
    if "$$p" -m venv "$$venv" && "$$venv/bin/python" -m pip --version >/dev/null; then return 0; fi; \
    echo "$$p cannot make a virtual environment with pip."; rm -rf "$$venv"; return 1; }; \
  if test -n "$(2)"; then try "$(2)"; \
  else try /usr/bin/python3 || try python3; fi || { \
    echo "No Python made one; pick one with $(3)=/path/to/python3."; restore; exit 1; }

## Install garmin-font-scaler in its own environment, linked into BIN_DIR [BIN_DIR FONT_SCALER_VENV FONT_SCALER_PYTHON]
install-garmin-font-scaler:
	@$(call make_venv,$(FONT_SCALER_VENV),$(FONT_SCALER_PYTHON),FONT_SCALER_PYTHON); \
	echo "Installing garmin-font-scaler $(FONT_SCALER_VERSION) from $(FONT_SCALER_REPO)..."; \
	"$$venv/bin/python" -m pip install --quiet --disable-pip-version-check \
	  "git+$(FONT_SCALER_REPO)@v$(FONT_SCALER_VERSION)" || { echo "pip install failed."; restore; exit 1; }; \
	got=$$("$$venv/bin/garmin-font-scaler" --version 2>/dev/null | head -n 1 | sed -nE 's/^garmin-font-scaler v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'); \
	$(call version_at_least,$$got,$(FONT_SCALER_VERSION)) || { \
	  echo "The installed garmin-font-scaler does not run as $(FONT_SCALER_VERSION) or newer."; restore; exit 1; }; \
	trap - INT TERM; rm -rf "$$old"; \
	mkdir -p "$(BIN_DIR)" && ln -sf "$$venv/bin/garmin-font-scaler" "$(BIN_DIR)/garmin-font-scaler" || exit 1; \
	"$(BIN_DIR)/garmin-font-scaler" --version >/dev/null 2>&1 || { \
	  echo "$(BIN_DIR)/garmin-font-scaler does not run."; exit 1; }; \
	echo "Installed garmin-font-scaler $$got at $(BIN_DIR)/garmin-font-scaler."; \
	case ":$$PATH:" in *":$(BIN_DIR):"*) ;; \
	  *) echo "$(BIN_DIR) is not on PATH: add it, or make check-garmin-font-scaler will not find the scaler." ;; esac

# The bitmap fonts (#17): garmin-font-scaler writes every resources-<family>/fonts/ from
# resources/fonts/ (fonts.xml, charsets.json, resolutions.json), and fonts.md. It does not
# refresh resources/fonts/'s own bitmaps, which the compiler reads for a product with no
# directory of its own, so they are copied from the reference resolution's; the reference is
# read from resolutions.json. docs/fonts.md's size table is copied from fonts.md, and the
# typeface's and the bitmaps' SHA-256 recorded in fonts.sha256; then all of it is checked.
## Regenerate the bitmap fonts, fonts.md, fonts.sha256 and docs/fonts.md's size table (needs ttf2bmp and garmin-font-scaler)
fonts:
	$(require_ttf2bmp)
	$(require_font_scaler)
	@garmin-font-scaler
	@ref=$$(python3 -c 'import json; r = json.load(open("resources/fonts/resolutions.json"))["reference"]; print("resources-%s-%dx%d" % (r["shape"], *r["resolution"]))') && \
	  for f in $$(sed -nE 's/.*filename="([^"]+)\.fnt".*/\1/p' resources/fonts/fonts.xml); do \
	    cp "$$ref/fonts/$$f.fnt" "$$ref/fonts/$$f.png" resources/fonts/ || exit 1; done
	@garmin-font-scaler --table fonts.md
	@python3 tools/check-font-config.py --write

# Pure Python, no SDK and no font tools, so it runs in CI's consistency checks.
## Check that the fonts agree with their configuration, the design's sizes and docs/fonts.md
check-fonts:
	@echo "Checking the fonts..."
	@python3 tools/check-font-config.py

# The store and README images (#7), captured by garmin-graphics-generator: the Connect IQ
# simulator in a container under Xvfb, so Docker and nothing else -- no desktop simulator,
# no GUI, no macOS screen-recording permission. The container is CI's tester image, a
# private package: docker login ghcr.io first. tools/make-graphics.py holds the inventory,
# the moments each image shows; each is a build of its own through graphics.jungle, with
# the clock frozen at its moment (source/Now.mc). On an arm64 Mac the image runs emulated,
# a minute or so a build.
#
# Run make graphics again whenever what the face draws changes: nothing reports the images
# stale. They are deterministic, the same face drawing the same images, but for the hero's
# placement, which is random: look at the draft and run again if it is poor.
#
# The tool runs in GRAPHICS_PYTHON, which must have it installed. It is not on PyPI, so
# install-garmin-graphics-generator (#39) installs it from its tag, in a virtual environment
# of its own, GRAPHICS_VENV, and GRAPHICS_PYTHON is that environment's Python once it exists.
# 0.8.1 is the release the targets were written and run against (tools/make-graphics.py).
# Pillow is pinned to GRAPHICS_PILLOW_VERSION, the one the icons were drawn with and CI's
# (.github/workflows/build.yml): check-icons compares pixels, which only one Pillow reproduces.
## The generator's virtual environment, which install-garmin-graphics-generator replaces
GRAPHICS_VENV ?= $(HOME)/.local/share/venvs/garmin-graphics-generator
# test -x, not $(wildcard): wildcard splits a path with spaces, and reads [ and * as patterns.
## The Python graphics, preview, icons and check-icons run in: GRAPHICS_VENV's, else python3
GRAPHICS_PYTHON ?= $(shell test -x "$(GRAPHICS_VENV)/bin/python" && printf '%s' "$(GRAPHICS_VENV)/bin/python" || echo python3)
# The same choice as the scaler's environment (FONT_SCALER_PYTHON, above), for the same reason.
## The Python to build the generator's environment on; empty tries /usr/bin/python3, then python3
GRAPHICS_VENV_PYTHON ?=
## The container platform for graphics and preview; the tester image is amd64 only
PLATFORM ?= linux/amd64
GRAPHICS_TOOL_VERSION := 0.8.1
GRAPHICS_TOOL_REPO := https://github.com/wkusnierczyk/garmin-graphics-generator
GRAPHICS_PILLOW_VERSION := 11.3.0
# Prints the generator's version in $(1), a Python, or nothing.
graphics_tool_version = "$(1)" -c 'from importlib.metadata import version; print(version("garmin_graphics_generator"))' 2>/dev/null

define require_graphics_tool
@"$(GRAPHICS_PYTHON)" -c 'import sys; from importlib.metadata import version; \
  number = lambda v: tuple(int(part) for part in v.split(".")[:3]); \
  raise SystemExit(number(version("garmin_graphics_generator")) < number(sys.argv[1]))' \
  '$(GRAPHICS_TOOL_VERSION)' 2>/dev/null || { \
  echo "make $@ needs garmin-graphics-generator $(GRAPHICS_TOOL_VERSION) or newer, installed for"; \
  echo "GRAPHICS_PYTHON ($(GRAPHICS_PYTHON)). Install it into GRAPHICS_VENV with:"; \
  echo "  make install-garmin-graphics-generator"; exit 1; }
endef

## Check that GRAPHICS_PYTHON has garmin-graphics-generator, new enough for the images [GRAPHICS_PYTHON]
check-garmin-graphics-generator:
	$(require_graphics_tool)
	@echo "garmin-graphics-generator $$($(call graphics_tool_version,$(GRAPHICS_PYTHON))) for $(GRAPHICS_PYTHON)."

# The package with its dependencies (rembg, for the hero, among them) and Pillow at
# GRAPHICS_PILLOW_VERSION, in one resolve; then checked for the version, and for that Pillow.
## Install garmin-graphics-generator in its own environment, GRAPHICS_VENV [GRAPHICS_VENV GRAPHICS_VENV_PYTHON]
install-garmin-graphics-generator:
	@$(call make_venv,$(GRAPHICS_VENV),$(GRAPHICS_VENV_PYTHON),GRAPHICS_VENV_PYTHON); \
	echo "Installing garmin-graphics-generator $(GRAPHICS_TOOL_VERSION) and Pillow $(GRAPHICS_PILLOW_VERSION)..."; \
	"$$venv/bin/python" -m pip install --quiet --disable-pip-version-check \
	  "garmin-graphics-generator @ git+$(GRAPHICS_TOOL_REPO)@v$(GRAPHICS_TOOL_VERSION)" \
	  "Pillow==$(GRAPHICS_PILLOW_VERSION)" || { echo "pip install failed."; restore; exit 1; }; \
	got=$$($(call graphics_tool_version,$$venv/bin/python)); \
	$(call version_at_least,$$got,$(GRAPHICS_TOOL_VERSION)) || { \
	  echo "The installed garmin-graphics-generator is not $(GRAPHICS_TOOL_VERSION) or newer."; restore; exit 1; }; \
	"$$venv/bin/python" -c 'import garmin_graphics_generator.cli' || { \
	  echo "The installed garmin-graphics-generator does not import."; restore; exit 1; }; \
	pil=$$("$$venv/bin/python" -c 'import PIL; print(PIL.__version__)' 2>/dev/null); \
	test "$$pil" = "$(GRAPHICS_PILLOW_VERSION)" || { \
	  echo "The environment has Pillow $${pil:-none}, not $(GRAPHICS_PILLOW_VERSION)."; restore; exit 1; }; \
	trap - INT TERM; rm -rf "$$old"; \
	echo "Installed garmin-graphics-generator $$got, with Pillow $$pil, in $$venv."

# On the reference product, epix2pro47mm, whatever DEVICE says: the images show what CI
# builds and tests. Writes store/lite/graphics/: ClimberTimeCapture.png, the raw screen;
# ClimberTime1.png and on, the gallery at 200 px, which the README uses too; and
# ClimberTimeHero-draft.png with its 900x450 banner. Never ClimberTimeHero.png, the name a
# published hero takes.
## Capture the store gallery and a draft hero into store/lite/graphics [PLATFORM GRAPHICS_PYTHON]
graphics:
	$(require_graphics_tool)
	@"$(GRAPHICS_PYTHON)" tools/make-graphics.py $(if $(PLATFORM),--platform $(PLATFORM),)

# The same frames as make graphics, at full size and on a labelled contact sheet, for
# review and for picking the gallery, plus any moments in AT: HH:MM:SS, HH:MM:fall (the
# first fall of that minute) or HH:MM:always-on, e.g. AT="09:05:30 09:00:fall". Writes
# nothing outside PREVIEW_DIR, which is gitignored.
PREVIEW_DIR := .dev/scratchpad/preview
## More moments for preview: HH:MM:SS, HH:MM:fall or HH:MM:always-on, space-separated
AT ?=
## Capture the gallery's frames, and AT, on a contact sheet in .dev/scratchpad/preview [DEVICE AT PLATFORM GRAPHICS_PYTHON]
preview:
	$(require_graphics_tool)
	@"$(GRAPHICS_PYTHON)" tools/make-graphics.py --preview $(PREVIEW_DIR) -d $(DEVICE) \
	  $(foreach moment,$(AT),--at $(moment)) $(if $(PLATFORM),--platform $(PLATFORM),)
	@echo "Contact sheet: $(PREVIEW_DIR)/contact-sheet.png"

# The launcher icons (#19). Their size is a per-device property, not a per-family one,
# so the icons and the per-product jungle mapping that serves them are generated from
# the SDK's device definitions rather than kept by hand, by garmin-graphics-generator's
# icons command with the renderer tools/launcher_icon.py: a white climber in a high
# step, on black, drawn at each size. The command writes resources-icon-<size>/, the
# fallback resources/drawables/launcher_icon.png (the largest size), the block between
# the markers in monkey.jungle, and the size table in docs/graphics.md that follows the
# sentence in ICONS_README. The store cover, store/lite/graphics/ClimberTimeCover.png, is the same
# drawing at 500 x 500; the command knows nothing about it, so the renderer, run as a
# script, writes and checks it. --check needs no SDK: it cross-checks the mapping with
# the device definitions when they are there, and skips that when not (CI).
#
# Both go through GRAPHICS_PYTHON, not through the tool's own garmin-graphics-generator
# script, which may belong to another interpreter: so one Pillow draws the icons and the
# cover. 0.8.1 is the first release that records the renderer in the jungle's
# "Regenerate with:" line, so every machine writes that line the same way.
ICONS_TOOL = "$(GRAPHICS_PYTHON)" -c 'import sys; from garmin_graphics_generator.cli import main; \
  sys.argv[0] = "garmin-graphics-generator"; sys.exit(main())'
ICONS_README := --readme docs/graphics.md --readme-anchor 'Each supported product is mapped to the icon its device asks for'

## Regenerate the launcher icons, their mapping in monkey.jungle, docs/graphics.md's table and the store cover [GRAPHICS_PYTHON]
icons:
	$(require_graphics_tool)
	@echo "Generating the launcher icons..."
	@$(ICONS_TOOL) icons -R tools/launcher_icon.py $(ICONS_README)
	@echo "Generating the store cover..."
	@"$(GRAPHICS_PYTHON)" tools/launcher_icon.py cover

## Check the launcher icons, their mapping, docs/graphics.md's table and the store cover [GRAPHICS_PYTHON]
check-icons:
	$(require_graphics_tool)
	@echo "Checking the launcher icons..."
	@$(ICONS_TOOL) icons $(ICONS_README) --check
	@echo "Checking the icons' and the store cover's pixels against the renderer..."
	@"$(GRAPHICS_PYTHON)" tools/launcher_icon.py check

## Remove build output
clean:
	@rm -Rf $(OUTPUT) $(APP)*-settings.json test_build* *.debug.xml gen/ internal-mir/ external-mir/ $(EXPORT_DIR)/
	@echo "Clean complete."

# The help is the "## " line above each target and ?= variable; tools/make-help.py
# (as in Matrix Time, #168) reads them out, with the values make passes in.
## List the targets and the variables
help:
	@python3 tools/make-help.py Makefile \
	  $(foreach v,$(shell python3 tools/make-help.py Makefile --variables),'$(v)=$(subst ','\'',$($(v)))')
	@test -x "$(SDK_BIN)/monkeyc" || echo "No Connect IQ SDK at SDK_BIN: the targets that run the SDK locally need one."

# Fails on a target in .PHONY, or a ?= variable, with no "## " line above it.
## Check that every target and variable has help
check-help:
	@echo "Checking the help..."
	@python3 tools/make-help.py Makefile --check
