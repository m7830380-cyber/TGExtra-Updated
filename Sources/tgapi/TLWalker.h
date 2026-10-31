#pragma once
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
#define TLW_NOFORWARDS     (1u << 0)
#define TLW_ANTI_DELETE    (1u << 1)
#define TLW_LOCAL_PREMIUM  (1u << 2)
#define TLW_MAX_DELETED 256
typedef struct {
    uint32_t noforwardsCleared;
    uint32_t deletedCount;
    int32_t deletedIds[TLW_MAX_DELETED];
} TLWalkStats;
/// Patches a TL payload in place. Returns 1 if the whole object was understood.
int TLWalkPatch(uint8_t *data, size_t len, uint32_t opts, TLWalkStats *stats);
const char *TLWalkSchemaLayer(void);
#ifdef __cplusplus
}
#endif
