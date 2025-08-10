package security

default allow = true

# Check for hardcoded secrets in files
deny[msg] {
  input.file_content[_] =~ "(?i)(api[_-]?key|secret|password|token)\\s*=\\s*[\"'][^\"']+[\"']"
  msg := "Potential hardcoded secret detected"
}

# Ensure Dockerfiles don't use latest tags
deny[msg] {
  input.dockerfile[_].cmd == "FROM"
  contains(input.dockerfile[_].value[0], ":latest")
  msg := "Docker images should not use 'latest' tag"
}

# Ensure Dockerfiles use non-root user
deny[msg] {
  input.dockerfile[_].cmd == "USER"
  input.dockerfile[_].value[0] == "root"
  msg := "Dockerfile should not run as root user"
}

# Check for HTTPS in URLs
deny[msg] {
  input.file_content[_] =~ "http://[^localhost]"
  msg := "Use HTTPS instead of HTTP for external URLs"
}

# Ensure sensitive files have proper permissions
deny[msg] {
  input.file_path =~ "\\.(pem|key|crt|p12|jks|keystore)$"
  input.file_permissions != "600"
  msg := sprintf("Sensitive file %s should have 600 permissions", [input.file_path])
}