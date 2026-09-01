# incubator — 지금은 자는 것

**로드 경로 밖이다.** `skills/`·`agents/`·`hooks/`가 아니므로 Claude Code가 읽지 않고, 컨텍스트 비용이 **0**이다.

## 꺼내는 법

```bash
mv incubator/ready/skills/<이름> skills/
```

`mv` 한 번이면 다음 세션부터 동작한다. 꺼낼 때 **그 스킬을 부르는 쪽(주로 `skills/sdd/SKILL.md`)에
호출 지점을 같이 넣어야 한다** — 없는 스킬을 부르지 않기 위해 참조를 미리 심어두지 않기 때문이다.

## 지금 들어 있는 것

없다.

## 나간 것

| 언제 | 무엇 | 어디로 |
|---|---|---|
| 2026-09-01 | `design-brief` · `design-plan` · `design-reconcile` | `skills/`. `sdd/SKILL.md`에 `## 0. 트랙 판단` 절과 DESIGN·PLAN·REVIEW 3개 호출 지점을 복원했다. 산출물 종착지는 `.claude/design/` |
