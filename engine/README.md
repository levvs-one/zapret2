# engine

Files that Prosvet ships next to `winws2.exe`.

- `lua/prosvet.lua` extends the zapret2 `circular` orchestrator with a per-network memory of the strategy that works for each host.
- `lists/*.txt` are hostlists. A profile applies only to these domains and all of their subdomains.
- `windivert/*.txt` are WinDivert filter parts copied from zapret2 `init.d/windivert.filter.examples`.

The zapret2 binaries and standard Lua libraries are not stored in git. `tools/fetch-engine.ps1` downloads a pinned zapret2 release, verifies its SHA-256 and places the files into `build/engine`.
