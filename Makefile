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
# export/ClimberTime-0.0.1.iq. Only MAJOR.MINOR.PATCH from exactly one <iq:application>
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

.PHONY: all build sim run test golden sideload export check-ttf2bmp install-ttf2bmp clean help \
  check-help

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
# garmin-font-scaler looks too; install-ttf2bmp puts ttf2bmp in BIN_DIR, which must be on PATH.
## Where install-ttf2bmp puts ttf2bmp; must be on PATH
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
