# base 브랜치에 바로 커밋이 쌓였을 때 — 작업 브랜치로 옮기기

`pr-write` 1단계에서 **현재 브랜치가 `<base>` 자신**이면 `<base>..HEAD`가 비거나 틀린다. 사용자 확인 뒤 커밋을 작업 브랜치로 옮긴다:

```bash
git fetch -q
git log origin/<base>..HEAD --oneline   # 옮길 커밋 확인
git switch -c <type>/<slug>             # 지금 HEAD 그대로 새 브랜치
git branch -f <base> origin/<base>      # 로컬 base 를 원격 위치로 (커밋은 새 브랜치에 남는다)
```

이후 단계의 비교 기준은 `origin/<base>`를 쓴다. 원격에 `<base>`가 없으면 멈추고 묻는다.

- `git branch -f`는 로컬 포인터만 옮긴다. 원격은 건드리지 않는다.
- 이미 `<base>`를 원격에 push한 뒤라면 이 절차로는 되돌릴 수 없다 — 멈추고 사용자와 revert/PR 방향을 정한다.
