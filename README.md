# go-backend-pipelines

Shared CI/CD and container setup for the `go-backend-*` family: reusable GitHub Actions workflows, an includable GitLab CI template, a production Dockerfile, a Makefile include and the standard `deploy.sh`.

## Add it to a service

```sh
curl -fsSL https://raw.githubusercontent.com/ahmedbaig/go-backend-pipelines/main/scripts/install.sh | bash -s -- .
```

This writes `Dockerfile`, `make/go.mk`, `deploy.sh`, `.gitlab-ci.yml` and `.github/workflows/ci.yml` (existing files are skipped unless `FORCE=1`). Pin a version with `PIPELINES_REF=v1.0.0`. Then in the service `Makefile`:

```make
APP := my-service
CMD := ./cmd/server
include make/go.mk
```

## GitHub Actions

Reusable workflows, called with `uses:`:

```yaml
jobs:
  test:
    uses: ahmedbaig/go-backend-pipelines/.github/workflows/go-ci.yml@v1
    with:
      coverage-min: 70
  docker:
    needs: test
    if: github.event_name == 'push'
    uses: ahmedbaig/go-backend-pipelines/.github/workflows/docker.yml@v1
    permissions: { contents: read, packages: write }
  release:
    if: startsWith(github.ref, 'refs/tags/v')
    uses: ahmedbaig/go-backend-pipelines/.github/workflows/release.yml@v1
    permissions: { contents: write }
```

| Workflow | Does | Inputs |
|---|---|---|
| `go-ci.yml` | gofmt check, `go vet`, staticcheck, `go test -race` with coverage (shown in the job summary), govulncheck | `go-version-file`, `working-directory`, `race`, `lint`, `vulncheck`, `coverage-min` |
| `docker.yml` | multi-arch buildx build, push to GHCR | `image` (default `ghcr.io/<owner>/<repo>`), `dockerfile`, `context`, `platforms`, `push` |
| `release.yml` | GitHub release with generated notes for a `v*` tag | |

Image tags: branch pushes get `<branch>-<VERSION file>` and `sha-<8 chars>`; a `v1.2.3` git tag gets `v1.2.3` and `latest`.

## GitLab CI

```yaml
include:
  - remote: 'https://raw.githubusercontent.com/ahmedbaig/go-backend-pipelines/v1/gitlab/go.gitlab-ci.yml'
variables:
  COVERAGE_MIN: "70"
```

Or mirror this repo into GitLab and use `include: - project: '<group>/go-backend-pipelines', ref: v1, file: gitlab/go.gitlab-ci.yml`.

| Job | Stage | When |
|---|---|---|
| `go:lint` | lint | MRs, branches, tags |
| `go:test` | test | MRs, branches, tags. Coverage shows on MRs (Cobertura report) |
| `go:vulncheck` | test | default branch and tags, allowed to fail |
| `docker:branch` | build | branches, pushes `$CI_REGISTRY_IMAGE:<branch-slug>-<VERSION>` and `:sha-<short>` |
| `docker:release` | release | `v1.2.3` tags, pushes `:v1.2.3` and `:latest` |

Variables: `GO_IMAGE`, `DOCKERFILE`, `DOCKER_IMAGE_NAME`, `COVERAGE_MIN`, `DOCKER_DISABLED=true` for libraries. Docker jobs need a runner with Docker-in-Docker (privileged) and the project's container registry enabled.

## Dockerfile

`docker/Dockerfile.go`: Go build stage with module and build caches, then Alpine with `tini` as PID 1, non-root `app` user, `CONFIG_DIR=/app/var/secrets`, `TZ` (default `Australia/Sydney`) and a `HEALTHCHECK` on `/healthz`. Build args `CMD` (default `./cmd/server`), `VERSION` (injected as `main.version`), `GO_VERSION`, `TZ`.

## Makefile targets

`make help` lists them: `fmt`, `vet`, `lint`, `test` (race, empty `CONFIG_DIR`), `cover`, `vuln`, `check` (what CI runs), `tidy`, `build`, `run` (`CONFIG_DIR=./var`), `docker`, `docker-run`, `clean`.

## deploy.sh

Builds and pushes an image by hand, for testing a branch on a server before CI does it.

```sh
./deploy.sh                       # prompts for anything not given, shows defaults
./deploy.sh -y --no-push          # local build only
./deploy.sh -r ghcr.io -i ahmedbaig/my-service -g linux/amd64,linux/arm64 -y
./deploy.sh --forget -r ghcr.io   # drop saved credentials
```

Default tag is `<branch>-<VERSION>`. `v1.2.3` tags are refused because CI builds those from git tags, and `:latest` only goes out with `--latest`. Credentials are saved after a successful login to `~/.config/go-backend-deploy/credentials` (mode 600, one line per registry).

## License

MIT
