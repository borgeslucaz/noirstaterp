# Contributing to ShadowForge DevTools

Thanks for thinking about contributing. This is a community-driven dev tool for FiveM script authors, so good ideas and clean code from anyone are welcome.

## Ways to contribute

- **Report bugs** — open a [bug report issue](https://github.com/TonyHinojosa4/Shadowforge-devtools/issues/new?template=bug_report.yml).
- **Suggest features** — open a [feature request](https://github.com/TonyHinojosa4/Shadowforge-devtools/issues/new?template=feature_request.yml), or float the idea in [Discussions](https://github.com/TonyHinojosa4/Shadowforge-devtools/discussions) first if you're not sure.
- **Improve docs** — typos, clarifications, better examples. PRs against anything in `docs/` are very welcome.
- **Send code** — see below.

## Code contributions

### Before you start coding

For anything bigger than a small fix, open an issue or Discussion first. Saves you the heartbreak of writing 400 lines and finding out it conflicts with planned work or doesn't fit the project direction.

### Local setup

1. Fork the repo and clone your fork.
2. Drop the folder into your server's `resources/` directory (or symlink it — easier for iterating).
3. Add `ensure shadowforge-devtools` to your `server.cfg`.
4. Start the server and use `/devtools` in-game.

### Branch & commit style

- Branch off `main`. Name branches descriptively: `fix/coords-copy-clipboard`, `feat/zone-builder-grid-snap`.
- Commit messages: short imperative subject line, one logical change per commit where reasonable.
  - Good: `Fix coord copy on empty selection`
  - Less good: `bug fix`
- [Conventional Commits](https://www.conventionalcommits.org/) prefixes (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`) are appreciated but not required.

### Code style

- Lua: 4-space indentation (the `.editorconfig` enforces this), `snake_case` for locals and module functions, `PascalCase` for exported tables.
- Prefer `local` for everything that doesn't need to be global.
- No `print` debug spam in committed code — use the project's logger module.
- Keep modules focused. If a file is doing two unrelated things, it's two modules.
- Run `luacheck` before pushing. CI will run it anyway, but catch it locally first.

### Testing

This project doesn't have automated tests (in-game tools are awkward to unit test). At minimum:

- Test against **at least one framework** you have set up.
- Note which framework(s) you tested in your PR description.
- For UI changes, drop a screenshot or short clip in the PR.

### Pull request flow

1. Push your branch to your fork.
2. Open a PR against `main`. Fill out the PR template fully — it exists to save review cycles.
3. Update `CHANGELOG.md` under the `[Unreleased]` section.
4. CI (lint) needs to pass before merge.
5. I'll review, possibly ask for changes. Don't take review comments personally — they make the project better.

## Reporting security issues

Don't open a public issue for security vulnerabilities. See [SECURITY.md](SECURITY.md) for the private disclosure process.

## Code of conduct

Be decent. Disagreements about technical decisions are fine; personal attacks aren't. If something feels off, message me directly.

## License

By contributing, you agree your contributions will be licensed under the MIT License that covers this project.
