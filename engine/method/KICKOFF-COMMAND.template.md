<!-- method-version: 4.0 -->

# Kickoff — shared workflow

Read PROJECT-BRIEF.template.md. Brief source: supplied file, then pasted text;
otherwise fill it with the human one section at a time. Unknowns remain TO DECIDE.

1. Resolve/register the repo via the new-project workflow. Preserve existing state.
2. Save the brief at `projects/<slug>/brief.md` with leading frontmatter (type:
   brief, project, date, status: current). Preserve its vision; amendments are dated.
3. Derive hub purpose from Vision and fixed stack choices; CONTEXT task summary
   from MVP scope/out-of-scope, open questions from risks, next action from the
   first unresolved step. Do not overwrite existing progress when rerun.
4. Record only already fixed durable decisions with the rationale actually given.
   TO DECIDE items remain questions; ask before resolving architectural choices.
5. Propose verifiable MVP phases tied to success criteria; first phase ends in
   something runnable. Use native plan mode when available. On approval save
   `plans/YYYY-MM-DD-mvp.md`; reference it from CONTEXT without duplicating steps.
6. Report brief path, notes created/preserved, plan approval status and next action.
   Run close to persist before stopping; do not claim an unapproved plan is approved.

Before planning work mark the project dirty with the shared checker, even if no
source file changes. Git init and other mutations need scoped authorization.
