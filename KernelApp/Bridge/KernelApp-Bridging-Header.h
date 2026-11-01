#import "LlamaBridge.h"
#import "DebuggerBridge.h"

#include <sys/types.h>
int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);

int ptrace(int request, pid_t pid, caddr_t addr, int data);
