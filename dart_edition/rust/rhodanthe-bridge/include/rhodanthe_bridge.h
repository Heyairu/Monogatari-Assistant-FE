#ifndef RHODANTHE_BRIDGE_H
#define RHODANTHE_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#define RHODANTHE_API __declspec(dllimport)
#else
#define RHODANTHE_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct RhodantheHandle RhodantheHandle;

typedef struct RhodantheBuffer {
  uint8_t *data;
  size_t len;
  size_t capacity;
} RhodantheBuffer;

RHODANTHE_API uint32_t rhodanthe_abi_version(void);

/* Returns NULL only when engine allocation fails or a panic is contained. */
RHODANTHE_API RhodantheHandle *rhodanthe_engine_new(void);

/* NULL is accepted. A live handle must be released exactly once. */
RHODANTHE_API void rhodanthe_engine_free(RhodantheHandle *handle);

/*
 * Executes one UTF-8 JSON request. The input is borrowed only for this call.
 * The returned data is not NUL-terminated and must be released exactly once
 * with rhodanthe_buffer_free. Requests on one handle are serialized.
 */
RHODANTHE_API RhodantheBuffer rhodanthe_engine_request(
    const RhodantheHandle *handle,
    const uint8_t *input,
    size_t input_len);

RHODANTHE_API void rhodanthe_buffer_free(RhodantheBuffer buffer);

#ifdef __cplusplus
}
#endif

#endif
