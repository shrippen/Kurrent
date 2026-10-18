- When writing something intended for human consumption, (comment, commit message, reply to prompt) use as few words as possible. Pick every word meticulously to reduce the volume to a strict minimum. Be down to the point. Less is more.

- Avoid superlatives and praise. Stop telling me I am absolutely right. Give me the cold hard truth.

- Avoid magic numbers and strings by extracting recurring or meaningful values into descriptive constants (const) or enums. Keep self-explanatory, one-off values inline to avoid clutter. If a value comes from a spec (e.g. HTTP 200 OK), use a constant regardless.

- Reduce code indentation. Avoid Arrow Anti-Pattern. Leverage early return and continue.

- Keep function names short. Less than 30 characters.

- Use enums instead of booleans for function parameters.

- Let the reader of the code breathe. Add empty lines between logical blocks of code.

- Add a small, to the point, comment to explain *what* the block does and *why*. Use examples when possible. Propose ASCII drawings to explain complete systems.

- Treat member visibility changes as a breaking design shift. Keep all fields and functions private unless external access is strictly required by the design. Prompt the user for explicit approval before changing any access modifier from private to internal or public.

- Program to levels of abstraction. Lower-level mechanics (e.g., raw hardware I/O, sector parsing, direct socket streams) must be encapsulated in a dedicated driver/abstraction layer. Expose clean, high-level APIs to the rest of the application so calling code works with domain concepts, not raw implementation details.

- Don't touch blocks of code unrelated to the feature you implement. e.g. Don't add comments to a block of code if you did not create it or modify it. As much as possible try to minimize the number of changed lines when implementing a feature.

- Strictly adhere to the layered boundary hierarchy: each layer may only communicate with its immediate neighbor directly below it. Never "punch holes" through layers (e.g., controllers or UI components must never directly call database queries, raw hardware drivers, or low-level network clients; always route through the intermediate service/abstraction layer).

- Always use {}, even on a one-line "if" statement.

When you write a commit message, follow these 7 rules:
Rule 1: Separate the subject line from the body with a single blank line.
Rule 2: Limit the subject line to 50 characters (72 is the absolute hard limit).
Rule 3: Capitalize the first letter of the subject line.
Rule 4: Do not end the subject line with a period.
Rule 5: Use the imperative mood in the subject line (e.g., "Fix bug," "Add feature," 
        not "Fixed" or "Adds"). Test formula: It must complete the sentence: "If applied,
        this commit will [your subject line here]".
Rule 6: Wrap the body text manually at 72 characters to prevent Git formatting issues.
Rule 7: Use the body to explain what and why vs. how. Assume the code explains the how;
        the message must explain the context and reasoning. 

- If the prompt indicates that a bug is being fixed, don't write the fix right away. First write the test. Observe it failing. Then write the fix. And observe the test passing.

- After every code change, run `bash install.sh` (full build, unit tests, plasmoidviewer smoke tests, install, plasmashell restart). Do not proceed until all tests pass. The script takes ~2 minutes end-to-end; set command timeout accordingly.

- UI changes: check them visually with `tests/screenshot.sh [OUT_DIR]` (offscreen PNGs of every style × view × width, plus the editor; `KURRENT_SCREENSHOT_PLAN` narrows it). Never screenshot the desktop.

- Never push automatically. Always ask for permission before pushing to remote.

- Changelogs and GitHub release notes are always written in English, regardless of the conversation language.

## GUI rule

- Every GUI of this project is generated from Kante, not inspired by it: landing pages,
  web apps, Qt Quick / Kirigami apps, Plasma widgets, dialogs, e-mail and print layouts.
  Source: https://github.com/shrippen/Kante (checkout `../Kante`).
  Web: link `https://shrippen.github.io/v1/shrippen.css` and `shrippen.js`, or vendor them
  unchanged. Apps: copy `qml/Kante` (and `KantePlasma` for Plasma widgets) unchanged.
- Use Kante's tokens, roles, components, classes, QML components and motion as they are.
  No own colours, fonts, sizes, radii, cuts, shadows, animation timings, no own copy or
  variant of a component that Kante has. Raw values (`#hex`, `px` for controls) are a bug;
  use roles (`--primary`, `--focus`, `--warn`, `KanteStyle.*`).
- A missing element is added to Kante first (CSS or QML, docs, catalogue), then used here.
  Never solve it locally in this project and never wait with a "temporary" copy.
- Exception: Kimai plugins take their GUI from Knust (`kimai/knust/` in shrippen/Kante), the
  Kante spinoff that adapts Kante to Kimai's look. The same rule applies to Knust: use it
  as it is, and add missing elements to Knust.
- A project without a GUI (library, CLI, scripts) has nothing to do here.
- Rule text: https://github.com/shrippen/Kante/blob/main/AGENT-RULE.md

## Repository rule

- This repository lives on Gitea (`git.arianw.de`). GitHub is only a push mirror of it.
- CI runs on the GitHub mirror (`.github/workflows/tests.yml`, since 16.10.2026) and reports back to Gitea as the commit status `github / test`.
- Changes arrive as pull requests: work on a branch, open a PR, merge it on Gitea (the mirror follows).
- Never merge a PR, push to `main` (or any default branch), push tags or publish releases on GitHub. A merge there is overwritten by the next Gitea push.
- Never force-push a branch that someone else's PR depends on.
- Claude review (all shrippen repositories, owner 18.10.2026): every PR is reviewed by a new Claude agent before it is merged. The owner does not read code, so this is the second reader.
  - The session that wrote the PR starts a new agent (Agent tool, no shared context) and gives it only the PR's title and body, the diff against its base (`git diff <base>...HEAD`), the repository and `REVIEW.md`. It does not tell it what it thinks of its own change.
  - The agent checks every finding it would post against the code (file, line, the input that goes wrong) and drops what it cannot show. It reports as `REVIEW.md` says: count first, labels **Wichtig**, **Kleinigkeit**, **Bestand**.
  - The session posts the report unchanged as a PR comment on Gitea. Above it goes the heading `## Claude-Review (neuer Agent) zu <commit>`, below it the footer `---` and `_Generated by [Claude Code](https://claude.ai/code)_`.
  - Each **Wichtig** is fixed, or answered in the PR with a reason. An answer counts only when the next review agent accepts it; if it does not, the owner decides in words.
  - After a fix or an answer, a new agent gets the PR's title and body, the open **Wichtig** of the last round with the answers, and only the new commits (`git diff <last reviewed commit>..HEAD`; without new commits, the code at HEAD). After a rebase, a merge of the base or a change of the PR's base branch a new round is due, also without a new commit, and the agent gets the whole diff again, against the new base. Every round counts, also one with answers only: after three rounds that still leave a **Wichtig** open, stop and rethink the approach with the owner.
  - Merge only when the last review covers the PR's latest commit against its current base branch (the branch by name; the base moving on alone needs no new round) and has no open **Wichtig**, and CI is green on the PR's latest commit: every CI check that runs on each push (such as `github / test` from the GitHub mirror) shows success there. No status there yet means wait, not merge; if it never comes, check the mirror or ask the owner. PR-Agent's status does not count here. Where CI runs only for some paths, the repository rule says which commits need it. Without CI, the local checks of the merging rule count.
  - Before the merge, the owner confirms in words, not by reading code, a PR that changes CI or release workflows (`.gitea/`, `.github/`, `packaging/`), this review rule (`agent.md`, `REVIEW.md`), secrets or what is published (a release, a tag, a new public page, site or package; rebuilding what is already published does not count).
  - `REVIEW.md` in the repository root says what failure looks like here, what to check in particular, what to skip and how to report. A repository without one gets it in its next PR.
- PR-Agent (`.gitea/workflows/pr-agent.yml`, where set up) runs only when the owner comments `/review` on a PR (owner, 18.10.2026). Sessions do not post `/review`. Without one no merge waits for PR-Agent; after the owner's `/review` the merge waits for that run (a run that fails holds nothing, say so in the PR). Fix or answer its findings in the PR before the merge; an answer counts only when the next review agent accepts it, as for the Claude review's findings.
