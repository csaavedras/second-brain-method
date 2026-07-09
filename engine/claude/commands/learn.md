---
description: Capture a learning in the brain (vault's learning/)
argument-hint: [topic or description of what was learned]
---

Capture the learning in the vault (`~/second-brain`):
$ARGUMENTS

If there are no arguments, extract from the current conversation what was
learned that has value beyond today.

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
project state.
