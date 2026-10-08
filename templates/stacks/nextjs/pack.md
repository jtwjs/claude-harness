# nextjs 팩

TS 프로젝트이므로 기존 조건부 규칙 `rules/{typescript,functional-programming}.md`도 같이 복사한다. 이 팩은 그 위에 Next 전용만 더한다.

## 검증 명령 후보 — 하나씩 실행해 통과한 것만 `verify`에

| 키 | 후보 | 비고 |
|---|---|---|
| format | `<pm> exec prettier --check .` · `<pm> exec biome format .` | 읽기 전용만 |
| lint | `package.json`의 `lint` 스크립트 · `<pm> exec eslint .` | **Next 16에서 `next lint`는 제거됐고 `next build`도 린트를 돌리지 않는다.** `next lint`가 스크립트에 남아 있으면 실패하므로 적지 않고 보고한다(코드모드 `npx @next/codemod@canary next-lint-to-eslint-cli .`) |
| typecheck | `<pm> exec next typegen && <pm> exec tsc --noEmit` | `LayoutProps`·`PageProps` 같은 전역 타입은 Next가 `.next/types`에 **생성**한다. `tsc`만 돌리면 `.next`가 없는 CI에서 `TS2304`로 실패하고, 로컬은 앞선 build 덕에 통과해 **로컬만 초록**이 된다(stack-kits 실측) |
| test | `package.json`의 `test` 스크립트 (보통 `vitest run`) | E2E(Playwright)는 verify에 넣지 않고 CI 별도 잡으로 |
| build | `<pm> build` | |

`<pm>`은 lock 파일로 정한다: `pnpm-lock.yaml` → pnpm · `yarn.lock` → yarn · `package-lock.json` → npm.

## test · tdd

- `test.runner`: `vitest` 또는 `jest`(설정 파일로 판정).
- `tdd.include` 제안: `src/**/model/**`, `src/**/lib/**`, `src/**/*.server.ts` 같은 도메인 로직 경로(레포 구조를 보고 고른다).
- `tdd.exclude` 제안: `**/page.tsx`, `**/layout.tsx`, `**/loading.tsx`, `**/error.tsx`, `**/generated/**`, `**/*.stories.tsx` — 얇은 조립·생성물은 통합(E2E)이 커버한다.

## CI 셋업 스텝 (`{{SETUP_STEPS}}` 자리, pnpm 예)

```yaml
      - uses: pnpm/action-setup@v4
        with: { package_json_file: <root>/package.json }   # pnpm 버전은 package.json packageManager 한 곳에서
      - uses: actions/setup-node@v4
        with:
          node-version-file: <root>/.nvmrc
          cache: pnpm
          cache-dependency-path: <root>/pnpm-lock.yaml
      - run: pnpm install --frozen-lockfile
```

`<root>`는 `stacks.packs[].root`(단일 앱이면 `.`). `.nvmrc`·`engines`가 없으면 Node 버전을 묻는다. `package_json_file`을 안 주면 action이 루트 `package.json`만 찾아 앱별 레포에서 실패한다.

## create-next-app이 만드는 에이전트 파일 (16.x 실측)

- `AGENTS.md`의 `<!-- BEGIN:nextjs-agent-rules -->` 블록은 **`next dev`가 실행될 때마다 다시 써 넣는다.** 지우면 미커밋 변경으로 되살아난다 — 지우지 말고 커밋한다. 내용은 "설치된 버전 문서 `node_modules/next/dist/docs/`를 먼저 읽어라".
- `CLAUDE.md`는 `@AGENTS.md` 한 줄로 만들어진다. `harness-init`은 이 파일을 덮지 않고 **그 줄을 보존한 채** 하네스 내용을 더한다.

## 복사할 규칙

`rules/nextjs.md` · `rules/e2e.md`(Playwright가 있을 때) (+ 기존 TS 조건부 두 파일)
