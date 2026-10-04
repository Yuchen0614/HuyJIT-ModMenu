#ifndef NAKANO_YOTSUBA_H
#define NAKANO_YOTSUBA_H

#include "dobby.h"

// ===== 加密宏（防止靜態分析）=====
#define ENCRYPTOFFSET(x) (x)
#define ENCRYPTHEX(x) (x)

// ===== 目標 Binary =====
#define TARGET_BINARY "UnityFramework"

// ===== 你的功能 Offset =====
// 攻擊力 getter (你在 dnSpy 找到的 RVA)
#define OFFSET_GET_ATTACK "0x2BE5EA4"

// 如果有其他功能，在這裡繼續加
// #define OFFSET_GET_HEALTH "0xXXXXXXX"
// #define OFFSET_SPEND_GEMS "0xYYYYYYY"

// ===== Patch 用 Hex (若用 vm_write 而非 Hook) =====
// 通常 Hook 不需要這些，保留給 vm_patch 用
#define ORIGINAL_ATTACK_HEX "00008052C0035FD6"  // 原始指令 bytes
#define PATCH_ATTACK_HEX "1F040071"             // mov w0, #9999; ret (範例)

#endif // NAKANO_YOTSUBA_H
