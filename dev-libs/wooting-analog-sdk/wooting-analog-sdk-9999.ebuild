EAPI=8

# Use git-r3 for live fetching and cargo for Rust compilation
inherit git-r3 cargo

DESCRIPTION="Native support for Analog Keyboards (Wooting Analog SDK) - Live Version"
HOMEPAGE="https://github.com/WootingKb/wooting-analog-sdk"
EGIT_REPO_URI="https://github.com/WootingKb/wooting-analog-sdk.git"

LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS="~*"

# Dependencies for building and running
RDEPEND="virtual/libudev"
DEPEND="${RDEPEND}"
BDEPEND="dev-util/cbindgen"


src_unpack() {
	git-r3_src_unpack
	cargo_live_src_unpack
}

src_compile() {
	cargo_src_compile -p wooting-analog-sdk --features ffi

	ebegin "Generating C headers using cbindgen"
	mkdir -p includes || die "Failed to create includes directory"
	cbindgen --crate wooting-analog-sdk --output ./includes/wooting-analog-sdk.h || die "cbindgen failed"
	eend $?
}

src_install() {
	dolib.so "target/release/libwooting_analog_sdk.so"

	# Install the dynamically generated C header
	insinto /usr/include
	doins includes/wooting-analog-sdk.h

	einstalldocs
}
