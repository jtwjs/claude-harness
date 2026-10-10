---
name: brain-walk
description: 레포를 7단계(R1~R7)로 한 바퀴 돌아 _brain/wiki/ 의 첫 다섯 장을 만든다 — 입출구 목록·테이블 표·생애 문서·바뀔 수 있는 값 표·막힌 질문 목록. raw 투입이 필요 없다(코드가 곧 raw). 하네스는 깔렸는데 _brain/ 이 비어 있는 레포, 인수인계 없이 맡게 된 레포, "이 서비스가 뭘 하는지 모르겠다"에 쓴다. 이미 5장이 있으면 갱신 모드로 돈다.
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
---

코드를 읽어 **사실로 채운다.** 모르는 것은 **모른다고 적고 5번 문서로 보낸다.**

> 🔴 **이 스킬의 실패 모드는 둘이다.**
> ① **추측을 사실처럼 적는 것** — 확인 안 한 것은 `⚠️`와 함께 「막힌 질문」으로 보낸다.
> ② **비밀값을 문서로 옮기는 것** — 설정 문서는 **키 이름만** 적는다. 값은 한 글자도 옮기지 않는다.

## 왜 이 스킬이 따로 있나

`harness-init`은 **명령·규칙·CI**를 깐다. `brain-intake`(2026-10-11 삭제)는 **사람이 `raw/`에 던진 것**을 정리했다. 그 사이가 비어 있었다 — 아무도 raw를 던지지 않으면 `_brain/`은 영원히 스캐폴드로 남는다(실측: `raw` 0건인 레포는 콘텐츠 0~1장, 4건인 레포는 31장).

**`brain-walk`의 트리거는 사람의 결심이 아니라 레포 자체다.** 코드가 raw다.

```
harness-init(스택 판정·명령·규칙·CI) → brain-walk(코드→5장) → brain-sync(레포→vault)
```

> 2026-10-11부터 `_brain/`은 **팀 위키·인수인계용**이다. raw 투입구(`brain-intake`)는 실측 30일 호출 0이라 흐름에서 뺐고 스킬도 삭제했다. 사람이 이해해야 할 것은 커밋되지 않는 `_learn/`에 따로 쌓인다(`learn-setup` 훅).

## 0. 스택 판정 — 먼저 무엇을 grep할지 고른다

판정은 `harness-init`과 **같은 표**를 쓴다: `${CLAUDE_PLUGIN_ROOT}/templates/stacks/README.md`(빌드 파일 기준). `.claude/harness.json`의 `stacks.packs`가 이미 있으면 그 값을 그대로 쓰고 다시 판정하지 않는다. 모노레포면 `root`마다 따로 돈다.

판정된 스택으로 아래 표의 grep 대상을 고른다. 표에 없는 스택(`go.mod`·`pyproject.toml` 등)이면 입구·스키마 패턴을 사용자에게 묻는다.

| 스택 (팩) | 입구 | 스키마 | 트랜잭션 | 설정 |
|---|---|---|---|---|
| **Kotlin/Spring** (`kotlin-spring`) | `@RestController` `@Scheduled` `@KafkaListener` `@SqsListener` | `@Entity` `@Table` Flyway/Liquibase | `@Transactional` | `application-*.yml` `@Value` |
| Node/NestJS | `@Controller` `@Cron` `@SqsMessageHandler` | `@Entity`(TypeORM) · Prisma schema · migrations | `queryRunner` `$transaction` | `.env*` `ConfigService` |
| Next.js(FE) (`nextjs`) | route handler · server action · `revalidate` | — | — | `.env*` `next.config` |

⛔ **스택을 추측하지 않는다.** 빌드 파일이 없으면 사용자에게 묻는다.

## R1 — 경계: 입구·출구를 파일 트리보다 먼저

```bash
for a in RestController Controller Scheduled KafkaListener SqsListener RabbitListener EventListener; do
  echo "@$a 파일 $(grep -rl "@$a" --include='*.kt' src/main | wc -l) / 건 $(grep -rho "@$a" --include='*.kt' src/main | wc -l)"
done
for m in GetMapping PostMapping PutMapping DeleteMapping PatchMapping RequestMapping; do
  echo "@$m $(grep -rho "@$m" --include='*.kt' src/main | wc -l)"
done
grep -rh "@FeignClient" --include='*.kt' src/main | sort -u      # 출구
```

🔴 **세 종류(HTTP·스케줄러·큐)를 반드시 전수로 센다.** 비율이 서비스마다 뒤집힌다 — 실측에서 한 서비스는 `@Scheduled` 55 vs `@RestController` 61이었고 **다른 서비스는 30 vs 0**이었다. 한쪽만 세면 진짜 일꾼을 놓친다.

🔴 **주석 처리된 것을 잡는다.** `grep "@Scheduled"`는 주석도 센다. 한 서비스는 2건이 **둘 다 주석**이어서 활성 스케줄러가 0이었다 — 이걸 놓치면 "스케줄러 2개"라는 **틀린 문서**가 남는다.

```bash
grep -rn "@Scheduled" --include='*.kt' src/main | grep -v "^\s*//" | grep -vE ":\s*//"
```

## R2 — 스키마: 무엇을 만지나, 그리고 무엇을 알 수 없나

```bash
find . -name "*.sql" -not -path "./build/*" | head          # 마이그레이션 유무
grep -rn "flyway\|liquibase\|ddl-auto" build.gradle.kts src/main/resources/application*.y*ml
grep -rho '@Table(name = "[^"]*"' --include='*.kt' src/main | sed 's/.*name = "//; s/"//' | sort -u
for k in UniqueConstraint "@Column(unique" "@Index" "@ManyToOne" "@OneToMany" "@Enumerated"; do
  echo "$k $(grep -rho "$k" --include='*.kt' src/main | wc -l)"
done
```

**테이블이 20개를 넘으면 접두사로 묶어 표를 만든다.** 80개를 나열하면 아무도 안 읽는다.

```bash
... | awk -F_ '{print $1}' | sort | uniq -c | sort -rn
```

⭐ **없는 것을 적는 것이 이 단계의 절반이다.** 마이그레이션 도구가 없으면 **엔티티 클래스가 사실상 스키마 정본**이고 변경 이력이 어디에도 없다는 뜻이다. `@UniqueConstraint` 0건이면 중복 방지가 DB에만 있어 **코드 리뷰로 확인할 수 없다.** 둘 다 그대로 적는다.

## R3·R4 — 한 건의 생애와 트랜잭션 경계

```bash
grep -rh "enum class" --include='*.kt' src/main | sed 's/ *{.*//' | sort -u
sed -n "/enum class <상태Enum>/,/^}/p" <파일>              # 값을 실제로 읽는다
echo "@Transactional $(grep -rho '@Transactional' --include='*.kt' src/main | wc -l) / readOnly $(grep -rho '@Transactional(readOnly = true)' --include='*.kt' src/main | wc -l)"
```

🔴 **상태 enum에 실패 값이 있는지 반드시 확인한다.** 이것이 이 단계의 핵심 산출물이다. 한 서비스는 `READY`·`DONE` 둘뿐이고 **`FAILED`가 없었다** — 실패가 상태로 남지 않으면 "실패 건수" 쿼리를 쓸 수 없고 누락은 사람이 눈으로 볼 때만 발견된다. **incident 기록(A6)이 필요한 이유가 코드에 있다는 증거**이므로 놓치면 안 된다.

⚠️ 여기서 단정하지 않는다. "실패가 어느 테이블에 남는가"는 **행을 봐야** 알고, 운영 DB를 직접 탐색하지 않는다(읽기 전용 복제본 먼저). → 막힌 질문으로 보낸다.

## R5 — 설정과 환경: 🔴 키 이름만

**순서를 바꾸지 않는다. 추적 여부를 먼저 본다.**

```bash
git ls-files src/main/resources/ | grep -E "\.ya?ml$"      # ① 비밀 파일이 git에 있나
grep -c "yml\|yaml" .gitignore
for f in src/main/resources/application*.y*ml; do          # ② 개수만 센다
  echo "$f $(grep -ciE 'password|secret|access-?key|token|api-?key|credential' $f)"
done
```

③ 키 **경로만** 뽑는다. 값은 지운다.

```bash
python3 -c "
import io,re,sys
for l in io.open(sys.argv[1],encoding='utf-8'):
    m=re.match(r'^(\s*)([A-Za-z0-9_.-]+):\s*(.*)$', l.rstrip())
    if m: print('%s%s:%s' % (m.group(1), m.group(2), '' if not m.group(3) else ' ·'))
" src/main/resources/application-prod.yml
```

④ 🔴🔴 **프로필별 DB 호스트를 대조한다. 값은 출력하지 않고 해시로만.**

이 단계를 건너뛰면 가장 중요한 것을 놓친다 — 실측한 한 서비스는 **`stage`와 `prod`의 호스트가 동일**했다. 즉 "스테이지에서 테스트"가 운영 DB에 쓰는 일이었고, **파일 이름만 보면 절대 안 보인다.**

```bash
python3 - <<'EOF'
import io,re,hashlib,glob
for f in sorted(glob.glob('src/main/resources/application*.y*ml')):
    m=re.search(r'url:\s*jdbc:[a-z]+://([^:/?]+)', io.open(f,encoding='utf-8').read())
    if not m: print('%-34s (url 없음 — 상위 상속)' % f); continue
    h=m.group(1)
    print('%-34s host해시 %s · %s · 이름에 %s' % (f, hashlib.sha1(h.encode()).hexdigest()[:8],
        'localhost' if h in ('localhost','127.0.0.1') else '원격',
        'prod' if 'prod' in h else ('dev' if 'dev' in h else '표기없음')))
EOF
```

**해시가 같은 프로필 쌍이 있으면 🔴로 적는다.** 호스트 값은 옮기지 않고 **"같다/다르다"**로만 쓴다. 기본 활성 프로필(`spring.profiles.active`)과 Dockerfile의 기본값도 같이 확인한다 — 지정을 빠뜨리면 어디를 가리키는지가 조용히 바뀐다.

⛔ **값이 섞였는지 문서를 쓴 뒤 반드시 검사한다.**

```bash
grep -rnoE "AKIA[A-Z0-9]{10,}|rds\.amazonaws\.com|[0-9]{12}\.dkr\.ecr|[0-9a-f]{8}-[0-9a-f]{4}-" _brain/wiki/ && echo "🔴 값 유출 — 제거"
```

그리고 **코드에 박혀 배포가 필요한 값**을 따로 가른다 — 하드코딩된 키·이미지 태그·JVM 옵션·기본 프로필. 한 서비스는 설정에 외부 API 키가 있는데도 컨트롤러가 같은 값을 **인자로 하드코딩**하고 있었다(한 값이 두 곳, 한 곳은 코드).

## R6 — 인프라: 몇 개가 어디서 도나

```bash
ls .github/workflows deploy Dockerfile* 2>/dev/null
grep -nE "^on:|branches|tags|uses:|ECR|docker (build|run|stop)|scp|ssh" .github/workflows/*.yml | head -30
cat deploy/Dockerfile 2>/dev/null || cat Dockerfile
```

반드시 답할 것 넷: **트리거**(브랜치 push인가 태그 push인가) · **인스턴스 수** · **메모리 상한** · 🔴 **되돌리는 법**.

⭐ **롤백 가능성을 이미지 태그로 판정한다.** 태그가 `:latest`·고정 숫자면 매 배포가 같은 태그를 덮어써 **이전 이미지로 못 돌아간다.** runbook의 "되돌리는 법" 칸을 채울 수 없는 상태이므로 문서에 🔴로 적는다.

## R7 — 되묻기: 🔴 사람 단계다

**문서를 덮고 답해본다.** 에이전트는 이 단계를 대신할 수 없다 — 대신 두 가지만 한다.

1. R1~R6에서 **"확인하지 않았다"고 표시한 것을 전부 모은다**
2. 표로 만들고 **「누가 답하나」 칸을 비워 둔다**

사람이 그 칸을 채운다. 🔴 **이 칸이 없으면 목록이 영원히 안 줄어든다** — 질문만 쌓이고 답이 안 온다.

한 바퀴 뒤 문서 없이 답해서 **막힌 질문만** 남긴다. 막히지 않은 것은 해당 문서로 옮기고 목록에서 지운다.

## 산출물 — 다섯 장, 경로 고정

| # | 파일 | 나오는 단계 |
|---|---|---|
| 1 | `_brain/wiki/domain/io-inventory.md` | R1 + R6 |
| 2 | `_brain/wiki/domain/tables.md` | R2 |
| 3 | `_brain/wiki/domain/<핵심흐름>-lifecycle.md` | R3 + R4 |
| 4 | `_brain/wiki/infra/configurable-values.md` | R5 |
| 5 | `_brain/wiki/open-questions.md` | R7 |

frontmatter 4필드 **전부 필수**(`_brain/CLAUDE.md` 규약).

```yaml
---
type: domain          # 4번은 infra
tags: [<서비스>, ...]
updated: YYYY-MM-DD
status: active
---
```

본문 골격: `# 제목` → 한 줄 요지 → 표 중심 본문 → 마지막 줄 `관련: [[..]] · [[..]]`

**5번은 카테고리 폴더에 넣지 않고 `wiki/` 바로 아래 둔다** — `overview.md`·`index.md`·`log.md`와 같은 메타 레벨이다(5분류 — decisions·domain·infra·conventions·glossary — 에 "질문" 버킷이 없다).

마지막에 `wiki/index.md`에 5행을 추가하고 `wiki/log.md`에 1엔트리를 append한다.

```
## [YYYY-MM-DD] walk | <레포> R1~R7 한 바퀴 — 5장 생성
```

## 금지

- ⛔ **커밋·push·PR 생성 안 한다.** 파일만 쓰고 멈춘다 — 사람이 읽고 사람이 올린다
- ⛔ **운영 DB에 쿼리를 날리지 않는다.** 행을 봐야 하는 질문은 막힌 질문으로 남긴다(읽기 전용 복제본 확보가 선행)
- ⛔ **프로필 이름으로 환경을 판단하지 않는다.** 실행·쿼리 명령을 제안하기 전에 그 프로필의 `datasource.url` 호스트를 확인한다 — 이름이 `stage`인데 운영을 가리킨 실물이 있다
- ⛔ **빈 폴더를 만들지 않는다.** 쓸 파일이 있는 폴더만 만든다. 열 때마다 0이 보이면 안 열게 된다
- ⛔ **여러 레포를 한 번에 돌리지 않는다.** 5장 × N레포를 한 번에 내면 아무도 안 읽는 문서가 5N장 남는다. **구조 설치는 일괄, 내용은 한 레포씩**
- ⛔ 수치를 창작하지 않는다. 센 것만 적고, 안 센 것은 막힌 질문으로

## 완료 판정

- [ ] 다섯 장이 있고 frontmatter 4필드가 전부 찼다
- [ ] 각 장에 **"없다"고 적은 항목이 최소 하나** 있다 (없는 것을 안 적으면 훑지 않은 것이다)
- [ ] 비밀값 검사 grep이 0건이다
- [ ] 막힌 질문의 모든 행에 「누가 답하나」가 채워졌다
- [ ] `wiki/index.md` 5행 · `wiki/log.md` 1엔트리
