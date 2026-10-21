#!/usr/bin/env bash
set -euo pipefail

# Ensure an unprivileged user exists because makepkg refuses to run as root
if ! id -u builder &>/dev/null; then
  useradd -m -s /bin/bash builder
fi

out_dir="${OUTPUT_DIR:-dist/release}"
mkdir -p "$out_dir"
chmod 777 "$out_dir"

builder_home="$(getent passwd builder | cut -d: -f6)"
builder_home="${builder_home:-/home/builder}"

# Run arch-package.sh as the unprivileged builder user.
#
# The input values (tarball path, arch, etc.) arrive as environment variables.
# They are passed to the builder through `env` as data and the script reads them
# via its own argument/environment handling, so none of these values are ever
# interpolated into a shell command string. `runuser`/`su` is invoked with a fixed
# argument vector.
run_as_builder() {
  if command -v runuser >/dev/null 2>&1; then
    runuser -u builder -- env \
      HOME="$builder_home" \
      TARBALL="$TARBALL" \
      TARGET_ARCH="$TARGET_ARCH" \
      OUTPUT_DIR="$OUTPUT_DIR" \
      ARCH_LICENSE="$ARCH_LICENSE" \
      PKGREL="$PKGREL" \
      SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" \
      bash /action/arch-package.sh "$TARBALL" "$TARGET_ARCH" "$OUTPUT_DIR"
  else
    su builder -s /usr/bin/env -- \
      HOME="$builder_home" \
      TARBALL="$TARBALL" \
      TARGET_ARCH="$TARGET_ARCH" \
      OUTPUT_DIR="$OUTPUT_DIR" \
      ARCH_LICENSE="$ARCH_LICENSE" \
      PKGREL="$PKGREL" \
      SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" \
      bash /action/arch-package.sh "$TARBALL" "$TARGET_ARCH" "$OUTPUT_DIR"
  fi
}

run_as_builder

# Ensure output packages are readable by the host user
chmod 0644 "$out_dir"/*.pkg.tar.zst 2>/dev/null || true
