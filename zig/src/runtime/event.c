#include "event.h"
#include <stdlib.h>
#include <limits.h>
#ifdef _WIN32
#include <windows.h>
struct dz_event { SRWLOCK lock; CONDITION_VARIABLE condition; uint32_t permits; uint64_t epoch; };
dz_event* dz_event_create(void) {
  dz_event* e = calloc(1, sizeof(*e));
  if (!e) return NULL;
  InitializeSRWLock(&e->lock); InitializeConditionVariable(&e->condition);
  return e;
}
void dz_event_signal(dz_event* e) {
  AcquireSRWLockExclusive(&e->lock);
  if (e->permits < UINT32_MAX) ++e->permits;
  ++e->epoch;
  WakeAllConditionVariable(&e->condition);
  ReleaseSRWLockExclusive(&e->lock);
}
void dz_event_wait(dz_event* e) {
  AcquireSRWLockExclusive(&e->lock);
  while (!e->permits) SleepConditionVariableSRW(&e->condition, &e->lock, INFINITE, 0);
  --e->permits;
  ReleaseSRWLockExclusive(&e->lock);
}
void dz_event_destroy(dz_event* e) { free(e); }
#else
#include <pthread.h>
struct dz_event { pthread_mutex_t lock; pthread_cond_t condition; uint32_t permits; uint64_t epoch; };
dz_event* dz_event_create(void) {
  dz_event* e = calloc(1, sizeof(*e));
  if (!e) return NULL;
  if (pthread_mutex_init(&e->lock, NULL)) { free(e); return NULL; }
  if (pthread_cond_init(&e->condition, NULL)) { pthread_mutex_destroy(&e->lock); free(e); return NULL; }
  return e;
}
void dz_event_signal(dz_event* e) {
  pthread_mutex_lock(&e->lock);
  if (e->permits < UINT32_MAX) ++e->permits;
  ++e->epoch;
  pthread_cond_broadcast(&e->condition);
  pthread_mutex_unlock(&e->lock);
}
void dz_event_wait(dz_event* e) {
  pthread_mutex_lock(&e->lock);
  while (!e->permits) pthread_cond_wait(&e->condition, &e->lock);
  --e->permits;
  pthread_mutex_unlock(&e->lock);
}
void dz_event_destroy(dz_event* e) {
  pthread_cond_destroy(&e->condition); pthread_mutex_destroy(&e->lock); free(e);
}
#endif
uint64_t dz_monotonic_ns(void) {
#ifdef _WIN32
  LARGE_INTEGER value, frequency;
  QueryPerformanceCounter(&value); QueryPerformanceFrequency(&frequency);
  return (uint64_t)(value.QuadPart / frequency.QuadPart) * 1000000000ULL +
    (uint64_t)(value.QuadPart % frequency.QuadPart) * 1000000000ULL / (uint64_t)frequency.QuadPart;
#else
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return (uint64_t)now.tv_sec * 1000000000ULL + (uint64_t)now.tv_nsec;
#endif
}

uint64_t dz_event_epoch(dz_event* e) {
#ifdef _WIN32
  AcquireSRWLockExclusive(&e->lock); uint64_t epoch = e->epoch; ReleaseSRWLockExclusive(&e->lock);
#else
  pthread_mutex_lock(&e->lock); uint64_t epoch = e->epoch; pthread_mutex_unlock(&e->lock);
#endif
  return epoch;
}
void dz_event_wait_since(dz_event* e, uint64_t epoch) {
#ifdef _WIN32
  AcquireSRWLockExclusive(&e->lock);
  while (e->epoch == epoch) SleepConditionVariableSRW(&e->condition, &e->lock, INFINITE, 0);
  ReleaseSRWLockExclusive(&e->lock);
#else
  pthread_mutex_lock(&e->lock);
  while (e->epoch == epoch) pthread_cond_wait(&e->condition, &e->lock);
  pthread_mutex_unlock(&e->lock);
#endif
}
