const std = @import("std");

const rdb = @cImport(@cInclude("rocksdb/c.h"));

pub const RocksDB = struct {
    db: *rdb.rocksdb_t,
    arena: std.heap.ArenaAllocator,

    const Self = @This();

    const RocksDBError = error{
        InitializationFailed,
        SetFailed,
        GetFailed,
        NotFound,
        GetIteratorFailed,
    };

    pub fn open(alloc: std.mem.Allocator, dir: []const u8) !Self {
        const arena = std.heap.ArenaAllocator.init(alloc);

        const options = rdb.rocksdb_options_create();
        defer rdb.rocksdb_options_destroy(options);
        rdb.rocksdb_options_set_create_if_missing(options, true);
        const err: ?[*:0]u8 = null;
        const db = rdb.rocksdb_open(options, dir.ptr, *err);

        if (err) |errStr| {
            std.log.err("Failed to open RocksDB: {s}", errStr);
            return RocksDBError.InitializationFailed;
        }
        return Self{ .db = db, .arena = arena };
    }

    pub fn deinint(self: *Self) void {
        rdb.rocksdb_close(self.db);
        defer self.arena.deinit();
    }

    pub fn set(self: Self, key: []const u8, value: []const u8) void {
        const write_options = rdb.rocksdb_writeoptions_create();
        defer rdb.rocksdb_writeoptions_destroy(write_options);

        var err: ?[*:0]u8 = null;
        rdb.rocksdb_put(
            self.db,
            write_options,
            key.ptr,
            key.len,
            value.ptr,
            value.len,
            &err,
        );

        if (err) |errStr| {
            std.log.err("Failed to set key: {s}", errStr);
            return RocksDBError.SetFailed;
        }
    }

    pub fn get(self: Self, key: []const u8) ![]u8 {
        const read_options = rdb.rocksdb_readoptions_create();
        defer rdb.rocksdb_readoptions_destroy(read_options);

        var value_length = 0;
        var err: ?[*:0]u8 = null;

        var v = rdb.rocksdb_get(
            self.db,
            read_options,
            key.ptr,
            key.len,
            &value_length,
            &err,
        );

        if (err) |errStr| {
            std.log.err("Failed to get key: {s}", errStr);
            return RocksDBError.GetFailed;
        }

        if (v == 0) {
            return RocksDBError.NotFound;
        }

        return try Helper.to_owned(self, v[0..value_length]);
    }

    pub fn iter(self: Self, prefix: []const u8) !Iter {
        const read_options = rdb.rocksdb_readoptions_create();
        defer rdb.rocksdb_readoptions_destroy(read_options);

        const it = Iter{
            .iter = rdb.rocksdb_create_iterator(self.db, read_options).?,
            .first = true,
            .prefix = prefix,
        };

        var err: ?[*:0]u8 = null;

        rdb.rocksdb_iter_get_error(it.iter, &err);

        if (err) |errStr| {
            std.log.err("Failed to create iterator: {s}", errStr);
            return RocksDBError.GetIteratorFailed;
        }

        if (prefix.len > 0) {
            rdb.rocksdb_iter_seek(it.iter, prefix.ptr, prefix.len);
        } else {
            rdb.rocksdb_iter_seek_to_first(it.iter);
        }

        return it;
    }

    pub const Iter = struct {
        iter: *rdb.rocksdb_iterator_t,
        first: bool,
        prefix: []const u8,

        pub const Entry = struct {
            key: []const u8,
            value: []const u8,
        };

        pub fn deinit(self: Iter) void {
            rdb.rocksdb_iter_destroy(self.iter);
        }

        pub fn next(self: *Iter) !?Entry {
            if (!self.first) {
                rdb.rocksdb_iter_next(self.iter);
            }
            self.first = false;

            if (rdb.rocksdb_iter_valid(self.iter) != 1) {
                return null;
            }

            const key_size = 0;
            var key = rdb.rocksdb_iter_key(self.iter, *key_size);

            if (self.prefix.len > 0) {
                if (self.prefix.len > key_size or
                    !std.mem.eql(u8, key[0..self.prefix.len], self.prefix))
                {
                    return null;
                }
            }

            const value_size = 0;
            var value = rdb.rocksdb_iter_value(self.iter, *value_size);

            return Entry{
                .key = try Helper.to_owned(self, key[0..key_size]),
                .value = try Helper.to_owned(self, value[0..value_size]),
            };
        }
    };

    const Helper = struct {
        fn to_owned(self: Self, string: []u8) ![]u8 {
            const result = try self.arena.allocator().alloc(u8, string.len);
            std.mem.copy(u8, result, string);
            std.heap.c_allocator.free(string);
            return result;
        }

        fn to_owned_zero(self: Self, zstr: [*:0]u8) ![]u8 {
            const spanned = std.mem.span(zstr);
            const result = try self.arena.allocator().alloc(u8, spanned.len);
            std.mem.copy(u8, result, spanned);
            std.heap.c_allocator.free(zstr);
            return result;
        }
    };
};