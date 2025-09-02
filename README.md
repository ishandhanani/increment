# misc

Various small projects and experiments.

## Coding agent setup

This repository leverages [ruler](https://github.com/intellectronica/ruler) to manage AI agent rules for cursor, claude-code, etc. I primarily use claude-code for terminal tasks and cursor for my IDE. When on a new machine, you can setup all of the rules/md files by running:

```bash
# install
npm install -g @intellectronica/ruler

# generate mds
ruler apply --no-gitignore
```

test
