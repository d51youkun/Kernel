#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol KernelDebuggerRunner
- (void)run:(NSString *)operation pid:(int32_t)pid pairing:(NSData *)data;
@end
@protocol KernelDebuggerHost
- (void)ready;
- (void)log:(NSString *)line;
- (void)finished:(BOOL)success detail:(NSString *)detail;
@end

@interface DebuggerBridge : NSObject
+ (BOOL)debugged;
+ (BOOL)hasDebugEntitlement;
+ (BOOL)prepareExecutableProbe;
- (void)launchWithHost:(id<KernelDebuggerHost>)host completion:(void (^)(id<KernelDebuggerRunner> _Nullable runner, NSError * _Nullable error))completion;
- (void)invalidate;
@end
NS_ASSUME_NONNULL_END
