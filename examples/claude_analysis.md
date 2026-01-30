# Command → Claude Analysis

**Command:** `-/bin/zsh`
**Generated:** 2026-01-30 11:15:58

## Prompt
```text
Analyze this output and explain what it shows. Ignore ASCII art, banners, and trivial or non-essential decorative elements. Focus on the substantive content and functionality.
```

## Input
```

[0m▄[0m
[38;2;128;128;128m█[0m[38;2;128;128;128m▀[0m[38;2;128;128;128m▀[0m[38;2;128;128;128m█[0m [38;2;128;128;128m█[0m[38;2;128;128;128m▀[0m[38;2;128;128;128m▀[0m[38;2;128;128;128m█[0m [38;2;128;128;128m█[0m[38;2;128;128;128m▀[0m[38;2;128;128;128m▀[0m[38;2;128;128;128m█[0m [38;2;128;128;128m█[0m[38;2;128;128;128m▀[0m[38;2;128;128;128m▀[0m[38;2;128;128;128m▄[0m [0m█[0m[0m▀[0m[0m▀[0m[0m▀[0m [0m█[0m[0m▀[0m[0m▀[0m[0m█[0m [0m█[0m[0m▀[0m[0m▀[0m[0m█[0m [0m█[0m[0m▀[0m[0m▀[0m[0m█[0m
[38;2;128;128;128m█[0m[48;5;235m [0m[48;5;235m [0m[38;2;128;128;128m█[0m [38;2;128;128;128m█[0m[48;5;235m [0m[48;5;235m [0m[38;2;128;128;128m█[0m [38;2;128;128;128m█[0m[38;2;128;128;128m[48;5;235m▀[0m[38;2;128;128;128m[48;5;235m▀[0m[38;2;128;128;128m[48;5;235m▀[0m [38;2;128;128;128m█[0m[48;5;235m [0m[48;5;235m [0m[38;2;128;128;128m█[0m [0m█[0m[48;5;238m [0m[48;5;238m [0m[48;5;238m [0m [0m█[0m[48;5;238m [0m[48;5;238m [0m[0m█[0m [0m█[0m[48;5;238m [0m[48;5;238m [0m[0m█[0m [0m█[0m[0m[48;5;238m▀[0m[0m[48;5;238m▀[0m[0m[48;5;238m▀[0m
[38;2;128;128;128m▀[0m[38;2;128;128;128m▀[0m[38;2;128;128;128m▀[0m[38;2;128;128;128m▀[0m [38;2;128;128;128m█[0m[38;2;128;128;128m▀[0m[38;2;128;128;128m▀[0m[38;2;128;128;128m▀[0m [38;2;128;128;128m▀[0m[38;2;128;128;128m▀[0m[38;2;128;128;128m▀[0m[38;2;128;128;128m▀[0m [38;2;128;128;128m▀[0m[38;5;235m▀[0m[38;5;235m▀[0m[38;2;128;128;128m▀[0m [0m▀[0m[0m▀[0m[0m▀[0m[0m▀[0m [0m▀[0m[0m▀[0m[0m▀[0m[0m▀[0m [0m▀[0m[0m▀[0m[0m▀[0m[0m▀[0m [0m▀[0m[0m▀[0m[0m▀[0m[0m▀[0m

Commands:
  opencode completion          generate shell completion script
  opencode acp                 start ACP (Agent Client Protocol) server
  opencode mcp                 manage MCP (Model Context Protocol) servers
  opencode [project]           start opencode tui                                          [default]
  opencode attach <url>        attach to a running opencode server
  opencode run [message..]     run opencode with a message
  opencode debug               debugging and troubleshooting tools
  opencode auth                manage credentials
  opencode agent               manage agents
  opencode upgrade [target]    upgrade opencode to the latest or a specific version
  opencode uninstall           uninstall opencode and remove all related files
  opencode serve               starts a headless opencode server
  opencode web                 start opencode server and open web interface
  opencode models [provider]   list all available models
  opencode stats               show token usage and cost statistics
  opencode export [sessionID]  export session data as JSON
  opencode import <file>       import session data from JSON file or URL
  opencode github              manage GitHub agent
  opencode pr <number>         fetch and checkout a GitHub PR branch, then run opencode
  opencode session             manage sessions

Positionals:
  project  path to start opencode in                                                        [string]

Options:
  -h, --help        show help                                                              [boolean]
  -v, --version     show version number                                                    [boolean]
      --print-logs  print logs to stderr                                                   [boolean]
      --log-level   log level                   [string] [choices: "DEBUG", "INFO", "WARN", "ERROR"]
      --port        port to listen on                                          [number] [default: 0]
      --hostname    hostname to listen on                            [string] [default: "127.0.0.1"]
      --mdns        enable mDNS service discovery (defaults hostname to 0.0.0.0)
                                                                          [boolean] [default: false]
      --cors        additional domains to allow for CORS                       [array] [default: []]
  -m, --model       model to use in the format of provider/model                            [string]
  -c, --continue    continue the last session                                              [boolean]
  -s, --session     session id to continue                                                  [string]
      --prompt      prompt to use                                                           [string]
      --agent       agent to use                                                            [string]
```

## Analysis

This is the help output for **OpenCode**, an AI-powered coding assistant CLI tool. Here's what it shows:

## Core Functionality

OpenCode is a terminal-based AI coding assistant with multiple interface options:
- **TUI (Terminal UI)** - the default mode when running `opencode`
- **Web interface** - via `opencode web`
- **Headless server** - via `opencode serve`
- **Single-run mode** - via `opencode run [message]`

## Key Commands

| Command | Purpose |
|---------|---------|
| `mcp` | Manage Model Context Protocol servers (for tool integrations) |
| `acp` | Start Agent Client Protocol server |
| `auth` | Manage API credentials |
| `models` | List available AI models by provider |
| `stats` | View token usage and costs |
| `session` | Manage conversation sessions |
| `export/import` | Save/load session data as JSON |
| `github` / `pr` | GitHub integration - fetch PRs and manage GitHub agents |
| `agent` | Manage different agent configurations |
| `attach` | Connect to a running OpenCode server |

## Notable Options

- **`-m, --model`** - Select model in `provider/model` format
- **`-c, --continue`** - Resume the last session
- **`-s, --session`** - Resume a specific session by ID
- **`--prompt`** - Specify a custom prompt
- **`--mdns`** - Enable local network discovery
- **`--cors`** - Configure allowed domains for web access

This appears to be an open-source alternative to tools like Claude Code, supporting multiple AI providers and offering both local and networked operation modes.

---
