// TLWalker: schema-driven, in-place walker for MTProto TL payloads.
//
// Replaces the old approach of bundling a full copy of Telegram's generated Swift
// `Api` (which had to exactly match the client build, so it broke on every layer bump).
// The schema table is generated at build time from the newest Swiftgram + tdesktop
// schemas (scripts/gen_schema.py), and every patch done here only flips flag bits or
// rewrites fixed-size integers, so the payload length/layout never changes and no
// re-serialisation is needed. Unknown constructors stop the walk safely: every edit
// made before that point is still valid.

#include "TLWalker.h"
#define TL_SCHEMA_TABLES 1
#include "TLSchema.h"
#include <string.h>
#include <stdlib.h>

#define MAX_DEPTH 64

typedef struct {
    uint8_t *p;
    size_t len;
    size_t off;
    uint32_t opts;
    TLWalkStats *stats;
} Walker;

static const TLCtor *findCtor(uint32_t id) {
    size_t lo = 0, hi = TL_CTOR_COUNT;
    while (lo < hi) {
        size_t mid = (lo + hi) / 2;
        uint32_t v = kTLCtors[mid].id;
        if (v == id) return &kTLCtors[mid];
        if (v < id) lo = mid + 1; else hi = mid;
    }
    return NULL;
}

static int readU32(Walker *w, uint32_t *out) {
    if (w->off + 4 > w->len) return 0;
    memcpy(out, w->p + w->off, 4);
    w->off += 4;
    return 1;
}

static int skip(Walker *w, size_t n) {
    if (w->off + n > w->len) return 0;
    w->off += n;
    return 1;
}

static int skipString(Walker *w) {
    if (w->off >= w->len) return 0;
    size_t n = w->p[w->off];
    size_t total;
    if (n < 254) {
        total = 1 + n;
    } else {
        if (w->off + 4 > w->len) return 0;
        n = (size_t)w->p[w->off + 1] | ((size_t)w->p[w->off + 2] << 8) | ((size_t)w->p[w->off + 3] << 16);
        total = 4 + n;
    }
    total = (total + 3) & ~(size_t)3;
    return skip(w, total);
}

static int walkBoxed(Walker *w, int depth);

static int walkValue(Walker *w, uint8_t kind, uint8_t elem, int depth);

static int walkVectorBody(Walker *w, uint8_t elem, int depth, size_t *firstElem, uint32_t *countOut) {
    uint32_t count;
    if (!readU32(w, &count)) return 0;
    if (count > (w->len - w->off)) return 0; // every element is >= 1 byte; sanity bound
    if (firstElem) *firstElem = w->off;
    if (countOut) *countOut = count;
    for (uint32_t i = 0; i < count; i++) {
        if (!walkValue(w, elem, 0, depth + 1)) return 0;
    }
    return 1;
}

static int walkValue(Walker *w, uint8_t kind, uint8_t elem, int depth) {
    switch (kind) {
        case 1: case 8: return skip(w, 4);
        case 2: case 3: return skip(w, 8);
        case 4: return skip(w, 16);
        case 5: return skip(w, 32);
        case 6: return skipString(w);
        case 7: return 1;
        case 9: return walkBoxed(w, depth + 1);
        case 10: {
            uint32_t sig;
            if (!readU32(w, &sig) || sig != TLC_vector) return 0;
            return walkVectorBody(w, elem, depth, NULL, NULL);
        }
        case 11: return walkVectorBody(w, elem, depth, NULL, NULL);
        default: return 0;
    }
}

static void clearBit(Walker *w, size_t flagsOff, int bit) {
    uint32_t v;
    memcpy(&v, w->p + flagsOff, 4);
    if (v & (1u << bit)) {
        v &= ~(1u << bit);
        memcpy(w->p + flagsOff, &v, 4);
        if (w->stats) w->stats->noforwardsCleared++;
    }
}

static int walkBoxed(Walker *w, int depth) {
    if (depth > MAX_DEPTH) return 0;
    uint32_t id;
    if (!readU32(w, &id)) return 0;

    if (id == TLC_vector) {
        // Untyped vector at top level (e.g. Vector<int>, Vector<User>). Peek the first
        // element: if it is a known constructor, treat as boxed elements; otherwise we
        // cannot know the bare element size, so stop (nothing to patch inside anyway).
        uint32_t count;
        if (!readU32(w, &count)) return 0;
        for (uint32_t i = 0; i < count; i++) {
            if (w->off + 4 > w->len) return 0;
            uint32_t peek; memcpy(&peek, w->p + w->off, 4);
            if (!findCtor(peek)) return 0;
            if (!walkBoxed(w, depth + 1)) return 0;
        }
        return 1;
    }

    const TLCtor *c = findCtor(id);
    if (!c) return 0;

    size_t fieldOffsets[64];
    uint32_t flagValues[64] = {0};
    int n = c->fieldCount > 64 ? 64 : c->fieldCount;

    for (int i = 0; i < n; i++) {
        const TLField *f = &kTLFields[c->fieldStart + i];
        fieldOffsets[i] = w->off;
        if (f->flagField != 255) {
            uint32_t fv = flagValues[f->flagField];
            if (!(fv & (1u << f->bit))) continue;
        }
        if (f->kind == 8) {
            if (w->off + 4 > w->len) return 0;
            memcpy(&flagValues[i], w->p + w->off, 4);
        }

        // Anti-delete: neutralise the deleted id list in place (ids -> 0, a no-op delete).
        if ((w->opts & TLW_ANTI_DELETE) && f->kind == 10 &&
            ((id == TLC_updateDeleteMessages && i == TLF_updateDeleteMessages_messages) ||
             (id == TLC_updateDeleteChannelMessages && i == TLF_updateDeleteChannelMessages_messages))) {
            uint32_t sig, count;
            if (!readU32(w, &sig) || sig != TLC_vector) return 0;
            if (!readU32(w, &count)) return 0;
            if ((size_t)count * 4 > w->len - w->off) return 0;
            for (uint32_t k = 0; k < count; k++) {
                int32_t mid; memcpy(&mid, w->p + w->off + k * 4, 4);
                if (w->stats && mid != 0) {
                    if (w->stats->deletedCount < TLW_MAX_DELETED) w->stats->deletedIds[w->stats->deletedCount++] = mid;
                }
                memset(w->p + w->off + k * 4, 0, 4);
            }
            w->off += (size_t)count * 4;
            continue;
        }

        if (!walkValue(w, f->kind, f->elem, depth)) return 0;
    }

    // Constructor fully parsed: apply flag patches (layout-neutral, 'true' flags carry no data).
    if (w->opts & TLW_NOFORWARDS) {
        for (int k = 0; k < TL_NOFORWARDS_COUNT; k++) {
            if (kTLNoForwards[k].id == id && kTLNoForwards[k].flagField < n) {
                clearBit(w, fieldOffsets[kTLNoForwards[k].flagField], kTLNoForwards[k].bit);
            }
        }
    }
    if ((w->opts & TLW_LOCAL_PREMIUM) && id == TLC_user && n > 0) {
        uint32_t v; memcpy(&v, w->p + fieldOffsets[0], 4);
        if ((v & (1u << 10)) && !(v & (1u << 28))) { // self && !premium
            v |= (1u << 28);
            memcpy(w->p + fieldOffsets[0], &v, 4);
        }
    }
    return 1;
}

int TLWalkPatch(uint8_t *data, size_t len, uint32_t opts, TLWalkStats *stats) {
    if (!data || len < 4 || !opts) return 0;
    Walker w = { data, len, 0, opts, stats };
    return walkBoxed(&w, 0);
}

const char *TLWalkSchemaLayer(void) { return TL_SCHEMA_LAYER; }
