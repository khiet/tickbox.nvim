# Override when plenary lives elsewhere: make test PLENARY_DIR=/path/to/plenary.nvim
PLENARY_DIR ?= $(HOME)/.local/share/nvim/lazy/plenary.nvim
export PLENARY_DIR

.PHONY: test
test:
	@test -d "$(PLENARY_DIR)" || { echo "plenary.nvim not found at $(PLENARY_DIR); set PLENARY_DIR"; exit 1; }
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"
