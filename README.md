# Rock Clip

A high-performance RocksDB wrapper library for Zig, providing safe and ergonomic bindings to Facebook's RocksDB key-value store.

## Description

Rock Clip makes RocksDB accessible in Zig by providing:
- Type-safe wrappers around RocksDB's C API
- Memory-safe operations using Zig's allocator patterns
- Iterator support for efficient data scanning
- Error handling using Zig's error union types

## Installation

1. Install RocksDB dependencies (required for building):
   ```bash
   # Ubuntu/Debian
   sudo apt-get install libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev

   # MacOS
   brew install rocksdb
   ```

2. Clone and set up the repository:
   ```bash
   git clone <repository-url>
   cd rock-clip
   ```

3. Run the configure script to set up RocksDB:
   ```bash
   chmod +x configure
   ./configure
   ```

4. Build the project:
   ```bash
   zig build
   ```

For development builds, you can use different optimization flags:
```bash
# Debug build
zig build -Doptimize=Debug

# Release build
zig build -Doptimize=ReleaseFast
```

## Usage

Here's a basic example of using Rock Clip:

```zig
const std = @import("std");
const RocksDB = @import("rock-clip").RocksDB;

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    
    // Open database
    var db = try RocksDB.open(alloc, "/tmp/db");
    defer db.deinit();

    // Set value
    try db.set("key1", "value1");

    // Get value
    const value = try db.get("key1");
    std.debug.print("Value: {s}\n", .{value});

    // Iterate over keys with prefix
    var iter = try db.iter("key");
    defer iter.deinit();

    while (try iter.next()) |entry| {
        std.debug.print("Key: {s}, Value: {s}\n", .{entry.key, entry.value});
    }
}
```

## Features

- **Safe Memory Management**: Utilizes Zig's arena allocator for automatic memory cleanup.

- **Comprehensive API Coverage**: Supports all basic operations including get, set, delete, and iteration.

- **Prefix Iteration**: Efficient iteration over keys with a common prefix, perfect for implementing namespaces.

- **Error Handling**: Well-defined error types for all operations, making error handling explicit and reliable.

- **Resource Safety**: Automatic cleanup of RocksDB resources through Zig's defer mechanism.

## Contributing Guidelines

1. Tag issues appropriately with [BUG] or [FEATURE] to indicate the type of change.

2. Do not start work on issues that are already assigned.

3. Include tests for new functionality.

4. Update README if adding new features.

5. Follow existing code style and error handling patterns.
