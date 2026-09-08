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
