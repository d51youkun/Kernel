#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^LlamaTokenCallback)(NSString * _Nullable piece,
                                   BOOL isDone,
                                   NSError * _Nullable error);

@interface LlamaBridge : NSObject

@property (nonatomic, readonly) BOOL isModelLoaded;
@property (atomic, readonly) BOOL reachedTokenLimit;
@property (nonatomic, readonly, nullable) NSString *modelDescription;

@property (nonatomic, assign) int32_t contextLength;
@property (nonatomic, assign) int32_t nGpuLayers;
@property (nonatomic, assign) int32_t nThreads;
@property (nonatomic, assign) float temperature;
@property (nonatomic, assign) int32_t topK;
@property (nonatomic, assign) float topP;
@property (nonatomic, assign) int32_t maxNewTokens;

+ (void)initializeBackend;
+ (void)freeBackend;

- (BOOL)loadModelFromPath:(NSString *)path error:(NSError **)error;
- (void)unloadModel;

- (void)generateFromMessages:(NSArray<NSDictionary<NSString *, NSString *> *> *)messages
               tokenCallback:(LlamaTokenCallback)callback;
- (void)cancelGeneration;
- (void)waitUntilIdle:(void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END
