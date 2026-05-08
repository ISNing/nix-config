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
    rtk # CLI proxy that reduces LLM token consumption
  ];
}
