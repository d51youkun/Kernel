// LlamaBridge.h
// llama.cpp C API を Objective-C でラップするブリッジ
// StickJIT で JIT が有効になった後、llama.cpp が MAP_JIT メモリを使えるようになる

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// トークンのストリーミングコールバック
/// @param piece    生成されたテキストの断片（isDone=NO のとき）
/// @param isDone   生成終了フラグ
/// @param error    エラー（nil のとき正常）
typedef void (^LlamaTokenCallback)(NSString * _Nullable piece,
                                   BOOL isDone,
                                   NSError * _Nullable error);

/// llama.cpp ラッパー。1インスタンスで1モデルを保持する。
@interface LlamaBridge : NSObject

// ── 状態 ──────────────────────────────────────
@property (nonatomic, readonly) BOOL isModelLoaded;
/// モデルの説明文字列（例: "llama 7B Q4_0"）
@property (nonatomic, readonly, nullable) NSString *modelDescription;

// ── 推論パラメータ ────────────────────────────
/// コンテキスト長（デフォルト 4096）
@property (nonatomic, assign) int32_t contextLength;
/// Metal GPU に渡すレイヤー数（99 = 全レイヤー）
@property (nonatomic, assign) int32_t nGpuLayers;
/// 温度（0.0〜2.0、デフォルト 0.8）
@property (nonatomic, assign) float temperature;
/// Top-K（デフォルト 40）
@property (nonatomic, assign) int32_t topK;
/// Top-P（デフォルト 0.95）
@property (nonatomic, assign) float topP;
/// 1回の生成で出力する最大トークン数（デフォルト 1024）
@property (nonatomic, assign) int32_t maxNewTokens;

// ── ライフサイクル ──────────────────────────
/// アプリ起動時に1回だけ呼ぶ
+ (void)initializeBackend;
/// アプリ終了時に呼ぶ
+ (void)freeBackend;

/// GGUFファイルをロードする（ブロッキング）
- (BOOL)loadModelFromPath:(NSString *)path error:(NSError **)error;

/// モデルをアンロードしメモリを解放する
- (void)unloadModel;

// ── 生成 ───────────────────────────────────
/// チャット履歴を渡してトークンをストリーミング生成する
/// @param messages [{"role": "user"/"assistant"/"system", "content": "..."}] の配列
/// @param callback 各トークンを受け取るコールバック（バックグラウンドスレッドから呼ばれる）
- (void)generateFromMessages:(NSArray<NSDictionary<NSString *, NSString *> *> *)messages
               tokenCallback:(LlamaTokenCallback)callback;

/// 生成を中断する（コールバックで isDone=YES が届く）
- (void)cancelGeneration;

@end

NS_ASSUME_NONNULL_END
