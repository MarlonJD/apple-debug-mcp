// Apple Debug MCP complex runtime casebook fixture
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

#include <stdio.h>

struct MeasurementBatch {
    // The fifth slot is allocated deliberately so the buggy read is safe but
    // still outside the logical input length used by the function.
    int readings[5];
};

__attribute__((noinline))
static int sum_readings(const int *readings, int count) {
    int total = 0;

#if defined(APPLE_DEBUG_DEMO_FIXED)
    for (int index = 0; index < count; index++) {
#else
    // Intentional casebook bug: count is a length, not the last valid index.
    for (int index = 0; index <= count; index++) {
#endif
        total += readings[index];
    }
    return total;
}

int main(void) {
    struct MeasurementBatch batch = {
        .readings = {5, 8, 13, 21, -1000},
    };
    volatile int requested_count = 4;
    const int expected_total = 47;
    int actual_total = sum_readings(batch.readings, requested_count);

    printf("actual=%d expected=%d\n", actual_total, expected_total);
    return actual_total == expected_total ? 0 : 1;
}
