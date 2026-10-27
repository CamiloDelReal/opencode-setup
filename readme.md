# Setting up OpenCode on macOS

OpenCode is an open source AI coding agent that runs in your terminal. This guide walks through
installing it on macOS, connecting a model provider, and configuring it for daily use.

To do the install interactively instead, run [`install.sh`](install.sh) from this repo. It detects an
existing install, lets you pick the source, and offers a multi-select list of add-ons — MCP servers,
plugins, skills, and a VS Code extension — installing each one the way its own project documents:

```bash
./install.sh
```

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
- **Homebrew** if you plan to install that way — <https://brew.sh>.

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

OpenCode has no separate GUI — you run the CLI in VS Code's integrated terminal, and a companion
extension adds editor awareness on top. The extension installs itself the first time you run
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
`plugin`, one array shadows the other entirely and the plugins in the losing file never load.

This bites easily, because `opencode plugin <pkg> --global` writes to `opencode.jsonc` while most
third-party installers patch `opencode.json`. `install.sh` folds any stray `opencode.jsonc` back
into `opencode.json` on every run, and also strips a `plugin` key from `tui.json`, where it is
silently ignored. If you edit config by hand, keep everything in `opencode.json`.

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

OpenCode has five distinct extension mechanisms. They are easy to confuse, so here is what each one
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

Install from npm:

```bash
opencode plugin <npm-module> --global   # writes to global config
opencode plugin <npm-module>            # project config
opencode plugin <npm-module> --force    # replace an existing version
```

Or declare them directly:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-helicone-session", "@my-org/custom-plugin"]
}
```

You can also load a plugin from a local file by dropping it in `~/.config/opencode/plugins/` or
`.opencode/plugins/`, or by pointing the `plugin` array at a path. **Relative paths resolve against
the `opencode.json` that declares them**, so a `./...` path in your global config will not resolve
the way you expect — use an absolute path when sharing one checkout across projects.

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

Commands are discovered from files only in the project directory or the global commands directory —
a plugin's own command files are not picked up just because you loaded the plugin from a path. See
the Ponytail notes below for the practical consequence.

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

- **Dependencies follow the selected tool.** Working installations are reused. Missing Node is
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
- **DCP is installed last on purpose.** Its docs ask for it at the end of the `plugin` array so it
  does not interfere with OAuth plugins, so the script moves it there after everything else.
- **caveman installs from git `main`**, so you always get the current plugin. Its per-turn
  reinforcement uses `experimental.chat.system.transform` — the same hook ponytail uses — which is
  by design; the two projects are meant to run together.

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

On OpenCode it ships as a plugin that appends the ruleset to the system prompt every turn via the
`experimental.chat.system.transform` hook, registers the `/ponytail` commands, and persists the
active intensity level.

#### Install (recommended)

```bash
opencode plugin @dietrichgebert/ponytail --global
```

This installs the npm package and adds it to `~/.config/opencode/opencode.json`, making it active in
every project. Equivalent manual edit:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["@dietrichgebert/ponytail"]
}
```

Drop `--global` to scope it to the current project instead. Restart OpenCode; a startup badge shows
the current mode.

#### Install from a checkout

Useful if you want to edit the ruleset or track `main`. Clone once to a permanent location:

```bash
git clone https://github.com/DietrichGebert/ponytail ~/ponytail
```

Then point your **global** config at the plugin file by **absolute** path:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["/Users/YOUR_USERNAME/ponytail/.opencode/plugins/ponytail.mjs"]
}
```

Two things trip people up here:

1. The README shows `"./.opencode/plugins/ponytail.mjs"`, which resolves relative to the project's
   own `opencode.json`. That only works when the project you open *is* the ponytail checkout. Use
   the absolute path for every other project — the plugin locates its own `hooks/` and `skills/`
   relative to its file, so one checkout serves all projects.
2. The plugin and the slash commands are separate. The plugin gives you the always-on ruleset
   everywhere, but the `/ponytail` command files live in `.opencode/command/` and OpenCode only
   auto-discovers those from the current project or the global commands directory. Link them once:

   ```bash
   mkdir -p ~/.config/opencode/command
   ln -sf ~/ponytail/.opencode/command/* ~/.config/opencode/command/
   ```

   The npm install above does not need this step — the packaged plugin registers the commands
   itself. Even without autocomplete, typing `/ponytail` still runs.

#### Commands

| Command | What it does |
| --- | --- |
| `/ponytail [lite \| full \| ultra \| off]` | Set intensity, or turn it off. No argument reports the current level. |
| `/ponytail-review` | Review the current diff for over-engineering, hands back a delete-list. |
| `/ponytail-audit` | Audit the whole repo, not just the diff. |
| `/ponytail-debt` | Collect the `ponytail:` shortcuts you deferred into a ledger. |
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

#### Uninstall

Remove the entry from the `plugin` array in your config (and the symlinked command files, if you
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
opencode upgrade v0.1.48         # specific version
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

It does not know about add-ons, though. Running [`install.sh`](install.sh) and choosing **Uninstall**
removes those too. It offers a config backup first, then clears:

| Removed outright | What it holds |
| --- | --- |
| `~/.config/opencode` | config, agents, commands, skills, plugins |
| `~/.local/share/opencode` | credentials, sessions, MCP auth |
| `~/.cache/opencode` | caches, including downloaded plugin packages |
| `~/.local/state/opencode` | logs and state |
| `~/.opencode` | install-script binary |
| `~/.config/ponytail` | ponytail mode and config |
| `~/.serena` | Serena's global config and logs |

Four things it asks about individually, because removing them might not be what you want:

- **The Kotlin by JetBrains extension**, since it lives in the editor rather than under `$HOME`. The
  script also refuses to guess which editor: if `code` is missing but `cursor` is present, it asks
  before touching the other one.
- **The globally installed `opencode-mem0` package**, if you chose the local memory backend.
- **The `~/.zshrc` lines the script added** — the `PATH` entry and the Superpowers telemetry opt-out.
  It matches the exact comment header it wrote and the single line beneath it, and refuses to write
  the file back if the result would be empty.
- **uv and JBang**, which Serena and gradle-mcp need. Defaults to keeping them, since other projects
  on the machine may depend on them.

Two categories are deliberately left alone. Project directories are never touched, so `.serena/`,
`.agents/skills/`, `.opencode/`, and any KTX block appended to an `AGENTS.md` survive — the script
prints a reminder listing them rather than hunting through your repositories. And `MEM0_API_KEY` and
`CONTEXT7_API_KEY` lines written outside installer-owned blocks are left alone. Hosted mem0 can
save its key in an installer-owned `.zshrc` block; the mem0 uninstall option removes that block.

---

## 12. Troubleshooting

**`opencode: command not found`** — the install script's target directory isn't on your `PATH`. Add
it to `~/.zshrc` and reload. With Homebrew on Apple Silicon, make sure `/opt/homebrew/bin` is on
`PATH`.

**No models listed** — confirm a provider is authenticated with `opencode auth list`, then refresh
the model cache with `opencode models --refresh`.

**See the resolved config** — `opencode debug config` prints the final merged configuration,
including anything enforced by managed settings or MDM.

**OpenCode hangs on startup and prints nothing** — a plugin is blocking during load. The log at
`~/.local/share/opencode/log/opencode.log` stops after the `loading path=.../opencode.json` lines and
never reaches `all LSPs are disabled`. Bisect by pointing `~/.config/opencode/opencode.json` at one
plugin at a time and running `opencode debug config`, which completes in about a second on a healthy
config. A plugin waiting on a backend you never configured — mem0 without `MEM0_API_KEY` is the
usual one — waits forever rather than failing.

**`/status` lists fewer plugins than you installed** — you almost certainly have both an
`opencode.json` and an `opencode.jsonc` in `~/.config/opencode/`, and only one of the two `plugin`
arrays is winning. Merge them into `opencode.json`, delete the `.jsonc`, and restart. Re-running
`install.sh` does this for you. Note that a plugin loaded from a path shows up in `/status` under
its filename, so `./plugins/caveman/plugin.js` appears as `plugin` rather than as caveman.

**Read the logs** — `opencode --print-logs --log-level DEBUG`.

**Broken rendering or mouse behavior** — try a different terminal emulator, or set
`OPENCODE_DISABLE_MOUSE=true`.

**Slow startup with MCP servers** — run `opencode serve` once and use
`opencode run --attach http://localhost:4096 "..."` to skip MCP cold boots on every invocation.

---

## Reference

- Docs: <https://opencode.ai/docs/>
- IDE integration: <https://opencode.ai/docs/ide/>
- Config schema: <https://opencode.ai/config.json>
- TUI schema: <https://opencode.ai/tui.json>
- Model catalog: <https://models.dev>
- Ponytail: <https://github.com/DietrichGebert/ponytail>
- Kotlin Language Server: <https://kotlinlang.org/docs/kotlin-lsp.html>
- Serena configuration: <https://oraios.github.io/serena/02-usage/050_configuration.html>
- gradle-mcp: <https://gradle-mcp.rnett.dev/latest/>
