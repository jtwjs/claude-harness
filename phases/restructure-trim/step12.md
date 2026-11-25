# Step 12: closed-skill-callers

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016 D0 · Q1 · Q2). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `phases/restructure-trim/index.json` step 9 summary(사람만으로 닫은 스킬 11개 · 경로로 바꾼 곳)
- `skills/sdd/SKILL.md` 「단계 → 스킬 · 체크포인트」 표 위 줄(step 9가 넣은 「단계 스킬은 경로를 읽고 그대로 따른다」)
- `hooks/cadence-reminder.sh` 축 1 블록 · `hooks/test.sh` 「cadence 축 1」 검사(390~400행 근처, 고치지 않는다)
- `templates/.claude/README.md` 라우팅 표 · `templates/.claude/references/tracks.md` 87행 · `templates/.github/workflows/ci.yml` 1~3행
- `agents/code-reviewer.md` 103행 · `skills/changeset/SKILL.md` · `skills/sdd-run/SKILL.md` description

## 작업

바꾸는 파일:

- `skills/sdd/SKILL.md` · `skills/changeset/SKILL.md` · `skills/sdd-run/SKILL.md`(description 한 줄만)
- `hooks/cadence-reminder.sh`
- `templates/.claude/README.md` · `templates/.claude/references/tracks.md` · `templates/.github/workflows/ci.yml`(3행 주석만)
- `agents/code-reviewer.md`(103행만)

step 9가 단계 · 슬래시 스킬 11개를 사람만(모델 호출 닫힘)으로 바꿨다: `changeset` · `design-brief` · `design-critique` · `design-reconcile` · `sdd-plan` · `sdd-review` · `sdd-run` · `harness-doctor` · `harness-gaps` · `harness-init` · `project-new`. 모델이 그 스킬을 Skill 도구로 부르면 오류가 난다. 그 이름으로 모델에게 실행을 시키는 곳을 경로 읽기(`skills/<이름>/SKILL.md`를 읽고 따른다) 또는 「사람이 `/<이름>`으로」로 바꾼다(ADR-016 D0 「단계 스킬은 입구가 경로로 부른다」). 이름을 설명으로만 쓰는 문장(「`harness-doctor` 검사 2가 잡는다」 · 「`harness-init`이 채운다」)은 그대로 둔다.

- `hooks/cadence-reminder.sh`
  - 49 · 56행의 모델 맥락 문구(「(harness-doctor 로 점검)」 · 「harness-doctor 의 §2 · §3 두 검사만 돌려」)가 `harness-doctor` SKILL.md를 펼친 절대 경로로 읽게 한다. 경로 뿌리는 `${CLAUDE_PLUGIN_ROOT:-<이 스크립트 폴더의 상위>}`로 정한다 — 플러그인 훅 실행 때는 환경 변수가 있고, 테스트 · 직접 실행 때는 없다
  - 50행 `HINTS+=("harness-doctor — fix …")`는 사람이 보는 상태줄 권고이고 `hooks/test.sh`가 그 글자를 그대로 검사한다 → 바꾸지 않는다
  - 「오늘 이 레포 첫 세션」 글자도 `hooks/test.sh`가 검사한다 → 남긴다. `hooks/test.sh`는 고치지 않는다
- `templates/.claude/README.md` 라우팅 표(대상 레포 세션이 읽는다): `sdd-plan` 두 행 · 디자인 트랙 행 · `harness-doctor` · `harness-gaps` 행. 계획 · 디자인은 입구 `sdd`로 보내고(단계 스킬은 `sdd`가 경로로 읽는다), 점검 · 반복 계수는 「사람이 `/harness-doctor`」처럼 바꾼다. 같은 파일의 설명 문장(26 · 28 · 37행)은 그대로
- `templates/.claude/references/tracks.md` 87행 「전체 브랜치 리뷰 1회(`sdd-review`, …)」 → 트랙 세션이 Skill 도구로 부르지 않게 `sdd` REVIEW 절을 따르거나 사람이 `/sdd-review`
- `agents/code-reviewer.md` 103행 「수정 step을 만들어 `sdd-run`(…)」 → 「`sdd` REVIEW 절대로 수정 step을 만든다」처럼 입구를 가리키게
- `skills/changeset/SKILL.md` description: 「모델이 직접 호출」을 지금(사람만 · `sdd` 마무리에서 `commit`이 경로로 읽음)에 맞춘다. description 안에 `disable-model-invocation: true` 글자를 쓰지 않는다(auto 개수 AC가 파일 전체를 grep한다)
- `skills/sdd-run/SKILL.md` description 끝 「sdd-plan 스킬로 만든 계획」 → 「`sdd-plan`으로 만든 계획」 같은 설명형
- `templates/.github/workflows/ci.yml` 3행 「출처와 비었을 때 규칙은 harness-init SKILL.md §4 표」: step 6에서 그 표가 `skills/harness-init/scripts/fill_ci.py` 호출로 바뀌었다 → 지금 있는 것(그 스크립트)을 가리키게
- `skills/sdd/SKILL.md` 표 위 줄에 한 구절: 경로로 읽은 단계 스킬 본문의 플러그인 루트 변수 자리는 치환되지 않고 셸에도 그 변수가 없다 → `${CLAUDE_PLUGIN_ROOT}` 값으로 바꿔 읽고 명령에도 그 값을 넣는다
  - 이 파일은 Skill 도구로 로드될 때 `${…}` 꼴이 치환된다. 그래서 「치환 안 되는 변수」를 가리킬 땐 `${…}` 꼴로 쓰지 말고 이름(`CLAUDE_PLUGIN_ROOT`)만 적는다. 바꿔 넣을 값 쪽은 `${CLAUDE_PLUGIN_ROOT}`로 적어 치환되게 둔다
  - 근거(지휘 실측 1회): 다른 폴더 임시 레포에서 `claude -p --plugin-dir`로 「sdd 로드 → REVIEW 단계 파일 열기 → 기준 브랜치 스크립트 실행」을 시켰다. 모델은 셸 변수가 빈 것을 확인하고 스크립트를 따로 열어 본 뒤 루트를 추정해 성공했다 — 루트 추정에 도구 호출 2회가 더 들었다
- 성공 기준(러너 밖, 판정 뒤 지휘 쪽이 같은 실측을 한 번 더 돈다): 루트 추정에 더 드는 도구 호출 2회 → 0회. 이 step 안에서 `claude -p`를 돌리지 않는다
- tdd: false — 지시문 · 안내 문구 바꾸기다. 모델이 문구를 따르는지는 테스트로 판정할 대상이 아니고, 기계로 볼 것은 아래 AC grep이다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `grep -q 'skills/harness-doctor/SKILL.md' hooks/cadence-reminder.sh && ! grep -q '모델이 직접 호출' skills/changeset/SKILL.md`
- 닫힌 11개를 부르는 문장 0줄(hooks · templates · agents · 모든 description). 아래 출력이 빈 줄이어야 한다:

```bash
N='(changeset|design-brief|design-critique|design-reconcile|sdd-plan|sdd-review|sdd-run|harness-doctor|harness-gaps|harness-init|project-new)'
CALL="${N}\`? ?(스킬로|스킬을 (호출|부르|불러)|로 점검|을 이어서 돈|Skill 도구)|${N} 의 §[0-9]|^\| [^|]+ \| \`${N}\`|트랙: \`${N}\`|\(\`${N}\`, 필요하면|만들어 \`${N}\`"
{ git grep -nE "$CALL" -- hooks templates agents ':!hooks/tests' ':!hooks/test.sh'
  grep -nE '^description:' skills/*/SKILL.md agents/*.md | grep -E "$CALL"
  grep -nE '^description:.*모델이 직접 호출' skills/{changeset,design-brief,design-critique,design-reconcile,sdd-plan,sdd-review,sdd-run,harness-doctor,harness-gaps,harness-init,project-new}/SKILL.md; }
```

  (이 step 시작 시점에 이 명령은 11줄을 낸다: code-reviewer:103 · cadence-reminder:49 · :56 · README 9 · 10 · 11 · 15 · 16 · tracks:87 · sdd-run description · changeset description)
- `for f in skills/*/SKILL.md; do n=$(basename $(dirname $f)); grep -q 'disable-model-invocation: true' $f && echo human:$n || echo auto:$n; done | grep -c '^auto:'`이 8(step 9 유지)

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-trim/index.json`의 step 12에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
