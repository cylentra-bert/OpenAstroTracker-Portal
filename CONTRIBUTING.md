# Contributing Guide

This document outlines the workflow for making changes to this repository.

## Branch Strategy

- **main** - Protected branch. All changes require PR review.
- **Feature branches** - Temporary branches for developing changes

## Making Changes

Never push directly to main. Always use a pull request.

### 1. Start from an updated main branch

git checkout main
git pull origin main

### 2. Create a feature branch

git checkout -b feature/your-change-description

Use descriptive names:
- `feature/add-new-feature`
- `fix/bug-description`
- `docs/update-documentation`

### 3. Make your changes and commit

git add -A
git commit -m "Brief description of changes"

### 4. Push the feature branch

git push -u origin feature/your-change-description

### 5. Create a Pull Request

1. Go to the repository on GitHub
2. Click the "Compare & pull request" button
3. Add a description of changes
4. Click "Create pull request"

### 6. Review and Merge

1. Review the changes in the PR
2. Click "Merge pull request"
3. Delete the feature branch

### 7. Clean up local branch

git checkout main
git pull origin main
git branch -d feature/your-change-description

## Quick Reference

| Task | Command |
|------|---------|
| Create feature branch | `git checkout -b feature/name` |
| Push feature branch | `git push -u origin feature/name` |
| Switch branches | `git checkout branch-name` |
| Update current branch | `git pull origin branch-name` |
| Delete local branch | `git branch -d branch-name` |

## Commit Message Guidelines

- Use present tense: "Add feature" not "Added feature"
- Keep first line under 50 characters
- Add details in body if needed
