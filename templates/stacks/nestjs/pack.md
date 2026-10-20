# nestjs 팩

TS 프로젝트이므로 기존 조건부 규칙 `rules/{typescript,functional-programming}.md`도 같이 복사한다. 이 팩은 그 위에 NestJS 전용만 더한다.

⚠️ **미실측 팩이다(2026-10-20).** 이 팩을 쓰는 레포가 아직 없다. 첫 레포에서 아래 후보를 실제로 돌려 보고 이 파일을 고친다.

## 판정

- `package.json` dependencies에 `@nestjs/core`

## 검증 명령 후보 — 하나씩 실행해 통과한 것만 `verify`에

| 키 | 후보 (위에서부터 시도) | 비고 |
|---|---|---|
| format | `<pm> format:check` · `<pm> exec prettier --check .` | 읽기 전용만. Nest CLI 기본 `format`은 `--write`라 쓰지 않는다 |
| lint | `<pm> lint` · `<pm> exec eslint .` | Nest CLI 기본 `lint`가 `--fix`면 `eslint .`로 |
| typecheck | `<pm> exec tsc --noEmit` | |
| test | `<pm> test` (Jest 또는 Vitest) | e2e(`test:e2e`)는 verify에 넣지 않고 CI 별도 |
| build | `<pm> build` (`nest build`) | |

`<pm>`은 lock 파일로 정한다(nextjs 팩과 같다).

## test · tdd

- `tdd.include` 제안: `src/**/domain/**` — 규칙 조립 층(`rules/domain.md`)
- `tdd.exclude` 제안: `src/main.ts`, `**/*.module.ts`, `**/*.controller.ts`, `**/dto/**` — 조립 · 선언은 통합 테스트가 커버한다

## CI 셋업 스텝

react-vite 팩의 「CI 셋업 스텝」과 같다(pnpm · `.nvmrc` · `--frozen-lockfile`). npm · yarn이면 그 lock 파일에 맞춘다.

## 복사할 규칙

`rules/domain.md` (+ 기존 TS 조건부 두 파일)
