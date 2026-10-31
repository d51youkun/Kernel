// LlamaBridge.mm
// llama.cpp C API の Objective-C++ ラッパー実装
// b12020 の llama.h に対して API を検証済み

#import "LlamaBridge.h"

#include <llama.h>

#include <atomic>
#include <string>
#include <vector>
#include <cstring>

// ─────────────────────────────────────────────
// MARK: - エラードメイン
// ─────────────────────────────────────────────

static NSErrorDomain const LlamaErrorDomain = @"com.kernel.LlamaError";
typedef NS_ERROR_ENUM(LlamaErrorDomain, LlamaError) {
    LlamaErrorModelLoad   = 100,
    LlamaErrorContextInit = 101,
    LlamaErrorTokenize    = 102,
    LlamaErrorDecode      = 103,
    LlamaErrorNoModel     = 104,
    LlamaErrorPromptTooLong = 105,
};

// ─────────────────────────────────────────────
// MARK: - LlamaBridge 実装
// ─────────────────────────────────────────────

@implementation LlamaBridge {
    llama_model   *_model;
    llama_context *_ctx;
    dispatch_queue_t _genQueue;        // ロード・生成専用シリアルキュー
    std::atomic<bool> _shouldCancel;
}

// ── バックエンド ──────────────────────────────

+ (void)initializeBackend {
    llama_backend_init();
}

+ (void)freeBackend {
    llama_backend_free();
}

// ── 初期化・解放 ────────────────────────────

- (instancetype)init {
    if (self = [super init]) {
        _model        = nullptr;
        _ctx          = nullptr;
        _genQueue     = dispatch_queue_create("com.kernel.llama.gen", DISPATCH_QUEUE_SERIAL);
        _shouldCancel = false;
    }
    return self;
}

- (void)dealloc {
    [self unloadModel];
}

// ── プロパティ ──────────────────────────────

- (BOOL)isModelLoaded { return _model != nullptr; }

- (nullable NSString *)modelDescription {
    if (!_model) return nil;
    char buf[256] = {0};
    llama_model_desc(_model, buf, sizeof(buf));
    return [NSString stringWithUTF8String:buf];
}

// ── モデルロード ────────────────────────────

- (BOOL)loadModelFromPath:(NSString *)path
            contextLength:(int32_t)contextLength
               nGpuLayers:(int32_t)nGpuLayers
                    error:(NSError **)error {
    [self unloadModel];

    llama_model_params mparams = llama_model_default_params();
    mparams.n_gpu_layers = nGpuLayers;

    _model = llama_model_load_from_file(path.UTF8String, mparams);
    if (!_model) {
        if (error) {
            *error = [NSError errorWithDomain:LlamaErrorDomain
                                         code:LlamaErrorModelLoad
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:
                                                        @"モデルのロードに失敗しました: %@\nGGUFファイルが壊れていないか確認してください",
                                                        path.lastPathComponent]}];
        }
        return NO;
    }

    llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx   = (uint32_t)contextLength;
    cparams.n_batch = 512;

    _ctx = llama_new_context_with_model(_model, cparams);
    if (!_ctx) {
        llama_model_free(_model);
        _model = nullptr;
        if (error) {
            *error = [NSError errorWithDomain:LlamaErrorDomain
                                         code:LlamaErrorContextInit
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"コンテキストの初期化に失敗しました (メモリ不足の可能性があります)"}];
        }
        return NO;
    }

    return YES;
}

// ── アンロード ──────────────────────────────

- (void)unloadModel {
    if (!_model && !_ctx) return;
    // 生成中なら中断させ、キューの完了を待つ (デッドロック防止のため
    // キュー自身から呼ばれたときは待たない)
    _shouldCancel = true;
    if (dispatch_get_specific((__bridge const void *)kCFNull) == nil &&
        strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL),
               dispatch_queue_get_label(_genQueue)) != 0) {
        dispatch_sync(_genQueue, ^{});
    }
    if (_ctx)   { llama_free(_ctx);         _ctx   = nullptr; }
    if (_model) { llama_model_free(_model); _model = nullptr; }
}

// ── 生成 ──────────────────────────────────

- (void)cancelGeneration {
    _shouldCancel = true;
}

- (void)generateFromMessages:(NSArray<NSDictionary<NSString *, NSString *> *> *)messages
                maxNewTokens:(int32_t)maxNewTokens
                 temperature:(float)temperature
                        topK:(int32_t)topK
                        topP:(float)topP
               tokenCallback:(LlamaTokenCallback)callback {
    if (!_model || !_ctx) {
        callback(nil, YES,
                 [NSError errorWithDomain:LlamaErrorDomain
                                     code:LlamaErrorNoModel
                                 userInfo:@{NSLocalizedDescriptionKey:
                                                @"モデルがロードされていません"}]);
        return;
    }

    _shouldCancel = false;

    // NSArray / NSDictionary はオブジェクトとしてそのまま渡す (ARC が保持する)
    dispatch_async(_genQueue, ^{
        [self _generateWithMessages:messages
                       maxNewTokens:maxNewTokens
                        temperature:temperature
                               topK:topK
                               topP:topP
                           callback:callback];
    });
}

- (void)_generateWithMessages:(NSArray<NSDictionary<NSString *, NSString *> *> *)messages
                 maxNewTokens:(int32_t)maxNewTokens
                  temperature:(float)temperature
                         topK:(int32_t)topK
                         topP:(float)topP
                     callback:(LlamaTokenCallback)callback {

    // ────────────────────────────────────────
    // 1. チャットテンプレートを適用してプロンプトを組み立て
    // ────────────────────────────────────────
    std::vector<llama_chat_message> chatMsgs;
    std::vector<std::string>        roleStore, contentStore;

    for (NSDictionary<NSString *, NSString *> *msg in messages) {
        roleStore.push_back(std::string(msg[@"role"].UTF8String ?: "user"));
        contentStore.push_back(std::string(msg[@"content"].UTF8String ?: ""));
    }
    chatMsgs.reserve(roleStore.size());
    for (size_t i = 0; i < roleStore.size(); i++) {
        llama_chat_message m;
        m.role    = roleStore[i].c_str();
        m.content = contentStore[i].c_str();
        chatMsgs.push_back(m);
    }

    std::string prompt;
    const char *tmpl = llama_model_chat_template(_model, nullptr);
    int32_t bufLen  = 8192;
    std::vector<char> tmplBuf((size_t)bufLen);
    int32_t needed = llama_chat_apply_template(tmpl,
                                               chatMsgs.data(), chatMsgs.size(),
                                               true,
                                               tmplBuf.data(), bufLen);
    if (needed > bufLen) {
        tmplBuf.resize((size_t)needed + 1);
        needed = llama_chat_apply_template(tmpl,
                                           chatMsgs.data(), chatMsgs.size(),
                                           true,
                                           tmplBuf.data(), needed);
    }
    if (needed > 0) {
        prompt.assign(tmplBuf.data(), (size_t)needed);
    } else {
        // フォールバック: ChatML 形式
        prompt.clear();
        for (size_t i = 0; i < chatMsgs.size(); i++) {
            std::string role(chatMsgs[i].role);
            std::string content(chatMsgs[i].content);
            if (role == "system") {
                prompt += "<|im_start|>system\n" + content + "<|im_end|>\n";
            } else if (role == "user") {
                prompt += "<|im_start|>user\n" + content + "<|im_end|>\n";
            } else {
                prompt += "<|im_start|>assistant\n" + content + "<|im_end|>\n";
            }
        }
        prompt += "<|im_start|>assistant\n";
    }

    // ────────────────────────────────────────
    // 2. トークナイズ
    // ────────────────────────────────────────
    const struct llama_vocab *vocab = llama_model_get_vocab(_model);
    int32_t nCtx = (int32_t)llama_n_ctx(_ctx);
    std::vector<llama_token> tokens((size_t)nCtx);

    int32_t nTokens = llama_tokenize(vocab,
                                     prompt.c_str(), (int32_t)prompt.size(),
                                     tokens.data(), (int32_t)tokens.size(),
                                     /*add_special=*/true, /*parse_special=*/true);
    if (nTokens < 0) {
        tokens.resize((size_t)(-nTokens));
        nTokens = llama_tokenize(vocab,
                                 prompt.c_str(), (int32_t)prompt.size(),
                                 tokens.data(), (int32_t)tokens.size(),
                                 true, true);
    }
    if (nTokens < 0) {
        callback(nil, YES,
                 [NSError errorWithDomain:LlamaErrorDomain
                                     code:LlamaErrorTokenize
                                 userInfo:@{NSLocalizedDescriptionKey:
                                                @"トークナイズに失敗しました"}]);
        return;
    }
    tokens.resize((size_t)nTokens);

    // コンテキストに収まるかチェック (生成用の余裕を残す)
    if (nTokens + maxNewTokens > nCtx) {
        callback(nil, YES,
                 [NSError errorWithDomain:LlamaErrorDomain
                                     code:LlamaErrorPromptTooLong
                                 userInfo:@{NSLocalizedDescriptionKey:
                                                [NSString stringWithFormat:
                                                    @"会話が長すぎます (プロンプト %d + 出力上限 %d > コンテキスト %d)\n"
                                                    "新しいチャットを始めるか、設定でコンテキスト長を上げてください",
                                                    nTokens, maxNewTokens, nCtx]}]);
        return;
    }

    // ────────────────────────────────────────
    // 3. KV キャッシュをクリアしてプロンプトをデコード
    // ────────────────────────────────────────
    llama_memory_clear(llama_get_memory(_ctx), true);

    llama_batch batch = llama_batch_get_one(tokens.data(), nTokens);
    if (llama_decode(_ctx, batch) != 0) {
        callback(nil, YES,
                 [NSError errorWithDomain:LlamaErrorDomain
                                     code:LlamaErrorDecode
                                 userInfo:@{NSLocalizedDescriptionKey:
                                                @"プロンプトのデコードに失敗しました"}]);
        return;
    }

    // ────────────────────────────────────────
    // 4. サンプラー設定
    // ────────────────────────────────────────
    llama_sampler *smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(smpl, llama_sampler_init_top_k(topK));
    llama_sampler_chain_add(smpl, llama_sampler_init_top_p(topP, 1));
    llama_sampler_chain_add(smpl, llama_sampler_init_temp(temperature));
    llama_sampler_chain_add(smpl, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    // ────────────────────────────────────────
    // 5. 生成ループ
    // ────────────────────────────────────────
    int32_t nCur      = nTokens;
    int32_t remaining = maxNewTokens;

    // UTF-8 のマルチバイト文字 (日本語 = 3 バイト) が跨いでも
    // 完全な文字になるまでバッファしてから Swift に渡す
    std::string utf8Buf;

    auto flushBuffer = [&](bool force) {
        if (utf8Buf.empty()) return;
        NSString *piece = [NSString stringWithUTF8String:utf8Buf.c_str()];
        if (piece) {
            callback(piece, NO, nil);
            utf8Buf.clear();
        } else if (force) {
            // 中途半端なバイト列は Latin-1 として送る (文字化け防止の最後の手段)
            NSString *rest = [[NSString alloc] initWithBytes:utf8Buf.data()
                                                      length:utf8Buf.size()
                                                    encoding:NSISOLatin1StringEncoding];
            if (rest) callback(rest, NO, nil);
            utf8Buf.clear();
        }
        // force=NO かつ不完全な場合はバッファに貯めたまま次ループへ
    };

    while (nCur < nCtx && remaining > 0 && !_shouldCancel.load()) {
        llama_token token = llama_sampler_sample(smpl, _ctx, -1);

        if (llama_vocab_is_eog(vocab, token)) break;

        char pieceBuf[256] = {0};
        int32_t pieceLen = llama_token_to_piece(vocab, token,
                                                pieceBuf, (int32_t)sizeof(pieceBuf) - 1,
                                                0, false);
        if (pieceLen < 0) {
            std::vector<char> bigBuf((size_t)(-pieceLen) + 1, 0);
            pieceLen = llama_token_to_piece(vocab, token,
                                            bigBuf.data(), (int32_t)bigBuf.size() - 1,
                                            0, false);
            if (pieceLen > 0) utf8Buf.append(bigBuf.data(), (size_t)pieceLen);
        } else if (pieceLen > 0) {
            utf8Buf.append(pieceBuf, (size_t)pieceLen);
        }

        flushBuffer(false);

        // 次トークンをデコード
        llama_batch next = llama_batch_get_one(&token, 1);
        if (llama_decode(_ctx, next) != 0) break;

        nCur++;
        remaining--;
    }

    flushBuffer(true);
    llama_sampler_free(smpl);
    callback(nil, YES, nil);
}

@end
