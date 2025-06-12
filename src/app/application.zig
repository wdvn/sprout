const glfw = @import("glfw");

pub const App = struct {
    window: *glfw.Window,
    pub fn New() App {
        return App{ .window = try glfw.createWindow(800, 640, "Hello World", null, null) };
    }
    pub fn Initialize(self: App) bool {
        try glfw.init();
        if (self.window == null) {
            self.window = try glfw.createWindow(800, 640, "Hello World", null, null);
        }

        return true;
    }
    pub fn Terminate(self: App) void {
        glfw.destroyWindow(self.window);
    }

    pub fn MainLoop(self:App) void {
        glfw.pollEvents();
    }

    pub fn IsRunning(self: App) bool {
        return !glfw.windowShouldClose(self.window);
    }
};
