// Apple Debug MCP fixture
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

#include <unistd.h>

volatile int debug_value = 7;

int main(void) {
    for (int iteration = 0; iteration < 20; iteration++) {
        debug_value += iteration;
        usleep(10000);
    }
    return debug_value;
}
