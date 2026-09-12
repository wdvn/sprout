# Roadmap Final: UI Engine + ECS + Shader trên Sokol (WebGL)

Engine general purpose, không OOP, đủ sức làm Android XML, Diablo Inventory, PoE Skill Tree.

---

## PHASE 0: Core Foundation
- [ ] `sokol_app` wrapper - window, loop
- [ ] `sokol_gfx` wrapper - 2 queue: 3D Queue (WebGL) và UI Queue
- [ ] Input System: Mouse, Keyboard, Scroll -> `UIEvent { x, y, type, button }`
- [ ] File System: `assets://` abstraction + file watcher (hot reload)
- [ ] ECS World: `jecs` / `flecs-zig` hoặc sparse set tự viết. World chứa cả game entity và UI entity.

---

## PHASE 1: Resource Manager
- [ ] **Texture Manager:** Load PNG -> `sg_image`. Quản lý Atlas.
- [ ] **Atlas System:**
  - `SpriteAtlas`: icon, frame UI
  - `FontAtlas`: `sokol_fontstash` + SDF font (để làm glow/outline)
- [ ] **Shader Library (Resource, không phải Component):**
```zig
var shader_lib: HashMap(u32, ShaderAsset) = .{
    .ui_default = { sg_shader, sg_pipeline }, // rect + texture
    .ui_nine_slice = {}, // khung đá Diablo
    .ui_sdf_text = {},   // chữ có outline/glow
    .ui_item_preview = {}, // render 3D item vào UI
};
```

---

## PHASE 2: UI Runtime - ECS Components

### Components (Data thuần)
```zig
const Parent = struct { entity: Entity };
const Children = struct { list: List(Entity) };
const Layout = struct { // Input cho layout engine
    width: Size, height: Size, // AUTO, FIXED, PERCENT, GROW
    direction: enum { ROW, COLUMN }, padding: Vec4, margin: Vec4, gap: f32, grow: f32,
};
const Style = struct { // Tách khỏi Layout
    background: enum { NONE, COLOR, IMAGE, NINE_SLICE }, nine_slice_id: u32, color: u32,
};
const ComputedBounds = struct { x, y, w, h: f32 }; // Output của layout
const ComputedClip = struct { x, y, w, h: f32 };
const Text = struct { content: []u8, font_id: u32, size: f32 };
const Interactable = struct { clickable: bool, draggable: bool };
const State = struct { hovered: bool, pressed: bool, focused: bool };
const Id = struct { id: u64 };
const Material = struct { // Gắn shader vào entity
    shader_id: u32, texture_id: u32, color: u32,
    params: struct { glow: f32, outline: f32 },
};
```

### Systems
- [ ] **Layout System:** Query root (không có Parent) -> dùng Clay/Yoga tính `ComputedBounds`. Chạy khi Layout dirty.
- [ ] **Style System:** Query (Style, State, Tag) -> đổi màu theo theme `theme.json` (hover/pressed)
- [ ] **Interaction System:** Hit test (ComputedBounds) -> set State.hovered -> tạo Event Entity `ClickEvent{ target }`
- [ ] **DragDrop System (Global):** `Dragging { payload, ghost }`, `DropTarget { accepted }`. Ghost entity theo chuột.
- [ ] **Render System (Batch):** Query (ComputedBounds, Material, Text) -> push vào `RenderCommand[]` -> sort by `shader_id + texture_id` -> flush.

**Thứ tự chạy mỗi frame:**
```
fileWatcher -> layout -> style -> interaction -> drag -> gameAction -> render -> batchFlush
```

---

## PHASE 3: Rendering & Shader - Làm nên chất Diablo

### Batch Renderer
- Đừng `sg.applyPipeline` cho mỗi button. Gom lại.
- `RenderCommand { shader_id, texture_id, bbox, uv, color, clip }`
- Sort -> 100 button cùng shader = 1 draw call.

### Shader UI (Ánh sáng giả, không phải light thật)
UI Diablo/PoE không dùng light position. Dùng fake lighting vẽ sẵn.

1. **ui_default.glsl:** rect + atlas
2. **ui_nine_slice.glsl:** 9-patch. Giữ 4 góc, scale cạnh. Bắt buộc cho khung đá.
3. **ui_sdf_text.glsl:** SDF font -> outline, glow, emboss không cần texture riêng.
```glsl
float dist = texture(atlas, uv).a;
float alpha = smoothstep(0.5 - glow, 0.5 + glow, dist);
```
4. **Fake Light trong Nine-Slice:** Lưu height map ở kênh Alpha của atlas, tính light cố định trong shader:
```glsl
vec3 normal = decodeNormal(texture(atlas, uv).a);
float light = dot(normal, vec3(0.5, 0.5, 1.0));
frag_color.rgb *= light;
```

### 3D trong UI (Item Preview xoay)
- Tạo `sg_image` render target offscreen
- Render model 3D (kiếm) bằng WebGL pipeline + 1 light vào render target
- Dùng render target làm texture cho `ui_default` để vẽ lên slot inventory

---

## PHASE 4: Layout Primitives (ECS Entities)
- [ ] Primitives: `Div`, `Text`, `Image`, `Button` (thực chất là entity có bộ component khác nhau)
- [ ] Layouts:
  - `StackLayout` (ROW/COLUMN) -> LinearLayout Android
  - `GridLayout` (rows, cols, cellSize) -> Nền cho Inventory
  - `CanvasLayout` (infinite, zoomable) -> Nền cho Skill Tree / Minimap
- [ ] `ScrollView`: clip + scroll offset
- [ ] `TextInput`: caret, selection

---

## PHASE 5: Event là Entity
- [ ] Không dùng callback. Click tạo ra Event Entity:
```zig
world.newEntity().set(ClickEvent{ .target = btn }).set(EquipAction{ .item_id = 123 });
```
- [ ] Game logic query Event Entity:
```zig
fn inventorySystem(world: *World) void {
    for (world.query(.{ClickEvent, EquipAction})) |e| { world.destroy(e); }
}
```
- [ ] Lợi ích: Inventory query slot trống cực nhanh, Skill Tree 2000 node query 1 lần.

---

## PHASE 6: Advanced Compositions (Game-specific nhưng dùng lại Engine)
- [ ] **Inventory:** Dùng `GridLayout` + `DragDropSystem` + `TooltipManager` (layer global render sau cùng)
- [ ] **Skill Tree:** Dùng `CanvasLayout` + custom render `onCustomRender = (ctx) => drawLines(connections)`
- [ ] **Context Menu / Tooltip Manager:** 1 entity global, theo chuột

---

## PHASE 7: Workflow & Tooling
- [ ] **XML Loader -> ECS:** `loadXml(world, node)` tạo entity + gắn component. Cho phép `registerWidget("InventoryGrid", ...)`
- [ ] **Hot Reload:** XML đổi -> destroy old UI entities -> load lại, giữ State nếu có thể
- [ ] **Theme Hot Reload:** `theme.json` đổi -> StyleSystem cập nhật ngay
- [ ] **Debug Overlay:** Vẽ bbox, layout info (Chrome DevTools), draw calls, FPS
- [ ] **Atlas Builder Tool:** Pack `*.png` -> `atlas.png + atlas.json`

---

## PHASE 8: Polish & Performance
- [ ] Dirty Check: Chỉ re-layout khi Layout/Children dirty
- [ ] Animation System: `animate(entity, .{ .alpha = 0 }, .{ .duration = 0.2 })`
- [ ] Gamepad Navigation: Focus ring
- [ ] Text Shaping: Harfbuzz nếu cần i18n

---

## Cấu trúc thư mục
```
/src
  /ecs/world.zig
  /gfx
    webgl.zig
    batch_renderer.zig
    nine_slice.zig
    shader_manager.zig
  /ui
    /components/{layout, style, bounds, material, interact}.zig
    /systems/{layout, style, interaction, drag, render, action}.zig
    /loader/xml_loader.zig
/assets
  /ui/{hud.xml, inventory.xml}
  /shaders/{ui_default.glsl, ui_nine_slice.glsl, ui_sdf_text.glsl}
  /atlas/{ui_atlas.png, ui_atlas.json}
  /theme/theme.json
```

## Checklist bắt đầu
1. 5 component đầu: Parent, Children, Layout, ComputedBounds, Style
2. shader_manager + 2 shader đầu: ui_default, ui_nine_slice
3. layoutSystem dùng Clay
4. renderSystem batch
=> Chạy được là đã có engine.
