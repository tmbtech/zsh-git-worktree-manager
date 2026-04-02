# Repository Guidelines

## Project Structure & Module Organization
`git-worktree-manager.plugin.zsh` is the plugin entrypoint: it adds `completions/` to `fpath`, sources every file in `functions/`, and defines the `wtp` alias. Put user-facing Zsh commands in `functions/` using the existing `worktree` dispatcher and `_wt_*` helper pattern (for example, `functions/_wt_clean`). Keep tab completion logic in `completions/_git_worktree_manager`. The interactive TUI lives in `tui/`, with the CLI entry at `tui/cmd/worktree-tui/main.go`, domain code under `tui/internal/`, and Go tests beside the code as `*_test.go`. Use `scripts/build-tui.sh` to produce `bin/worktree-tui-*` binaries.

## Build, Test, and Development Commands
Install and link the plugin locally with `./install.sh`, or symlink the repo into `~/.oh-my-zsh/custom/plugins/git-worktree-manager` and reload with `source ~/.zshrc`. Build the TUI from the repo root with `./scripts/build-tui.sh`; it cross-compiles and refreshes `bin/worktree-tui`. For Go-only iteration, run `cd tui && go build -o ../bin/worktree-tui ./cmd/worktree-tui`. Run tests with `cd tui && go test ./...`. After shell changes, verify manually by reloading Zsh and exercising commands such as `worktree setup --help` or `worktree clean --dry-run`.

## Coding Style & Naming Conventions
Match the existing shell style: 2-space indentation, `local` for function variables, quoted expansions, and explicit error paths. Name internal Zsh helpers with the `_wt_*` prefix; keep help text and flag parsing in the same file as the command. In Go, rely on `gofmt` formatting and idiomatic package layout under `tui/internal/{data,model,style}`. Test files should mirror the package name and use descriptive `TestXxx` cases.

## Testing Guidelines
Go tests are the only automated test suite currently in-tree. Add or update `*_test.go` files next to the affected Go package and run `go test ./...` before opening a PR. Shell behavior is validated manually; cover new flags, help output, and destructive flows with at least one reproducible command sequence in the PR description.

## Commit & Pull Request Guidelines
Use Conventional Commits, consistent with recent history: `feat(clean): ...`, `fix(clean): ...`, `docs: ...`. Keep scopes tied to the changed area (`worktree`, `clean`, `tui`, `docs`). PRs should include a short summary, a flat list of changes, and a testing section. Update `README.md` for command or UX changes, and update `CHANGELOG.md` for user-facing changes.
