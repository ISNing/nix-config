{
  pkgs,
  llm-agents,
  open-design,
  ...
}:
{
  home.packages =
    (with llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
      # Agents
      codex
      # cursor-cli
      claude-code
      gemini-cli
      opencode

      # Utilities
      codegraph # pre-indexed code knowledge graph, auto syncs on code changes
      rtk # CLI proxy that reduces LLM token consumption
    ])
    ++ [
      # Open Design - on-demand CLI, run `opendesign` to start
      (pkgs.writeShellScriptBin "opendesign" ''
        exec ${open-design.packages.${pkgs.stdenv.hostPlatform.system}.daemon}/bin/od "$@"
      '')
      open-design.packages.${pkgs.stdenv.hostPlatform.system}.daemon
    ];
}
