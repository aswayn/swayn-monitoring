# AGENTS.md - Development Guidelines for swayn-monitoring

This document provides guidelines for agentic coding assistants working on the swayn-monitoring project.

## Project Overview

swayn-monitoring is a monitoring system project. The codebase is currently minimal and will be expanded to include monitoring functionality.

## Build/Lint/Test Commands

### Primary Build Commands
```bash
# Build the project (when applicable)
npm run build
# or
yarn build
# or
cargo build --release
# or
python setup.py build
```

### Linting Commands
```bash
# Run linter
npm run lint
# or
yarn lint
# or
cargo clippy
# or
ruff check .
# or
eslint .
```

### Test Commands
```bash
# Run all tests
npm test
# or
yarn test
# or
cargo test
# or
pytest
# or
python -m pytest
```

### Run Single Test File
```bash
# JavaScript/TypeScript (Jest/Mocha/Vitest)
npm test -- path/to/test/file.test.js
# or
yarn test path/to/test/file.test.js
# or
npx vitest run path/to/test/file.test.js

# Python (pytest)
pytest path/to/test_file.py
# or
python -m pytest path/to/test_file.py

# Rust
cargo test test_name
# or
cargo test -- --test test_name

# Go
go test -run TestName ./path/to/package
```

### Type Checking
```bash
# TypeScript
npx tsc --noEmit
# or
npm run typecheck

# Python (mypy)
mypy .

# Go
go vet ./...
```

## Code Style Guidelines

### General Principles
- Write clean, readable, and maintainable code
- Follow the principle of least surprise
- Use meaningful variable and function names
- Keep functions small and focused on a single responsibility
- Document complex logic with comments
- Avoid magic numbers and strings

### Language-Specific Guidelines

#### JavaScript/TypeScript
- Use ES6+ features
- Prefer `const` over `let`, avoid `var`
- Use arrow functions for anonymous functions
- Use template literals for string interpolation
- Use async/await over promises when possible
- Use meaningful variable names (camelCase)
- Use PascalCase for component names and classes
- Use UPPER_SNAKE_CASE for constants

#### Python
- Follow PEP 8 style guide
- Use snake_case for variables and functions
- Use PascalCase for classes
- Use UPPER_SNAKE_CASE for constants
- Maximum line length: 88 characters (Black formatter default)
- Use type hints for function parameters and return values
- Use docstrings for module, class, and function documentation

#### Rust
- Follow the official Rust style guide
- Use snake_case for variables and functions
- Use PascalCase for types, traits, and enums
- Use UPPER_SNAKE_CASE for constants and statics
- Maximum line length: 100 characters
- Use meaningful error handling with Result and Option types

#### Go
- Follow effective Go guidelines
- Use camelCase for exported identifiers
- Use PascalCase for exported types and functions
- Use snake_case for unexported identifiers
- Maximum line length: 80 characters (gofmt default)

### Imports and Dependencies

#### JavaScript/TypeScript
```javascript
// Group imports by type and sort alphabetically
import React from 'react';
import { useState, useEffect } from 'react';

import { Button } from '@components/ui';
import { apiClient } from '@lib/api';
import type { User } from '@types/user';

// External libraries
import axios from 'axios';
import { format } from 'date-fns';
```

#### Python
```python
# Standard library imports first
import os
import sys
from typing import List, Optional

# Third-party imports
import requests
import pandas as pd

# Local imports
from .models import User
from ..utils import format_date
```

#### Rust
```rust
// Group imports logically
use std::collections::HashMap;
use std::sync::Arc;

// External crates
use serde::{Deserialize, Serialize};
use tokio::sync::Mutex;

// Local modules
mod models;
mod utils;

use models::User;
use utils::format_date;
```

### Error Handling

#### JavaScript/TypeScript
- Use try/catch for synchronous errors
- Use .catch() for promise rejections
- Provide meaningful error messages
- Avoid throwing generic Error objects
- Use custom error classes when appropriate

```typescript
try {
  const result = await apiCall();
  return result;
} catch (error) {
  console.error('API call failed:', error.message);
  throw new ApiError('Failed to fetch data', { cause: error });
}
```

#### Python
- Use specific exception types
- Avoid catching bare Exception
- Use context managers for resource management
- Provide informative error messages

```python
try:
    result = api_call()
    return result
except requests.RequestException as e:
    logger.error(f"API call failed: {e}")
    raise ApiError("Failed to fetch data") from e
```

#### Rust
- Use Result<T, E> for recoverable errors
- Use panic! only for unrecoverable errors
- Implement custom error types with thiserror
- Use the ? operator for error propagation

```rust
fn process_data() -> Result<Data, Error> {
    let data = fetch_data().await?;
    let processed = validate_data(data)?;
    Ok(processed)
}
```

### Naming Conventions

#### Files and Directories
- Use kebab-case for file names: `user-service.ts`, `api-client.py`
- Use snake_case for Python files: `user_service.py`
- Group related files in directories
- Use index files for clean imports

#### Variables and Functions
- Use descriptive names that explain purpose
- Avoid abbreviations unless widely understood
- Use boolean prefixes: `is_enabled`, `has_permission`
- Use action verbs for functions: `get_user()`, `validate_input()`

#### Database and API
- Use snake_case for database columns
- Use kebab-case for API endpoints: `/api/users/{id}`
- Use consistent HTTP methods and status codes
- Document API responses and error formats

### Testing Guidelines

#### General Testing Principles
- Write tests for all public functions
- Test both positive and negative cases
- Use descriptive test names
- Mock external dependencies
- Test edge cases and error conditions

#### Test Structure
```
tests/
├── unit/
├── integration/
└── e2e/
```

#### Example Test Patterns
```javascript
// Jest example
describe('UserService', () => {
  describe('getUser', () => {
    it('should return user data for valid ID', async () => {
      const userId = '123';
      const mockUser = { id: userId, name: 'John' };

      mockApi.get.mockResolvedValue(mockUser);

      const result = await userService.getUser(userId);

      expect(result).toEqual(mockUser);
      expect(mockApi.get).toHaveBeenCalledWith(`/users/${userId}`);
    });

    it('should throw error for invalid ID', async () => {
      const invalidId = 'invalid';

      await expect(userService.getUser(invalidId))
        .rejects
        .toThrow('Invalid user ID');
    });
  });
});
```

### Code Organization

#### Directory Structure
```
src/
├── components/     # UI components
├── services/       # Business logic and API calls
├── models/         # Data models and types
├── utils/          # Utility functions
├── hooks/          # Custom React hooks
├── constants/      # Application constants
├── config/         # Configuration files
└── types/          # TypeScript type definitions
```

#### File Organization
- Keep files focused on single responsibility
- Use barrel exports (index.ts) for clean imports
- Separate concerns: UI, business logic, data access
- Use dependency injection for testability

### Security Considerations

- Never commit secrets or credentials
- Use environment variables for sensitive data
- Implement proper input validation
- Use parameterized queries to prevent SQL injection
- Implement proper authentication and authorization
- Keep dependencies updated and audit for vulnerabilities

### Performance Guidelines

- Optimize bundle size and loading times
- Use lazy loading for large components
- Implement proper caching strategies
- Monitor and optimize database queries
- Use efficient algorithms and data structures
- Profile and benchmark performance-critical code

### Documentation

- Document public APIs with examples
- Use inline comments for complex logic
- Maintain up-to-date README files
- Document environment setup and deployment
- Use consistent documentation format

## Development Workflow

1. Create a feature branch from main
2. Write tests for new functionality
3. Implement the feature following style guidelines
4. Run tests and linting locally
5. Commit with descriptive messages
6. Create pull request for review
7. Address review feedback
8. Merge after approval

## Tool Configuration

### EditorConfig (.editorconfig)
```
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.{js,ts,jsx,tsx}]
indent_style = space
indent_size = 2

[*.{py,rs}]
indent_style = space
indent_size = 4

[*.{go,md}]
indent_style = tab
indent_size = 4
```

### Pre-commit Hooks
- Run linting before commits
- Run tests before commits
- Format code automatically
- Check for secrets in commits

This document should be updated as the project evolves and specific technologies are chosen.