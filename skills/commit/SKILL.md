---
name: commit
description: git 변경 내용을 기반으로 커밋 단위로 논리적으로 분리하고, 각 커밋에 대해 한국어 커밋 메시지를 생성해줘. Reflect 완료 후 모델이 직접 호출 가능(워크플로우 자동 전환과 정합).
disable-model-invocation: false
---

## 사전 준비

`.claude/harness.json`의 `verify`를 순서대로 실행한다(`harness-run` §4 코드 커밋과 같은 근거 — CLAUDE.md에 적힌 시퀀스는 그 사본이다). 각 단계에서 바뀐 파일도 관련 커밋에 포함한다.

## git 맥락 수집

- `git diff`
- `git diff --name-only`
- `git log --oneline -5`

## 커밋 분리 원칙

- 기능 단위 또는 변경 목적 기준으로 분리
- 서로 관련 없는 변경은 반드시 분리

## 커밋 메시지 형식

`<type>: 한 줄 요약` (한국어). `.claude/harness.json`의 `git.commitScope`가 `true`일 때만 `<type>(<scope>):`를 쓴다 — 아니면 영역/패키지는 본문에 서술.

## 출력 형식

```
## 커밋 1
**포함 파일/범위:** …
**메시지:**
feat: 한 줄 요약

(선택) 본문: 영역·의도·주의사항

## 커밋 2
…
```

## 실행

1. 위 형식으로 **커밋 계획을 먼저 출력**한다(파일 범위·메시지).
2. **사용자 승인 뒤 실행**한다 — 단, `sdd` REFLECT에서 불렸고 REVIEW 최종 판정(체크포인트 ④)을 이미 통과했으면 그 승인이 커밋 승인을 겸하므로 다시 묻지 않고 실행한다.
3. 실행 뒤 `git log --oneline -n <개수>`로 만들어진 커밋을 보여준다. `--no-verify`·`--amend`(사용자 요청 없이)·force 류는 쓰지 않는다.

`harness.json.release.tool`이 `changesets`이고 사용자 영향 변경인데 `.changeset/*.md`가 없으면, 커밋 계획 끝에 "먼저 `/changeset`실행 필요 (예상 bump: {patch|minor|major})" 한 줄을 덧붙인다. 대상 패키지 판정 근거는`changeset` 스킬을 따른다.
