# Prototype Makefile, cut down from Matrix Time's.
CIQ_HOME ?= $(HOME)/Library/Application Support/Garmin/ConnectIQ
SDK_BIN  ?= $(shell sed -e 's:/*$$::' "$(CIQ_HOME)/current-sdk.cfg" 2>/dev/null)/bin
DEV_KEY  ?= ../garmin-keys/developer_key
DEVICE   ?= epix2pro47mm
SIM_PORT ?= 1234
APP      := ClimberTime
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

## Build for the connected watch and copy it over USB, retrying with backoff (MTP; brew install libmtp) [WAIT EVERY TRIES BACKOFF]
sideload:
	@tools/sideload.sh wait "$(WAIT)" "$(EVERY)" || exit 1
	@n=1; gap=$(BACKOFF); \
	until watch=$$(CIQ_HOME="$(CIQ_HOME)" tools/sideload.sh detect); do \
	  test $$n -lt $(TRIES) || { echo "The watch did not answer after $(TRIES) attempts."; exit 1; }; \
	  echo "Detect attempt $$n of $(TRIES) failed; trying again in $${gap}s."; \
	  sleep $$gap; n=$$((n+1)); gap=$$((gap*2)); \
	done; \
	echo "Watch detected: $$watch"; \
	grep -q '<iq:product id="'"$$watch"'"/>' manifest.xml || { echo "manifest.xml does not list $$watch."; exit 1; }; \
	$(SUBMAKE) --no-print-directory build DEVICE=$$watch || exit 1; \
	n=1; gap=$(BACKOFF); \
	until tools/sideload.sh install $(OUTPUT); do \
	  test $$n -lt $(TRIES) || { echo "Install failed after $(TRIES) attempts."; exit 1; }; \
	  echo "Install attempt $$n of $(TRIES) failed; trying again in $${gap}s."; \
	  sleep $$gap; n=$$((n+1)); gap=$$((gap*2)); \
	done

## Remove build output
clean:
	rm -f $(OUTPUT) $(OUTPUT).debug.xml
