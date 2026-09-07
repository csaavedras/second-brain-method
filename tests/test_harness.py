"""Behavioral fixtures; never use the executor's real provider config or vault."""
import ast
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Harness(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="second-brain-test-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name).resolve()
        self.vault = self.home / "vault with spaces"
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("GIT_", "CLAUDE_", "CODEX_"))}
        self.env.update(HOME=str(self.home), PYTHONDONTWRITEBYTECODE="1", GIT_CONFIG_NOSYSTEM="1",
                        GIT_CONFIG_GLOBAL=os.devnull, GIT_AUTHOR_NAME="Fixture", GIT_AUTHOR_EMAIL="fixture@example.invalid",
                        GIT_COMMITTER_NAME="Fixture", GIT_COMMITTER_EMAIL="fixture@example.invalid")

    def run_cmd(self, args, code=0, data=None, cwd=None):
        result = subprocess.run([str(a) for a in args], input=data, text=True,
                                capture_output=True, env=self.env, cwd=cwd or ROOT)
        self.assertEqual(result.returncode, code, result.stdout + result.stderr)
        return result.stdout

    def install(self, platform="both", code=0, extra=()):
        return self.run_cmd(["bash", ROOT / "install.sh", self.vault, "--platform", platform, *extra], code)

    def put(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def registry(self, *args, code=0):
        return self.run_cmd(["bash", self.vault / "method/scripts/project-registry.sh", "--vault", self.vault, *args], code)

    def repo(self, name="repo"):
        repo = self.home / name
        repo.mkdir()
        self.run_cmd(["git", "init", "-q", repo])
        return repo

    def project(self, repo):
        self.registry("register", "example", repo)
        context = self.put(self.vault / "projects/example/CONTEXT.md", "---\ntype: context\nproject: example\ndate: 2026-09-07\n---\nInitial state\n")
        self.put(context.parent / "hub.md", "# Example\n")
        return context

    def core(self, op, repo, code=0, legacy=False):
        return self.run_cmd(["bash", self.vault / "method/scripts/check-close-core.sh", "--vault", self.vault,
                             *(["--legacy"] if legacy else []), op, repo], code)

    def hook(self, provider, event, repo, session="s1", **fields):
        payload = dict(cwd=str(repo), session_id=session, stop_hook_active=False, **fields)
        output = self.run_cmd(["bash", self.home / f".{provider}/hooks/second-brain-check-close.sh", event], data=json.dumps(payload))
        return json.loads(output) if output.strip() else {}

    def test_install_matrix_and_default(self):
        for platform in ("claude", "codex", "both"):
            with self.subTest(platform=platform):
                self.install(platform)
                self.assertTrue((self.vault / "00-index/projects.json").is_file())
                self.assertFalse((self.vault / "method/method").exists())
                if platform == "claude":
                    self.assertFalse((self.home / ".codex").exists())
                    self.assertFalse((self.home / ".agents").exists())
                elif platform == "codex":
                    # Claude from the prior install must survive.
                    self.assertTrue((self.home / ".claude/CLAUDE.md").is_file())
                for provider in ([platform] if platform != "both" else ["claude", "codex"]):
                    global_file = self.home / f".{provider}" / ("CLAUDE.md" if provider == "claude" else "AGENTS.md")
                    self.assertEqual(global_file.read_text().count("<!-- BEGIN SECOND BRAIN METHOD -->"), 1)
        self.run_cmd(["bash", ROOT / "install.sh"])
        self.assertTrue((self.home / "second-brain/00-index/projects.json").is_file())

    def test_codex_only_does_not_create_claude(self):
        self.install("codex")
        self.assertFalse((self.home / ".claude").exists())
        self.assertFalse((self.home / ".codex/config.toml").exists())
        self.assertFalse((self.home / ".codex/AGENTS.override.md").exists())
        for name in ("start", "close", "learn", "new-project", "kickoff"):
            skill = self.home / f".agents/skills/sb-{name}"
            self.assertIn(f"name: sb-{name}", (skill / "SKILL.md").read_text())
            self.assertIn("allow_implicit_invocation: false", (skill / "agents/openai.yaml").read_text())
        for role in ("implementer", "tester"):
            self.assertTrue((self.home / f".codex/agents/second-brain-{role}.toml").exists())
        self.assertTrue((self.home / ".codex/rules/second-brain.rules").exists())

    def test_preservation_idempotency_and_backups(self):
        for provider, name in (("claude", "CLAUDE.md"), ("codex", "AGENTS.md")):
            self.put(self.home / f".{provider}/{name}", "My personal instructions.\n")
        self.put(self.home / ".claude/settings.json", (ROOT / "tests/fixtures/claude-settings.json").read_text())
        self.put(self.home / ".codex/hooks.json", (ROOT / "tests/fixtures/codex-hooks.json").read_text())
        preserved = [self.put(self.home / ".codex/config.toml", 'model = "my-choice"\n'),
                     self.put(self.home / ".codex/rules/default.rules", "# mine\n"),
                     self.put(self.home / ".agents/skills/other/SKILL.md", "My skill\n"),
                     self.put(self.home / ".codex/agents/implementer.toml", "# mine\n"),
                     self.put(self.vault / "projects/foo/CONTEXT.md", "personal context\n"),
                     self.put(self.vault / "projects/foo/decisions/ADR-001.md", "personal ADR\n"),
                     self.put(self.vault / "learning/example.md", "personal learning\n")]
        contents = {p: p.read_bytes() for p in preserved}
        self.put(self.vault / "method/README.md", "old snapshot\n")
        self.install()
        repo = self.repo()
        self.registry("register", "foo", repo)
        snapshots = {p: p.read_bytes() for p in self.home.rglob("*") if p.is_file() and ".git" not in p.parts}
        self.install(extra=["--force"])
        self.assertEqual(snapshots, {p: p.read_bytes() for p in self.home.rglob("*") if p.is_file() and ".git" not in p.parts})
        self.assertEqual(contents, {p: p.read_bytes() for p in contents})
        self.assertEqual(self.registry("resolve", repo).strip(), "foo")
        self.assertTrue(any(p.read_text() == "old snapshot\n" for p in (self.vault / ".second-brain/backups").rglob("README.md")))
        for provider, name in (("claude", "CLAUDE.md"), ("codex", "AGENTS.md")):
            text = (self.home / f".{provider}/{name}").read_text()
            self.assertTrue(text.startswith("My personal instructions.\n"))
            self.assertEqual(text.count("<!-- BEGIN SECOND BRAIN METHOD -->"), 1)
        settings = json.loads((self.home / ".claude/settings.json").read_text())
        self.assertEqual(settings["model"], "personal-choice")
        self.assertIn("Read(private/**)", settings["permissions"]["deny"])
        handlers = [h for g in settings["hooks"]["Stop"] for h in g["hooks"]]
        self.assertEqual(len(handlers), 2)
        self.assertEqual(handlers[0]["command"], "echo my-check-close")
        hooks = json.loads((self.home / ".codex/hooks.json").read_text())
        self.assertEqual(hooks["description"], "Personal hooks")
        self.assertEqual(len(hooks["hooks"]["Stop"]), 2)
        self.assertIn("SessionEnd", hooks["hooks"])

    def test_custom_roots_and_shell_quoting(self):
        self.vault = self.home / "brain '\"\\$literal & space"
        self.env.update(CODEX_HOME=str(self.home / "codex custom"), CLAUDE_HOME=str(self.home / "claude custom"),
                        CODEX_SKILLS_HOME=str(self.home / "skills custom"))
        self.install()
        for p in self.home.rglob("*"):
            if p.is_file() and ".git" not in p.parts and p.suffix in (".md", ".sh", ".json", ".toml"):
                self.assertNotIn("~/second-brain", p.read_text(), str(p))
                self.assertNotRegex(p.read_text(), r"@@[A-Z_]+@@", str(p))
        config = json.loads((Path(self.env["CODEX_HOME"]) / "hooks.json").read_text())
        try:
            import tomllib
        except ImportError:
            tomllib = None
        if tomllib:
            for agent in (Path(self.env["CODEX_HOME"]) / "agents").glob("*.toml"):
                self.assertIn(str(self.vault), tomllib.loads(agent.read_text())["developer_instructions"])
        cmd = config["hooks"]["Stop"][0]["hooks"][0]["command"]
        self.assertEqual(self.run_cmd(["bash", "-c", cmd], data=json.dumps({"cwd": str(self.repo())})), "")

    def test_corrupt_inputs_fail_before_mutation(self):
        cases = [(".codex/AGENTS.md", "before\n<!-- BEGIN SECOND BRAIN METHOD -->\n"),
                 (".codex/hooks.json", "{bad"),
                 (".claude/settings.json", '{"hooks":{"Stop":{}}}'),
                 (".codex/AGENTS.md", "<!-- END SECOND BRAIN METHOD --><!-- BEGIN SECOND BRAIN METHOD -->")]
        for relative, text in cases:
            path = self.put(self.home / relative, text)
            before = {p: p.read_bytes() for p in self.home.rglob("*") if p.is_file()}
            self.install(code=1)
            self.assertEqual(before, {p: p.read_bytes() for p in self.home.rglob("*") if p.is_file()})
            path.unlink()
        path = self.put(self.vault / "00-index/projects.json", "not JSON")
        self.install(code=1)
        self.assertEqual(path.read_text(), "not JSON")
        self.assertFalse((self.vault / "method").exists())

    def test_managed_symlink_refused(self):
        target = self.put(self.home / "personal", "keep me")
        (self.home / ".codex").mkdir()
        (self.home / ".codex/AGENTS.md").symlink_to(target)
        self.install("codex", code=1)
        self.assertEqual(target.read_text(), "keep me")
        self.assertFalse((self.vault / "method").exists())

    def test_registry_alias_worktree_conflicts_and_invalid_json(self):
        self.install()
        self.registry("init")
        repo = self.repo()
        self.registry("resolve", repo, code=1)
        self.registry("register", "example", repo)
        before = (self.vault / "00-index/projects.json").read_bytes()
        self.registry("register", "example", repo)
        self.assertEqual(before, (self.vault / "00-index/projects.json").read_bytes())
        subdir = repo / "sub"; subdir.mkdir()
        alias = self.home / "alias"; alias.symlink_to(repo, target_is_directory=True)
        self.assertEqual(self.registry("resolve", subdir).strip(), "example")
        self.assertEqual(self.registry("resolve", alias).strip(), "example")
        self.run_cmd(["git", "-C", repo, "commit", "--allow-empty", "-qm", "fixture"])
        worktree = self.home / "worktree"
        self.run_cmd(["git", "-C", repo, "worktree", "add", "-q", "-b", "fixture-worktree", worktree])
        self.registry("add-root", "example", worktree)
        self.assertEqual(self.registry("resolve", worktree).strip(), "example")
        self.registry("register", "different", repo, code=2)
        self.registry("register", "../escape", self.repo("other"), code=2)
        self.registry("add-root", "unknown", repo, code=2)
        projects = json.loads(self.registry("list"))["projects"]
        self.assertEqual(len(projects), 1)
        self.assertEqual(len(projects[0]["repo_roots"]), 2)
        path = self.put(self.vault / "00-index/projects.json", "broken")
        self.registry("init", code=2)
        self.assertEqual(path.read_text(), "broken")

    def test_registry_concurrent_registration(self):
        self.install()
        repos = [self.repo(f"repo-{i}") for i in range(6)]
        with ThreadPoolExecutor(max_workers=6) as pool:
            list(pool.map(lambda pair: self.registry("register", f"project-{pair[0]}", pair[1]), enumerate(repos)))
        self.assertEqual(len(json.loads(self.registry("list"))["projects"]), 6)

    def test_hooks_and_bidirectional_switch(self):
        self.install()
        repo = self.repo()
        for provider in ("claude", "codex"):
            self.assertEqual(self.hook(provider, "stop", repo), {})
        context = self.project(repo)
        for provider in ("claude", "codex"):
            self.hook(provider, "start", repo)
            self.assertEqual(self.hook(provider, "stop", repo), {})
        self.put(repo / "code.txt", "first change")
        for provider in ("claude", "codex"):
            self.assertEqual(self.hook(provider, "stop", repo)["decision"], "block")
            payload = json.dumps(dict(cwd=str(repo), session_id="s1", stop_hook_active=True))
            self.assertEqual(self.run_cmd(["bash", self.home / f".{provider}/hooks/second-brain-check-close.sh", "stop"], data=payload), "")
        self.assertFalse(self.hook("codex", "precompact", repo)["continue"])
        self.assertIn("systemMessage", self.hook("claude", "precompact", repo))
        # Claude close -> Codex start over the same persistent state.
        context.write_text("Claude saved first change\n")
        self.core("persist", repo, legacy=True)
        self.assertEqual(self.hook("codex", "stop", repo), {})
        self.hook("codex", "start", repo, session="codex-next")
        self.assertEqual(self.registry("resolve", repo).strip(), "example")
        self.assertEqual(context.read_text(), "Claude saved first change\n")
        self.put(repo / "code.txt", "second change")
        self.assertFalse(self.hook("codex", "precompact", repo, session="codex-next")["continue"])
        # Codex close -> Claude start.
        context.write_text("Codex saved second change\n")
        self.core("persist", repo)
        self.hook("claude", "start", repo, session="claude-next")
        self.assertEqual(self.hook("claude", "stop", repo), {})
        self.assertEqual(context.read_text(), "Codex saved second change\n")
        self.assertFalse((repo / "AGENTS.override.md").exists())
        self.assertFalse((repo / ".codex").exists())

    def test_planning_dirty_receipt_and_post_close_edits(self):
        self.install()
        repo = self.repo(); context = self.project(repo)
        self.hook("codex", "start", repo)
        self.core("persist", repo, code=2)
        self.core("mark-dirty", repo)
        self.core("persist", repo, code=2)
        self.assertEqual(self.hook("codex", "stop", repo)["decision"], "block")
        context.write_text("A durable plan decision\n")
        self.core("persist", repo)
        self.assertEqual(self.hook("codex", "stop", repo), {})
        self.core("mark-dirty", repo)
        self.assertEqual(self.hook("codex", "stop", repo)["decision"], "block")
        context.write_text("Next decision\n")
        self.core("persist", repo)
        self.put(repo / "new.txt", "new work")
        self.assertEqual(self.hook("codex", "stop", repo)["decision"], "block")
        # Repeated start / resume must not erase the dirty baseline.
        self.hook("codex", "start", repo)
        self.assertEqual(self.hook("codex", "stop", repo)["decision"], "block")

    def test_committed_work_and_initial_dirty_read_only(self):
        self.install()
        repo = self.repo(); self.project(repo)
        self.put(repo / "existing", "pre-existing dirty work")
        self.hook("codex", "start", repo)
        self.assertEqual(self.hook("codex", "stop", repo), {})
        self.run_cmd(["git", "-C", repo, "add", "existing"])
        self.run_cmd(["git", "-C", repo, "commit", "-qm", "fixture"])
        self.assertEqual(self.hook("codex", "stop", repo)["decision"], "block")

    def test_legacy_anchor_with_spaces_and_subdirectory(self):
        self.install()
        repo = self.repo()
        context = self.put(self.vault / "projects/legacy/CONTEXT.md", "Old legacy state\n")
        self.put(repo / "CLAUDE.local.md", f"Live state: `{context}`\n")
        subdir = repo / "sub"; subdir.mkdir()
        self.hook("claude", "start", subdir)
        self.put(repo / "work.txt", "work")
        self.assertEqual(self.hook("claude", "stop", subdir)["decision"], "block")
        context.write_text("Saved legacy state\n")
        self.core("persist", repo, legacy=True)
        self.assertEqual(self.hook("claude", "stop", subdir), {})
        self.assertEqual(self.hook("codex", "stop", subdir), {})
        self.assertEqual(json.loads(self.registry("list"))["projects"], [])

    def test_bad_registry_blocks_without_overwriting(self):
        self.install()
        repo = self.repo(); self.project(repo)
        path = self.put(self.vault / "00-index/projects.json", "broken")
        self.assertEqual(self.hook("codex", "stop", repo)["decision"], "block")
        self.assertFalse(self.hook("codex", "precompact", repo)["continue"])
        self.assertEqual(path.read_text(), "broken")

    def test_rules_static_and_native(self):
        rules = ROOT / "engine/codex/rules/second-brain.rules"
        tree = ast.parse(rules.read_text())
        entries = []
        for statement in tree.body:
            self.assertIsInstance(statement, ast.Expr)
            call = statement.value
            self.assertIsInstance(call, ast.Call)
            self.assertEqual(call.func.id, "prefix_rule")
            entry = {kw.arg: ast.literal_eval(kw.value) for kw in call.keywords}
            self.assertIn(entry["decision"], ("allow", "prompt", "forbidden"))
            self.assertTrue(entry["pattern"])
            entries.append(entry)
        self.assertTrue(any(e["decision"] == "prompt" for e in entries))
        if shutil.which("codex"):
            for cmd, expected in [(["git", "status"], "allow"), (["git", "push"], "prompt"),
                                  (["git", "commit", "-m", "test"], "prompt"), (["gh", "pr", "create"], "prompt"),
                                  (["rm", "-rf", "/"], "forbidden")]:
                output = self.run_cmd(["codex", "execpolicy", "check", "--rules", rules, "--", *cmd])
                self.assertEqual(json.loads(output)["decision"], expected)
        else:
            print("Codex CLI unavailable: native rules check skipped; static rules PASS")

    def test_documentation_and_adapter_contracts(self):
        for p in (ROOT / "engine").rglob("*.md"):
            text = p.read_text()
            self.assertNotRegex(text, r"method-version: (?!4\.0)\d")
            self.assertNotIn("~/.codex/skills", text)
        for skill in (ROOT / "engine/codex/skills").glob("sb-*/SKILL.md"):
            text = skill.read_text()
            self.assertTrue(text.startswith("---\nname: "))
            for name in re.findall(r"/method/([A-Z-]+\.template\.md)", text):
                self.assertTrue((ROOT / "engine/method" / name).is_file(), name)
        for p in (ROOT / "engine").rglob("*.json"):
            self.assertIsInstance(json.loads(p.read_text()), dict)
        try:
            import tomllib
        except ImportError:
            tomllib = None
        for p in (ROOT / "engine/codex/agents").glob("*.toml"):
            text = p.read_text()
            self.assertNotRegex(text, r"^model\s*=", re.M)
            if tomllib:
                data = tomllib.loads(text)
                self.assertEqual(data["name"], "second-brain-" + p.stem)
                self.assertTrue(data["developer_instructions"])
