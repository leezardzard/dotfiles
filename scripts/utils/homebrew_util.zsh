#!/bin/zsh

is_package_installed() {
  package=$1
  if brew list --formula | grep -q "^$package\$"; then
    return 0  # true
  else
    return 1  # false
  fi
}
