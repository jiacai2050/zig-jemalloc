
clean:
	rm -rf zig-out .zig-cache zig-cache

build: clean
	zig build

test:
	zig build test
