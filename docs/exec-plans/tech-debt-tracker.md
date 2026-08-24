# Technical Debt Tracker

| ID | Area | Evidence | Impact | Owner | Next action or revisit trigger | Status |
| --- | --- | --- | --- | --- | --- | --- |
| DEBT-001 | LLDB backend | Foundation exposes discovery only; no session adapter exists yet | Product cannot inspect a running process | Apple Debug MCP maintainers | Implement DAP session spike and promote only after fixture proof | open |
| DEBT-002 | Physical iOS | Device capability restrictions are documented but no device adapter exists | Physical-device workflow is candidate-only | Apple Debug MCP maintainers | Add paired development-app fixture before enabling device tools | open |
| DEBT-003 | Static analysis | Mach-O/ObjC/Swift analysis boundary is specified but not implemented | No reverse-engineering parity yet | Apple Debug MCP maintainers | Add parser fixture and symbol/disassembly contract | open |
