# Prototype Makefile, cut down from Matrix Time's.
CIQ_HOME ?= $(HOME)/Library/Application Support/Garmin/ConnectIQ
SDK_BIN  ?= $(shell sed -e 's:/*$$::' "$(CIQ_HOME)/current-sdk.cfg" 2>/dev/null)/bin
DEV_KEY  ?= ../garmin-keys/developer_key
DEVICE   ?= epix2pro47mm
SIM_PORT ?= 1234
APP      := ClimberTime
OUTPUT   := $(APP).prg

MONKEYC   = "$(SDK_BIN)/monkeyc"
MONKEYDO  = "$(SDK_BIN)/monkeydo"
CONNECTIQ = "$(SDK_BIN)/connectiq"

.PHONY: all build sim run sideload clean

all: build

## Build the .prg for DEVICE
build:
	@echo "Building for $(DEVICE)..."
	@$(MONKEYC) -f monkey.jungle -d $(DEVICE) -y $(DEV_KEY) -w -o $(OUTPUT)
	@echo "Build complete: $(OUTPUT)"

## Start the simulator unless it is running
sim:
	@if nc -z 127.0.0.1 $(SIM_PORT) 2>/dev/null; then echo "Simulator already running."; else \
	  $(CONNECTIQ) & n=0; until nc -z 127.0.0.1 $(SIM_PORT) 2>/dev/null; do \
	    n=$$((n+1)); test $$n -lt 60 || { echo "Simulator did not start."; exit 1; }; sleep 1; done; \
	  echo "Simulator ready."; fi

## Build and load into the simulator (stays attached; Ctrl-C to stop)
run: build sim
	@$(MONKEYDO) $(OUTPUT) $(DEVICE)

## Build for the connected watch and copy it over USB (MTP; brew install libmtp)
sideload:
	@watch=$$(CIQ_HOME="$(CIQ_HOME)" tools/sideload.sh detect) || exit 1; \
	echo "Watch detected: $$watch"; \
	grep -q '<iq:product id="'"$$watch"'"/>' manifest.xml || { echo "manifest.xml does not list $$watch."; exit 1; }; \
	$(MAKE) --no-print-directory build DEVICE=$$watch && tools/sideload.sh install $(OUTPUT)

## Remove build output
clean:
	rm -f $(OUTPUT) $(OUTPUT).debug.xml
