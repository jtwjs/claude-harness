# nextjs 팩

TS 프로젝트이므로 기존 조건부 규칙 `rules/{typescript,functional-programming}.md`도 같이 복사한다. 이 팩은 그 위에 Next 전용만 더한다.

## 검증 명령 후보 — 하나씩 실행해 통과한 것만 `verify`에

| 키 | 후보 | 비고 |
|---|---|---|
| format | `<pm> exec prettier --check .` · `<pm> exec biome format .` | 읽기 전용만 |
| lint | `package.json`의 `lint` 스크립트 · `<pm> exec eslint .` | **Next 16에서 `next lint`는 제거됐고 `next build`도 린트를 돌리지 않는다.** `next lint`가 스크립트에 남아 있으면 실패하므로 적지 않고 보고한다(코드모드 `npx @next/codemod@canary next-lint-to-eslint-cli .`) |
| typecheck | `<pm> exec tsc --noEmit` | |
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
      - uses: actions/setup-node@v4
        with: { node-version-file: ".nvmrc", cache: pnpm }
      - run: pnpm install --frozen-lockfile
```

`.nvmrc`·`engines`가 없으면 Node 버전을 묻는다.

## 복사할 규칙

`rules/nextjs.md` (+ 기존 TS 조건부 두 파일)
