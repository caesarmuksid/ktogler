## Summary

What this change does and why.

## Test plan

- [ ] `make check-version`
- [ ] `make build` and the `.kwinscript` contains `metadata.json` at the zip root
- [ ] `npx --yes eslint contents/code/main.js`
- [ ] `npx --yes prettier --check .`
- [ ] `shellcheck ktogler.sh install.sh build.sh scripts/bump-version.sh`

## Related issues

Fixes #... / Closes #...
