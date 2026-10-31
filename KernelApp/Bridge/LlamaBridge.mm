#import "LlamaBridge.h"

#include <llama.h>
#include <atomic>
#include <string>
#include <vector>
#include <cstring>

static NSErrorDomain const LlamaErrorDomain = @"com.kernel.LlamaError";
typedef NS_ERROR_ENUM(LlamaErrorDomain, LlamaError) {
    LlamaErrorModelLoad = 100,
    LlamaErrorContextInit = 101,
    LlamaErrorTokenize = 102,
    LlamaErrorDecode = 103,
    LlamaErrorNoModel = 104,
};

@implementation LlamaBridge {
    llama_model *_model;
    llama_context *_ctx;
    dispatch_queue_t _genQueue;
    std::atomic<bool> _shouldCancel;

    int32_t _contextLength;
    int32_t _nGpuLayers;
    float _temperature;
    int32_t _topK;
    float _topP;
    int32_t _maxNewTokens;
}

+ (void)initializeBackend {
    llama_backend_init();
}

+ (void)freeBackend {
    llama_backend_free();
}

- (instancetype)init {
    if (self = [super init]) {
        _model = nullptr;
        _ctx = nullptr;
        _genQueue = dispatch_queue_create("com.kernel.llama.gen", DISPATCH_QUEUE_SERIAL);
        _shouldCancel = false;
        _contextLength = 4096;
        _nGpuLayers = 99;
        _temperature = 0.80f;
        _topK = 40;
        _topP = 0.95f;
        _maxNewTokens = 1024;
    }
    return self;
}

- (void)dealloc {
    [self unloadModel];
}

- (BOOL)isModelLoaded {
    return _model != nullptr;
}

- (int32_t)contextLength {
    return _contextLength;
}

- (void)setContextLength:(int32_t)v {
    _contextLength = v;
}

- (int32_t)nGpuLayers {
    return _nGpuLayers;
}

- (void)setNGpuLayers:(int32_t)v {
    _nGpuLayers = v;
}

- (float)temperature {
    return _temperature;
}

- (void)setTemperature:(float)v {
    _temperature = v;
}

- (int32_t)topK {
    return _topK;
}

- (void)setTopK:(int32_t)v {
    _topK = v;
}

- (float)topP {
    return _topP;
}

- (void)setTopP:(float)v {
    _topP = v;
}

- (int32_t)maxNewTokens {
    return _maxNewTokens;
}

- (void)setMaxNewTokens:(int32_t)v {
    _maxNewTokens = v;
}

- (nullable NSString *)modelDescription {
    if (!_model) return nil;
    char buf[256] = {0};
    llama_model_desc(_model, buf, sizeof(buf));
    return [NSString stringWithUTF8String:buf];
}

- (BOOL)loadModelFromPath:(NSString *)path error:(NSError **)error {
    [self unloadModel];

    llama_model_params mparams = llama_model_default_params();
    mparams.n_gpu_layers = _nGpuLayers;

    _model = llama_model_load_from_file(path.UTF8String, mparams);
    if (!_model) {
        if (error) {
            *error = [NSError errorWithDomain:LlamaErrorDomain
                                         code:LlamaErrorModelLoad
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"モデルのロードに失敗しました: %@",
                                                     path.lastPathComponent]}];
        }
        return NO;
    }

    llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx = (uint32_t)_contextLength;
    cparams.n_batch = 512;

    _ctx = llama_new_context_with_model(_model, cparams);
    if (!_ctx) {
        llama_model_free(_model);
        _model = nullptr;
        if (error) {
            *error = [NSError errorWithDomain:LlamaErrorDomain
                                         code:LlamaErrorContextInit
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"コンテキストの初期化に失敗しました"}];
        }
        return NO;
    }

    return YES;
}

- (void)unloadModel {
    _shouldCancel = true;
    dispatch_sync(_genQueue, ^{
    });
    _shouldCancel = false;

    if (_ctx) {
        llama_free(_ctx);
        _ctx = nullptr;
    }
    if (_model) {
        llama_model_free(_model);
        _model = nullptr;
    }
}

- (void)cancelGeneration {
    _shouldCancel = true;
}

- (void)generateFromMessages:(NSArray<NSDictionary<NSString *, NSString *> *> *)messages
               tokenCallback:(LlamaTokenCallback)callback {
    if (!_model || !_ctx) {
        callback(nil, YES,
                 [NSError errorWithDomain:LlamaErrorDomain
                                     code:LlamaErrorNoModel
                                 userInfo:@{NSLocalizedDescriptionKey: @"モデルがロードされていません"}]);
        return;
    }

    _shouldCancel = false;

    dispatch_async(_genQueue, ^{
        [self _generateFromMessages:messages callback:callback];
    });
}

- (void)_generateFromMessages:(NSArray<NSDictionary<NSString *, NSString *> *> *)messages
                     callback:(LlamaTokenCallback)callback {

    std::string prompt;
    const struct llama_vocab *vocab = llama_model_get_vocab(_model);

    std::vector<llama_chat_message> chatMsgs;
    std::vector<std::string> roles, contents;

    for (NSDictionary<NSString *, NSString *> *msg in messages) {
        roles.push_back(std::string([msg[@"role"] UTF8String]));
        contents.push_back(std::string([msg[@"content"] UTF8String]));
    }
    for (size_t i = 0; i < roles.size(); i++) {
        llama_chat_message m;
        m.role = roles[i].c_str();
        m.content = contents[i].c_str();
        chatMsgs.push_back(m);
    }

    const char *tmpl = llama_model_chat_template(_model, nullptr);
    int32_t bufLen = 8192;
    std::vector<char> tmplBuf(bufLen);
    int32_t needed = llama_chat_apply_template(
        tmpl,
        chatMsgs.data(), chatMsgs.size(),
        true,
        tmplBuf.data(), bufLen
    );
    if (needed > bufLen) {
        tmplBuf.resize(needed + 1);
        needed = llama_chat_apply_template(
            tmpl,
            chatMsgs.data(), chatMsgs.size(),
            true,
            tmplBuf.data(), needed
        );
    }
    if (needed > 0) {
        prompt = std::string(tmplBuf.data(), (size_t)needed);
    } else {
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

    int32_t nCtx = (int32_t)llama_n_ctx(_ctx);
    std::vector<llama_token> tokens(nCtx);

    int32_t nTokens = llama_tokenize(
        vocab,
        prompt.c_str(), (int32_t)prompt.size(),
        tokens.data(), (int32_t)tokens.size(),
        true, true
    );
    if (nTokens < 0) {
        callback(nil, YES,
                 [NSError errorWithDomain:LlamaErrorDomain
                                     code:LlamaErrorTokenize
                                 userInfo:@{NSLocalizedDescriptionKey: @"トークナイズに失敗しました"}]);
        return;
    }
    tokens.resize(nTokens);

    llama_memory_clear(llama_get_memory(_ctx), true);

    llama_batch batch = llama_batch_get_one(tokens.data(), (int32_t)tokens.size());
    if (llama_decode(_ctx, batch) != 0) {
        callback(nil, YES,
                 [NSError errorWithDomain:LlamaErrorDomain
                                     code:LlamaErrorDecode
                                 userInfo:@{NSLocalizedDescriptionKey: @"プロンプトのデコードに失敗しました"}]);
        return;
    }

    llama_sampler *smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(smpl, llama_sampler_init_top_k(_topK));
    llama_sampler_chain_add(smpl, llama_sampler_init_top_p(_topP, 1));
    llama_sampler_chain_add(smpl, llama_sampler_init_temp(_temperature));
    llama_sampler_chain_add(smpl, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    int32_t nCur = nTokens;
    int32_t remaining = _maxNewTokens;

    std::string utf8Buf;

    while (nCur < nCtx && remaining > 0 && !_shouldCancel.load()) {
        llama_token token = llama_sampler_sample(smpl, _ctx, -1);

        if (llama_vocab_is_eog(vocab, token)) {
            break;
        }

        char pieceBuf[256] = {0};
        int32_t pieceLen = llama_token_to_piece(vocab, token,
                                                 pieceBuf, (int32_t)sizeof(pieceBuf) - 1,
                                                 0, false);
        if (pieceLen < 0) {
            std::vector<char> bigBuf(-pieceLen + 1, 0);
            pieceLen = llama_token_to_piece(vocab, token,
                                             bigBuf.data(), (int32_t)bigBuf.size() - 1,
                                             0, false);
            if (pieceLen > 0) {
                utf8Buf.append(bigBuf.data(), (size_t)pieceLen);
            }
        } else if (pieceLen > 0) {
            utf8Buf.append(pieceBuf, (size_t)pieceLen);
        }

        NSString *piece = [NSString stringWithUTF8String:utf8Buf.c_str()];
        if (piece) {
            callback(piece, NO, nil);
            utf8Buf.clear();
        }

        batch = llama_batch_get_one(&token, 1);
        if (llama_decode(_ctx, batch) != 0) break;

        nCur++;
        remaining--;
    }

    if (!utf8Buf.empty()) {
        NSString *rest = [NSString stringWithUTF8String:utf8Buf.c_str()];
        if (!rest) {
            rest = [[NSString alloc] initWithBytes:utf8Buf.c_str()
                                            length:utf8Buf.size()
                                          encoding:NSISOLatin1StringEncoding];
        }
        if (rest) callback(rest, NO, nil);
    }

    llama_sampler_free(smpl);
    callback(nil, YES, nil);
}

@end
