# --- Dynamic Cross-Platform Command Discovery ---
ifeq ($(OS),Windows_NT)
    # 1. Force Bash as the core execution shell early
    SHELL := C:/Program Files/Git/usr/bin/bash.exe

    # 2. Use cross-platform command location tool via Git Bash context
    EMACS_BIN := $(shell which emacs 2>/dev/null)
    ifeq ($(EMACS_BIN),)
        EMACS_BIN := "/cygdrive/c/Program Files/Emacs/emacs-30.1/bin/emacs.exe"
    endif

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

# --- Dynamic Asset Scanning & Filtering ---
# Find all raw source notes
ALL_SOURCES := $(shell $(FIND_CMD) $(ORG_DIR) -name "*.org")

# Staff Optimization: Filter out index.org from the default Markdown target list
SOURCES     := $(filter-out $(ORG_DIR)/index.org, $(ALL_SOURCES))
TARGETS     := $(patsubst $(ORG_DIR)/%.org, $(OUT_DIR)/%.md, $(SOURCES)) 

.PHONY: all clean

# Explicit execution order: directory -> markdown deltas -> root html entry-point
all: $(OUT_DIR) $(TARGETS) $(OUT_DIR)/index.html
	@touch $(OUT_DIR)/.nojekyll
	@echo "[SUCCESS] Digital Garden build sequence completed."

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

# Root entry point compiled explicitly to HTML via Pandoc
$(OUT_DIR)/index.html: $(ORG_DIR)/index.org
	@mkdir -p $(patsubst %/,%,$(dir $@))
	@echo "--- Compiling Root HTML Interface: $< ---"
	pandoc $< -f org -t html5 -s -o $@

# Deep notes directories compiled to Markdown via Headless Emacs
$(OUT_DIR)/%.md: $(ORG_DIR)/%.org $(SCRIPTS)
	@mkdir -p $(patsubst %/,%,$(dir $@))  
	@echo "--- Compiling Markdown Files: $< ---"
	$(EMACS) --eval '(my-cloud-export "$<" "$@")'

clean:
	rm -rf $(OUT_DIR)
