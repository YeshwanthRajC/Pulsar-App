#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#if PULSAR_HAS_ENGINE
#include "needle.h"
#endif

#define PULSAR_API extern "C" __attribute__((visibility("default")))

/* 1 when the real Needle/Whistle engine is linked into this build, else 0. */
PULSAR_API int pulsar_engine_supported(void) { return PULSAR_HAS_ENGINE; }

/* Maps a .cact file and loads it into the engine. The mapping is intentionally
   kept for the life of the process: the engine reads weights in place.
   Returns needle_load()'s result (>= 0 on success) or a negative error:
   -100 unsupported ABI, -101 open failed, -102 stat failed, -103 mmap failed. */
PULSAR_API int pulsar_load_file(const char* path) {
#if PULSAR_HAS_ENGINE
  int fd = open(path, O_RDONLY);
  if (fd < 0) return -101;
  struct stat st;
  if (fstat(fd, &st) != 0) { close(fd); return -102; }
  void* p = mmap(nullptr, (size_t)st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
  close(fd);
  if (p == MAP_FAILED) return -103;
  return needle_load((const unsigned char*)p, (unsigned long long)st.st_size);
#else
  (void)path;
  return -100;
#endif
}
