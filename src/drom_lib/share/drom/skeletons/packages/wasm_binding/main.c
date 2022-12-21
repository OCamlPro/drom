#include "stdint.h"

void reverse(uint8_t *p, uint64_t len) {
  uint8_t tmp;
  for (int i = 0; i < len / 2; i++) {
    tmp = p[i];
    p[i] = p[len-i-1];
    p[len-i-1] = tmp;
  }
}
