"""Installer regressions: real shell/config code, fake installers and OpenCode."""

import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "install.sh"


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="opencode-install-test-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def shell(self, body, *, expected=0, env=None, timeout=12):
        # Fail closed if a test accidentally reaches a real installer/profile.
        prelude = r'''
source "$1"
USE_COLOR=0; setup_colors
OPENCODE_CONFIG_DIR="$2"
OPENCODE_CONFIG="$2/opencode.json"
SKILLS_DIR="$2/skills"
SDKMAN_DIR="$2/sdkman"
cd "$2" || exit 99
require_brew() { echo 'unexpected Homebrew bootstrap' >&2; return 97; }
persist_path() { echo 'unexpected shell profile write' >&2; return 97; }
brew() { echo 'unexpected brew call' >&2; return 97; }
curl() { echo 'unexpected curl call' >&2; return 97; }
npm() { echo 'unexpected npm call' >&2; return 97; }
npx() { echo 'unexpected npx call' >&2; return 97; }
sdk() { echo 'unexpected sdk call' >&2; return 97; }
opencode() { echo 1.18.31; }
'''
        environment = os.environ.copy()
        environment.pop("MEM0_API_KEY", None)
        environment.update(env or {})
        result = subprocess.run(
            ["/bin/bash", "-c", prelude + body, "test", str(SCRIPT), str(self.root)],
            capture_output=True, text=True, env=environment, timeout=timeout,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result.stdout

    def test_hosted_mem0_without_key_can_skip_under_nounset(self):
        output = self.shell('''
menu() { MENU_CHOICE=1; }
read() { return 1; }
add_plugin() { exit 96; }
install_addon_mem0
''', expected=2)
        self.assertIn("Skipping mem0", output)
        self.assertFalse((self.root / "opencode.json").exists())

    def test_ponytail_full_replaces_old_mode_and_preserves_settings(self):
        path = self.root / "ponytail.json"
        path.write_text('{"defaultMode":"ultra","other":true}')
        self.shell('set_ponytail_mode full "$2/ponytail.json"')
        self.assertEqual(json.loads(path.read_text()), {"defaultMode": "full", "other": True})

    def test_results_distinguish_failure_skip_and_success(self):
        output = self.shell('''
ADDON_ID=(good bad skip); ADDON_NAME=(Good Bad Skip); ADDON_KIND=(plugin plugin skill)
ADDON_SELECTED=(1 1 1)
consolidate_config() { return 0; }; config_has() { return 1; }
install_addon_good() { return 0; }; install_addon_bad() { return 1; }
install_addon_skip() { return 2; }
rc=0; install_addons || rc=$?
[ "$rc" = 1 ] && [ "$ADDON_FAILURES" = 1 ] || exit 91
[ "${ADDON_STATUS[*]}" = 'configured failed skipped' ] || exit 92
summary
''')
        self.assertIn("Good (plugin) — configured", output)
        self.assertIn("Bad — failed", output)
        self.assertIn("Skip — skipped", output)

    def test_node_dependency_installs_and_rechecks_version(self):
        output = self.shell('''
printf 'v20.0.0' > version
node() { cat version; }; npm() { return 0; }; npx() { return 0; }
require_brew() { return 0; }
brew() {
  case "$1" in
    list) return 1 ;;
    install) [ "$2" = node@24 ] || return 95; printf 'v24.0.0' > version ;;
    --prefix) printf '%s' "$OPENCODE_CONFIG_DIR" ;;
    *) return 94 ;;
  esac
}
persist_path() { echo "activated $1"; }
ensure_node 22.20.0
''')
        self.assertIn("brew install node@24", output)
        self.assertIn("activated", output)

    def test_failed_node_dependency_prevents_handoff_install(self):
        self.shell('''
confirm() { return 0; }
ensure_node() { return 1; }
npx() { touch should-not-install; }
install_addon_handoff
''', expected=1)
        self.assertFalse((self.root / "should-not-install").exists())

    def test_sufficient_node_reuses_existing_install(self):
        self.shell('''
node() { echo v22.20.0; }; npm() { return 0; }; npx() { return 0; }
ensure_node 22.20.0
''')

    def test_path_activation_is_idempotent_and_quotes_spaces(self):
        self.shell('''
source "$1"
USE_COLOR=0; setup_colors
persist_path "$2/node space/bin" '# test node' "$2/zshrc"
persist_path "$2/node space/bin" '# test node' "$2/zshrc"
bash -n "$2/zshrc"
''')
        profile = (self.root / "zshrc").read_text()
        self.assertEqual(profile.count("# test node"), 1)

    def test_missing_json_runtime_installs_node(self):
        self.shell('''
node() { return 127; }; python3() { return 127; }
ensure_node() { touch runtime-installed; }
ensure_json_runtime
''')
        self.assertTrue((self.root / "runtime-installed").exists())

    def test_uv_is_installed_and_verified(self):
        self.shell('''
uv() { [ -f uv-installed ]; }; uvx() { [ -f uv-installed ]; }
require_brew() { return 0; }
brew() { [ "$*" = 'install uv' ] && touch uv-installed; }
ensure_uv
''')
        self.assertTrue((self.root / "uv-installed").exists())

    def test_sdkman_initialization_handles_nounset_and_enables_auto_answers(self):
        root = self.root / "sdkman"
        (root / "bin").mkdir(parents=True); (root / "etc").mkdir()
        (root / "bin" / "sdkman-init.sh").write_text(
            'sdkman_auto_answer=false\nignore="$SDKMAN_OPTIONAL_UNSET_TEST"\nsdk() { return 0; }\n'
        )
        (root / "etc" / "config").write_text("sdkman_auto_answer=false\n")
        self.shell('''
unset SDKMAN_OPTIONAL_UNSET_TEST
ensure_command() { echo "$1" >> dependencies; }
ensure_sdkman
[ "$sdkman_auto_answer" = true ]
''')
        self.assertEqual((self.root / "dependencies").read_text().splitlines(), ["curl", "zip", "unzip"])

    def test_main_returns_addon_failure_after_summary(self):
        self.shell('''
opencode_installed() { return 0; }; detect_install_method() { echo script; }
menu() { MENU_CHOICE=1; }; select_addons() { return 0; }
install_addons() { return 1; }; summary() { touch summary-printed; }
main
''', expected=1)
        self.assertTrue((self.root / "summary-printed").exists())

    def test_git_dependency_is_installed_when_git_is_broken(self):
        self.shell('''
git() { [ -f git-installed ]; }
require_brew() { return 0; }
brew() {
  case "$1" in
    install) [ "$2" = git ] && touch git-installed ;;
    --prefix) printf '%s' "$OPENCODE_CONFIG_DIR" ;;
    *) return 94 ;;
  esac
}
ensure_git
''')
        self.assertTrue((self.root / "git-installed").exists())

    def test_sdkman_installs_requested_lts_instead_of_default(self):
        self.shell('''
ensure_sdkman() { return 0; }
toolchain_ready() { [ -f jdk-installed ]; }
sdk() {
  case "$1" in
    list) printf ' | Temurin | 21.0.9 | tem | | 21.0.9-tem\n' ;;
    install) [ "$2 $3" = 'java 21.0.9-tem' ] && touch jdk-installed ;;
    use) [ "$2 $3" = 'java 21.0.9-tem' ] ;;
    *) return 94 ;;
  esac
}
sdkman_ensure java 21
''')
        self.assertTrue((self.root / "jdk-installed").exists())

    def test_java_failure_prevents_mcp_registration(self):
        self.shell('''
sdkman_ensure() { return 1; }
config_add_mcp() { touch should-not-configure; }
install_addon_gradle_mcp
''', expected=1)
        self.assertFalse((self.root / "should-not-configure").exists())

    def test_gradle_wrapper_avoids_unnecessary_gradle_install(self):
        wrapper = self.root / "gradlew"
        wrapper.touch(); wrapper.chmod(0o755)
        self.shell('''
sdkman_ensure() { echo "$*" >> dependencies; }
jbang() { return 0; }; JAVA_HOME="$2/jdk"
config_add_mcp() { printf '%s' "$2" > mcp.json; }
install_addon_gradle_mcp
''')
        self.assertEqual((self.root / "dependencies").read_text().splitlines(), ["java 21", "jbang"])
        config = json.loads((self.root / "mcp.json").read_text())
        self.assertEqual(config["environment"]["JAVA_HOME"], str(self.root / "jdk"))

    def test_serena_installs_python_and_packages_before_registration(self):
        executable = self.root / "serena"
        executable.write_text("#!/bin/bash\nexit 0\n"); executable.chmod(0o755)
        self.shell('''
ensure_uv() { return 0; }
uv() {
  echo "$*" >> dependencies
  if [ "$1 $2" = 'tool dir' ]; then printf '%s' "$OPENCODE_CONFIG_DIR"; fi
}
config_add_mcp() { printf '%s' "$2" > mcp.json; }
install_addon_serena
''')
        calls = (self.root / "dependencies").read_text()
        self.assertIn("python install 3.13", calls)
        self.assertIn("tool install --python 3.13 serena-agent", calls)
        self.assertEqual(json.loads((self.root / "mcp.json").read_text())["command"][0], str(executable))

    def test_missing_editor_is_installed(self):
        self.shell('''
editor_cli() { [ -f editor-installed ]; }
require_brew() { return 0; }
brew() { [ "$*" = 'install --cask visual-studio-code' ] && touch editor-installed; }
ensure_editor
''')
        self.assertTrue((self.root / "editor-installed").exists())

    def test_plugin_config_uses_host_key_and_preserves_existing_settings(self):
        for version, key in [("1.18.31", "plugin"), ("2.0.18", "plugins")]:
            with self.subTest(version=version):
                config = self.root / "opencode.json"
                config.write_text('{"model":"keep","plugin":["existing"]}')
                self.shell(f'''opencode() {{ echo {version}; }}
add_plugin example
add_plugin example
''')
                data = json.loads(config.read_text())
                self.assertEqual(data["model"], "keep")
                self.assertEqual(data[key], ["existing", "example"])
                self.assertNotIn("plugins" if key == "plugin" else "plugin", data)

    def test_mcp_config_uses_version_specific_enablement(self):
        for version in ["1.18.31", "2.0.18"]:
            with self.subTest(version=version):
                (self.root / "opencode.json").write_text('{"model":"keep"}')
                self.shell(f'''opencode() {{ echo {version}; }}
config_add_mcp example '{{"type":"local","command":["server"],"enabled":true}}'
''')
                config = json.loads((self.root / "opencode.json").read_text())
                self.assertEqual(config["model"], "keep")
                entry = config["mcp"]["servers"]["example"] if version.startswith("2") else config["mcp"]["example"]
                if version.startswith("2"):
                    self.assertIs(entry["disabled"], False)
                    self.assertNotIn("enabled", entry)
                else:
                    self.assertIs(entry["enabled"], True)

    def test_json_edits_have_python_fallback(self):
        self.shell('''
has() { [ "$1" != node ] && command -v "$1" >/dev/null 2>&1; }
opencode() { echo 2.0.18; }
add_plugin example
config_add_mcp example '{"type":"local","command":["server"],"enabled":true}'
remove_plugin example
''')
        config = json.loads((self.root / "opencode.json").read_text())
        self.assertEqual(config["plugins"], [])
        self.assertIs(config["mcp"]["servers"]["example"]["disabled"], False)

    def test_consolidation_preserves_plugins_and_ui_settings(self):
        (self.root / "opencode.json").write_text('{"plugin":["existing"],"model":"keep"}')
        (self.root / "opencode.jsonc").write_text('// comment\n{"plugin":["side"]}')
        (self.root / "tui.json").write_text('{"plugins":["misplaced"],"theme":"keep"}')
        self.shell('''
ensure_node() { return 0; }; opencode() { echo 2.0.18; }
consolidate_config
''')
        config = json.loads((self.root / "opencode.json").read_text())
        self.assertEqual(set(config["plugins"]), {"existing", "side", "misplaced"})
        self.assertEqual(config["model"], "keep")
        self.assertEqual(json.loads((self.root / "tui.json").read_text()), {"theme": "keep"})
        self.assertTrue((self.root / "opencode.jsonc.superseded").exists())

    def test_warden_uses_release_compatible_with_host(self):
        for version, expected in [("1.18.31", "opencode-warden@1.3.0"), ("2.0.18", "opencode-warden")]:
            with self.subTest(version=version):
                self.shell(f'''opencode() {{ echo {version}; }}
remove_plugin() {{ return 0; }}
add_plugin() {{ printf '%s' "$1" > spec; }}
install_addon_warden
''')
                self.assertEqual((self.root / "spec").read_text(), expected)

    def test_mem0_requires_positive_registry_evidence_and_cleans_up(self):
        fake = self.root / "bin" / "opencode"
        fake.parent.mkdir()
        fake.write_text(f"#!{sys.executable}\n" + r'''
import http.server, json, os, signal, sys
from pathlib import Path
mode = os.environ['FAKE_OPENCODE_MODE']
def stop(*args):
    Path(os.environ['FAKE_STOP_FILE']).touch()
    sys.exit(0)
signal.signal(signal.SIGTERM, stop)
if mode == 'crash': sys.exit(7)
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        import base64
        auth = 'Basic ' + base64.b64encode(('opencode:' + os.environ['OPENCODE_PASSWORD']).encode()).decode()
        path = '/api/plugin' if 'v2' in mode else '/experimental/tool/ids'
        if self.headers.get('Authorization') != auth or self.path != path:
            self.send_response(403); self.end_headers(); return
        self.send_response(200); self.end_headers()
        body = ['memory'] if mode == 'v1' else []
        if mode == 'v2':
            body = {'data': [{'id': 'opencode-mem0', 'state': {'status': 'active'}}]}
        if mode == 'failed-v2':
            body = {'data': [{'id': 'opencode-mem0', 'state': {'status': 'failed'}}]}
        self.wfile.write(json.dumps(body).encode())
    def log_message(self, *args): pass
server = http.server.HTTPServer(('127.0.0.1', 0), Handler)
print('server listening on http://127.0.0.1:' + str(server.server_port), flush=True)
server.serve_forever()
''')
        fake.chmod(0o755)
        for mode, version, expected in [
            ("v1", "1.18.31", 0), ("v2", "2.0.18", 0),
            ("empty", "1.18.31", 1), ("failed-v2", "2.0.18", 1),
            ("crash", "1.18.31", 1),
        ]:
            with self.subTest(mode=mode):
                stopped = self.root / (mode + "-stopped")
                self.shell(f'''opencode() {{ echo {version}; }}
export PATH={shlex.quote(str(fake.parent))}:"$PATH"
mem0_smoke_test 1000
''', expected=expected, env={"FAKE_OPENCODE_MODE": mode, "FAKE_STOP_FILE": str(stopped)})
                if mode != "crash":
                    self.assertTrue(stopped.exists(), "temporary server was not terminated")


if __name__ == "__main__":
    unittest.main()
