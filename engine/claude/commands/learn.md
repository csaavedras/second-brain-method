---
description: Capture a learning in the brain (vault's learning/)
argument-hint: [topic or description of what was learned]
---

Capture the learning in the vault (`~/second-brain`):
$ARGUMENTS

If there are no arguments, extract from the current conversation what was
learned that has value beyond today.

**Special mode — `/learn review <MR comment>`**: the argument is a review
comment a real MR received. Don't file it under `learning/`; instead:
distill it into ONE checkable rule (what to check in a diff, in one line —
not the anecdote), and append it to the current project's
`~/second-brain/projects/<project>/review-checklist.md` (create it from the
method's REVIEW-CHECKLIST.template.md if absent), with the origin comment
and date. Deduplicate: if an existing rule already covers it, sharpen that
rule instead of adding a twin. This file is the ONE exception to the
"don't touch projects/" rule below — it feeds `/gate`. Report the rule
added/updated and stop (skip the steps below).

1. **Classify** per the method's BRAIN.md (`~/second-brain/method`):
   - `concept` — durable idea → `learning/<topic>/<slug>.md`
   - `resource` — course/book/article → `learning/<topic>/<slug>.md` with
     `status: in-progress | done | dropped`
   - `til` — a single fact of the day → `learning/til/<YYYY-MM-DD>-<slug>.md`
2. **Check for duplicates**: grep for the topic in `learning/` and
   `00-index/`. If a note for the concept already exists, update it — don't
   create a second one.
3. **Write the atomic note** (one idea per note) with the frontmatter and
   format from BRAIN.md. The explanation goes in your own words, not copied
   from the source.
4. **Link**: to the topic's MOC in `00-index/` if it exists, and to related
   concepts, patterns or decisions. **MOC rule**: if the topic gathers 3+
   notes and has no MOC, create `00-index/<topic>.md` (type: moc) and link
   the existing notes from there (+ a line in `00-index/home.md`).
5. **Report**: path of the note created/updated, links added, and whether you
   created a MOC.

Don't touch `projects/` or any CONTEXT.md: this is knowledge capture, not
project state. (Sole exception: `review-checklist.md` in the `review` mode
above.)
