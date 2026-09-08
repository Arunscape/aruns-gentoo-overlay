#!/usr/bin/env bash
# Automatically bumps the zephyr-sdk-bin ebuild in a Gentoo overlay

# --- CONFIGURATION ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CATEGORY="dev-embedded"
PN="zephyr-sdk-bin"
PKG_DIR="${OVERLAY_DIR}/${CATEGORY}/${PN}"

export DISTDIR="${HOME}/.cache/distfiles"
mkdir -p "${DISTDIR}"
# ---------------------

set -e

# Ensure required tools are installed
for tool in curl grep head sed ebuild git; do
    if ! command -v "$tool" &> /dev/null; then
        echo "Error: Required tool '$tool' is not installed."
        exit 1
    fi
done

echo "Checking for latest release of Zephyr SDK..."

# 1. Fetch the latest release version from Github
LATEST_TAG=$(curl -s "https://api.github.com/repos/zephyrproject-rtos/sdk-ng/releases/latest" | grep '"tag_name":' | head -n 1 | sed -E 's/.*"tag_name": *"v([^"]+)".*/\1/')

if [[ -z "$LATEST_TAG" ]]; then
    echo "Error: Failed to fetch the latest version from GitHub."
    exit 1
fi

EBUILD_VER="${LATEST_TAG}"
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

# Download the file to DISTDIR so we can generate the Manifest
# For >=1.0.0, it uses _gnu suffix. Let's just assume _gnu for 1.x
FILENAME="zephyr-sdk-${EBUILD_VER}_linux-x86_64_gnu.tar.xz"
DL_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${EBUILD_VER}/${FILENAME}"

echo "Downloading ${FILENAME} to generate manifest..."
curl -L -s -o "${DISTDIR}/${FILENAME}" "${DL_URL}"

# 4. Generate the new ebuild file
cat << 'EOF' > "${EBUILD_NAME}"
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Zephyr RTOS Software Development Kit (SDK)"
HOMEPAGE="https://github.com/zephyrproject-rtos/sdk-ng"
SRC_URI="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${PV}/zephyr-sdk-${PV}_linux-x86_64_gnu.tar.xz"

LICENSE="Apache-2.0 GPL-2+"
SLOT="0"
KEYWORDS="-* ~amd64"

RESTRICT="mirror strip bindist"
QA_PREBUILT="*"

S="${WORKDIR}/zephyr-sdk-${PV}"

DEPEND=""
RDEPEND="${DEPEND}
	sys-apps/dtc
	dev-util/cmake
	dev-util/ninja
	dev-python/ply
"

src_install() {
	local optdir="/opt/zephyr-sdk"
	dodir "${optdir}"

	# Install everything
	cp -a . "${ED}${optdir}/" || die "Failed to copy zephyr-sdk files"

	# Fix permissions
	chmod -R 0755 "${ED}${optdir}"

	# Setup Zephyr SDK env var
	echo "ZEPHYR_SDK_INSTALL_DIR=${EPREFIX}${optdir}" > 99zephyr-sdk
	doenvd 99zephyr-sdk
}

pkg_postinst() {
	einfo "Zephyr SDK has been installed to /opt/zephyr-sdk"
	einfo "Please run 'source /etc/profile' to update your environment variables."
	einfo "You may want to install the udev rules manually if needed:"
	einfo "  sudo cp /opt/zephyr-sdk/sysroots/x86_64-pokysdk-linux/usr/share/openocd/contrib/60-openocd.rules /etc/udev/rules.d"
	einfo "  sudo udevadm control --reload"
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
    
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "Pushing to remote..."
        if ! git push; then
            echo "Warning: git push failed. You may need to push manually."
        fi
    fi
else
    echo "No changes to commit."
fi

echo "Successfully processed ${CATEGORY}/${PN}-${EBUILD_VER}!"
