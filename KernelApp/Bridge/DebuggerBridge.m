#import "DebuggerBridge.h"
#import <objc/message.h>
#import <dlfcn.h>
#import <sys/mman.h>
#import <libkern/OSCacheControl.h>
#import <TargetConditionals.h>

extern int csops(pid_t, unsigned int, void *, size_t);

@implementation DebuggerBridge {
    NSXPCListener *_listener;
    NSXPCConnection *_connection;
    id _extension;
    id<KernelDebuggerHost> _host;
    void (^_completion)(id<KernelDebuggerRunner>, NSError *);
}
+ (BOOL)debugged {
#if TARGET_OS_SIMULATOR
    return NO;
#else
    uint32_t flags = 0;
    return csops(getpid(), 0, &flags, sizeof(flags)) == 0 && (flags & 0x10000000) != 0;
#endif
}
+ (BOOL)hasDebugEntitlement {
    CFTypeRef (*create)(CFAllocatorRef) = dlsym(RTLD_DEFAULT, "SecTaskCreateFromSelf");
    CFTypeRef (*copy)(CFTypeRef, CFStringRef, CFErrorRef *) = dlsym(RTLD_DEFAULT, "SecTaskCopyValueForEntitlement");
    if (!create || !copy) return NO;
    CFTypeRef task = create(NULL); if (!task) return NO;
    CFTypeRef value = copy(task, CFSTR("get-task-allow"), NULL);
    BOOL allowed = value && CFEqual(value, kCFBooleanTrue);
    if (value) CFRelease(value); CFRelease(task); return allowed;
}
#if defined(__arm64__) && !TARGET_OS_SIMULATOR
__attribute__((noinline, optnone, naked)) static void *KernelPrepare(void *address, size_t length) {
    __asm__("mov x16, #1\n brk #0xf00d\n ret\n");
}
__attribute__((noinline, optnone, naked)) static void KernelDetach(void) {
    __asm__("mov x16, #0\n brk #0xf00d\n ret\n");
}
#endif
+ (BOOL)prepareExecutableProbe {
#if defined(__arm64__) && !TARGET_OS_SIMULATOR
    if (![self debugged]) return NO;
    size_t length = (size_t)getpagesize();
    void *memory = mmap(NULL, length, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
    if (memory == MAP_FAILED) return NO;
    uint32_t instructions[] = {0x52800540, 0xD65F03C0}; // mov w0, #42; ret
    memcpy(memory, instructions, sizeof(instructions));
    // Only used after explicitly requesting the universal script in our helper.
    void *prepared = KernelPrepare(memory, length);
    BOOL valid = prepared == memory && mprotect(memory, length, PROT_READ | PROT_EXEC) == 0;
    if (valid) { sys_icache_invalidate(memory, sizeof(instructions)); valid = ((int (*)(void))memory)() == 42; }
    KernelDetach();
    munmap(memory, length);
    return valid;
#else
    return NO;
#endif
}
- (void)launchWithHost:(id<KernelDebuggerHost>)host completion:(void (^)(id<KernelDebuggerRunner>, NSError *))completion {
    _host = host; _completion = [completion copy];
    _listener = NSXPCListener.anonymousListener; _listener.delegate = (id<NSXPCListenerDelegate>)self; [_listener resume];
    NSError *error = nil;
    Class cls = NSClassFromString(@"NSExtension");
    SEL create = NSSelectorFromString(@"extensionWithIdentifier:excludingDisabledExtensions:error:");
    if ([cls respondsToSelector:create]) {
        _extension = ((id (*)(id, SEL, id, BOOL, NSError **))objc_msgSend)(cls, create, [NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".Debugger"], NO, &error);
    }
    NSExtensionItem *item = [NSExtensionItem new]; item.userInfo = @{@"KernelEndpoint": _listener.endpoint};
    SEL begin = NSSelectorFromString(@"beginExtensionRequestWithInputItems:error:");
    id request = nil;
    if ([_extension respondsToSelector:begin]) request = ((id (*)(id, SEL, id, NSError **))objc_msgSend)(_extension, begin, @[item], &error);
    if (!request) { [self fail:error.localizedDescription ?: @"デバッガ拡張を起動できません。この署名方式が拡張を保持しているか確認してください。"]; return; }
    __weak DebuggerBridge *weak = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [weak fail:@"デバッガ拡張の接続がタイムアウトしました。"]; });
}
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)connection {
    if (_connection) return NO;
    _connection = connection;
    connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(KernelDebuggerHost)];
    connection.exportedObject = _host;
    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(KernelDebuggerRunner)];
    [connection resume];
    id proxy = [connection remoteObjectProxyWithErrorHandler:^(NSError *error) { [self->_host finished:NO detail:error.localizedDescription]; }];
    if (_completion) { _completion(proxy, nil); _completion = nil; }
    return YES;
}
- (void)fail:(NSString *)message {
    if (_completion) { _completion(nil, [NSError errorWithDomain:@"Kernel.Debugger" code:1 userInfo:@{NSLocalizedDescriptionKey:message}]); _completion = nil; }
}
- (void)invalidate { [_connection invalidate]; [_listener invalidate]; _connection = nil; _listener = nil; _extension = nil; _host = nil; _completion = nil; }
@end
