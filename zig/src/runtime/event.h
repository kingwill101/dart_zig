#ifndef DART_ZIG_EVENT_H
#define DART_ZIG_EVENT_H
#include <stdint.h>
typedef struct dz_event dz_event;
dz_event* dz_event_create(void);
void dz_event_signal(dz_event* event);
void dz_event_wait(dz_event* event);
void dz_event_destroy(dz_event* event);
uint64_t dz_monotonic_ns(void);
uint64_t dz_event_epoch(dz_event* event);
void dz_event_wait_since(dz_event* event, uint64_t epoch);
#endif
