
clean:
	rm -rf zig-out .zig-cache zig-cache

test:
	zig build test
