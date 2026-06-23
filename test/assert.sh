# Tiny assertion harness. Source this, call assert_eq, end with finish.
_fails=0
assert_eq() { # assert_eq "$actual" "$expected" "label"
  if [[ "$1" == "$2" ]]; then
    echo "  ok: $3"
  else
    echo "  FAIL: $3"
    echo "    expected: [$2]"
    echo "    actual:   [$1]"
    _fails=$((_fails + 1))
  fi
}
finish() {
  if [[ $_fails -eq 0 ]]; then echo "PASS"; else echo "$_fails check(s) FAILED"; exit 1; fi
}
