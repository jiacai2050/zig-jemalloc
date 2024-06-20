
clean:
	rm -rf zig-out .zig-cache

test:
	zig build test
