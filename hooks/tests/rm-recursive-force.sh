# deny rm-recursive-force — 재귀 + 강제 삭제는 경로와 상관없이 막는다(#120). test.sh 가 source 한다(check_deny 를 쓴다).
# -f 없는 rm -r 은 통과(#120 결정 1 B, 사용자). 루트 · 홈은 -f 가 없어도 rm-rf-root-home 이 막는다.
# 명령은 문자열로만 넘긴다 — 실제로 지우지 않는다.
printf '\n[rm-recursive-force] 재귀 강제 삭제 — 경로 무관 차단 · rm -r 단독 · 문자열 속 글자는 통과\n'

# ── 막을 꼴: 변수 · 따옴표 경로, 플래그 표기, sh -c 안, 서브셸, && · ; 뒤, 앞에 붙는 낱말 ──
check_deny 2 'rm -rf "$X/none"'
check_deny 2 'rm -rf $TMPDIR/x'
check_deny 2 'rm -fr ./build'
check_deny 2 'rm -rf /tmp/x'
check_deny 2 'rm -r -f a'
check_deny 2 'rm -f -r a'
check_deny 2 'rm -R --force a'
check_deny 2 'rm --recursive --force a'
check_deny 2 'rm -rfv a'
check_deny 2 'rm a -rf'
check_deny 2 "sh -c 'rm -rf \"\$X\"'"
check_deny 2 'bash -c "cd /tmp && rm -rf x"'
check_deny 2 '(cd /tmp && rm -rf x)'
check_deny 2 'mkdir -p a && rm -rf a'
check_deny 2 'true; rm -rf a'
check_deny 2 'echo "$(rm -rf a)"'
check_deny 2 'X=1 rm -rf a'
check_deny 2 'sudo rm -rf a'
check_deny 2 'command rm -rf a'
check_deny 2 '/bin/rm -rf a'
check_deny 2 '\rm -rf a'
check_deny 2 'ls | xargs rm -rf'
check_deny 2 'find . -name x -exec rm -rf {} +'
check_deny 2 "$(printf 'mkdir -p a\nrm -rf a')"
# 루트 · 홈은 -f 가 없어도 막는다(rm-rf-root-home 회귀)
check_deny 2 'rm -r ~'
check_deny 2 'rm -r /'

# ── 통과할 꼴: 단일 파일 · -f 만 · -r 만(결정 1 B) · 문자열 속 글자 · 다른 명령의 -rf ──
check_deny 0 'rm a.txt'
check_deny 0 'rm -f a.txt'
check_deny 0 'rm -r build'
check_deny 0 'rm -r "$X/none"'
check_deny 0 'rm -ri a'
check_deny 0 'echo "rm -rf x"'
check_deny 0 "printf 'rm -rf %s\n' x"
check_deny 0 'git commit -m "막기: rm -rf 금지"'
check_deny 0 'orca orchestration ask --question "a; rm -rf b"'
check_deny 0 'grep -rf patterns.txt .'
check_deny 0 'rmdir -p a/b'
check_deny 0 'rm -r a; ls -f'
check_deny 0 'rm -r a && grep -f x y'
