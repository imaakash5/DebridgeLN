# Submodule management

install:
	@git submodule update --init --recursive

# Build and test

profile ?=default

build:
	@FOUNDRY_PROFILE=production forge build

test:
	forge test

debug: 
	forge test -vvvvv

clean:
	@forge clean