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
    int64_t deletedChannel[TLW_MAX_DELETED]; // 0 = private chat / basic group
} TLWalkStats;
#define TLW_CAPTURE_TEXT   (1u << 3)
/// Called for every `message` constructor seen (text is NOT null-terminated).
typedef void (*TLWMessageCallback)(int64_t channelId, int32_t messageId, int32_t date, int32_t editDate,
                                   const char *text, size_t textLen);
void TLWSetMessageCallback(TLWMessageCallback cb);
/// Patches a TL payload in place. Returns 1 if the whole object was understood.
int TLWalkPatch(uint8_t *data, size_t len, uint32_t opts, TLWalkStats *stats);
const char *TLWalkSchemaLayer(void);
#ifdef __cplusplus
}
#endif
