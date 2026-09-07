---
description: Register a repository in the shared Second Brain vault.
argument-hint: [project-name]
---
<!-- method-version: 4.0 -->

Vault: `@@VAULT@@`.
Read and execute `@@VAULT@@/method/NEW-PROJECT-COMMAND.template.md`.
This is the shared workflow contract; load other method guides only as it directs.

Use registry lookup first, then an unambiguous legacy `CLAUDE.local.md` anchor.

For Claude compatibility, keep existing CLAUDE.local.md and
.claude/settings.local.json. On a new Claude registration, create these personal
files only after `git check-ignore -q CLAUDE.local.md` succeeds. Use the legacy
anchor template, with the registry's context path and the hub's convention index.
Merge local permissions, never replace them: allow only verified safe build/test/
lint commands and vault reads; ask for Git mutations/rm/mv; deny secret-file reads
(.env*, *.pem, *.key, secrets/, credentials/, .aws/, .ssh/). Preserve all existing
allow/ask/deny entries. Do not modify team files or global Git configuration.
If the anchor isn't ignored, report the needed personal exclusion before creating it.

Use `--legacy` with the shared close checker for anchor-only projects.

User arguments: $ARGUMENTS
