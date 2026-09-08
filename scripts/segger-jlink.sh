#!/usr/bin/env bash
# Automatically bumps the segger-jlink-bin ebuild in a Gentoo overlay

# --- CONFIGURATION ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CATEGORY="dev-embedded"
PN="segger-jlink-bin"
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

echo "Checking for latest release of Segger J-Link..."

# 1. Fetch the latest release version from Segger website
# The version is embedded in the first <option value="0"> element for J-Link
LATEST_VER=$(curl -s "https://www.segger.com/downloads/jlink/" | grep -oP '(?<=<option value="0">V)[0-9a-z.]+' | head -n 1)

if [[ -z "$LATEST_VER" ]]; then
    echo "Error: Failed to fetch the latest version from Segger."
    exit 1
fi

EBUILD_VER="${LATEST_VER}"
EBUILD_NAME="${PN}-${EBUILD_VER}.ebuild"
EBUILD_PATH="${PKG_DIR}/${EBUILD_NAME}"

# 3. Check if the ebuild already exists
if [[ -f "$EBUILD_PATH" ]]; then
    echo "Package ${CATEGORY}/${PN} is already up to date at version ${EBUILD_VER}."
    exit 0
fi

echo "New version found: ${LATEST_VER}. Creating ebuild ${EBUILD_NAME}..."

# Ensure directory exists
mkdir -p "${PKG_DIR}"
cd "${PKG_DIR}"

# Download the file to DISTDIR using the POST method so we can generate the Manifest
DL_VER="${LATEST_VER//./}"
ARCH="x86_64"
FILENAME="JLink_Linux_V${DL_VER}_${ARCH}.tgz"
DL_URL="https://www.segger.com/downloads/jlink/${FILENAME}"

echo "Downloading ${FILENAME} to generate manifest..."
curl -s -o "${DISTDIR}/${FILENAME}" -d "accept_license_agreement=accepted" -d "submit=Download software" "${DL_URL}"

# 4. Generate the new ebuild file
cat << 'EOF' > "${EBUILD_NAME}"
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop udev xdg-utils

MY_PN="JLink_Linux"
# Remove dots from version for the filename, e.g. 9.74 -> 974
MY_PV="${PV//./}"

DESCRIPTION="SEGGER J-Link Software and Documentation Pack"
HOMEPAGE="https://www.segger.com/downloads/jlink/"
SRC_URI="amd64? ( https://www.segger.com/downloads/jlink/${MY_PN}_V${MY_PV}_x86_64.tgz )"

LICENSE="SEGGER"
SLOT="0"
KEYWORDS="-* ~amd64"

RESTRICT="mirror strip bindist"
QA_PREBUILT="*"

S="${WORKDIR}/${MY_PN}_V${MY_PV}_x86_64"

DEPEND="
	virtual/libusb:1
	virtual/udev
"
RDEPEND="${DEPEND}"

pkg_nofetch() {
	einfo "Please download the J-Link software from:"
	einfo "  ${HOMEPAGE}"
	einfo "Place the downloaded file (${A}) into your DISTDIR directory."
	einfo "Note: You can download it directly using curl:"
	einfo "  curl -d \"accept_license_agreement=accepted\" -d \"submit=Download software\" -o ${DISTDIR}/${A} ${SRC_URI}"
}

src_install() {
	local optdir="/opt/SEGGER/JLink"
	dodir "${optdir}"

	# Install binaries and shared libraries
	cp -a . "${ED}${optdir}/" || die "Failed to copy J-Link files"

	# Fix permissions
	chmod -R 0755 "${ED}${optdir}"
	chmod -R 0644 "${ED}${optdir}"/Doc "${ED}${optdir}"/Samples "${ED}${optdir}"/ETC

	# Symlink binaries to /usr/bin
	dodir /usr/bin
	for bin in JLinkExe JLinkGDBServer JLinkGUIServerExe JLinkLicenseManager JLinkRegistration JLinkRemoteServer JLinkRTTClient JLinkRTTLogger JLinkRTTViewer JLinkSWOViewerExe JMemExe JRunExe JTAGLoadExe; do
		if [[ -f "${ED}${optdir}/${bin}" ]]; then
			dosym "${optdir}/${bin}" "/usr/bin/${bin}"
		fi
	done

	# Install udev rules
	insinto /lib/udev/rules.d
	newins 99-jlink.rules 99-jlink.rules
}

pkg_postinst() {
	udev_reload
	xdg_desktop_database_update
	xdg_icon_cache_update
}

pkg_postrm() {
	udev_reload
	xdg_desktop_database_update
	xdg_icon_cache_update
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
