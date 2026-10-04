// 這個檔案從原專案複製即可，提供 getRealOffset() 等工具
// 如果沒有，建立一個簡易版：
#ifndef CAPTAIN_HOOK_H
#define CAPTAIN_HOOK_H

#include <mach-o/dyld.h>
#include <stdint.h>

static inline uint64_t getRealOffset(uint64_t offset) {
    // ASLR slide 修正
    const struct mach_header *header = _dyld_get_image_header(0);
    uint64_t slide = (uint64_t)header - 0x100000000; // 通常基址
    return offset + slide;
}

#endif
