# \_brain — Second Brain (LLM Wiki + Obsidian)

> 이 프로젝트의 **지식 레이어**이자 이 폴더의 **운영 규칙·스키마 정본**. **repo에 커밋**(코드와 함께 버전관리·PR)되며 동시에 **Obsidian vault로 연다**(Obsidian "Open folder as vault" → 이 `_brain/` 폴더 지정). 같은 markdown을 git·Obsidian이 함께 본다.
>
> 📌 **의도된 하위 `CLAUDE.md`.** 하네스는 하위 CLAUDE.md 대신 `.claude/rules/` + `paths:`를 쓰지만, `_brain/`은 **코드가 import하지 않는 폴더**라 이 폴더를 만질 때만 로드된다 — 무관한 세션에는 비용 0이다(`harness-init` §5의 예외 조건).

## 3레이어

```
_brain/
├── raw/            # append-only 원본 투입구 (사람은 여기 던지기만)
│   └── _processed/ # 처리 완료된 raw
├── wiki/           # agent(brain-intake)가 생성·관리
│   ├── overview.md # 전 소스 종합 synthesis (프로젝트가 뭘 아는가)
│   ├── index.md    # 전체 노드 카탈로그 (링크+한줄+카테고리)
│   └── log.md      # 변경 이력 (append-only, operation 파싱 가능)
└── CLAUDE.md       # 이 파일 = 운영규칙 + schema
```

- **raw/**: 회의록·ADR·PR 설명·결정 기록·**Slack 스레드·Notion·VoC·사용자 요청**을 raw markdown으로 던진다(사람은 던지기만). 처리분은 `raw/_processed/`로 이동.
- **wiki/**: `brain-intake` 스킬이 raw를 분류·인덱싱·링크·정리. 노드는 `[[wikilink]]`로 연결.

## 카테고리 — 다섯 개

`decisions` · `domain`(비즈니스 흐름) · `infra` · `conventions` · `glossary`(도메인 용어).

🔴 **빈 폴더를 미리 만들지 않는다. 쓸 파일이 생길 때 그 폴더를 만든다.**
빈 칸 8개를 깔아두면 한 장을 쓰려고 8지 선다를 먼저 통과해야 하고, 열 때마다 0이 보이면 안 열게 된다.

**셋을 뺐다** (운영 중인 `_brain/` 4곳 실측, 콘텐츠 37장 기준).

| 뺀 것 | 실측 | 왜 |
|---|---|---|
| `voc/` | **0건** | 이 규약이 개별 요청 복제를 금지해 **쓸 것이 남지 않는다**(이슈가 정본) |
| `retro/` | 1건 | 회고는 `infra/`로 흡수했다 — 아래 §회고의 집 참고 |
| `design/` | 2건 | `decisions/`로 합친다 |

남긴 다섯의 근거: `decisions` 13 · `domain` 9 · `infra` 6 · `conventions` 4 · `glossary` 2 = **37장 중 34장**.

## 운영 규칙 (schema)

- 모든 wiki 페이지는 `[[wikilink]]`로 관련 페이지를 잇는다. 도메인 용어는 `glossary/` 단일 노드에 누적.
- 낡은 노드는 **폴더로 옮기지 않고 `status:`만 바꾼다**(`superseded`·`archived`). 🔴 파일을 옮기면 `[[wikilink]]`가 깨지는데, 실측 4곳에서 `archived/` 폴더는 **한 번도 만들어지지 않았고** `superseded`도 0건이었다 — 옮길 사람이 없다는 뜻이다.
- ⚠️ **각 노드는 간결하게** 유지한다(요지 우선, 상세는 링크·코드 경로로). `overview.md`도 짧은 종합만(상세는 노드 링크). 0.8 이전 `harness-init`이 깐 레포는 루트 `CLAUDE.md`가 `@_brain/wiki/`를 참조해 **노드 전부가 매 세션 로드**된다 — 그래서 간결해야 했다. 0.9부터 init은 이 줄을 넣지 않는다(`brain-sync` 머리글: 배출구 없는 레포가 33파일 72KB를 매 세션 로드했다). 노드는 `brain-walk`·`brain-intake`·`brain-sync`와 필요한 세션이 연다.

## 3-operation (LLM wiki 워크플로우)

wiki는 정적 폴더가 아니라 **ingest·query·lint 세 동작으로 자라는 살아있는 아티팩트**다. 사람은 소스 큐레이션·질문에 집중하고, 부기(링크·요약·정합)는 agent가 한다.

| operation  | 트리거                        | 하는 일                                                                                                                                                                                            |
| ---------- | ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **walk** ⭐ | **레포를 맡았을 때 · `_brain/`이 비었을 때** | **`brain-walk` 스킬**이 코드를 R1~R7로 훑어 다섯 장을 만든다(입출구 · 테이블 · 생애 · 바뀔 수 있는 값 · 막힌 질문). **raw가 필요 없다 — 코드가 raw다.** |
| **ingest** | `raw/`에 자료 투입            | **`brain-intake` 스킬**로 분류→노드 생성·갱신, 관련 노드 cross-link, `overview.md`·`index.md` 갱신, `log.md` append. 처리 raw는 `raw/_processed/`로 이동.                                          |
| **query**  | 사람이 wiki에 질문            | index에서 관련 노드 검색→읽고 **인용과 함께** 답한다. 답이 **재사용 가능한 분석·비교**면 새 노드로 환류(⚠️ 개별 VoC·요청은 복제 금지 — 이슈가 정본). `log.md` append.                              |
| **lint**   | **PR에서 5장 중 하나를 고칠 때** (❌ "정기"로 두지 않는다 — 실측에서 한 번도 안 돌았다) | 모순·stale 주장·고아 노드(링크 0)·끊긴 `[[wikilink]]`·index↔파일 불일치·커버리지 갭 점검 후 보고·수선. **코드 drift 점검은 `harness-doctor`·`/revise-claude-md` 몫** — 여기선 wiki 내부 정합만. `log.md` append. |

- **개별 사용자 요청·VoC**는 raw→triage→**GitHub 이슈(정본)**. wiki에 복제하지 않는다(이슈 트래커 중복·stale 방지). 반복 테마가 제품 판단으로 굳으면 그때 `decisions/` 1장. query 환류도 이 규칙을 따른다.
- **`log.md` 포맷(파싱 가능)**: `## [YYYY-MM-DD] {walk|ingest|query|lint} | {요약}` 헤더 + 하위 불릿(소스→노드, 갱신 노드 목록 등). 최신이 위.
- ingest/query 시 `wiki/index.md` 해당 섹션에 항목 추가·갱신하고, 소스 종합이 바뀌면 `overview.md`도 반영.

## 🔴 언제 채우나 — 정해진 세 순간

**"정기"·"주간"·"시간 날 때"는 실패한 트리거다.** `_brain/` 4곳 실측에서 콘텐츠가 0·1·5·31장으로 갈렸고, 31장인 레포조차 **26장이 세팅 첫 주**에 몰려 있었다. 그 뒤 두 달 반 동안 살아남은 경로는 **하나뿐**이었다 — 기능 PR 안에서 같이 갱신.

| 순간 | 무엇을 | 왜 이 순간인가 |
|---|---|---|
| **대안을 버렸을 때** | `decisions/` 1장 | 코드에는 **채택된 것만** 남는다. 지금 안 적으면 복원 불가다 |
| **장애를 닫을 때** | `infra/` 1장 | 회고 때가 아니라 **닫는 자리**에서 |
| **같은 질문을 두 번 받았을 때** | `domain/` 또는 `glossary/` 1장 | 두 번은 우연이 아니다 |

**같은 PR에서 갱신한다. 별도 작업으로 미루면 안 한다.**

그리고 `wiki/open-questions.md`(`brain-walk` 산출물 5번)는 **카테고리 폴더에 넣지 않는다** — `overview.md`·`index.md`·`log.md`와 같은 메타 레벨이다.

## 노드 템플릿

모든 wiki 노드는 아래 골격을 따른다(Obsidian 호환·일관성). `brain-intake`가 이 템플릿으로 생성한다.

**Frontmatter (YAML):**

```yaml
---
type: domain | decision | infra | convention | glossary
tags: [키워드]
updated: YYYY-MM-DD # 필수 — freshness(6개월 규칙)·Dataview 정렬용
status: active # 필수 — active | archived | superseded
---
```

> **frontmatter는 4필드 모두 필수**로 채운다(Obsidian **Dataview** 동적 쿼리·정렬이 일관 메타에 의존). lint가 누락·불일치를 잡는다.

**본문 골격:** `# 제목` → 한 줄 요지 → (카테고리별 본문) → 마지막 줄 `관련: [[..]] · [[..]]`

**카테고리별 본문 구성:**

| type                   | 본문                                                                                                  |
| ---------------------- | ----------------------------------------------------------------------------------------------------- |
| `infra` · `convention` | 규칙 한 줄 + **Why:**(왜) + **How to apply:**(언제·어떻게)                                            |
| `decision`             | 맥락 → 결정 → 대안(버린 이유) → 결과·함정                                                             |
| `glossary`             | 용어 정의 + 내부↔외부 명칭 차이 + 코드 위치                                                           |
| `domain`               | 비즈니스 흐름·프로세스 + 관련 엔티티/코드 경로                                                        |

**폐기된 셋** — `voc`(개별 요청은 GitHub 이슈가 정본이라 쓸 것이 남지 않는다) · `retro`(`infra/`로 흡수) · `design`(`decisions`로 합친다).

## 민감정보 격리

- PII·보안사고·인사 정보는 wiki에 넣지 않는다. 필요 시 `_brain/internal/` + `.gitignore` + "이 폴더 읽지 말 것" 명시.
- 🔴 **자격증명·설정 값은 키 이름까지만 적는다. 값은 0자다.** 비밀번호·토큰·API 키·access key뿐 아니라 **DB 호스트·RDS 엔드포인트·계정 ID·내부 도메인**도 값이다.
  - 왜 이 줄이 필요한가: 설정 파일(yml·.env)에 비밀값이 평문으로 커밋된 레포가 드물지 않다. `_brain/wiki/infra/`에 설정 문서를 쓰는 순간 값이 딸려오는 경로가 생긴다.
  - 쓰는 방법: `custom.openai-key 🔴` 처럼 **키 경로 + 🔴 표기**만. 프로필 간 차이를 보여야 하면 값을 비교하지 말고 **"같다/다르다"**로 적는다(해시 대조로 판정).
  - 쓴 뒤 검사한다 — 값 패턴이 섞였으면 지운다.

    ```bash
    grep -rnoE "AKIA[A-Z0-9]{10,}|rds\.amazonaws\.com|[0-9]{12}\.dkr\.ecr|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-" wiki/
    ```
- 🔴 **`internal/`은 이중으로 막는다** — `_brain/.gitignore`에 있어도, 나중에 `_brain/`을 커밋으로 전환할 때 같이 열릴 수 있다. 루트 `.gitignore`에도 `_brain/internal/`을 따로 박아둔다.

## 관계

- 루트 `CLAUDE.md`는 `_brain/`을 **자동 로드하지 않는다**(0.9부터. 옛 레포의 `@_brain/wiki/` 줄은 그대로 두되 노드가 커지면 지우는 쪽을 권한다). 들어오는 길은 `.claude/README.md` 라우팅의 `brain-walk`·`brain-intake`다. **회고 정본은 `_brain/wiki/infra/`** 다.

## 🔴 회고의 집은 하나다 — `docs/LEARNED.md` 를 접었다 (2026-09-28)

실측이 근거다. 레포 7곳에서 `docs/LEARNED.md` 는 **3곳에만 있고 3곳 전부 죽었다.**

| | 실측 |
|---|---|
| 있는 곳 | 3 / 7 |
| 마지막 엔트리 | 2026-08-21 ~ 09-18 |
| 임계(5) 대비 쌓인 `feat`/`refactor` | **13 · 21 · 8건** — 훅이 매 세션 환기했는데 엔트리 생산은 **0** |
| cm-admin | 훅은 설치됐는데 **대상 파일이 없어 anchor 가 빈 값** → 구조적으로 절대 발화하지 않았다 |
| 형식 | 헤딩형 2곳 · 표형 1곳 — 단순 grep 은 표형을 0으로 오판한다 |

반면 `_brain/wiki/infra/` 는 같은 기간 **6장이 살아 있었다.** 붙은 경로가 셋(`brain-walk`·`brain-intake`·`brain-sync`)이라 갱신될 이유가 있고, LEARNED 는 붙은 경로가 훅 환기 하나뿐이었다.

**그래서 인프라 회고는 `infra/` 한 곳에 쓴다.** 기존 `docs/LEARNED.md` 가 있는 레포는 포인터 한 줄만 남기고 내용을 옮긴다 — 두 곳에 두면 둘 다 썩는다.
- 팀이 커밋해 공유하는 지식은 `_brain/` 한 곳이다. 통합 wiki로 흘려보내는 배출구는 `brain-sync`.
- 세션 auto-recall memory(`~/.claude/projects/.../memory/`)는 **개인 로컬 레이어**로 별도 유지(커밋 안 함).
