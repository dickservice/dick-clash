#include <cassert>
#include <cstring>
#include "core.cpp"

static bool native_result;
static bool exception_thrown;
static bool local_ref_deleted;
static int callback_refs;

static jobject JNICALL retain(JNIEnv *, jobject value) {
    ++callback_refs;
    return value;
}
static jclass JNICALL lookup(JNIEnv *, const char *name) {
    assert(std::strcmp(name, "java/lang/IllegalStateException") == 0);
    return reinterpret_cast<jclass>(1);
}
static jint JNICALL raise(JNIEnv *, jclass, const char *message) {
    assert(std::strcmp(message, "Native TUN startup failed") == 0);
    exception_thrown = true;
    return 0;
}
static void JNICALL release(JNIEnv *, jobject) {
    local_ref_deleted = true;
}

char *jni_get_string(JNIEnv *, jstring) { return nullptr; }
extern "C" GoUint8 startTUN(void *, int, char *, char *, char *) {
    return native_result;
}

int main() {
    JNINativeInterface_ methods{};
    methods.NewGlobalRef = retain;
    methods.FindClass = lookup;
    methods.ThrowNew = raise;
    methods.DeleteLocalRef = release;
    JNIEnv env{&methods};
    native_result = false;
    Java_com_follow_clash_core_Core_startTun(&env, nullptr, 7, nullptr,
                                            nullptr, nullptr, nullptr);
    assert(exception_thrown && local_ref_deleted && callback_refs == 1);
    native_result = true;
    exception_thrown = local_ref_deleted = false;
    Java_com_follow_clash_core_Core_startTun(&env, nullptr, 7, nullptr,
                                            nullptr, nullptr, nullptr);
    assert(!exception_thrown && !local_ref_deleted && callback_refs == 2);
}
