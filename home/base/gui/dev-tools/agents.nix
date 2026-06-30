{ pkgs, llm-agents, ... }:
{
  home.packages = with llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
    # Agents
    codex
    # cursor-cli
    claude-code
    gemini-cli
    opencode

    # Utilities
    codegraph # pre-indexed code knowledge graph, auto syncs on code changes
    rtk # CLI proxy that reduces LLM token consumption
  ];
}
