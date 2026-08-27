// Apple Debug MCP complex concurrency casebook fixture
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

#include <pthread.h>
#include <stdio.h>
#include <unistd.h>

static pthread_mutex_t cache_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t metrics_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t barrier_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t barrier_condition = PTHREAD_COND_INITIALIZER;
static int acquired_first_lock = 0;

static void wait_for_both_workers(void) {
    pthread_mutex_lock(&barrier_lock);
    acquired_first_lock += 1;
    if (acquired_first_lock < 2) {
        while (acquired_first_lock < 2) {
            pthread_cond_wait(&barrier_condition, &barrier_lock);
        }
    } else {
        pthread_cond_broadcast(&barrier_condition);
    }
    pthread_mutex_unlock(&barrier_lock);
}

static void *cache_worker(void *context) {
    (void)context;
    pthread_mutex_lock(&cache_lock);
#if !defined(APPLE_DEBUG_DEMO_FIXED)
    wait_for_both_workers();
#endif
    pthread_mutex_lock(&metrics_lock);
    pthread_mutex_unlock(&metrics_lock);
    pthread_mutex_unlock(&cache_lock);
    return NULL;
}

static void *metrics_worker(void *context) {
    (void)context;
#if defined(APPLE_DEBUG_DEMO_FIXED)
    // Fixed lock ordering: every worker acquires cache before metrics.
    pthread_mutex_lock(&cache_lock);
    pthread_mutex_lock(&metrics_lock);
#else
    // Intentional bug: this worker acquires the shared locks in reverse order.
    pthread_mutex_lock(&metrics_lock);
    wait_for_both_workers();
    pthread_mutex_lock(&cache_lock);
#endif
    pthread_mutex_unlock(&metrics_lock);
    pthread_mutex_unlock(&cache_lock);
    return NULL;
}

static void *deadlock_watchdog(void *context) {
    (void)context;
    usleep(300000);
    puts("deadlock-ready");
    fflush(stdout);
    while (1) {
        usleep(100000);
    }
    return NULL;
}

int main(void) {
    pthread_t cache_thread;
    pthread_t metrics_thread;
    pthread_t watchdog_thread;
    // Give an authorized debugger a bounded window to attach before workers start.
    usleep(500000);
    pthread_create(&cache_thread, NULL, cache_worker, NULL);
    pthread_create(&metrics_thread, NULL, metrics_worker, NULL);
#if !defined(APPLE_DEBUG_DEMO_FIXED)
    pthread_create(&watchdog_thread, NULL, deadlock_watchdog, NULL);
#endif
    puts("workers-started");
    fflush(stdout);
#if defined(APPLE_DEBUG_DEMO_FIXED)
    pthread_join(cache_thread, NULL);
    pthread_join(metrics_thread, NULL);
    puts("fixed-ok");
#else
    pthread_join(watchdog_thread, NULL);
#endif
    return 0;
}
