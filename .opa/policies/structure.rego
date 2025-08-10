package structure

default valid_structure = true

# Ensure required files exist
required_files = [
  "README.md",
  "Makefile",
  ".gitignore",
  "LICENSE"
]

deny[msg] {
  required := required_files[_]
  not input.files[required]
  msg := sprintf("Missing required file: %v", [required])
}

# Ensure required directories exist
required_directories = [
  "platform",
  ".github/workflows",
  "scripts",
  "docs"
]

deny[msg] {
  required := required_directories[_]
  not input.directories[required]
  msg := sprintf("Missing required directory: %v", [required])
}

# Check for proper documentation
deny[msg] {
  not input.files["README.md"]
  msg := "Project must have a README.md file"
}

deny[msg] {
  input.files["README.md"]
  input.readme_size < 100
  msg := "README.md should have meaningful content (at least 100 bytes)"
}

# Check for CI/CD workflows
deny[msg] {
  count(input.workflows) == 0
  msg := "Project should have at least one GitHub workflow"
}

# Check for test files
warn[msg] {
  count(input.test_files) == 0
  msg := "Project should have test files"
}