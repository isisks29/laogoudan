// fishhook.h — Facebook fishhook 精简版
// 用于 Hook 系统级 C 函数（ptrace、sysctl、dyld 函数等）
#ifndef FISHHOOK_H
#define FISHHOOK_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

struct rebinding {
  const char *name;
  void *replacement;
  void **replaced;
};

struct rebinding_bs {
  const char *name;
  void *replacement;
  void **replaced;
  const char *shlib;
};

// 核心函数：对所有已加载的镜像执行符号重绑定
int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

// 针对指定共享库的重绑定
int rebind_symbols_image(void *header,
                          intptr_t slide,
                          struct rebinding rebindings[],
                          size_t rebindings_nel);

#ifdef __cplusplus
}
#endif

#endif // FISHHOOK_H
