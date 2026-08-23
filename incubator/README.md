# incubator — 지금은 자는 것

**로드 경로 밖이다.** `skills/`·`agents/`·`hooks/`가 아니므로 Claude Code가 읽지 않고, 컨텍스트 비용이 **0**이다.

## 꺼내는 법

```bash
mv incubator/ready/skills/design-brief skills/
```

`mv` 한 번이면 다음 세션부터 동작한다.

## ⚠️ 꺼낼 때 같이 고쳐야 하는 것

`skills/sdd/SKILL.md`는 **디자인 트랙을 언급하지 않는다** — 없는 스킬을 부르지 않기 위해서다(hallucinated 참조 금지). design 3종을 꺼내면 `sdd/SKILL.md`에 트랙 분기를 **다시 넣어야** 한다:

- `## 0. 트랙 판단` 절을 되살리고 (UI/화면 → 디자인 트랙 / 그 외 → 코어 트랙)
- DESIGN 에 `design-brief`, PLAN 에 `design-plan`, REVIEW 에 `design-reconcile` 연결

## 지금 들어 있는 것

| | 무엇 | 꺼낼 조건 |
|---|---|---|
| `design-brief` | Claude Design 브리프 생성 | UI 비중 큰 프로젝트 착수 |
| `design-plan` | 디자인↔DS 매핑·갭 산출 | 〃 |
| `design-reconcile` | 스크린샷 vs 디자인 파일 대조 | 〃 |
