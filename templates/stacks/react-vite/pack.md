# react-vite 팩

TS 프로젝트이므로 기존 조건부 규칙 `rules/{typescript,functional-programming}.md`도 같이 복사한다. 이 팩은 그 위에 Vite + React SPA 전용만 더한다.

## 판정

- `vite.config.*`가 있고 `package.json` dependencies에 `react`가 있다
- **`next`가 없다** — 있으면 `nextjs` 팩이다
- 코드 뼈대는 stack-kits `fullstack` kit의 `apps/web`이다. ESLint 설정(FSD 경계)의 정본은 kit의 `apps/web/eslint.config.*`이고, 이 팩의 `rules/fsd.md`는 판정만 옮긴다

## 검증 명령 후보 — 하나씩 실행해 통과한 것만 `verify`에

⚠️ kit 확정 후 맞출 것 — 스크립트 이름은 kit `apps/web/package.json`과 kit README 검증 표가 정본이다.

| 키 | 후보 (위에서부터 시도) | 비고 |
|---|---|---|
| format | `<pm> format:check` · `<pm> exec prettier --check .` | 읽기 전용만 |
| lint | `<pm> lint` · `<pm> exec eslint .` | FSD 경계도 여기서 막힌다 |
| typecheck | `<pm> typecheck` · `<pm> exec tsc -b --noEmit` | Vite 템플릿은 tsconfig가 project references라 `-b`가 필요하다 |
| test | `<pm> test` (보통 `vitest run`) | E2E(Playwright)는 verify에 넣지 않고 CI 별도 잡으로 |
| build | `<pm> build` | 번들 크기 경고(500 kB)를 보고 `rules/bundle.md` |

- 계약 생성 타입(openapi-typescript)을 쓰면 CI에 "재생성 → `git diff --exit-code`" 스텝을 test 앞에 둔다. 재생성 명령은 kit의 스크립트를 쓴다(⚠️ kit 확정 후 맞출 것). 생성물은 손으로 고치지 않는다.
- `<pm>`은 lock 파일로 정한다(nextjs 팩과 같다).

## test · tdd

- `test.runner`: `vitest`.
- `tdd.include` 제안: `src/**/model/**`, `src/**/lib/**` — 순수 계산 · 도메인 규칙이 모이는 세그먼트.
- `tdd.exclude` 제안: `src/main.tsx`, `src/app/**`, `**/ui/**`, `**/*.stories.tsx`, `**/generated*` — 조립 · 표시 · 생성물은 화면 통합 테스트가 커버한다.

## CI 셋업 스텝 (`{{SETUP_STEPS}}` 자리, pnpm 예)

```yaml
      - uses: pnpm/action-setup@v4
        with: { package_json_file: <root>/package.json }
      - uses: actions/setup-node@v4
        with:
          node-version-file: <root>/.nvmrc
          cache: pnpm
          cache-dependency-path: <root>/pnpm-lock.yaml
      - run: pnpm install --frozen-lockfile
```

`<root>`는 `stacks.packs[].root`. 앱별 레포면 잡에 `defaults.run.working-directory: <root>`.

## 복사할 규칙

`rules/fsd.md`(FSD를 쓸 때만 — 묻는다) · `rules/e2e.md`(Playwright가 있을 때) · `rules/bundle.md` (+ 기존 TS 조건부 두 파일)
