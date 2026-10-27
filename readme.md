# Setting up OpenCode on macOS

OpenCode is an open source AI coding agent that runs in your terminal. This guide walks through
installing it on macOS, connecting a model provider, and configuring it for daily use.

For the interactive setup, run [`install.sh`](install.sh) from this repo. It detects an
existing install, lets you pick the source, and offers a multi-select list of add-ons — MCP servers,
plugins, skills, and a VS Code extension — installing each one the way its own project documents:

```bash
./install.sh
```

Use `./install.sh --help` for usage or `./install.sh --no-color` for plain output. `NO_COLOR=1`
also disables colors. All 14 add-ons start selected; enter numbers to toggle them, `a` for all,
`n` for none, or Enter to accept.

For project-local handoff skills or KTX conventions, run the script **from your target project**:

```bash
cd /path/to/your/project
/path/to/opencode-dev-setup/install.sh
```

Provider login, API keys, and Serena's per-project configuration remain separate steps. The script
writes global OpenCode settings to `~/.config/opencode/opencode.json`; the `OPENCODE_CONFIG` and
`OPENCODE_CONFIG_DIR` environment variables do not change the installer's destination.

See [Add-ons](#7-add-ons) for what the list contains.

`install.sh` is self-contained: it downloads add-ons as needed and does not require bundled
skills or configuration. Local `.opencode/`, `.agents/`, and `skills-lock.json` files are ignored
by Git so running add-on installers here does not add generated files to this setup repository.

---

## 1. Prerequisites

- **macOS** with a working shell (`zsh` is the default).
- **A modern terminal emulator.** The built-in Terminal.app works, but the TUI renders better in
  [Ghostty](https://ghostty.org), [WezTerm](https://wezterm.org), [Alacritty](https://alacritty.org),
  or [Kitty](https://sw.kovidgoyal.net/kitty/).
- **An API key** for at least one LLM provider (Anthropic, OpenAI, OpenCode Zen, etc.).
- **Homebrew** for the manual Homebrew commands below — <https://brew.sh>. The interactive installer
  can install it when needed.

The interactive installer installs missing dependencies for the tools you select. This can include
Homebrew itself, Node.js/npm/npx, Git, VS Code, uv/Python, and the JVM toolchain. Homebrew may ask for
your administrator password or Apple's Command Line Tools. Downloads require internet access.

---

## 2. Install

Pick one method. The Homebrew tap is the most convenient on macOS since it keeps OpenCode updated
alongside your other packages.

### Homebrew (recommended)

```bash
brew install anomalyco/tap/opencode
```

The `anomalyco` tap carries the most up-to-date releases. There is also an official
`brew install opencode` formula maintained by the Homebrew team, but it is updated less frequently.

### Install script

```bash
curl -fsSL https://opencode.ai/install | bash
```

This drops a binary in your home directory and prints the path it used. If `opencode` isn't found
afterwards, add that directory to your `PATH` in `~/.zshrc`.

### npm

```bash
npm install -g opencode-ai
```

Also works with `bun`, `pnpm`, and `yarn`.

### Verify

```bash
opencode --version
```

---

## 3. Connect a provider

The manual CLI/config examples below primarily use OpenCode V1 conventions. The installer detects
V1 versus V2 and writes the matching plugin and MCP keys; version differences are called out in
those sections. Check `opencode --version`, command `--help`, and the
[V2 documentation](https://opencode.ai/v2/docs/) when using a V2 installation.

OpenCode stores credentials in `~/.local/share/opencode/auth.json`. Two ways to get them there:

### From the TUI

Start OpenCode and run the connect command:

```bash
opencode
```

```
/connect
```

Select your provider, follow the browser flow, and paste the API key when prompted.

If you are new to LLM providers, choose **opencode** (OpenCode Zen) — a curated, pre-tested set of
models. Sign in at <https://opencode.ai/auth>, add billing details, and copy the key.

### From the CLI

```bash
opencode auth login                  # interactive picker
opencode auth login --provider anthropic
opencode auth list                   # show authenticated providers
opencode auth logout                 # remove a provider
```

### Via environment variables

OpenCode also reads provider keys from your environment or from a `.env` file in the project. Add to
`~/.zshrc`:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
```

Then `source ~/.zshrc`.

### Check which models are available

```bash
opencode models              # all configured providers
opencode models anthropic    # filter by provider
opencode models --refresh    # refresh the cache from models.dev
```

Model names use the `provider/model` form, e.g. `anthropic/claude-sonnet-4-5`.

---

## 4. First run on a project

```bash
cd /path/to/your/project
opencode
```

Inside the TUI, initialize the project:

```
/init
```

This analyzes the repo and writes an `AGENTS.md` file at the root describing the project structure
and coding patterns, which OpenCode reads on every future session. Commit it so your team benefits
too.

### Running inside VS Code

Run the CLI in VS Code's integrated terminal; a companion extension adds editor awareness.
The extension installs itself the first time you run
`opencode` from the integrated terminal (not an external one). If that fails, search for *OpenCode*
in the Extensions view, and make sure the `code` command is on your PATH via
`Cmd+Shift+P` → *Shell Command: Install 'code' command in PATH*.

What the extension adds:

| Shortcut | Effect |
| --- | --- |
| `Cmd+Esc` | Open OpenCode in a split terminal, or focus the existing session |
| `Cmd+Shift+Esc` | Start a new session even if one is already open |
| `Cmd+Option+K` | Insert a file reference at the cursor, like `@Player.kt#L37-42` |

It also shares your current selection and active tab with OpenCode automatically, so "fix this"
resolves to what you have highlighted.

The extension is optional — `opencode` works in any terminal without it. Set your editor so `/editor`
and `/export` open VS Code and wait for you to finish:

```bash
export EDITOR="code --wait"
```

Several unofficial sidebar-chat extensions exist that wrap `opencode serve` in a GUI panel. They are
community projects pinned to fast-moving beta APIs, so prefer the terminal workflow unless you
specifically want a chat pane.

---

## 5. Configuration

### Where config lives

| Scope | Path |
| --- | --- |
| Global (user) | `~/.config/opencode/opencode.json` |
| Global TUI | `~/.config/opencode/tui.json` |
| Per project | `opencode.json` in the project root |
| Per project TUI | `tui.json` in the project root |
| Managed (admin) | `/Library/Application Support/opencode/` |

Configs are **merged**, not replaced. Later sources override only the keys they define, in this
order: remote org config → global → `OPENCODE_CONFIG` → project → `.opencode/` directories →
`OPENCODE_CONFIG_CONTENT` → managed files → MDM managed preferences.

Both `.json` and `.jsonc` (with comments) are accepted — but **pick one and stay there**. Merging
happens per key, not per array element, so if `opencode.json` and `opencode.jsonc` both define
`plugin` (V1) or `plugins` (V2), competing arrays can leave some plugins unloaded.

Before and after add-on setup, `install.sh` consolidates a stray `opencode.jsonc` into
`opencode.json`, retaining the former as `opencode.jsonc.superseded` after a successful merge.
It also moves `plugin` / `plugins` entries out of `tui.json` while preserving other TUI settings.
Its JSONC reader handles full-line `//` comments; inline/block comments and trailing commas need
manual conversion to JSON. A parse failure stops setup without deleting the source configuration.
If you edit config by hand, keep one main config file.

### A reasonable starting global config

Create `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "anthropic/claude-sonnet-4-5",
  "small_model": "anthropic/claude-haiku-4-5",
  "autoupdate": true,
  "lsp": true,
  "formatter": true,
  "share": "manual",
  "permission": {
    "edit": "ask",
    "bash": "ask"
  }
}
```

- `model` — the main model.
- `small_model` — a cheaper model for lightweight work like generating session titles.
- `lsp` / `formatter` — off unless you opt in; `true` enables the built-ins.
- `permission` — by default OpenCode allows every operation without asking. Setting `edit` and
  `bash` to `"ask"` is a sensible safety net.
- `share` — `"manual"` (default), `"auto"`, or `"disabled"`.

### TUI settings

Theme, keybinds, cursor, and notifications go in `~/.config/opencode/tui.json`:

```json
{
  "$schema": "https://opencode.ai/tui.json",
  "theme": "tokyonight",
  "scroll_speed": 3,
  "diff_style": "auto",
  "cursor": {
    "style": "block",
    "blinking": true
  },
  "mouse": true,
  "keybinds": {
    "command_list": "ctrl+p"
  },
  "attention": {
    "enabled": true,
    "notifications": true,
    "sound": true,
    "volume": 0.4
  }
}
```

`keybinds` merges with the built-in defaults, so only list the ones you want to change. Setting
`attention.enabled` turns on macOS desktop notifications and sounds when the agent needs you.

Note: `theme`, `keybinds`, and `tui` keys inside `opencode.json` are deprecated and get migrated to
`tui.json` automatically.

### Referencing secrets without hardcoding them

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "anthropic": {
      "options": {
        "apiKey": "{env:ANTHROPIC_API_KEY}"
      }
    },
    "openai": {
      "options": {
        "apiKey": "{file:~/.secrets/openai-key}"
      }
    }
  }
}
```

`{env:NAME}` pulls from the environment, `{file:path}` reads a file (relative to the config, or
absolute with `/` or `~`).

### Restricting providers

```json
{
  "$schema": "https://opencode.ai/config.json",
  "enabled_providers": ["anthropic", "openai"],
  "disabled_providers": ["gemini"]
}
```

`disabled_providers` wins if a provider appears in both.

---

## 6. Extending OpenCode

OpenCode has six distinct extension mechanisms. They are easy to confuse, so here is what each one
actually is before the how-to:

| Mechanism | What it is | Loaded |
| --- | --- | --- |
| **Skills** | A `SKILL.md` of reusable instructions | On demand, when the agent picks it |
| **Plugins** | JS/TS modules that hook into the runtime | Every session, always on |
| **MCP servers** | External processes/APIs exposing tools | Every session; tools always in context |
| **Agents** | Named personas with their own model, prompt, tools | When selected |
| **Commands** | Reusable prompt templates behind a slash command | When you type them |
| **Instructions** | Extra rule files merged into the prompt | Every session, always on |

### Skills

A skill is a folder containing a `SKILL.md`. OpenCode advertises the name and description of every
discovered skill to the agent, which loads the full body only when it decides the skill is relevant.
That on-demand loading is the point: skills cost almost no context until used.

Searched locations (project-local paths are walked upward until the git worktree root):

- `.opencode/skills/<name>/SKILL.md` and `~/.config/opencode/skills/<name>/SKILL.md`
- `.claude/skills/<name>/SKILL.md` and `~/.claude/skills/<name>/SKILL.md`
- `.agents/skills/<name>/SKILL.md` and `~/.agents/skills/<name>/SKILL.md`

The Claude- and agent-compatible paths mean skills written for other agents usually work unmodified.

Each file needs YAML frontmatter. Only `name`, `description`, `license`, `compatibility`, and
`metadata` are recognized; anything else is ignored. Create
`~/.config/opencode/skills/git-release/SKILL.md`:

```markdown
---
name: git-release
description: Create consistent releases and changelogs
license: MIT
---

## What I do

- Draft release notes from merged PRs
- Propose a version bump
- Provide a copy-pasteable `gh release create` command

## When to use me

Use this when preparing a tagged release.
```

`name` must be lowercase alphanumeric with single hyphens (`^[a-z0-9]+(-[a-z0-9]+)*$`), 1–64
characters, and must match the containing directory name. `description` is 1–1024 characters — make
it specific, since it is the only thing the agent sees when deciding whether to load the skill.

Gate access with wildcard permissions:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "skill": {
      "*": "allow",
      "internal-*": "deny",
      "experimental-*": "ask"
    }
  }
}
```

`allow` loads immediately, `ask` prompts first, `deny` hides the skill from the agent entirely. To
turn skills off for a given agent, set `"tools": { "skill": false }` on it.

If a skill doesn't appear: check `SKILL.md` is capitalized, frontmatter has both `name` and
`description`, the name is unique across all locations, and no `deny` rule is hiding it.

### Plugins

Plugins are JS modules that hook into the OpenCode runtime — they can rewrite the system prompt,
intercept commands, register tools, and react to events. Unlike skills, a plugin is active on every
turn.

Declare npm packages in `~/.config/opencode/opencode.json` for global use, or in a project's
`opencode.json` for that project. OpenCode downloads declared packages and their dependencies when
it starts. OpenCode V1 uses `plugin`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-helicone-session", "@my-org/custom-plugin"]
}
```

OpenCode V2 uses `plugins`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": ["@dietrichgebert/ponytail"]
}
```

Local plugin entry points also differ: V1 can use a JS file path; V2 configured paths name a plugin
directory. Follow the plugin's version-specific installation instructions. **Relative paths resolve
against the config that declares them**; use an absolute path for a shared checkout. See the
[plugin docs](https://opencode.ai/docs/plugins/) and [Ponytail's installation guide](https://github.com/DietrichGebert/ponytail/blob/main/INSTALL.md#opencode).

### MCP servers

MCP servers expose external tools (issue trackers, docs search, browsers) to the agent. Add them
interactively:

```bash
opencode mcp add          # guided, local or remote
opencode mcp list         # servers and connection/auth status
opencode mcp auth <name>  # OAuth flow
opencode mcp logout <name>
opencode mcp debug <name> # diagnose connection/OAuth problems
```

A **local** server is a process OpenCode spawns:

The following local and remote examples use V1's direct `mcp.<name>` layout.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "my-local-server": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-everything"],
      "enabled": true,
      "environment": { "MY_ENV_VAR": "value" },
      "timeout": 5000
    }
  }
}
```

A **remote** server is reached over HTTP:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "context7": {
      "type": "remote",
      "url": "https://mcp.context7.com/mcp",
      "headers": { "CONTEXT7_API_KEY": "{env:CONTEXT7_API_KEY}" }
    },
    "sentry": {
      "type": "remote",
      "url": "https://mcp.sentry.dev/mcp",
      "oauth": {}
    }
  }
}
```

For V2, nest entries under `mcp.servers` and use `disabled` instead of `enabled`. A local example:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "servers": {
      "my-local-server": {
        "type": "local",
        "command": ["npx", "-y", "@modelcontextprotocol/server-everything"],
        "disabled": false,
        "timeout": { "startup": 5000 }
      }
    }
  }
}
```

Remote entries use the same V2 nesting and enablement fields. The installer applies these
differences automatically to Serena, Context7, and gradle-mcp. Manual examples require you to
provide their launcher dependencies, such as Node/npm for `npx`.

OAuth is auto-detected: OpenCode catches the 401, registers a client dynamically if the server
supports it, and stores tokens in `~/.local/share/opencode/mcp-auth.json`. Set `"oauth": false` for
servers that use API keys instead.

**Watch the context cost.** Every MCP tool description sits in the context window on every turn, and
large servers (the GitHub one is the usual offender) can eat a serious share of it. If you have many
servers, disable them globally and re-enable per agent:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "tools": { "my-mcp*": false },
  "agent": {
    "my-agent": {
      "tools": { "my-mcp*": true }
    }
  }
}
```

Glob patterns support `*` (zero or more characters) and `?` (exactly one).

Reference a server by name in your prompt — `use context7` — or add a line to `AGENTS.md` telling
the agent when to reach for it.

### Agents

```bash
opencode agent create      # guided setup
opencode agent list
```

Agents can also be markdown files in `~/.config/opencode/agents/` or `.opencode/agents/`, or inline
under the `agent` key. Set a default with `"default_agent": "plan"` (must be a primary agent, not a
subagent). `subagent_depth` controls how deeply subagents may spawn other subagents — default `1`.

### Commands

Reusable prompt templates, either in config or as markdown files in `~/.config/opencode/commands/`
(global) or `.opencode/commands/` (project):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "command": {
    "test": {
      "template": "Run the full test suite with coverage and suggest fixes for any failures.",
      "description": "Run tests with coverage",
      "agent": "build"
    }
  }
}
```

Standalone command files belong in the project or global commands directory. A plugin may also
register its own commands; follow that plugin's installation instructions for your OpenCode version.

### Instructions

Merge extra rule files into every prompt:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["CONTRIBUTING.md", "docs/guidelines.md", ".cursor/rules/*.md"]
}
```

OpenCode also auto-loads `AGENTS.md` from the project root, and reads `~/.claude/CLAUDE.md` plus
`.claude/skills` unless you set `OPENCODE_DISABLE_CLAUDE_CODE=true`.

### Formatters and LSP overrides

```json
{
  "$schema": "https://opencode.ai/config.json",
  "formatter": {
    "prettier": { "disabled": true },
    "custom-prettier": {
      "command": ["npx", "prettier", "--write", "$FILE"],
      "extensions": [".js", ".ts", ".jsx", ".tsx"]
    }
  },
  "lsp": {
    "typescript": { "disabled": true }
  }
}
```

### Performance on large repos

Snapshots track every agent change in an internal git repo so you can `/undo`. On very large
monorepos this gets slow and disk-hungry:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "snapshot": false,
  "watcher": {
    "ignore": ["node_modules/**", "dist/**", ".git/**"]
  }
}
```

Disabling snapshots means agent changes can no longer be rolled back from the UI.

---

## 7. Add-ons

A running list of add-ons worth installing, with the exact steps for each.

### What `install.sh` offers

The installer presents these as a multi-select list, all pre-selected. Each one is installed the way
its own project documents rather than through a single generic mechanism, because they genuinely
differ — some are npm plugins, some are MCP servers written into `opencode.json`, some are skill
directories copied from a git clone, and one is a VS Code extension.

| Add-on | Kind | What it gives the agent |
| --- | --- | --- |
| [ponytail](https://github.com/DietrichGebert/ponytail) | plugin | Reuse-before-rewrite discipline; roughly half the code |
| [Kotlin by JetBrains](https://kotlinlang.org/docs/kotlin-lsp.html) | vscode | IntelliJ-grade Kotlin support in your editor |
| [Serena](https://github.com/oraios/serena) | mcp | Symbol-level navigation and editing over Kotlin LSP |
| [Context7](https://context7.com) | mcp | Version-correct library docs instead of recalled APIs |
| [gradle-mcp](https://github.com/rnett/gradle-mcp) | mcp | Runs builds and tests, and reads the real classpath |
| [architecture-lens](https://github.com/zachcr-ws/improve-code-architecture) | skill | Design review during routine work, plus a restructuring workflow |
| [Superpowers](https://github.com/obra/superpowers) | plugin | Planning, TDD, and verification as a full framework |
| [caveman](https://github.com/JuliusBrussee/caveman) | plugin | Compresses the agent's prose, not its code |
| [handoff](https://github.com/mattpocock/skills) | skill | Turns a dying session into a document the next one can use |
| [mem0](https://docs.mem0.ai/integrations/opencode) | plugin | Memory across sessions, hosted or fully local |
| [damage-control](https://github.com/whjvenyl/opencode-damage-control) | plugin | Blocks destructive commands before they run |
| [warden](https://github.com/toreuyar/opencode-warden) | plugin | Secret detection, redaction, and an audit trail |
| KTX conventions | convention | An `AGENTS.md` block that stops Java-era libGDX habits |
| [DCP](https://github.com/yuyi118/DCP) | plugin | Prunes stale tool output as a session grows |

Things worth knowing before you run it:

- **Dependencies follow the selected tool.** Working installations are reused. Missing or unsuitable Node is
  installed as Node 24 LTS through Homebrew, with its path activated for this run and future zsh
  sessions. Handoff requires Node 22.20+; caveman and local mem0 use Node 22.13+ to satisfy their
  current transitive dependencies, even though their own quick-start requirements are lower.
- **Serena is installed through uv**, including Python 3.13 and its Python packages. Its managed
  Kotlin language server supplies its own Java runtime. The MCP entry uses the installed Serena
  executable's absolute path.
- **gradle-mcp gets a JDK 21+, JBang, and Gradle through SDKMAN.** A working project `./gradlew`
  replaces the need for a global Gradle installation. The script checks the dependencies before
  writing the MCP entry and includes the selected `JAVA_HOME` in that entry.
- **The Kotlin extension gets an editor if needed.** Existing editor CLIs and standard VS Code app
  locations are checked first; otherwise VS Code is installed through Homebrew. Keeping the old,
  conflicting Kotlin extension skips the new extension rather than reporting it as working.
- **Serena is per project.** The global MCP entry is only half of it; each project needs
  `.serena/project.yml` with `languages: ["kotlin"]`. The final summary repeats the command.
- **`handoff` installs into the current directory**, not your global config, because the skills.sh
  installer is project-scoped. The script warns and asks before running it, so run it from your
  project root if you want it there.
- **`mem0` asks which backend you want.** Hosted mem0 needs `MEM0_API_KEY`, and an empty answer skips
  it. Local mem0 gets Node/npm and runs `opencode-mem0 init` before registration. A temporary,
  authenticated loopback OpenCode server must then report the memory tool (V1) or an active mem0
  plugin (V2), within 120 seconds. Crashes, missing registration, and timeouts fail the check and
  remove that plugin entry. This checks registration, not an end-to-end memory query. First use
  can download a ~547 MB embedding model; automatic capture needs a configured memory provider.
- **DCP is installed last on purpose.** Its docs ask for it at the end of the plugin array so it
  does not interfere with OAuth plugins, so the script moves it there after everything else.
- **caveman runs its upstream GitHub installer** through `npx`. That installer manages its plugin,
  commands, and rules; it may pin the assets it downloads to an upstream release.

MCP servers and plugins load at startup, so restart OpenCode after the script finishes.

The final summary distinguishes **configured**, **skipped**, and **failed** selections. Any failed
setup returns a nonzero exit status. Plugin packages and their libraries are downloaded by OpenCode;
their development dependencies do not require separate system installs.

Dependency checks are based on these upstream installation instructions and package manifests:

| Tool | Prerequisites handled by this installer |
| --- | --- |
| [OpenCode](https://opencode.ai/docs/) | Homebrew for brew sources; Node/npm for the npm source |
| [Ponytail](https://github.com/DietrichGebert/ponytail/blob/main/INSTALL.md) | OpenCode's plugin runtime; JSON edits use Node or Python |
| [Kotlin](https://kotlinlang.org/docs/kotlin-lsp.html) | A VS Code-compatible editor; the extension manages its language server |
| [Serena](https://github.com/oraios/serena/blob/main/docs/02-usage/010_installation.md) | uv, managed Python 3.13, and the Serena package |
| [Context7](https://github.com/upstash/context7) | Remote MCP connection; API key optional |
| [gradle-mcp](https://github.com/rnett/gradle-mcp#getting-started) | JDK 21+, JBang, Gradle or an executable project wrapper; SDKMAN's curl/zip/unzip |
| [Architecture lens](https://github.com/zachcr-ws/improve-code-architecture#install) | Git for copying the two skills from upstream |
| [Superpowers](https://github.com/obra/superpowers/blob/main/.opencode/INSTALL.md) | Git; OpenCode V2 requires 2.0.4+ |
| [Caveman](https://github.com/JuliusBrussee/caveman/blob/main/package.json) | Node 22.13+ for its `@caveman-ai/cli` dependency, npm/npx, Git |
| [Handoff / skills](https://github.com/vercel-labs/skills/blob/main/package.json) | Node 22.20+, npm/npx, Git |
| [Hosted mem0](https://github.com/mem0ai/mem0/tree/main/integrations/opencode-plugin) | OpenCode's plugin runtime and a user-supplied API key |
| [Local mem0](https://github.com/ZeR020/opencode-mem0#quick-start) | Node 22.13+ for current AI/SQLite dependencies, npm/npx; native packages managed by npm/OpenCode |
| [Damage-control](https://github.com/whjvenyl/opencode-damage-control#quick-start) | OpenCode's plugin runtime |
| [Warden](https://github.com/toreuyar/opencode-warden/blob/main/package.json) | V1 uses Warden 1.3.0; V2 uses Warden 2 and requires OpenCode 2.0.18+ |
| KTX conventions | No extra runtime; writes Markdown |
| [DCP](https://github.com/Opencode-DCP/opencode-dynamic-context-pruning) | OpenCode 1.18.29+; bundled packages managed by OpenCode |

The script upgrades OpenCode when a selected add-on requires a newer host. It chooses `plugin`
for V1 and `plugins` for V2. Shared dependencies are retained by default during uninstall; the JVM,
uv, Bun, mem0, and extension removal options remain explicit.

Node checks also account for the published [`@caveman-ai/cli`](https://registry.npmjs.org/@caveman-ai/cli/latest),
[`ai` 7](https://registry.npmjs.org/ai/7.0.4), and
[`better-sqlite3` 13](https://registry.npmjs.org/better-sqlite3/13.0.2) runtime requirements.

Run the isolated regression checks with `python3 -m unittest discover -s tests -v` and the syntax
check with `bash -n install.sh`. The tests use fake installers and local HTTP servers.

### Ponytail

[Ponytail](https://github.com/DietrichGebert/ponytail) is a coding ruleset that makes the agent stop
over-building. Before writing code it walks a ladder and stops at the first rung that holds:

```
1. Does this need to exist?   → no: skip it (YAGNI)
2. Already in this codebase?  → reuse it, don't rewrite
3. Stdlib does it?            → use it
4. Native platform feature?   → use it
5. Installed dependency?      → use it
6. One line?                  → one line
7. Only then: the minimum that works
```

The ladder runs *after* the agent understands the problem, not instead of it, and validation, error
handling, security, and accessibility are explicitly never cut. On the maintainer's agentic
benchmark (12 feature tickets against a real FastAPI + React repo, Haiku 4.5, n=4) it produced ~54%
less code, ~20% lower cost, and ~27% less wall time than the same agent with no skill.

On OpenCode it ships as a plugin that injects the ruleset, registers the `/ponytail` commands,
and supports the active intensity level through the host's plugin API.

#### Install (recommended)

Select Ponytail in `install.sh`. The script registers it in the global config and asks which
intensity to use. For a manual global install, add the package to
`~/.config/opencode/opencode.json`. V1:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["@dietrichgebert/ponytail"]
}
```

V2:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": ["@dietrichgebert/ponytail"]
}
```

Use a project's `opencode.json` for project-only scope. Restart OpenCode after changing the config.
The [upstream guide](https://github.com/DietrichGebert/ponytail/blob/main/INSTALL.md#opencode)
also documents V2's `opencode plugin add @dietrichgebert/ponytail` command; V1 has no `plugin add`.

#### Install from a checkout

Useful if you want to edit the ruleset or track `main`. Clone once to a permanent location:

```bash
git clone https://github.com/DietrichGebert/ponytail ~/ponytail
```

Then point your global config at the appropriate entry point by absolute path. V1 uses the file:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["/Users/YOUR_USERNAME/ponytail/.opencode/plugins/ponytail.mjs"]
}
```

V2 uses the directory:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": ["/Users/YOUR_USERNAME/ponytail/.opencode/plugins"]
}
```

Use the checkout's actual absolute path. A relative path in a global config resolves against that
config, rather than against whichever project you open. V2 rejects a configured path to the
individual `ponytail.mjs` file. See the upstream guide for the command-discovery behavior of your
Ponytail/OpenCode versions.

#### Commands

| Command | What it does |
| --- | --- |
| `/ponytail [lite \| full \| ultra \| off]` | Set intensity or turn it off; no argument re-enables it if off, otherwise reports the level. |
| `/ponytail-review` | Review a change for correctness, safety, performance, and unnecessary code. |
| `/ponytail-audit` | Audit the whole repo, not just the diff. |
| `/ponytail-debt` | Collect `shortcut:` comments and older `ponytail:` comments into a ledger. |
| `/ponytail-gain` | Show the measured-impact scoreboard from the benchmark. |
| `/ponytail-help` | Quick reference for the above. |

A mode switch applies from the *next* message, not the one that set it.

#### Configure the default level

Default is `full`. Set it for every new session with an env var in `~/.zshrc`:

```bash
export PONYTAIL_DEFAULT_MODE=lite   # lite | full | ultra | off
```

Or in `~/.config/ponytail/config.json`:

```json
{ "defaultMode": "full" }
```

The installer writes every selected mode, including `full`, while retaining other config fields.
An exported `PONYTAIL_DEFAULT_MODE` takes precedence over the file; the installer reports that
override rather than silently changing your environment setting.

The ruleset is also injected into every subagent spawned via the task tool. To limit that, set
`PONYTAIL_SUBAGENT_MATCHER` to a regex tested (unanchored, case-insensitive) against the subagent's
type — `explore|general` matches either, `^general$` is exact. Unset injects into all of them.

#### As an MCP server instead

The repo also ships `ponytail-mcp`, which serves the same ruleset over stdio as both a prompt and a
read-only `ponytail_instructions` tool. It exists for hosts that have no always-on injection point;
on OpenCode the plugin is the better fit, since MCP prompts are user-invoked rather than automatic.

```bash
cd ~/ponytail/ponytail-mcp && npm install
```

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "ponytail": {
      "type": "local",
      "command": ["node", "/Users/YOUR_USERNAME/ponytail/ponytail-mcp/index.js"]
    }
  }
}
```

This MCP example uses V1 nesting; use `mcp.servers.ponytail` on V2 as described above.

#### Uninstall

Remove the entry from `plugin` (V1) or `plugins` (V2) in your config (and symlinked command files, if you
created them). Ponytail also writes a mode flag and `~/.config/ponytail/config.json` outside the
plugin folder; `node scripts/uninstall.js` from a checkout cleans those up.

---

## 8. Everyday usage

| Action | How |
| --- | --- |
| Start the TUI | `opencode` |
| Continue last session | `opencode --continue` |
| One-off prompt, no TUI | `opencode run "Explain closures in JS"` |
| Pick a model for a run | `opencode run -m anthropic/claude-sonnet-4-5 "..."` |
| Toggle Plan / Build mode | `Tab` inside the TUI |
| Undo / redo agent changes | `/undo` and `/redo` |
| Share a conversation | `/share` (copies a link to your clipboard) |
| List / delete sessions | `opencode session list`, `opencode session delete <id>` |
| Token usage and cost | `opencode stats --days 30` |
| Headless HTTP server | `opencode serve --port 4096` |
| Browser UI | `opencode web` |
| Attach TUI to a server | `opencode attach http://localhost:4096` |

Attach an image by dragging and dropping it into the terminal. Reference files in a prompt with
`@path/to/file`.

---

## 9. Useful environment variables

Add to `~/.zshrc` as needed:

```bash
export OPENCODE_CONFIG=~/my/custom-config.json   # custom config path
export OPENCODE_CONFIG_DIR=~/my/opencode-dir     # custom agents/commands/plugins dir
export OPENCODE_DISABLE_AUTOUPDATE=true          # pin your version
export OPENCODE_SERVER_PASSWORD="..."            # basic auth for serve/web
export OPENCODE_AUTO_SHARE=true                  # auto-share every session
```

Other useful ones: `OPENCODE_TUI_CONFIG`, `OPENCODE_DISABLE_MOUSE`, `OPENCODE_DISABLE_LSP_DOWNLOAD`,
`OPENCODE_DISABLE_AUTOCOMPACT`, `OPENCODE_DISABLE_CLAUDE_CODE` (stops it reading `~/.claude/CLAUDE.md`
and `.claude/skills`).

---

## 10. Updating

```bash
opencode upgrade                 # latest
opencode upgrade 1.18.29         # specific V1 version, as an example
opencode upgrade -m brew         # tell it which install method you used
```

If you installed via Homebrew, `brew upgrade opencode` works too. OpenCode also auto-updates on
startup unless you set `"autoupdate": false` or `"notify"` in your config.

---

## 11. Uninstalling

OpenCode's own uninstaller handles the binary and its data:

```bash
opencode uninstall --dry-run     # preview what gets removed
opencode uninstall               # remove binary, config, and session data
opencode uninstall --keep-config --keep-data
```

When `opencode` is on your `PATH`, running [`install.sh`](install.sh) offers **Uninstall and quit**.
That opens a removal menu; each family is a separate choice, and **Done** leaves the rest in place.
Reinstall uses the same menu and proceeds only after you remove the OpenCode core.

| Removal choice | What it removes |
| --- | --- |
| OpenCode + add-on config | OpenCode binary/packages, global config, credentials, sessions, caches, and the related directories below |
| JVM toolchain | All Java, JBang, and Gradle candidates under `~/.sdkman`; also Homebrew JBang/Gradle copies |
| uv / uvx | Homebrew or default standalone launchers, default uv data/cache directories, and a legacy `# uv` PATH block |
| Bun | An existing Homebrew/standalone Bun installation and its `# bun` shell block; this installer does not install Bun |
| opencode-mem0 | The global npm package and the installer-owned `# opencode mem0` key block |
| Kotlin extension | `JetBrains.kotlin-server` in the first detected editor, after confirmation |

The OpenCode core choice offers a backup of `~/.config/opencode` before removal. That archive
does **not** include credentials or sessions under `~/.local/share/opencode`. Core removal clears:

| Removed outright | What it holds |
| --- | --- |
| `~/.config/opencode` | config, agents, commands, skills, plugins |
| `~/.local/share/opencode` | credentials, sessions, MCP auth |
| `~/.cache/opencode` | caches, including downloaded plugin packages |
| `~/.local/state/opencode` | logs and state |
| `~/.opencode` | install-script binary |
| `~/.config/ponytail` | ponytail mode and config |
| `~/.serena` | Serena's global config and logs |

Core removal also removes the `# opencode` PATH block and `# opencode superpowers` telemetry block
from `.zshrc`. It matches the exact header and following line, and skips rewriting a profile that
would become empty. Node/Homebrew PATH blocks stay with those shared dependencies.

Homebrew, Node, Git, VS Code, and SDKMAN itself remain installed. The uv-managed Serena package
and Python environment also survive core removal; the uv removal option clears its default data
directory, which can include other uv-managed tools. Choosing a dependency removal item affects
that shared installation, not only its OpenCode use.

Two categories are deliberately left alone. Project directories are never touched, so `.serena/`,
`.agents/skills/`, `.opencode/`, and any KTX block appended to an `AGENTS.md` survive — the script
prints a reminder listing them rather than hunting through your repositories. And `MEM0_API_KEY` and
`CONTEXT7_API_KEY` lines written outside installer-owned blocks are left alone. Hosted mem0 can
save its key in an installer-owned `.zshrc` block; the mem0 uninstall option removes that block.

---

## 12. Troubleshooting

**`opencode: command not found`** — the install script's target directory isn't on your `PATH`. Add
it to `~/.zshrc` and reload with `source ~/.zshrc`. Dependency PATH changes made by the installer
apply to its own process and future shells; an already-open shell also needs that reload.

**A selected tool says failed or skipped** — those states are reported separately from configured
tools. Review the dependency/install output above the summary and re-run the script. Failure returns
a nonzero exit status; a deliberate skip does not. Configured npm plugins still load on the next
OpenCode start.

**Local mem0 fails its startup check** — the installer removes its plugin entry after a crash,
timeout, or missing registration. Check OpenCode/plugin compatibility and local storage setup
before retrying. The 120-second check proves registration, not a successful memory query or
completion of the initial embedding-model download. Hosted mem0 instead requires `MEM0_API_KEY`;
an empty key response skips it.

**Configuration consolidation fails** — keep the source file and correct its syntax. The
installer's JSONC merge accepts full-line `//` comments but not other JSONC extensions. Convert
inline/block comments and trailing commas to plain JSON before retrying.

**No models listed** — confirm a provider is authenticated with `opencode auth list`, then refresh
the model cache with `opencode models --refresh`.

**See the resolved config** — `opencode debug config` prints the final merged configuration,
including anything enforced by managed settings or MDM.

**OpenCode hangs on startup** — inspect the logs and isolate plugins one at a time. Check each
plugin's host-version compatibility, API keys, and backend configuration. For V1, `opencode debug
config` can help diagnose configuration/plugin loading; use V2's diagnostics for a V2 installation.

**Plugins are missing** — check `plugin` on V1 versus `plugins` on V2, supported package versions,
and conflicting global/project config files. Re-running `install.sh` consolidates its standard
global config files; successful merges retain `.jsonc` as `.jsonc.superseded`. Restart OpenCode
after changes. A configured result in the installer summary does not guarantee every plugin's
runtime initialization has succeeded.

**Read the logs** — `opencode --print-logs --log-level DEBUG`.

**Broken rendering or mouse behavior** — try a different terminal emulator, or set
`OPENCODE_DISABLE_MOUSE=true`.

**Slow startup with MCP servers** — run `opencode serve` once and use
`opencode run --attach http://localhost:4096 "..."` to skip MCP cold boots on every invocation.

---

## Reference

- Docs: <https://opencode.ai/docs/>
- V2 docs: <https://opencode.ai/v2/docs/>
- IDE integration: <https://opencode.ai/docs/ide/>
- Config schema: <https://opencode.ai/config.json>
- TUI schema: <https://opencode.ai/tui.json>
- Model catalog: <https://models.dev>
- Ponytail: <https://github.com/DietrichGebert/ponytail>
- Kotlin Language Server: <https://kotlinlang.org/docs/kotlin-lsp.html>
- Serena configuration: <https://oraios.github.io/serena/02-usage/050_configuration.html>
- gradle-mcp: <https://gradle-mcp.rnett.dev/latest/>
