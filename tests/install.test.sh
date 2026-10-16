#!/usr/bin/env bash
# tests/install.test.sh — end-to-end tests for install.sh.
# Runs the installer against throwaway targets and asserts the generated layout,
# shared skills, symlink fallback, link integrity, ownership-aware updates,
# migration, and uninstall. Dependency-free: bash, git, standard Unix tools.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/.." && pwd -P)"
installer="$repo/install.sh"
test_source="$repo"
state=".agents/catalogs/dotnet-tanstack-mono-skills/.install-manifest"

work="$(mktemp -d 2>/dev/null || mktemp -d -t harness-tests)"
trap 'rm -rf "$work"' EXIT

pass=0
fail=0

ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
ko() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1" >&2; }

assert_file() { if [ -f "$1" ]; then ok "exists: ${1#"$work"/}"; else ko "missing: ${1#"$work"/}"; fi; }
assert_missing() { if [ ! -e "$1" ] && [ ! -L "$1" ]; then ok "absent: ${1#"$work"/}"; else ko "should be absent: ${1#"$work"/}"; fi; }
assert_grep() { if grep -q -- "$2" "$1" 2>/dev/null; then ok "${1#"$work"/} contains: $2"; else ko "${1#"$work"/} lacks: $2"; fi; }
assert_not_grep() { if ! grep -q -- "$2" "$1" 2>/dev/null; then ok "${1#"$work"/} omits: $2"; else ko "${1#"$work"/} must not contain: $2"; fi; }
assert_exec() { if [ -x "$1" ]; then ok "executable: ${1#"$work"/}"; else ko "not executable: ${1#"$work"/}"; fi; }
assert_eq() { if [ "$1" = "$2" ]; then ok "$3 = $2"; else ko "$3: expected '$2', got '$1'"; fi; }
assert_same() { if cmp -s "$1" "$2"; then ok "identical: ${1#"$work"/}"; else ko "different: ${1#"$work"/}"; fi; }
assert_regular() { if [ -f "$1" ] && [ ! -L "$1" ]; then ok "regular file: ${1#"$work"/}"; else ko "not a regular file: ${1#"$work"/}"; fi; }
saved_fingerprint() { awk -F '\t' -v p="$2" '$1 == p { print $2; exit }' "$1/$state"; }
assert_unowned() { assert_eq "$(saved_fingerprint "$1" "$2")" "" "unmanaged $2"; }

install_to() {
  local label="$1"
  shift
  if "$installer" --source "$test_source" "$@" > "$work/$label.log" 2>&1; then
    ok "$label exited zero"
  else
    cat "$work/$label.log" >&2
    ko "$label exited non-zero"
  fi
}

snapshot() {
  find "$1" -type f -exec cksum {} + | LC_ALL=C sort
  find "$1" -type l -exec sh -c 'for link do printf "%s -> %s\n" "$link" "$(readlink "$link")"; done' sh {} + | LC_ALL=C sort
}

convert_crlf() {
  awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$1" > "$work/crlf-stage"
  mv "$work/crlf-stage" "$1"
}

# Every relative Markdown link in every .md/.mdc under DIR must resolve to an existing path.
assert_links_resolve() {
  local dir="$1" f t p total=0 broken=0
  if ! find -L "$dir" -path "$dir/.git" -prune -o \( -name '*.md' -o -name '*.mdc' \) -type f -exec awk '
    {
      line = $0
      while (match(line, /\]\([^)]*\)/)) {
        print FILENAME "\t" substr(line, RSTART + 2, RLENGTH - 3)
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' {} + > "$work/links"; then
    ko "could not scan Markdown links under ${dir#"$work"/}"
    return
  fi
  while IFS=$'\t' read -r f t; do
    case "$t" in http://* | https://* | mailto:* | \#* | /* | "") continue ;; esac
    p="${t%%#*}"
    total=$((total + 1))
    if [ ! -e "${f%/*}/$p" ]; then
      broken=$((broken + 1))
      printf '       broken: %s -> %s\n' "${f#"$dir"/}" "$t" >&2
    fi
  done < "$work/links"
  if [ "$broken" = 0 ] && [ "$total" -gt 0 ]; then ok "all $total relative links resolve under ${dir#"$work"/}"; else ko "$broken of $total links broken under ${dir#"$work"/}"; fi
}

section() { printf '\n== %s (elapsed %ss)\n' "$1" "$SECONDS"; }

# ---------------------------------------------------------------------------
section "shared layout, native adapters, hooks, and one physical skill source"
links_available=0
if ln -s "$repo/README.md" "$work/capability-link" 2>/dev/null && [ -L "$work/capability-link" ]; then links_available=1; fi
rm -f "$work/capability-link"
t1="$work/repo with spaces"; mkdir -p "$t1"; git -C "$t1" init -q
install_to full --target "$t1" --hooks --git-hooks
assert_grep "$t1/AGENTS.md" "](docs/architecture.md)"
assert_grep "$t1/AGENTS.md" "](.agents/rules/README.md)"
assert_grep "$t1/CLAUDE.md" "^@AGENTS.md"
assert_regular "$t1/docs/architecture.md"
assert_regular "$t1/.agents/skills/add-module/SKILL.md"
assert_file "$t1/.agents/templates/adr.template.md"
assert_exec "$t1/.agents/hooks/scripts/guard-generated-files"
assert_file "$t1/.agents/catalogs/dotnet-tanstack-mono-skills/LICENSE"
assert_grep "$t1/$state" "^# catalog: dotnet-tanstack-mono-skills$"
assert_grep "$t1/$state" "^# format: 2$"
assert_grep "$t1/$state" "^# options: --harness claude,copilot,codex,cursor"
assert_eq "$(find "$t1/.agents/skills" -name SKILL.md -type f | wc -l | tr -d ' ')" "11" "shared skill count"
if [ "$links_available" = 1 ]; then
  assert_eq "$(readlink "$t1/.claude/skills/add-module")" "../../.agents/skills/add-module" "relative Claude skill link"
  assert_eq "$(find "$t1" -name SKILL.md -type f | wc -l | tr -d ' ')" "11" "total physical skill count"
  assert_eq "$(find "$t1/.claude/skills" -type l | wc -l | tr -d ' ')" "11" "Claude alias count"
else
  assert_grep "$work/full.log" "Symlinks are unavailable"
  assert_eq "$(find "$t1/.claude/skills" -name SKILL.md -type f | wc -l | tr -d ' ')" "11" "fallback skill count"
fi
assert_same "$t1/.agents/skills/add-module/SKILL.md" "$t1/.claude/skills/add-module/SKILL.md"
assert_missing "$t1/.github/skills"
assert_missing "$t1/.cursor/skills"
assert_missing "$t1/harness"
assert_missing "$t1/.claude/agents"
assert_missing "$t1/.github/prompts"
assert_grep "$t1/.agents/skills/add-module/SKILL.md" "](references/module-scaffold.md)"
assert_grep "$t1/.agents/skills/add-module/SKILL.md" "](../../../docs/architecture.md"
assert_grep "$t1/.claude/skills/review-changes/references/boundary-checklist.md" "](../../../../.agents/rules/dotnet-api/slices.md)"
assert_grep "$t1/.claude/skills/review-changes/references/boundary-checklist.md" "](../../../../.agents/skills/cross-module-communication/SKILL.md)"
assert_grep "$t1/.claude/rules/csharp-async.md" "^paths:"
assert_grep "$t1/.claude/rules/csharp-async.md" "  - 'apps/api/\*\*/\*.cs'"
assert_not_grep "$t1/.claude/rules/csharp-async.md" "appliesTo"
assert_not_grep "$t1/.claude/rules/common-naming.md" "^paths:"
assert_grep "$t1/.claude/rules/testing-discipline.md" "  - 'apps/web/\*\*/\*.test.tsx'"
assert_grep "$t1/.github/instructions/web-routes.instructions.md" "^applyTo: 'apps/web/src/routes/\*\*/\*.ts, apps/web/src/routes/\*\*/\*.tsx'$"
assert_not_grep "$t1/.github/instructions/web-routes.instructions.md" "^title:"
assert_grep "$t1/.cursor/rules/common-boundaries.mdc" "^alwaysApply: true$"
assert_not_grep "$t1/.cursor/rules/common-boundaries.mdc" "^globs:"
assert_grep "$t1/.cursor/rules/dotnet-api-slices.mdc" "^globs: apps/api/src/Modules/\*\*/\*.cs$"
assert_grep "$t1/.cursor/rules/dotnet-api-slices.mdc" "^alwaysApply: false$"
assert_grep "$t1/.claude/settings.json" '[$]{CLAUDE_PROJECT_DIR}/.agents/hooks/scripts/guard-generated-files --stdin-json'
assert_grep "$t1/.github/hooks/guards.json" '".agents/hooks/scripts/guard-generated-files --stdin-json"'
assert_grep "$t1/.cursor/hooks.json" '".agents/hooks/scripts/guard-generated-files --stdin-json"'
assert_exec "$t1/.git/hooks/pre-commit"
assert_exec "$t1/.git/hooks/pre-push"
assert_grep "$t1/.git/hooks/pre-commit" '.agents/hooks/scripts/guard-generated-files" --staged'
assert_grep "$t1/.git/hooks/pre-push" '.agents/hooks/scripts/verify-gate"'
assert_links_resolve "$t1"

section "idempotent reinstall and complete owned uninstall"
snapshot "$t1" > "$work/before"
install_to identical --target "$t1" --hooks --git-hooks
snapshot "$t1" > "$work/after"
assert_same "$work/before" "$work/after"
assert_grep "$work/identical.log" "safely updating owned files"
printf 'keep me\n' > "$t1/README.md"
install_to uninstall --target "$t1" --uninstall
assert_file "$t1/README.md"
assert_missing "$t1/AGENTS.md"
assert_missing "$t1/CLAUDE.md"
assert_missing "$t1/docs"
assert_missing "$t1/.claude"
assert_missing "$t1/.github"
assert_missing "$t1/.agents"
assert_missing "$t1/.cursor"
assert_missing "$t1/.git/hooks/pre-commit"
assert_missing "$t1/.git/hooks/pre-push"
assert_file "$t1/.git/HEAD"

section "safe upgrades, unchanged upstream updates, edited files, and stale paths"
catalog="$work/catalog"; mkdir -p "$catalog"
# Full-catalog installation is covered above and in piped mode. Behavioral cases
# use a small catalog so their cost does not grow with the production catalog.
mkdir -p "$catalog/docs" "$catalog/rules/csharp" "$catalog/rules/web" \
  "$catalog/skills/add-module/references" "$catalog/skills/add-web-feature/references" "$catalog/hooks/scripts"
test_source="$catalog"
cp "$repo/LICENSE" "$catalog/LICENSE"
cp "$repo/hooks/scripts/format-gate" "$repo/hooks/scripts/guard-generated-files" "$repo/hooks/scripts/verify-gate" "$catalog/hooks/scripts/"
cat > "$catalog/AGENTS.md" <<'MD'
# Test catalog

[Architecture](docs/architecture.md), [rules](rules/README.md),
[skills](skills/README.md), and [hooks](hooks/README.md).
MD
printf '# Architecture\n' > "$catalog/docs/architecture.md"
printf '# Usage\n\n[Architecture](architecture.md).\n' > "$catalog/docs/usage.md"
printf '# Rules\n\n[Async](csharp/async.md), [routes](web/routes.md).\n' > "$catalog/rules/README.md"
printf '# Skills\n\n[Module](add-module/SKILL.md), [web](add-web-feature/SKILL.md).\n' > "$catalog/skills/README.md"
printf '# Hooks\n' > "$catalog/hooks/README.md"
cat > "$catalog/rules/csharp/async.md" <<'MD'
---
title: Async
description: Async rule fixture
appliesTo: 'apps/api/**/*.cs'
---

[Architecture](../../docs/architecture.md).
MD
cat > "$catalog/rules/web/routes.md" <<'MD'
---
title: Routes
description: Route rule fixture
appliesTo: 'apps/web/src/routes/**/*.ts, apps/web/src/routes/**/*.tsx'
---

[Architecture](../../docs/architecture.md).
MD
cat > "$catalog/skills/add-module/SKILL.md" <<'MD'
---
name: add-module
description: Module skill fixture
---

[Architecture](../../docs/architecture.md), [rule](../../rules/csharp/async.md),
[reference](references/example.md), and [web skill](../add-web-feature/SKILL.md).
MD
cat > "$catalog/skills/add-web-feature/SKILL.md" <<'MD'
---
name: add-web-feature
description: Web skill fixture
---

[Architecture](../../docs/architecture.md), [rule](../../rules/web/routes.md),
and [reference](references/example.md).
MD
printf '# Module example\n\n[Architecture](../../../docs/architecture.md).\n' > "$catalog/skills/add-module/references/example.md"
printf '# Web example\n\n[Architecture](../../../docs/architecture.md).\n' > "$catalog/skills/add-web-feature/references/example.md"
printf 'retired\n' > "$catalog/docs/retired.md"
printf 'retired with local edits\n' > "$catalog/docs/edited-retired.md"
printf 'literal-key document\n' > "$catalog/docs/lookup [one].md"
printf 'neighbor document\n' > "$catalog/docs/lookup o.md"
mkdir -p "$catalog/skills/retired-skill"
printf -- '---\nname: retired-skill\ndescription: Test obsolete skill cleanup.\n---\n' > "$catalog/skills/retired-skill/SKILL.md"
t2="$work/updates"; mkdir -p "$t2"
install_to initial --target "$t2" --source "$catalog" --hooks
baseline="$(saved_fingerprint "$t2" ".agents/skills/add-module/SKILL.md")"
printf '\nlocal skill edit\n' >> "$t2/.agents/skills/add-module/SKILL.md"
printf '\nlocal architecture edit\n' >> "$t2/docs/architecture.md"
printf '\nlocal literal-key edit\n' >> "$t2/docs/lookup [one].md"
printf '\nlocal neutral rule edit\n' >> "$t2/.agents/rules/web/routes.md"
printf '\nlocal rule edit\n' >> "$t2/.cursor/rules/web-routes.mdc"
printf '\n ' >> "$t2/.claude/settings.json"
printf '\nlocal obsolete edit\n' >> "$t2/docs/edited-retired.md"
chmod -x "$t2/.agents/hooks/scripts/format-gate"
printf '\n# local hook edit\n' >> "$t2/.agents/hooks/scripts/format-gate"
if [ -x "$t2/.agents/hooks/scripts/format-gate" ]; then edited_mode="x"; else edited_mode="-"; fi
mkdir -p "$t2/.agents/skills/third-party" "$t2/.github/skills/third-party" "$t2/.cursor/skills/third-party" "$t2/.claude/skills/third-party" "$t2/.agents/catalogs/another-catalog"
for where in .agents .github .cursor .claude; do printf 'foreign skill\n' > "$t2/$where/skills/third-party/SKILL.md"; done
printf '# another catalog\n' > "$t2/.agents/catalogs/another-catalog/.install-manifest"
printf 'foreign docs\n' > "$t2/docs/third-party.md"
printf 'untracked addition\n' > "$t2/.agents/skills/retired-skill/notes.txt"
printf '\nupstream skill update\n' >> "$catalog/skills/add-web-feature/SKILL.md"
printf '\nupstream conflicting update\n' >> "$catalog/skills/add-module/SKILL.md"
printf '\nupstream docs update\n' >> "$catalog/docs/usage.md"
printf '\nupstream architecture update\n' >> "$catalog/docs/architecture.md"
printf '\nupstream literal-key update\n' >> "$catalog/docs/lookup [one].md"
printf '\nupstream neighbor update\n' >> "$catalog/docs/lookup o.md"
printf 'new upstream doc\n' > "$catalog/docs/new.md"
rm "$catalog/docs/retired.md" "$catalog/docs/edited-retired.md" "$catalog/skills/retired-skill/SKILL.md"
rmdir "$catalog/skills/retired-skill"
install_to update --target "$t2" --source "$catalog" --hooks
assert_grep "$t2/.agents/skills/add-web-feature/SKILL.md" "upstream skill update"
assert_grep "$t2/docs/usage.md" "upstream docs update"
assert_file "$t2/docs/new.md"
assert_grep "$t2/.agents/skills/add-module/SKILL.md" "local skill edit"
assert_not_grep "$t2/.agents/skills/add-module/SKILL.md" "upstream conflicting update"
assert_grep "$t2/docs/architecture.md" "local architecture edit"
assert_not_grep "$t2/docs/architecture.md" "upstream architecture update"
assert_grep "$t2/docs/lookup [one].md" "local literal-key edit"
assert_not_grep "$t2/docs/lookup [one].md" "upstream literal-key update"
assert_grep "$t2/docs/lookup o.md" "upstream neighbor update"
assert_grep "$t2/.cursor/rules/web-routes.mdc" "local rule edit"
assert_grep "$t2/.claude/rules/web-routes.md" "local neutral rule edit"
assert_grep "$t2/.github/instructions/web-routes.instructions.md" "local neutral rule edit"
assert_grep "$work/update.log" "locally modified"
assert_eq "$(saved_fingerprint "$t2" ".agents/skills/add-module/SKILL.md")" "$baseline" "original fingerprint retained for edited skill"
if [ -x "$t2/.agents/hooks/scripts/format-gate" ]; then actual_mode="x"; else actual_mode="-"; fi
assert_eq "$actual_mode" "$edited_mode" "local executable status preserved"
assert_grep "$t2/.agents/hooks/scripts/format-gate" "local hook edit"
assert_missing "$t2/docs/retired.md"
assert_file "$t2/docs/edited-retired.md"
assert_missing "$t2/.agents/skills/retired-skill/SKILL.md"
assert_file "$t2/.agents/skills/retired-skill/notes.txt"
assert_missing "$t2/.claude/skills/retired-skill"
assert_unowned "$t2" "docs/third-party.md"
assert_unowned "$t2" ".agents/skills/third-party/SKILL.md"
install_to hard --target "$t2" --source "$catalog" --hooks --hard
assert_grep "$t2/.agents/skills/add-module/SKILL.md" "upstream conflicting update"
assert_not_grep "$t2/.agents/skills/add-module/SKILL.md" "local skill edit"
assert_grep "$t2/docs/architecture.md" "upstream architecture update"
assert_grep "$t2/docs/lookup [one].md" "upstream literal-key update"
assert_not_grep "$t2/docs/lookup [one].md" "local literal-key edit"
assert_not_grep "$t2/.cursor/rules/web-routes.mdc" "local rule edit"
assert_not_grep "$t2/.claude/rules/web-routes.md" "local neutral rule edit"
assert_exec "$t2/.agents/hooks/scripts/format-gate"
assert_not_grep "$t2/.agents/hooks/scripts/format-gate" "local hook edit"
assert_missing "$t2/docs/edited-retired.md"
for where in .agents .github .cursor .claude; do assert_eq "$(cat "$t2/$where/skills/third-party/SKILL.md")" "foreign skill" "foreign $where skill preserved by --hard"; done
assert_eq "$(cat "$t2/docs/third-party.md")" "foreign docs" "foreign docs preserved"
assert_eq "$(cat "$t2/.agents/catalogs/another-catalog/.install-manifest")" "# another catalog" "other manifest preserved"
assert_file "$t2/.agents/skills/retired-skill/notes.txt"
assert_links_resolve "$t2"

section "uninstall preserves edits and other catalogs; --force finishes only owned removal"
printf '\nkeep modified doc\n' >> "$t2/docs/architecture.md"
install_to safe-uninstall --target "$t2" --uninstall
assert_grep "$t2/docs/architecture.md" "keep modified doc"
assert_file "$t2/$state"
assert_file "$t2/docs/third-party.md"
assert_missing "$t2/.agents/skills/add-module"
install_to forced-uninstall --target "$t2" --uninstall --force
assert_missing "$t2/docs/architecture.md"
assert_missing "$t2/$state"
assert_file "$t2/.agents/skills/retired-skill/notes.txt"
assert_file "$t2/.agents/catalogs/another-catalog/.install-manifest"
for where in .agents .github .cursor .claude; do assert_file "$t2/$where/skills/third-party/SKILL.md"; done
assert_file "$t2/docs/third-party.md"

section "unmanaged same-name skills, docs, roots, adapters, and hooks are never adopted"
t3="$work/collisions"; mkdir -p "$t3"; git -C "$t3" init -q
mkdir -p "$t3/.agents/skills/add-module" "$t3/.claude/skills/add-web-feature" "$t3/.claude" "$t3/.github/instructions" "$t3/docs"
printf 'foreign canonical skill\n' > "$t3/.agents/skills/add-module/SKILL.md"
printf 'foreign Claude skill\n' > "$t3/.claude/skills/add-web-feature/SKILL.md"
printf 'foreign docs\n' > "$t3/docs/architecture.md"
printf 'foreign root\n' > "$t3/AGENTS.md"
printf 'foreign Claude root\n' > "$t3/CLAUDE.md"
printf '{}\n' > "$t3/.claude/settings.json"
printf 'foreign rule\n' > "$t3/.github/instructions/web-routes.instructions.md"
printf '#!/bin/sh\nexit 0\n' > "$t3/.git/hooks/pre-commit"
snapshot "$t3/.agents/skills/add-module" > "$work/foreign-skill-before"
install_to collisions --target "$t3" --force --hooks --git-hooks
assert_eq "$(cat "$t3/docs/architecture.md")" "foreign docs" "unmanaged docs preserved by --force"
assert_eq "$(cat "$t3/AGENTS.md")" "foreign root" "unmanaged AGENTS.md preserved by --force"
assert_eq "$(cat "$t3/CLAUDE.md")" "foreign Claude root" "unmanaged CLAUDE.md preserved by --force"
assert_eq "$(cat "$t3/.claude/settings.json")" "{}" "unmanaged hook config preserved"
assert_eq "$(cat "$t3/.github/instructions/web-routes.instructions.md")" "foreign rule" "unmanaged adapter preserved"
snapshot "$t3/.agents/skills/add-module" > "$work/foreign-skill-after"
assert_same "$work/foreign-skill-before" "$work/foreign-skill-after"
assert_eq "$(cat "$t3/.claude/skills/add-web-feature/SKILL.md")" "foreign Claude skill" "unmanaged Claude skill preserved"
assert_missing "$t3/.claude/skills/add-web-feature/references"
assert_missing "$t3/.claude/skills/add-module"
assert_unowned "$t3" "AGENTS.md"
assert_unowned "$t3" "docs/architecture.md"
assert_unowned "$t3" ".claude/settings.json"
assert_unowned "$t3" ".agents/skills/add-module/SKILL.md"
assert_grep "$work/collisions.log" "unmanaged"
install_to collisions-uninstall --target "$t3" --uninstall --force
assert_file "$t3/.agents/skills/add-module/SKILL.md"
assert_file "$t3/.claude/skills/add-web-feature/SKILL.md"
assert_file "$t3/.git/hooks/pre-commit"
assert_file "$t3/docs/architecture.md"

section "automatic copy fallback, including ln implementations that emulate symlinks"
mkdir -p "$work/no-links" "$work/emulated-links"
cat > "$work/no-links/ln" <<'SH'
#!/usr/bin/env bash
printf 'symlinks disabled for test\n' >&2
exit 1
SH
cat > "$work/emulated-links/ln" <<'SH'
#!/usr/bin/env bash
cp "$(dirname "$3")/$2" "$3"
SH
chmod +x "$work/no-links/ln" "$work/emulated-links/ln"
printf 'obsolete resource\n' > "$catalog/skills/add-module/obsolete-resource.txt"
t4="$work/fallback"; mkdir -p "$t4"
if PATH="$work/no-links:$PATH" "$installer" --target "$t4" --source "$catalog" --harness claude > "$work/fallback.log" 2>&1; then ok "copy fallback exited zero"; else cat "$work/fallback.log" >&2; ko "copy fallback failed"; fi
assert_grep "$work/fallback.log" "Symlinks are unavailable"
assert_regular "$t4/.claude/skills/add-module/SKILL.md"
assert_same "$t4/.agents/skills/add-module/SKILL.md" "$t4/.claude/skills/add-module/SKILL.md"
assert_eq "$(find "$t4/.claude/skills" -type l | wc -l | tr -d ' ')" "0" "fallback has no symlinks"
assert_missing "$t4/.github"
assert_missing "$t4/.cursor"
assert_file "$t4/.claude/skills/add-module/obsolete-resource.txt"
rm "$catalog/skills/add-module/obsolete-resource.txt"
printf '\nlocal shared edit\n' >> "$t4/.agents/skills/add-module/SKILL.md"
if PATH="$work/no-links:$PATH" "$installer" --target "$t4" --source "$catalog" --harness claude > "$work/fallback-update.log" 2>&1; then ok "fallback update exited zero"; else cat "$work/fallback-update.log" >&2; ko "fallback update failed"; fi
assert_same "$t4/.agents/skills/add-module/SKILL.md" "$t4/.claude/skills/add-module/SKILL.md"
assert_missing "$t4/.agents/skills/add-module/obsolete-resource.txt"
assert_missing "$t4/.claude/skills/add-module/obsolete-resource.txt"
mv "$t4/.agents/skills/add-module" "$work/missing-shared-skill"
snapshot "$t4" > "$work/fallback-dry-before"
install_to fallback-dry --target "$t4" --source "$catalog" --harness claude --dry-run
assert_not_grep "$work/fallback-dry.log" "could not enumerate"
snapshot "$t4" > "$work/fallback-dry-after"
assert_same "$work/fallback-dry-before" "$work/fallback-dry-after"
mv "$work/missing-shared-skill" "$t4/.agents/skills/add-module"
printf '\nlocal fallback-only edit\n' >> "$t4/.claude/skills/add-module/SKILL.md"
install_to fallback-preserved --target "$t4" --source "$catalog" --harness claude
assert_grep "$t4/.claude/skills/add-module/SKILL.md" "local fallback-only edit"
install_to fallback-force --target "$t4" --source "$catalog" --harness claude --force
assert_not_grep "$t4/.claude/skills/add-module/SKILL.md" "local fallback-only edit"
if [ "$links_available" = 1 ]; then assert_eq "$(readlink "$t4/.claude/skills/add-module")" "../../.agents/skills/add-module" "owned copies converted to symlinks"; fi
assert_links_resolve "$t4"
t5="$work/emulation"; mkdir -p "$t5"
if PATH="$work/emulated-links:$PATH" "$installer" --target "$t5" --source "$catalog" --harness claude > "$work/emulation.log" 2>&1; then ok "emulated symlink fallback exited zero"; else cat "$work/emulation.log" >&2; ko "emulated symlink fallback failed"; fi
assert_grep "$work/emulation.log" "ln did not create a real symbolic link"
assert_regular "$t5/.claude/skills/add-module/SKILL.md"
printf 'foreign addition inside a copied skill\n' > "$t5/.claude/skills/add-module/foreign-note.txt"
install_to fallback-untracked --target "$t5" --harness claude --force
assert_regular "$t5/.claude/skills/add-module/SKILL.md"
assert_eq "$(cat "$t5/.claude/skills/add-module/foreign-note.txt")" "foreign addition inside a copied skill" "untracked copy addition survives force"
install_to fallback-untracked-uninstall --target "$t5" --uninstall --force
assert_missing "$t5/.claude/skills/add-module/SKILL.md"
assert_file "$t5/.claude/skills/add-module/foreign-note.txt"
assert_missing "$t5/$state"

if [ "$links_available" = 1 ]; then
  if PATH="$work/no-links:$PATH" "$installer" --target "$t4" --source "$catalog" --harness claude > "$work/links-to-copies.log" 2>&1; then ok "existing links fall back to owned copies"; else cat "$work/links-to-copies.log" >&2; ko "link-to-copy fallback failed"; fi
  assert_regular "$t4/.claude/skills/add-module/SKILL.md"
  assert_same "$t4/.agents/skills/add-module/SKILL.md" "$t4/.claude/skills/add-module/SKILL.md"
  install_to copies-to-links --target "$t4" --source "$catalog" --harness claude
  assert_eq "$(readlink "$t4/.claude/skills/add-module")" "../../.agents/skills/add-module" "copies return to symlinks when available"
fi

section "scoped packs, --no-root, and safely removing obsolete adapters"
t6="$work/subset"; mkdir -p "$t6"
install_to subset --target "$t6" --source "$repo" --harness claude --packs api
assert_eq "$(find "$t6/.claude/rules" -type f | wc -l | tr -d ' ')" "20" "API role adapter count"
assert_missing "$t6/.claude/rules/web-routes.md"
assert_missing "$t6/.github"
assert_missing "$t6/.cursor"
assert_file "$t6/.agents/rules/web/routes.md"
printf '\nlocal contract edit\n' >> "$t6/AGENTS.md"
install_to no-root --target "$t6" --source "$repo" --harness codex --packs reviewer --no-root --force
assert_grep "$t6/AGENTS.md" "local contract edit"
assert_missing "$t6/.claude/rules"
assert_missing "$t6/.claude/skills"
assert_file "$t6/CLAUDE.md"
assert_links_resolve "$t6"

section "legacy copy-based installations require an explicit owned migration"
t7="$work/legacy"; mkdir -p "$t7/harness/docs" "$t7/harness/skills/add-module" "$t7/docs"
printf 'old docs\n' > "$t7/harness/docs/architecture.md"
printf 'old skill\n' > "$t7/harness/skills/add-module/SKILL.md"
printf 'old contract\n' > "$t7/AGENTS.md"
printf 'foreign vendor file\n' > "$t7/harness/foreign.txt"
printf 'foreign project docs\n' > "$t7/docs/foreign.md"
{
  printf '# agent-harness install manifest - generated by install.sh\n'
  printf 'AGENTS.md\nharness/docs/architecture.md\nharness/skills/add-module/SKILL.md\n'
  for where in .agents .claude .github .cursor; do
    mkdir -p "$t7/$where/skills/add-module"
    printf 'old copied skill\n' > "$t7/$where/skills/add-module/SKILL.md"
    printf '%s/skills/add-module/SKILL.md\n' "$where"
  done
} > "$t7/harness/.install-manifest"
convert_crlf "$t7/harness/.install-manifest"
snapshot "$t7" > "$work/legacy-before"
if "$installer" --target "$t7" --source "$catalog" > "$work/legacy-refused.log" 2>&1; then ko "legacy migration without force accepted"; else assert_grep "$work/legacy-refused.log" "legacy installation has no fingerprints"; fi
snapshot "$t7" > "$work/legacy-after"
assert_same "$work/legacy-before" "$work/legacy-after"
install_to legacy --target "$t7" --force
assert_missing "$t7/harness/.install-manifest"
assert_missing "$t7/harness/docs"
assert_missing "$t7/harness/skills"
assert_file "$t7/harness/foreign.txt"
assert_file "$t7/docs/foreign.md"
assert_file "$t7/docs/architecture.md"
assert_file "$t7/$state"
assert_missing "$t7/.github/skills"
assert_missing "$t7/.cursor/skills"
assert_grep "$t7/.agents/skills/add-module/SKILL.md" "^name: add-module$"
assert_links_resolve "$t7"
t8="$work/custom-legacy"; mkdir -p "$t8/.old-harness/docs"
printf 'old\n' > "$t8/.old-harness/docs/architecture.md"
printf '# agent-harness install manifest\n.old-harness/docs/architecture.md\n' > "$t8/.old-harness/.install-manifest"
install_to custom-legacy --target "$t8" --dir .old-harness --hard --harness codex
assert_missing "$t8/.old-harness"
assert_file "$t8/docs/architecture.md"
assert_links_resolve "$t8"

section "force never deletes a directory substituted for an owned file"
rm "$t8/docs/usage.md"
mkdir "$t8/docs/usage.md"
printf 'foreign data\n' > "$t8/docs/usage.md/data"
install_to directory-collision --target "$t8" --harness codex --force
assert_eq "$(cat "$t8/docs/usage.md/data")" "foreign data" "directory content preserved"
assert_grep "$work/directory-collision.log" "directory or special file"

section "failed installation retains ownership for a safe retry"
t9="$work/interrupted"; mkdir -p "$t9" "$work/failing-mv"
real_mv="$(command -v mv)"
cat > "$work/failing-mv/mv" <<SH
#!/usr/bin/env bash
last=""
for arg in "\$@"; do last="\$arg"; done
case "\$last" in */docs/usage.md) printf 'simulated write failure\n' >&2; exit 7 ;; esac
exec "$real_mv" "\$@"
SH
chmod +x "$work/failing-mv/mv"
if PATH="$work/failing-mv:$PATH" "$installer" --target "$t9" --source "$catalog" --harness codex > "$work/interrupted.log" 2>&1; then ko "simulated write failure was ignored"; else assert_grep "$work/interrupted.log" "simulated write failure"; fi
assert_file "$t9/docs/architecture.md"
assert_file "$t9/$state"
install_to retry --target "$t9" --harness codex
assert_not_grep "$work/retry.log" "is unmanaged"
assert_links_resolve "$t9"

section "CRLF source frontmatter and cloned ownership manifests are supported"
crlf_catalog="$work/crlf-catalog"
cp -R "$catalog" "$crlf_catalog"
while IFS= read -r file; do convert_crlf "$file"; done < <(find "$crlf_catalog" -name '*.md' -type f -print)
t13="$work/crlf"; mkdir -p "$t13"
install_to crlf --target "$t13" --source "$crlf_catalog" --harness claude,copilot
assert_grep "$t13/.claude/rules/csharp-async.md" "  - 'apps/api/\*\*/\*.cs'"
assert_grep "$t13/.github/instructions/web-routes.instructions.md" "^applyTo: 'apps/web/src/routes/\*\*/\*.ts, apps/web/src/routes/\*\*/\*.tsx'$"
convert_crlf "$t13/$state"
install_to crlf-reinstall --target "$t13" --source "$crlf_catalog" --harness claude,copilot
assert_not_grep "$work/crlf-reinstall.log" "locally modified"
assert_links_resolve "$t13"

section "failed source enumeration cannot delete obsolete-looking owned files"
mkdir -p "$work/failing-find"
real_find="$(command -v find)"
cat > "$work/failing-find/find" <<SH
#!/usr/bin/env bash
if [ "\$1" = rules ]; then printf 'simulated enumeration failure\n' >&2; exit 5; fi
exec "$real_find" "\$@"
SH
chmod +x "$work/failing-find/find"
snapshot "$t9/.agents/rules" > "$work/rules-before"
if PATH="$work/failing-find:$PATH" "$installer" --target "$t9" --source "$catalog" --harness codex > "$work/enumeration.log" 2>&1; then ko "enumeration failure was ignored"; else assert_grep "$work/enumeration.log" "could not enumerate"; fi
snapshot "$t9/.agents/rules" > "$work/rules-after"
assert_same "$work/rules-before" "$work/rules-after"
install_to enumeration-retry --target "$t9" --harness codex
assert_links_resolve "$t9"

section "dry runs never change fresh or populated targets"
t10="$work/dry"; mkdir -p "$t10"
install_to dry --target "$t10" --dry-run --hooks
assert_eq "$(find "$t10" -mindepth 1 | wc -l | tr -d ' ')" "0" "paths written by fresh dry run"
assert_grep "$work/dry.log" "  + .claude/skills/add-module ->"
assert_grep "$work/dry.log" "$state"
snapshot "$t7" > "$work/dry-before"
install_to dry-update --target "$t7" --dry-run --force
install_to dry-uninstall --target "$t7" --dry-run --uninstall --hard
snapshot "$t7" > "$work/dry-after"
assert_same "$work/dry-before" "$work/dry-after"

section "argument and ownership manifest validation"
if "$installer" --target "$t10" --dir a/b > "$work/v1.log" 2>&1; then ko "--dir a/b accepted"; else assert_grep "$work/v1.log" "single folder name"; fi
if "$installer" --target "$t10" --harness nope > "$work/v2.log" 2>&1; then ko "unknown harness accepted"; else assert_grep "$work/v2.log" "unknown harness 'nope'"; fi
if "$installer" --target "$t10" --packs nope > "$work/v3.log" 2>&1; then ko "unknown pack accepted"; else assert_grep "$work/v3.log" "unknown rule pack 'nope'"; fi
if "$installer" --target "$t10" --harness "" > "$work/v4.log" 2>&1; then ko "empty harness list accepted"; else assert_grep "$work/v4.log" "select at least one harness"; fi
if "$installer" --target "$t10" --packs "" > "$work/v5.log" 2>&1; then ko "empty pack list accepted"; else assert_grep "$work/v5.log" "select at least one rule pack"; fi
if "$installer" --target "$repo" --dry-run > "$work/v6.log" 2>&1; then ko "self-install accepted"; else assert_grep "$work/v6.log" "refusing to install the catalog into itself"; fi
if "$installer" --target "$t10" --uninstall > "$work/v7.log" 2>&1; then ko "uninstall without manifest accepted"; else assert_grep "$work/v7.log" "no manifest"; fi
printf 'docs/../../outside\tF:1:1:-\n' >> "$t7/$state"
if "$installer" --target "$t7" --hard --uninstall > "$work/v8.log" 2>&1; then ko "unsafe manifest accepted"; else assert_grep "$work/v8.log" "unsafe manifest path"; fi
mkdir -p "$t10/$(dirname "$state")"
printf '# catalog: another-catalog\n# format: 2\n' > "$t10/$state"
if "$installer" --target "$t10" --force > "$work/v9.log" 2>&1; then ko "foreign catalog manifest accepted"; else assert_grep "$work/v9.log" "manifest belongs to another catalog"; fi
assert_missing "$t10/docs"

section "symlink parents and modified alias links never redirect writes or deletion"
if [ "$links_available" = 1 ]; then
  t11="$work/parent-links"; outside="$work/outside"
  mkdir -p "$t11/.agents" "$outside"
  printf 'outside sentinel\n' > "$outside/architecture.md"
  ln -s "$outside" "$t11/docs"
  ln -s "$outside" "$t11/.agents/skills"
  install_to parent-links --target "$t11" --force
  assert_eq "$(cat "$outside/architecture.md")" "outside sentinel" "symlink parent target preserved"
  assert_missing "$outside/add-module"
  assert_missing "$t11/.claude/skills/add-module"
  assert_grep "$work/parent-links.log" "symlinked parent"
  rm "$t4/.claude/skills/add-module"
  ln -s "$outside" "$t4/.claude/skills/add-module"
  install_to changed-alias --target "$t4" --harness claude
  assert_eq "$(readlink "$t4/.claude/skills/add-module")" "$outside" "modified alias preserved"
  install_to changed-alias-force --target "$t4" --harness claude --force
  assert_eq "$(readlink "$t4/.claude/skills/add-module")" "../../.agents/skills/add-module" "force replaces owned alias only"
  assert_eq "$(cat "$outside/architecture.md")" "outside sentinel" "alias target never deleted"
fi

section "piped mode fetches the source instead of reusing the working directory"
t12="$work/piped"; mkdir -p "$t12"
if (cd "$repo" && HARNESS_REPO="$repo" bash -s -- --target "$t12" --harness codex < "$installer") > "$work/piped.log" 2>&1; then ok "piped install exited zero"; else cat "$work/piped.log" >&2; ko "piped install failed"; fi
assert_grep "$work/piped.log" "Fetching catalog from"
assert_file "$t12/.agents/skills/add-vertical-slice/SKILL.md"
assert_file "$t12/docs/architecture.md"
assert_file "$t12/AGENTS.md"
assert_missing "$t12/CLAUDE.md"
assert_missing "$t12/.github"
assert_missing "$t12/.cursor"
assert_links_resolve "$t12"

# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed (%ss)\n' "$pass" "$fail" "$SECONDS"
[ "$fail" = 0 ]
