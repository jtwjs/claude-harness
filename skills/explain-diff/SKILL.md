---
name: explain-diff
description: 코드 변경(diff·브랜치·PR) 하나를 배경 → 핵심 직관(예시 데이터·그림) → 코드 순회로 풀어 한 장짜리 HTML(기본) 또는 노션 페이지로 만든다. "이 변경 풀어서 설명해줘"·"이해한 뒤 공유하게 정리해줘"·"노션으로 정리해줘"일 때 쓴다.
---

# Explain Diff

Please make me a rich, interactive explanation of the specified code change.

**Output target**: one self-contained HTML file by default. If the user says Notion (노션) or asks for a page to share with the team, make a Notion page instead. The content below is the same for both; only the Format section differs.

It should have these sections:

- Background: Explain the existing system relevant to this change. (You should broadly explore surrounding code for this.) We don't know how much the reader already knows, so include a deep background for beginners (note that it can be skipped if the reader is already familiar), and then a more narrow background directly relevant to the change.
- Intuition: Explain the core intuition for the code change. The focus here is to explain the essence, not the full details. Use concrete examples with toy data. Use figures and diagrams liberally.
- Code: Do a high-level walkthrough of the changes to the code. Group/order the changes in an understandable way.

Writing: the clarity and flow of Martin Kleppmann, classic style, smooth transitions. Pick a small number of diagram families and reuse them (a very simplified UI for UI changes; a system diagram of data flow with example data). Use callouts for key concepts, definitions and important edge cases.

## Format — HTML (default)

- A single self-contained HTML file with CSS and JavaScript. One long page with section headers and a table of contents, no top-level tabs, basic responsive styling for phones.
- Save it outside the code repo, filename starting with today's date: `/tmp/YYYY-MM-DD-explanation-<slug>.html`.
- No ASCII diagrams. Use simple HTML for diagrams and HTML lists for lists. Code blocks use `<pre>`; a custom styled div **must** have `white-space: pre-wrap`. Before saving, scan each code block's CSS for `white-space: pre` or `pre-wrap`.

## Format — Notion

- Create a new page with the Notion MCP tools and return its URL.
