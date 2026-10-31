// KernelApp-Bridging-Header.h
// ObjC++ の LlamaBridge を Swift から使うためのブリッジヘッダー

#import "LlamaBridge.h"

// csops: コード署名フラグ取得（JIT判定用）
#include <sys/types.h>
int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);

// ptrace: JIT自己有効化 (iOS SDKにヘッダーなし、直接宣言)
int ptrace(int request, pid_t pid, caddr_t addr, int data);
