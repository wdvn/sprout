#ifndef RENDERER_H
#define RENDERER_H

#include "microui.h"

mu_Context* microui_init();
void microui_render_commands(int width, int height);
void microui_draw();

// TODO don't expose these, reimplement in Zig instead
int microui_text_width_cb(mu_Font font, const char* text, int len);
int microui_text_height_cb(mu_Font font);

void microui_debug_stuff();

void r_begin(int disp_width, int disp_height);
void r_end(void);
void r_push_quad(mu_Rect dst, mu_Rect src, mu_Color color);
void r_draw_rect(mu_Rect rect, mu_Color color);
void r_draw_text(const char* text, mu_Vec2 pos, mu_Color color);
void r_draw_icon(int id, mu_Rect rect, mu_Color color);
void r_set_clip_rect(mu_Rect rect);

#endif
