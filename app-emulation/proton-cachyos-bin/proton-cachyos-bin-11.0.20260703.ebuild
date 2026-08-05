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
SLOT="0"
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
