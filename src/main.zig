const std = @import("std");
const glfw = @import("glfw"); // Import thư viện GLFW
const stdout = std.io.getStdOut().writer();

pub fn main() !void {

    // 1. Khởi tạo GLFW
    if (glfw.init() == glfw.FALSE) {
        std.debug.print("Lỗi: Không thể khởi tạo GLFW\n", .{});
        return error.GlfwInitFailed;
    }
    defer glfw.terminate(); // Đảm bảo glfw.terminate() được gọi khi hàm kết thúc

    // 2. Cấu hình gợi ý GLFW (tùy chọn)
    // Ví dụ: Đặt phiên bản OpenGL
    glfw.windowHint(glfw.CONTEXT_VERSION_MAJOR, 3);
    glfw.windowHint(glfw.CONTEXT_VERSION_MINOR, 3);
    glfw.windowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);
    glfw.windowHint(glfw.OPENGL_FORWARD_COMPAT, glfw.TRUE); // Cần thiết trên macOS

    // Vô hiệu hóa khả năng thay đổi kích thước cửa sổ nếu bạn không muốn
    // glfw.windowHint(glfw.RESIZABLE, glfw.FALSE);

    // 3. Tạo cửa sổ
    const width: i32 = 800;
    const height: i32 = 600;
    const title = "Cửa sổ GLFW đầu tiên của tôi trong Zig";

    const window = glfw.createWindow(width, height, title, null, null);
    if (window == null) {
        std.debug.print("Lỗi: Không thể tạo cửa sổ GLFW\n", .{});
        // Giải phóng tài nguyên GLFW đã được khởi tạo
        glfw.terminate();
        return error.GlfwCreateWindowFailed;
    }
    defer glfw.destroyWindow(window); // Đảm bảo cửa sổ được giải phóng

    // 4. Tạo ngữ cảnh OpenGL (hoặc Vulkan)
    glfw.makeContextCurrent(window);

    // 5. Vòng lặp sự kiện (Render Loop)
    std.debug.print("Cửa sổ đã được tạo thành công! Đang đợi sự kiện...\n", .{});

    while (!glfw.windowShouldClose(window)) {
        // Xử lý đầu vào (ví dụ: nhấn phím Esc để đóng cửa sổ)
        if (glfw.getKey(window, glfw.KEY_ESCAPE) == glfw.PRESS) {
            glfw.setWindowShouldClose(window, true);
        }

        // --- Mã vẽ của bạn ở đây ---
        // Ví dụ: Xóa màn hình với màu xanh
        glfw.clearColor(0.2, 0.3, 0.3, 1.0); // Màu xanh lam
        glfw.clear(glfw.COLOR_BUFFER_BIT);

        // Swap buffers (hiển thị hình ảnh đã vẽ lên màn hình)
        glfw.swapBuffers(window);

        // Xử lý các sự kiện (ví dụ: nhấp chuột, gõ phím)
        glfw.waitEvents(); // Chờ sự kiện (tiết kiệm CPU)
        // hoặc glfw.pollEvents(); // Xử lý sự kiện ngay lập tức (tiêu tốn CPU hơn nhưng phản hồi nhanh hơn)
    }

    std.debug.print("Cửa sổ đã đóng. Thoát ứng dụng.\n", .{});
}
