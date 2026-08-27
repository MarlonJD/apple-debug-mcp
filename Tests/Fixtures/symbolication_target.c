// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

__attribute__((noinline)) int symbolication_fixture_symbol(int value) {
    int adjusted = value + 7;
    return adjusted * 3;
}

int main(void) {
    return symbolication_fixture_symbol(5) == 36 ? 0 : 1;
}
