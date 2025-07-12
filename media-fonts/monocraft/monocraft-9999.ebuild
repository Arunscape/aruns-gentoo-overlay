EAPI=8
inherit git-r3
DESCRIPTION="A monospaced programming font inspired by the Minecraft typeface"
HOMEPAGE="https://github.com/IdreesInc/Monocraft"
#SRC_URI="https://github.com/IdreesInc/Monocraft"
EGIT_REPO_URI="https://github.com/IdreesInc/Monocraft.git"

#KEYWORDS="~*"
SLOT="0"
IUSE=""
PROPERTIES="live"
EGIT_REPO_URI="https://github.com/IdreesInc/Monocraft.git"
S="${WORKDIR}/Monocraft"
EGIT_CHECKOUT_DIR=$S

pkg_postinst() {
	elog "Updating font cache..."
	fc-cache -fv || die "fc-cache failed"
}

pkg_prerm() {
	elog "Updating font cache..."
	fc-cache -fv || die "fc-cache failed"
}

src_install() {
	insinto /usr/share/fonts/monocraft
	doins "${S}/dist/Monocraft-nerd-fonts-patched.ttc"
}
