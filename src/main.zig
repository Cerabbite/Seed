const std = @import("std");
const sokol = @import("sokol");
const sokol_app = sokol.app;
const sokol_gfx = sokol.gfx;
const sokol_glue = sokol.glue;
const sokol_log = sokol.log;

var pass_action = sokol_gfx.PassAction{};

fn init() callconv(.c) void {
    sokol_gfx.setup(.{
        .environment = sokol_glue.environment(),
        .logger = .{ .func = sokol_log.func }, // Fixed: uses sokol_log.func
    });

    pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.1, .g = 0.3, .b = 0.8, .a = 1.0 },
    };
}

fn frame() callconv(.c) void {
    sokol_gfx.beginPass(.{
        .action = pass_action,
        .swapchain = sokol_glue.swapchain(),
    });

    sokol_gfx.endPass();
    sokol_gfx.commit();
}

fn cleanup() callconv(.c) void {
    sokol_gfx.shutdown();
}

pub fn main() void {
    sokol_app.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .width = 800,
        .height = 600,
        .window_title = "Seed - 0.1.0",
        .icon = .{ .sokol_default = true },
        .logger = .{ .func = sokol_log.func }, // Fixed: uses sokol_log.func
    });
}
