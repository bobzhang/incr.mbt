#!/usr/bin/env bash
# Verify the committed pkg.generated.mbti files against a fresh `moon info`.
#
# Those files are generated artifacts, and compilers do not agree on how to
# spell the same types: some emit Int/UInt, newer ones emit Int32/UInt32.
# Compare with that spelling normalized on both sides, so that whichever
# toolchain runs this check agrees with the committed files, and a real
# interface change -- a declaration added, removed, or changed -- still fails.
set -euo pipefail

moon info

status=0
while read -r file; do
  [ -n "$file" ] || continue
  if ! diff -u \
    <(git show "HEAD:$file" | sed -E 's/UInt32/UInt/g; s/Int32/Int/g') \
    <(sed -E 's/UInt32/UInt/g; s/Int32/Int/g' "$file"); then
    echo "::error file=$file::generated interface changed"
    status=1
  fi
done < <(git diff --name-only)

exit "$status"
