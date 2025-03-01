PANVIMDOC_DIR = misc/panvimdoc
PANVIMDOC_URL = https://github.com/kdheepak/panvimdoc
PLENARY_DIR = misc/plenary
PLENARY_URL = https://github.com/nvim-lua/plenary.nvim
TREESITTER_DIR = misc/treesitter
TREESITTER_URL = https://github.com/nvim-treesitter/nvim-treesitter

all: format test

build:
	@echo "===> Building Rust libraries:"
	@$(MAKE) -f Makefile.rust

clean:
	@echo "===> Cleaning Rust builds:"
	@$(MAKE) -f Makefile.rust clean

format:
	@echo "===> Formatting:"
	@stylua lua/ -f ./stylua.toml

test: $(PLENARY_DIR) $(TREESITTER_DIR)
	@echo "===> Testing:"
	nvim --headless --clean \
	-u scripts/minimal.vim \
	-c "PlenaryBustedDirectory lua/spec/context-groups { minimal_init = 'scripts/minimal.vim' }"

$(PLENARY_DIR):
	git clone --depth=1 $(PLENARY_URL) $(PLENARY_DIR)
	@rm -rf $(PLENARY_DIR)/.git

$(TREESITTER_DIR):
	git clone --depth=1 $(TREESITTER_URL) $(TREESITTER_DIR)
	@rm -rf $(TREESITTER_DIR)/.git

