#import "ExceptionGuard.h"
#include <unistd.h>

void objcTryCatch(
    void (^ NS_NOESCAPE block)(void),
    void (^ NS_NOESCAPE handler)(NSException *exception)
) {
    @try {
        block();
    } @catch (NSException *e) {
        handler(e);
    }
}

void relaunchProcess(const char *bundlePath) {
    pid_t pid = fork();
    if (pid == 0) {
        execl("/usr/bin/open", "open", bundlePath, NULL);
        _exit(1);
    }
    _exit(0);
}
