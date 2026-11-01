#import "LlamaBridge.h"
#import <TargetConditionals.h>
#include <atomic>
#include <algorithm>
#include <string>
#include <vector>
#include <stdexcept>
#if !TARGET_OS_SIMULATOR
#include <llama.h>
#endif

static NSError *failure(NSString *text) {
    return [NSError errorWithDomain:@"Kernel.Inference" code:1 userInfo:@{NSLocalizedDescriptionKey:text}];
}

@implementation LlamaBridge {
#if !TARGET_OS_SIMULATOR
    llama_model *_model;
    llama_context *_ctx;
#endif
    dispatch_queue_t _queue;
    std::atomic<bool> _cancel;
}
@synthesize contextLength = _contextLength, nGpuLayers = _nGpuLayers, nThreads = _nThreads, temperature = _temperature;
@synthesize topK = _topK, topP = _topP, maxNewTokens = _maxNewTokens;

+ (void)initializeBackend {
#if !TARGET_OS_SIMULATOR
    static dispatch_once_t once;
    dispatch_once(&once, ^{ llama_backend_init(); });
#endif
}
+ (void)freeBackend { /* Backend lives for the process lifetime. */ }
- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("app.kernel.inference", DISPATCH_QUEUE_SERIAL);
        _cancel = false;
        _contextLength = 4096; _nGpuLayers = 99; _nThreads = 6; _temperature = .65;
        _topK = 40; _topP = .95; _maxNewTokens = 1024;
    }
    return self;
}
- (BOOL)isModelLoaded {
#if !TARGET_OS_SIMULATOR
    return _model != nullptr && _ctx != nullptr;
#else
    return NO;
#endif
}
- (NSString *)modelDescription { return nil; }
- (BOOL)loadModelFromPath:(NSString *)path error:(NSError **)error {
    __block BOOL ok = NO;
    __block NSError *problem = nil;
    _cancel = true;
    dispatch_sync(_queue, ^{
#if !TARGET_OS_SIMULATOR
        [self releaseModel];
        self->_cancel = false;
        @try {
            try {
                [LlamaBridge initializeBackend];
                auto mp = llama_model_default_params();
                mp.n_gpu_layers = self->_nGpuLayers;
                self->_model = llama_model_load_from_file(path.fileSystemRepresentation, mp);
                if (!self->_model) throw std::runtime_error("GGUFモデルを読み込めません。形式・対応アーキテクチャ・空きメモリを確認してください。");
                auto cp = llama_context_default_params();
                cp.n_ctx = (uint32_t)std::clamp(self->_contextLength, 512, 16384);
                cp.n_batch = 256; cp.n_ubatch = 128;
                cp.n_threads = cp.n_threads_batch = (int32_t)std::max(1, std::min((int)self->_nThreads, (int)NSProcessInfo.processInfo.activeProcessorCount));
                cp.abort_callback = [](void *p) { return ((std::atomic<bool> *)p)->load(); };
                cp.abort_callback_data = &self->_cancel;
                self->_ctx = llama_init_from_model(self->_model, cp);
                if (!self->_ctx) throw std::runtime_error("推論領域を確保できません。コンテキスト長を小さくしてください。");
                ok = YES;
            } catch (const std::exception &e) { problem = failure([NSString stringWithUTF8String:e.what()]); }
            catch (...) { problem = failure(@"推論エンジンの初期化に失敗しました。"); }
        } @catch (NSException *e) { problem = failure(e.reason ?: @"モデル初期化エラー"); }
        if (!ok) [self releaseModel];
#else
        problem = failure(@"GGUF推論は実機iPadで使用してください。シミュレータは画面検証用です。");
#endif
    });
    if (error) *error = problem;
    return ok;
}
- (void)releaseModel {
#if !TARGET_OS_SIMULATOR
    if (_ctx) { llama_free(_ctx); _ctx = nullptr; }
    if (_model) { llama_model_free(_model); _model = nullptr; }
#endif
}
- (void)unloadModel {
    _cancel = true;
    dispatch_sync(_queue, ^{ [self releaseModel]; });
}
- (void)cancelGeneration { _cancel = true; }
- (void)generateFromMessages:(NSArray<NSDictionary<NSString *,NSString *> *> *)messages tokenCallback:(LlamaTokenCallback)callback {
    _cancel = false;
    // Capture an immutable configuration snapshot before entering the worker queue.
    const float temp = _temperature, topP = _topP;
    const int topK = _topK, limit = _maxNewTokens;
    dispatch_async(_queue, ^{
        @autoreleasepool {
#if !TARGET_OS_SIMULATOR
            llama_sampler *sampler = nullptr;
            NSError *problem = nil;
            try {
                if (!self->_model || !self->_ctx) throw std::runtime_error("モデルを選択してください。");
                const auto *vocab = llama_model_get_vocab(self->_model);
                std::vector<std::string> roles, texts;
                for (NSDictionary *m in messages) {
                    roles.emplace_back([m[@"role"] ?: @"user" UTF8String]);
                    texts.emplace_back([m[@"content"] ?: @"" UTF8String]);
                }
                std::vector<llama_chat_message> chat;
                for (size_t i = 0; i < roles.size(); ++i) chat.push_back({roles[i].c_str(), texts[i].c_str()});
                const char *tmpl = llama_model_chat_template(self->_model, nullptr);
                if (!tmpl) tmpl = "chatml";
                int n = llama_chat_apply_template(tmpl, chat.data(), chat.size(), true, nullptr, 0);
                if (n <= 0) throw std::runtime_error("このモデルのチャットテンプレートに対応していません。Instructモデルを使用してください。");
                std::vector<char> formatted(n + 1);
                n = llama_chat_apply_template(tmpl, chat.data(), chat.size(), true, formatted.data(), (int)formatted.size());
                if (n <= 0 || n >= (int)formatted.size()) throw std::runtime_error("プロンプトを構築できませんでした。");
                int count = llama_tokenize(vocab, formatted.data(), n, nullptr, 0, true, true);
                if (count >= 0) throw std::runtime_error("入力が空です。");
                std::vector<llama_token> tokens(-count);
                count = llama_tokenize(vocab, formatted.data(), n, tokens.data(), (int)tokens.size(), true, true);
                const int ctx = (int)llama_n_ctx(self->_ctx);
                const int reserve = std::min(limit, ctx / 2);
                if (count <= 0 || count + reserve > ctx) throw std::runtime_error("入力がコンテキスト長を超えています。添付を短くするか、新しいチャットを開始してください。");
                llama_memory_clear(llama_get_memory(self->_ctx), true);
                for (int offset = 0; offset < count && !self->_cancel; offset += 256) {
                    auto batch = llama_batch_get_one(tokens.data() + offset, std::min(256, count - offset));
                    if (llama_decode(self->_ctx, batch) != 0 && !self->_cancel) throw std::runtime_error("入力の処理に失敗しました。空きメモリを確認してください。");
                }
                sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
                if (temp <= 0) llama_sampler_chain_add(sampler, llama_sampler_init_greedy());
                else {
                    llama_sampler_chain_add(sampler, llama_sampler_init_top_k(topK));
                    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(topP, 1));
                    llama_sampler_chain_add(sampler, llama_sampler_init_temp(temp));
                    llama_sampler_chain_add(sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
                }
                std::string pending;
                for (int i = 0; i < std::min(limit, ctx - count) && !self->_cancel; ++i) {
                    llama_token token = llama_sampler_sample(sampler, self->_ctx, -1);
                    if (llama_vocab_is_eog(vocab, token)) break;
                    std::vector<char> piece(256);
                    int length = llama_token_to_piece(vocab, token, piece.data(), (int)piece.size(), 0, false);
                    if (length < 0) { piece.resize(-length); length = llama_token_to_piece(vocab, token, piece.data(), (int)piece.size(), 0, false); }
                    if (length > 0) pending.append(piece.data(), length);
                    NSString *text = [[NSString alloc] initWithBytes:pending.data() length:pending.size() encoding:NSUTF8StringEncoding];
                    if (text) { if (text.length) callback(text, NO, nil); pending.clear(); }
                    if (i + 1 < limit && count + i + 1 < ctx) {
                        auto batch = llama_batch_get_one(&token, 1);
                        if (llama_decode(self->_ctx, batch) != 0 && !self->_cancel) throw std::runtime_error("回答の生成に失敗しました。");
                    }
                }
            } catch (const std::exception &e) { problem = failure([NSString stringWithUTF8String:e.what()]); }
            catch (...) { problem = failure(@"推論処理に失敗しました。"); }
            if (sampler) llama_sampler_free(sampler);
            callback(nil, YES, problem);
#else
            callback(nil, YES, failure(@"推論には実機iPadが必要です。"));
#endif
        }
    });
}
@end
