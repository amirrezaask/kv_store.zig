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
};
const Command = struct {
    cmd_ty: CommandType,
    args: [][]const u8,
    pub fn init(input: []u8) !Command {
        var iter = std.mem.split(u8, input, " ");
        const ty = iter.next().?;
        if (std.mem.eql(u8, ty, "GET")) {
            return Command{ .cmd_ty = CommandType.Get, .args = &[1][]const u8{iter.next().?} };
        }
        if (std.mem.eql(u8, ty, "SET")) {
            return Command{
                .cmd_ty = CommandType.Set,
                .args = &[2][]const u8{ iter.next().?, iter.next().? },
            };
        }
        return errors.BadInput;
    }
};

fn handle_connection(allocator: Allocator, conn: Connection, store: *HashMap) !void {
    while (true) {
        var user_input = try conn.stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(u64));
        user_input = user_input[0 .. user_input.len - 1];
        print("user input <{s}>\n", .{user_input});
        const command = try Command.init(user_input);
        const arg1 = command.args[0];
        print("command type is {}\n", .{command.cmd_ty});
        print("command arg 1 is <{s}>\n", .{arg1});
        switch (command.cmd_ty) {
            .Get => {
                const value = store.get(arg1) orelse {
                    print("key {s} does not exists\n", .{arg1});
                    try conn.stream.writer().print("key {s} does not exists\n", .{arg1});
                    continue;
                };
                try conn.stream.writer().print("{s}\n", .{value});
            },
            .Set => {
                const arg2 = command.args[1];
                print("command arg 2 is {s}\n", .{arg2});
                try store.put(arg1, arg2);
                try conn.stream.writer().print("OK\n", .{});
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
        defer connection.stream.close();
        try handle_connection(allocator, connection, &hm);
    }
}
