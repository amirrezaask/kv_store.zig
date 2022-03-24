const std = @import("std");
const print = std.debug.print;
const net = std.net;
const HashMap = std.StringHashMap([]const u8);
const StreamServer = std.net.StreamServer;
const Connection = std.net.StreamServer.Connection;
const Address = std.net.Address;
const Allocator = std.mem.Allocator;
const errors = error{
    BadInput,
};
const CommandType = enum {
    Get,
    Set,
    Exit,
};
const Command = struct {
    const GetPayload = struct {
        key: []const u8,
    };
    const SetPayload = struct {
        key: []const u8,
        value: []const u8,
    };
    const Payload = union {
        get: GetPayload,
        set: SetPayload,
    };
    cmd_ty: CommandType,
    payload: Payload = undefined,
    pub fn init(input: []u8) !Command {
        var iter = std.mem.split(u8, input, " ");
        const ty = iter.next().?;
        if (std.mem.eql(u8, ty, "GET")) {
            return Command{ .cmd_ty = CommandType.Get, .payload = .{ .get = .{
                .key = iter.next().?,
            } } };
        }
        if (std.mem.eql(u8, ty, "SET")) {
            return Command{ .cmd_ty = CommandType.Set, .payload = .{ .set = .{
                .key = iter.next().?,
                .value = iter.next().?,
            } } };
        }
        if (std.mem.eql(u8, ty, "EXIT")) {
            return Command{
                .cmd_ty = CommandType.Exit,
            };
        }
        return errors.BadInput;
    }
};

fn handle_connection(allocator: Allocator, conn: Connection, store: *HashMap) !void {
    defer conn.stream.close();
    while (true) {
        var user_input = try conn.stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(u64));
        // handle \r since in telnet <enter> do \r\n
        user_input = user_input[0 .. user_input.len - 1];
        const command = try Command.init(user_input);
        switch (command.cmd_ty) {
            .Get => {
                const value = store.get(command.payload.get.key) orelse {
                    try conn.stream.writer().print("key {s} does not exists\n", .{command.payload.get.key});
                    continue;
                };
                try conn.stream.writer().print("{s}\n", .{value});
            },
            .Set => {
                try store.put(command.payload.set.key, command.payload.set.value);
                try conn.stream.writer().print("OK\n", .{});
            },
            .Exit => {
                return;
            },
        }
    }
}

pub fn main() !void {
    const ip = "127.0.0.1"; //take this from user flags ?
    const port = 8080; //take this from user flags ?

    // memory allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var hm = HashMap.init(allocator);
    defer _ = hm.deinit();
    const address = try Address.resolveIp(ip, port);
    var server = std.net.StreamServer.init(.{});
    defer _ = server.deinit();
    try server.listen(address);
    print("faramoosh started\n", .{});

    while (true) {
        const connection = try server.accept();
        print("client connected", .{});
        handle_connection(allocator, connection, &hm) catch |err| {
            std.log.warn("client conneciton closed: {}", .{err});
        };
    }
}
