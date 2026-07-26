#!/bin/sh
# Install shared pi packages (idempotent: pi install is a no-op if already present).
if command -v pi >/dev/null 2>&1; then
  pi install git:git@github.com:tkuminecz/pi-kit
else
  echo "pi not installed; skipping pi-kit setup"
fi
