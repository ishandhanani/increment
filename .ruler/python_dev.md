# Python Development Guidelines

# Tools

We use `uv` for all python related operations. Assume `uv` is installed.

## Working on new projects

```bash
# From the root of the repository run:
uv init hello-world
```

This creates a venv and a pyproject.toml file.

## Run code

```bash
# this will automatically run it in the venv
uv run main.py
```

## Dependencies

Use "uv add", "uv run", "uv sync", and "uv lock" for new projects—these manage dependencies via pyproject.toml and keep everything in sync. Use "uv pip" commands if you need pip-like flexibility or are working with legacy projects. Prefer project APIs for new work; use pip APIs for existing workflows.

## Working on individual scripts

When working on scripts or hacking things together quickly, please use inline dependency management.

```bash
uv add --script <name of script>.py 'pkgname1' 'pkgname2'
```
