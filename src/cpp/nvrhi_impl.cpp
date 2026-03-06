#include "nvrhi_impl.h"

#include <cstdint>

struct NvrhiState {
    std::uint64_t frame_index;
};

NvrhiState* nvrhi_init(void* window) {
    (void)window;

    auto* state = new NvrhiState();
    state->frame_index = 0;
    return state;
}

void nvrhi_render(NvrhiState* state) {
    if (!state) return;
    state->frame_index += 1;
}

void nvrhi_shutdown(NvrhiState* state) {
    delete state;
}
