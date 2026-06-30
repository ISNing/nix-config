# Agent CLI Commands

Reference commands for installing and updating agent CLIs. Run only the commands you need.

## Install CLIs

Installed via Nix:

- codex
- cursor-cli
- claude-code
- gemini-cli
- opencode
- codegraph

Install Manually:

```bash
# kimi-cli
uv tool install --python 3.13 kimi-cli
uv tool upgrade kimi-cli --no-cache
```

## CodeGraph MCP (semantic code intelligence)

```bash
codegraph install         # wire up MCP server to agents (one-time)
codegraph init            # build per-project knowledge graph index
codegraph explore <q>     # query symbols, call paths, blast radius
codegraph status          # verify index freshness
```

`codegraph install` is one-time; `codegraph init` must be run once per project. The MCP server
auto-syncs on file changes — no need to re-run manually.

## Optional tooling

```bash
# context7: up-to-date docs and code examples for LLMs and agents
npx ctx7 setup
```

## Update npm-installed agent tools

```bash
npm update -g
```
