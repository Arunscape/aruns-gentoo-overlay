#!/usr/bin/env bash
# Automatically bumps the Proton-CachyOS ebuild in a Gentoo overlay

# --- CONFIGURATION ---
# Dynamically detect overlay directory based on script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CATEGORY="app-emulation"
PN="proton-cachyos-bin"
PKG_DIR="${OVERLAY_DIR}/${CATEGORY}/${PN}"
REPO="CachyOS/proton-cachyos"

# Use a local DISTDIR to avoid permission issues with /var/cache/distfiles
export DISTDIR="${HOME}/.cache/distfiles"
mkdir -p "${DISTDIR}"
# ---------------------

set -e

# Ensure required tools are installed
for tool in curl jq ebuild git; do
    if ! command -v "$tool" &> /dev/null; then
        echo "Error: Required tool '$tool' is not installed."
        exit 1
    fi
done

echo "Checking for latest release of ${REPO}..."

# 1. Fetch the latest release tag from GitHub API
LATEST_TAG=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | jq -r '.tag_name')

if [[ -z "$LATEST_TAG" || "$LATEST_TAG" == "null" ]]; then
    echo "Error: Failed to fetch the latest tag from GitHub."
    exit 1
fi

# 2. Convert GitHub tag to Gentoo version format (e.g., cachyos-11.0-20260520-slr -> 11.0.20260520)
# Gentoo strict versioning requires numbers separated by dots.
CLEAN_TAG="${LATEST_TAG#cachyos-}"
CLEAN_TAG="${CLEAN_TAG%-slr}"
EBUILD_VER="${CLEAN_TAG//-/.}"
EBUILD_NAME="${PN}-${EBUILD_VER}.ebuild"
EBUILD_PATH="${PKG_DIR}/${EBUILD_NAME}"

# 3. Check if the ebuild already exists
if [[ -f "$EBUILD_PATH" ]]; then
    echo "Package ${CATEGORY}/${PN} is already up to date at version ${EBUILD_VER}."
    exit 0
fi

echo "New version found: ${LATEST_TAG}. Creating ebuild ${EBUILD_NAME}..."

# Ensure directory exists
mkdir -p "${PKG_DIR}"
cd "${PKG_DIR}"

# 4. Generate the new ebuild file 
cat << 'EOF' > "${EBUILD_NAME}"
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit optfeature

MY_PN="proton-cachyos"
# Replaces the 2nd dot in 11.0.20260520 with a dash to match CachyOS's release format: 11.0-20260520
MY_PV="$(ver_rs 2 '-')"
# CachyOS changed their tag format to include a prefix and suffix
MY_TAG="cachyos-${MY_PV}-slr"

DESCRIPTION="Compatibility tool for Steam Play based on Wine with CachyOS patches"
HOMEPAGE="https://github.com/CachyOS/proton-cachyos"

# CachyOS releases two versions of their pre-compiled binaries:
# A standard x86_64 version, and a heavily optimized x86-64-v3 (AVX2/AVX-512) version.
SRC_URI="
	cpu_flags_x86_v3? ( https://github.com/CachyOS/${MY_PN}/releases/download/${MY_TAG}/${MY_PN}-${MY_PV}-slr-x86_64_v3.tar.xz )
	!cpu_flags_x86_v3? ( https://github.com/CachyOS/${MY_PN}/releases/download/${MY_TAG}/${MY_PN}-${MY_PV}-slr-x86_64.tar.xz )
"

LICENSE="GPL-2 GPL-3 LGPL-2.1 MIT ZLIB"
SLOT="${PV}"
KEYWORDS="-* ~amd64"
IUSE="cpu_flags_x86_v3"

# Proton releases are pre-stripped and QA checks will fail on the embedded Windows binaries
RESTRICT="bindist mirror strip"
QA_PREBUILT="*"

S="${WORKDIR}"

src_install() {
	local installdir="/usr/share/steam/compatibilitytools.d/${MY_PN}"
	dodir "${installdir}"
	
	# Navigate into the extracted directory (wildcard protects against minor naming changes)
	cd "${WORKDIR}"/proton-cachyos* || die "Could not find extracted directory"
	
	# We use cp -a to strictly preserve permissions, executable bits, and symlinks.
	# The pre-compiled SLR (Steam Linux Runtime) binaries need their exact layout.
	cp -a . "${ED}${installdir}/" || die "Failed to copy proton files"
}

pkg_postinst() {
	elog "Proton-CachyOS has been installed system-wide to:"
	elog "  ${EROOT}/usr/share/steam/compatibilitytools.d/${MY_PN}"
	elog ""
	elog "Please restart Steam to see it in your Compatibility tool list."
	elog "Since you have the ntsync module loaded in your custom kernel,"
	elog "you can use the following Launch Options in Steam:"
	elog ""
	elog "  PROTON_USE_NTSYNC=1 %command%       (Smoother sync via ntsync kernel module)"
	elog "  PROTON_USE_OPTISCALER=1 %command%   (Enables Optiscaler integration)"
	elog "  PROTON_FSR4_UPGRADE=4.1.0 %command% (Downloads & uses FSR 4.1)"
	elog "  PROTON_ENABLE_WAYLAND=1 %command%   (Experimental Native Wayland support)"
	
	optfeature "Game Mode support" games-util/gamemode
	optfeature "Performance overlay" games-util/mangohud
}
EOF

# 5. Generate Manifest
echo "Generating Manifest..."
ebuild "${EBUILD_NAME}" manifest

# 6. Commit to Git
echo "Staging changes..."
git add "${EBUILD_NAME}" Manifest

# Only commit if there are changes staged
if ! git diff --cached --quiet; then
    echo "Committing to repository..."
    git commit -m "${CATEGORY}/${PN}: bump to ${EBUILD_VER}"
    
    # Optional: push if desired. We'll check if it's a git repo first.
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "Pushing to remote..."
        # Use --dry-run or just try it. For a script it's better to let it fail or be optional.
        if ! git push; then
            echo "Warning: git push failed. You may need to push manually."
        fi
    fi
else
    echo "No changes to commit."
fi

echo "Successfully processed ${CATEGORY}/${PN}-${EBUILD_VER}!"
