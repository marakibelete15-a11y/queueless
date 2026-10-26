# QueueLess Git & Team Workflow

This document outlines the version control policies, branching strategies, commit message standards, and code review rules for the QueueLess repository.

---

## 1. Branch Strategy

We maintain a strict GitFlow-inspired branching strategy:

### Primary Branches

- **`main`**: Represents production-ready releases.
  - **Direct pushes are strictly prohibited.**
  - All changes must arrive via approved pull requests from `develop` or emergency `hotfix/*` branches.
  - Every commit on `main` is tagged with a semantic release version (`v1.0.0`).
- **`develop`**: The primary integration branch.
  - Contains code that has passed code review and CI checks.
  - Nightly builds or staging deployments track this branch.

### Supporting Branches

- **`feature/<short-description>`**: Created from `develop`.
  - Used for developing new features, endpoints, or UI screens.
  - Example: `feature/queue-eta-calculation`, `feature/walkin-registration-ui`.
  - Merged back into `develop` via pull request.
- **`fix/<short-description>`**: Created from `develop` for non-emergency bug fixes.
  - Example: `fix/timezone-display-offset`.
- **`hotfix/<short-description>`**: Created directly from `main` for critical production regressions.
  - Must be merged into both `main` and `develop`.

---

## 2. Commit Message Convention (Conventional Commits)

All commit messages must adhere to the [Conventional Commits v1.0.0](https://www.conventionalcommits.org/) specification.

### Commit Format

```text
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

### Allowed Types

- **`feat`**: Introduces a new feature or capability.
- **`fix`**: Resolves a bug or defect.
- **`docs`**: Documentation changes only.
- **`style`**: Formatting, white-space, missing semi-colons (no code logic changes).
- **`refactor`**: Code restructuring without altering external behavior.
- **`perf`**: Performance optimization.
- **`test`**: Adding missing tests or correcting existing tests.
- **`chore`**: Maintenance tasks, dependencies, build configurations.

### Examples

- `feat(queue): implement dynamic doctor consultation ETA calculation`
- `fix(booking): prevent duplicate booking hold when clicking submit twice`
- `docs(api): document rate limiting headers for /api/v1/public/bookings`
- `test(health): add integration test verifying /api/v1/health returns UTC and Africa/Addis_Ababa`
- `chore: initialize project structure`

---

## 3. Pull Request Guidelines

1. **Self-Review**: Review your own diff before submitting the PR to catch stray debug statements, unused imports, or formatting inconsistencies.
2. **Template Adherence**: Fill in all sections of `.github/pull_request_template.md`, including related SRS IDs (e.g., `FR-2.1`, `BR-1`).
3. **Automated CI Gates**:
   - `npm run lint` must exit with 0 errors.
   - `npm test` must pass all integration and unit tests.
4. **Peer Approval**: At least one senior code review approval is required prior to merging.
5. **No Direct Push to Main**: Branch protection rules on GitHub must enforce status checks and review requirements on `main` and `develop`.
