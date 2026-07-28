package main

import future.keywords.if
import future.keywords.contains

# OCIRepository resources inside a ResourceSet must use the
# << inputs.version >> placeholder in spec.ref.tag.

deny contains msg if {
  input.kind == "ResourceSet"
  some resource in input.spec.resources
  resource.kind == "OCIRepository"
  tag := resource.spec.ref.tag
  not contains(tag, "<< inputs.version >>")
  msg := sprintf(
    "ResourceSet %s: OCIRepository %s ref.tag '%s' must use '<< inputs.version >>'",
    [input.metadata.name, resource.metadata.name, tag],
  )
}
