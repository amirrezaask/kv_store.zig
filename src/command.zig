const std = @import("std");
const errors = error{
    BadInput,
};
const CommandType = enum {
    Get,
    Set,
    Exit,
};
pub const Command = struct {
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
