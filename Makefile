# --- Dynamic Cross-Platform Command Discovery ---
ifeq ($(OS),Windows_NT)
    # 1. Make Bash the default execution shell
    SHELL     := C:/Program Files/Git/usr/bin/bash.exe

    # 2. Dynamically discover the emacs binary using Windows shell
    # If Emacs is in the system PATH, grab the absolute installation path
    EMACS_BIN := $(shell where emacs 2>NUL | head -n 1)
    
    # Fallback to standard installer path if it is not in your system environment PATH
    ifeq ($(EMACS_BIN),)
        EMACS_BIN := "C:/Program Files/Emacs/emacs-30.1/bin/emacs.exe"
    endif

    # 3. Target the native Git Bash find command to isolate away from system32/find.exe
    FIND_CMD  := /usr/bin/find
else
    # Linux / Cloud Execution Boundaries
    SHELL     := /bin/bash
    EMACS_BIN := emacs
    FIND_CMD  := find
endif

# --- Domain Constants ---
ORG_DIR := notes
OUT_DIR := public-export
SCRIPTS := scripts/build-env.el

EMACS   := $(EMACS_BIN) --batch -l $(SCRIPTS)

# --- Dynamic Asset Scanning ---
SOURCES := $(shell $(FIND_CMD) $(ORG_DIR) -name "*.org")
TARGETS := $(patsubst $(ORG_DIR)/%.org, $(OUT_DIR)/%.md, $(SOURCES)) 

.PHONY: all clean

all: $(OUT_DIR) $(TARGETS)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

$(OUT_DIR)/%.md: $(ORG_DIR)/%.org $(SCRIPTS)
	@mkdir -p $(dir $@)  
	@echo "--- Compiling $< ---"
	$(EMACS) --eval '(my-cloud-export "$<" "$@")'

clean:
	rm -rf $(OUT_DIR)
