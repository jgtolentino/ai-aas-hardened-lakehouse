package main

default allow = true

# Basic security policy
deny[msg] {
  input.kind == "Deployment"
  input.spec.template.spec.securityContext.runAsNonRoot != true
  msg := "Deployments must run as non-root user"
}

deny[msg] {
  input.kind == "StatefulSet"
  input.spec.template.spec.securityContext.runAsNonRoot != true
  msg := "StatefulSets must run as non-root user"
}

# Resource limits policy
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits
  msg := sprintf("Container '%s' in Deployment must have resource limits", [container.name])
}

deny[msg] {
  input.kind == "StatefulSet"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits
  msg := sprintf("Container '%s' in StatefulSet must have resource limits", [container.name])
}

# Health checks policy
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.livenessProbe
  not container.name == "init"
  msg := sprintf("Container '%s' should have livenessProbe", [container.name])
}

# Image tag policy
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("Container '%s' should not use ':latest' tag", [container.name])
}

deny[msg] {
  input.kind == "StatefulSet"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("Container '%s' should not use ':latest' tag", [container.name])
}

deny[msg] {
  input.kind == "Job"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("Container '%s' should not use ':latest' tag", [container.name])
}