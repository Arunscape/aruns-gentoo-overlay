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
	dev-build/cmake
	dev-build/ninja
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
