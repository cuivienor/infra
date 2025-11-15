#!/bin/bash
# lint.sh - Run all linters for homelab-notes repository
#
# Usage:
#   ./scripts/lint.sh           # Run all checks
#   ./scripts/lint.sh --fix     # Auto-fix what's possible

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FIX_MODE=false
if [[ "${1:-}" == "--fix" ]]; then
    FIX_MODE=true
fi

FAILED=0

echo "=== Terraform Format ==="
if $FIX_MODE; then
    terraform fmt -recursive terraform/
    echo -e "${GREEN}✓${NC} Terraform files formatted"
else
    if terraform fmt -check -recursive terraform/ 2>&1; then
        echo -e "${GREEN}✓${NC} Terraform formatting OK"
    else
        echo -e "${RED}✗${NC} Terraform formatting issues (run with --fix)"
        FAILED=1
    fi
fi
echo ""

echo "=== ShellCheck ==="
if shellcheck scripts/**/*.sh 2>&1; then
    echo -e "${GREEN}✓${NC} ShellCheck passed"
else
    echo -e "${YELLOW}!${NC} ShellCheck found issues (see above)"
    FAILED=1
fi
echo ""

echo "=== YAML Lint ==="
if yamllint -c .yamllint.yaml ansible/ 2>&1; then
    echo -e "${GREEN}✓${NC} YAML lint passed"
else
    echo -e "${YELLOW}!${NC} YAML lint found issues (see above)"
    FAILED=1
fi
echo ""

echo "=== Ansible Lint ==="
cd ansible
LINT_OUTPUT=$(ansible-lint playbooks/ --nocolor 2>&1)
LINT_ERRORS=$(echo "$LINT_OUTPUT" | grep -E '^\w+\[' | wc -l)
if [[ $LINT_ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} Ansible lint passed (0 violations)"
else
    echo "$LINT_OUTPUT" | head -50
    echo -e "${RED}✗${NC} Ansible lint found $LINT_ERRORS violations"
    FAILED=1
fi
cd "$REPO_ROOT"
echo ""

echo "=== Ansible Syntax Check ==="
cd ansible
SYNTAX_OK=true
for playbook in playbooks/*.yml; do
    if ! ansible-playbook "$playbook" --syntax-check >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} Syntax error in $playbook"
        SYNTAX_OK=false
        FAILED=1
    fi
done
if $SYNTAX_OK; then
    echo -e "${GREEN}✓${NC} All playbooks have valid syntax"
fi
cd "$REPO_ROOT"
echo ""

echo "=== Summary ==="
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}All critical checks passed!${NC}"
else
    echo -e "${RED}Some checks failed${NC}"
    exit 1
fi
