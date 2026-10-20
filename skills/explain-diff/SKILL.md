---
name: explain-diff
description: 코드 변경(diff·브랜치·PR) 하나를 배경 → 핵심 직관(예시 데이터·그림) → 코드 순회 → 레벨별 블록으로 풀어 한 장짜리 HTML(기본) 또는 노션 페이지로 만든다. "이 변경 풀어서 설명해줘"·"이해한 뒤 공유하게 정리해줘"·"노션으로 정리해줘"일 때, 또는 pr-write 이해 게이트 미달 뒤 쓴다.
---

# Explain Diff

Please make me a rich, interactive explanation of the specified code change.

**Output target**: one self-contained HTML file by default. If the user says Notion (노션) or asks for a page to share with the team, make a Notion page instead. The content below is the same for both; only the Format section differs.

It should have these sections:

- Background: Explain the existing system relevant to this change. (You should broadly explore surrounding code for this.) We don't know how much the reader already knows, so include a deep background for beginners (note that it can be skipped if the reader is already familiar), and then a more narrow background directly relevant to the change.
- Intuition: Explain the core intuition for the code change. The focus here is to explain the essence, not the full details. Use concrete examples with toy data. Use figures and diagrams liberally.
- Code: Do a high-level walkthrough of the changes to the code. Group/order the changes in an understandable way.
- Quiz (level blocks): read `~/.claude/learning-level.json` and follow `${CLAUDE_PLUGIN_ROOT}/docs/learning-level.md` — one block per area the diff touches (FE · BE · infra by file path) plus one domain block, each at that area's level. Missing file or value = beginner. beginner blocks are 2~3 technology cards (each: keyword in words a 12-year-old gets → where this technology is normally used → why this project uses it here, with file:line → what breaks without it → pitfalls → one small flow diagram) plus one fill-in-the-blank at the end whose answer is revealed right away, no scoring; a technology that already has a `종류: 기술` card in `_learn/inbox.md` gets only the "why here" and "pitfalls" lines; intermediate is multiple-choice on the big picture of the technologies used (2) plus how this project applies them (1), 3+2 if only one area; advanced is 1~2 free-text "why this way?" prompts with a reveal of the key reason. Questions are medium difficulty: you need the substance of the change to answer, but no gotchas. Every answer shows why it is correct or incorrect.

Writing: the clarity and flow of Martin Kleppmann, classic style, smooth transitions. Pick a small number of diagram families and reuse them (a very simplified UI for UI changes; a system diagram of data flow with example data). Use callouts for key concepts, definitions and important edge cases.

## Format — HTML (default)

- A single self-contained HTML file with CSS and JavaScript. One long page with section headers and a table of contents, no top-level tabs, basic responsive styling for phones.
- Quiz answers are clickable: clicking tells the reader whether they were right and shows the feedback.
- Save it outside the code repo, filename starting with today's date: `/tmp/YYYY-MM-DD-explanation-<slug>.html`.
- No ASCII diagrams. Use simple HTML for diagrams and HTML lists for lists. Code blocks use `<pre>`; a custom styled div **must** have `white-space: pre-wrap`. Before saving, scan each code block's CSS for `white-space: pre` or `pre-wrap`.

## Format — Notion

- Create a new page with the Notion MCP tools and return its URL.
- Quiz answers go in toggle blocks: each option is a toggle (`▶ Option`) whose body is `✅` or `❌` plus the explanation. Fill-in-the-blank and "why this way?" answers are in toggles too.
