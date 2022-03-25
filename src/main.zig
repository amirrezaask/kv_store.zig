const std = @import("std");
const Command = @import("command.zig").Command;
const print = std.debug.print;
const net = std.net;
const HashMap = std.StringHashMap([]const u8);
const StreamServer = std.net.StreamServer;
const Connection = std.net.StreamServer.Connection;
const Stream = std.net.Stream;
const Address = std.net.Address;
const Allocator = std.mem.Allocator;

// async babyyyyyyyy !!!
pub const io_mode = .evented;

const Client = struct {
    frame: @Frame(handle) = undefined,
    stream: Stream,
    store: *HashMap,
    allocator: Allocator,

    pub fn handle(self: *Client) !void {
        print("in handle\n", .{});
        try self.stream.writer().print("Welcome To Framoosh\nAvailable commands are:\n\tGET key\n\tSET key value\n", .{});
        defer self.stream.close();
        while (true) {
            var user_input = try self.stream.reader().readUntilDelimiterAlloc(self.allocator, '\n', std.math.maxInt(u64));
            // handle \r since in telnet <enter> do \r\n
            user_input = user_input[0..user_input.len];
            const command = try Command.init(user_input);
            switch (command.cmd_ty) {
                .Get => {
                    const value = self.store.get(command.payload.get.key) orelse {
                        try self.stream.writer().print("key {s} does not exists\n", .{command.payload.get.key});
                        continue;
                    };
                    try self.stream.writer().print("{s}\n", .{value});
                },
                .Set => {
                    try self.store.put(command.payload.set.key, command.payload.set.value);
                    try self.stream.writer().print("OK\n", .{});
                },
                .Exit => {
                    return;
                },
            }
        }
    }
};
pub fn main() !void {
    const ip = "127.0.0.1"; //take this from user flags ?
    const port = 0; //take this from user flags ?
    print("Async mode is {}\n", .{std.io.is_async});
    // memory allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Client frames, we need to store frames because we run handle_connection in loop
    // and every iteration we loose last frame.
    var clients = std.ArrayList(*Client).init(allocator);

    var hm = HashMap.init(allocator);
    defer hm.deinit();

    const address = try net.Address.resolveIp(ip, port);
    var server = std.net.StreamServer.init(.{});
    defer _ = server.deinit();

    try server.listen(address);
    print("faramoosh started on {}\n", .{server.listen_address});
    print("Connect using \"nc localhost {}\"\n", .{server.listen_address.getPort()});

    while (true) {
        print("clients count: {}\n", .{clients.items.len});
        const client = try allocator.create(Client);
        const stream = (try server.accept()).stream;
        client.* = .{ .allocator = allocator, .store = &hm, .stream = stream, .frame = async client.handle() };
        try clients.append(client);
    }
}
