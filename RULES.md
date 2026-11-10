# Rules for all shrippen repositories

Synced from the rules repository (`shrippen/regeln`, `rules/`) with `tools/sync-rules.sh`.
Do not edit this copy; change the source and sync. What is particular to this repository
is in `agent.md`.

## Writing and code

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

## Commit messages

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

## Bug fixes

- If the prompt indicates that a bug is being fixed, don't write the fix right away. First write the test. Observe it failing. Then write the fix. And observe the test passing.
  - This holds for every bug, however it was found (a user report, a review, your own run),
    and for performance problems and crashes too: stutter, late frames, a hang, a panic, a
    leak. The test stays in the suite; a one-off script run is not a test.
  - Name the failure in the commit or PR: the test and what it printed before the fix.

## Repository

- This repository lives on Gitea (`git.arianw.de`). Where a GitHub repository exists, it is only a push mirror of it.
- Changes arrive as pull requests: work on a branch, open a PR, merge it on Gitea (the mirror follows).
- Never merge a PR, push to `main` (or any default branch), push tags or publish releases on GitHub. A merge there is overwritten by the next Gitea push.
- Never force-push a branch that someone else's PR depends on.
- Every PR is reviewed before it is merged (all shrippen repositories, owner 18.10. and 22.10.2026). The owner does not read code, so the review is the second reader. Findings are labelled **Wichtig**, **Kleinigkeit** or **Bestand**; each **Wichtig** is fixed, or answered in the PR with a reason. Merge only when the last round covers the PR's latest commit, leaves no **Wichtig** open and CI is green.
- `REVIEW.md` in the repository root says what failure looks like here, what to check in particular, what to skip and how to report. A repository without one gets it in its next PR.
- Before the merge, the owner confirms in words, not by reading code, a PR that changes CI or release workflows (`.gitea/`, `.github/`), the rules (`agent.md`, `RULES.md`, `REVIEW.md`), secrets or what is published (a release, a tag, a new public page, site or package; rebuilding what is already published does not count), and whatever `agent.md` names in addition.
- `agent.md` holds what is particular to this repository: its CI check, what the merge waits for, further paths the owner confirms, project knowledge. The procedure of a review (rounds, who reviews, how to post) is the skill `pr-review` in the rules repository (`shrippen/regeln`).

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
- Exception: Kimai plugins take their GUI from Knust (`kimai/knust/` in Kante) and
  the kit (`kimai/kit/`), the Kante spinoff that adapts Kante to Kimai's look. The same rule applies to Knust: use it
  as it is, and add missing elements to Knust.
- Exception: Kintsugi (`shrippen/kintsugi`) uses Kante Gold (`<html data-kante="gold">`),
  the noble variant defined in Kante itself. The same rule applies: use it as it is, and
  add a missing element or Gold detail to Kante (its Gold block) first. No other project
  uses Kante Gold without a decision recorded here.
- A project without a GUI (library, CLI, scripts) has nothing to do here.
- Rule text: https://github.com/shrippen/Kante/blob/main/AGENT-RULE.md
