# 자동 입구 발동 정확도 (Before · After 같은 방법)

- 문항: `evals.json` — 스킬 7개 × 20문항(떠야 할 말 10 · 안 떠야 할 말 10). skill-creator 「Description Optimization」 방식으로 만들었다
- 실행: `python3 -I run_trigger.py --evals evals.json --cwd <대상 레포> --out <결과.json> --runs 3 --workers 4 --model claude-opus-5-5`
- 판정: 설치된 플러그인 스킬이 첫 도구 호출로 불리면 발동. 훅은 끄고, 세션은 저장하지 않고, `dontAsk` 권한으로 돌리며, 첫 도구 블록이 나오면 바로 끊는다(도구가 실행되지 않는다)
- 대상 레포: `bash make_target_repo.sh <폴더> <claude-harness 루트>`로 만든다. `templates/CLAUDE.md.tmpl` · `templates/.claude/README.md`를 채운 작은 React 앱이고, 작업 트리에 변경 1개를 남긴다. 레포 밖 스크래치 폴더에 만든다
- `before-0.40.0.json`: 2026-11-24에 설치본 0.40.0으로 잰 원자료. commit 60회는 첫 측정이 사용 한도에 걸려 전부 무효라 따로 다시 쟀다(오류 응답은 `first_tool: error:*`로 표시하도록 측정기를 고친 뒤)
- 한계: 스킬 전에 Bash로 상태부터 보는 경우는 미발동으로 센다
