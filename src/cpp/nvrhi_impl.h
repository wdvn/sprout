#ifndef NVRHI_IMPL_H
#define NVRHI_IMPL_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NvrhiState NvrhiState;

// Initialize NVRHI. 
// Note: This implementation embeds shaders directly, so no shader arguments are needed.
NvrhiState* nvrhi_init(void* window);

void nvrhi_render(NvrhiState* state);

void nvrhi_shutdown(NvrhiState* state);

#ifdef __cplusplus
}
#endif

#endif
