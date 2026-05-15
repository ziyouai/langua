#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 在 block 内捕获所有 ObjC 异常，异常时调用 handler 而不是崩溃。
/// Swift 无法直接 catch ObjC 异常，必须通过此 ObjC 包装层。
FOUNDATION_EXPORT void objcTryCatch(
    void (^ NS_NOESCAPE block)(void),
    void (^ NS_NOESCAPE handler)(NSException *exception)
);

/// fork + exec 重启 app（Swift 里 fork() 被标记为不可用，必须在 ObjC/C 里调用）
FOUNDATION_EXPORT void relaunchProcess(const char *bundlePath);

NS_ASSUME_NONNULL_END
