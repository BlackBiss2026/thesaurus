CC      ?= gcc
CFLAGS  = -std=c99 -Wall -Wextra -pedantic -g
SRCS    = $(wildcard src/*.c)

.PHONY: all test asan werror clean

all: build/thesaurus

build:
	mkdir -p build

build/thesaurus: $(SRCS) $(wildcard src/*.h) | build
	$(CC) $(CFLAGS) -O2 $(SRCS) -o $@

# Built with AddressSanitizer: catches leaks and invalid memory access.
build/thesaurus_asan: $(SRCS) $(wildcard src/*.h) | build
	$(CC) $(CFLAGS) -fsanitize=address,undefined -fno-omit-frame-pointer $(SRCS) -o $@

test: build/thesaurus
	./tests/run_tests.sh

asan: build/thesaurus_asan
	./tests/run_tests.sh --asan

werror: | build
	$(CC) $(CFLAGS) -Werror -fsyntax-only $(SRCS)

clean:
	rm -rf build
