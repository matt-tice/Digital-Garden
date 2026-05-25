
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

# Filter out index.org from the default Markdown target list
SOURCES     := $(filter-out $(ORG_DIR)/index.org, $(ALL_SOURCES))
TARGETS     := $(patsubst $(ORG_DIR)/%.org, $(OUT_DIR)/%.md, $(SOURCES))

SUBDIRS     := $(shell $(FIND_CMD) $(ORG_DIR) -mindepth 1 -type d)
DIR_INDEXES := $(patsubst $(ORG_DIR)/%, $(OUT_DIR)/%/index.html, $(SUBDIRS))

.PHONY: all clean

all: $(TARGETS) $(OUT_DIR)/index.html $(DIR_INDEXES)
	@touch $(OUT_DIR)/.nojekyll
	@echo "[SUCCESS] Digital Garden build sequence completed."


# Compile markdown from org files
$(OUT_DIR)/%.md: $(ORG_DIR)/%.org $(SCRIPTS) | $(OUT_DIR)
	@mkdir -p $(patsubst %/,%,$(dir $@))  
	@echo "--- Compiling Markdown Files: $< ---"
	$(EMACS) --eval '(my-cloud-export "$<" "$@")'


# Create homepage for github-pages
$(OUT_DIR)/index.html: $(ORG_DIR)/index.org | $(OUT_DIR)
	@echo "--- Compiling Root HTML Interface: $< ---"
	pandoc $< -f org -t html5 -s -o $@

# Generate index.html for each subdirectory
# Look only inside of DIR_INDEXES, so we don't end up with this rule applying to our public-exports/index.html
$(DIR_INDEXES): $(OUT_DIR)/%/index.html  | $(OUT_DIR)
	@echo "--- Making Directory Index for: $* ---"
	@( \
		echo "#+TITLE: Index of $*" ; \
		echo "* Notes in this area:" ; \
		for file in $(notdir $(basename $(filter $(ORG_DIR)/$*/% ,$(ALL_SOURCES)))); do \
			echo " - [[./$$file.md][$$file]]" ; \
		done \
	) > $@.tmp
	pandoc $@.tmp -f org -t html5 -s -o $@
	@rm -f $@.tmp

$(OUT_DIR):
	mkdir -p $(OUT_DIR)


clean:
	rm -rf $(OUT_DIR)
