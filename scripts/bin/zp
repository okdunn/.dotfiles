#!/usr/bin/env zsh

PROJECTS_DIR="$HOME/Projects"

if [[ ! -d "$PROJECTS_DIR" ]]; then
  echo "Error: $PROJECTS_DIR does not exist."
  exit 1
fi

PROJECT=$(ls -1 "$PROJECTS_DIR" | fzf --prompt="Select a project: " --height=40%)

if [[ -z "$PROJECT" ]]; then
  echo "No project selected."
  exit 0
fi

PROJECT_PATH="$PROJECTS_DIR/$PROJECT"

SESSION_NAME=$(basename "$PROJECT" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')

cd $PROJECT_PATH

zellij attach "$SESSION_NAME" --create
