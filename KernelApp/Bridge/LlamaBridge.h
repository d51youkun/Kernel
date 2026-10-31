// LlamaBridge.h
// llama.cpp C API を Objective-C でラップするブリッジ
// JIT 有効化後、llama.cpp は Metal (MAP_JIT) を使って GPU 推論できる

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// トークンのストリーミングコールバック
/// @param piece  生成されたテキストの断片 (isDone=NO のとき)
/// @param isDone 生成終了フラグ
/// @param error  エラー (nil のとき正常)
typedef void (^LlamaTokenCallback)(NSString * _Nullable piece,
                                   BOOL isDone,
                                   NSError * _Nullable error);

/// llama.cpp ラッパー。1 インスタンスで 1 モデルを保持する。
@interface LlamaBridge : NSObject

/// モデルがロード済みか
@property (nonatomic, readonly) BOOL isModelLoaded;
/// モデルの説明文字列 (例: "llama 3.2 1B Q4_0")
@property (nonatomic, readonly, nullable) NSString *modelDescription;

/// アプリ起動時に 1 回だけ呼ぶ
+ (void)initializeBackend;
/// アプリ終了時に呼ぶ
+ (void)freeBackend;

/// GGUF モデルをロードする (ブロッキング・専用キューから呼ぶこと)
- (BOOL)loadModelFromPath:(NSString *)path
            contextLength:(int32_t)contextLength
              nGpuLayers:(int32_t)nGpuLayers
                   error:(NSError **)error;

/// モデルをアンロードしてメモリを解放する
- (void)unloadModel;

/// 生成を中断する (スレッドセーフ)
- (void)cancelGeneration;

/// チャットメッセージ配列からストリーミング生成する
/// コールバックは内部シリアルキューから発火する
- (void)generateFromMessages:(NSArray<NSDictionary<NSString *, NSString *> *> *)messages
                maxNewTokens:(int32_t)maxNewTokens
                 temperature:(float)temperature
                        topK:(int32_t)topK
                        topP:(float)topP
               tokenCallback:(LlamaTokenCallback)callback;

@end

NS_ASSUME_NONNULL_END
