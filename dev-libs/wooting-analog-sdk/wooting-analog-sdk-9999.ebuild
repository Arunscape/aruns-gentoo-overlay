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
BDEPEND=">=virtual/rust-1.70"

# The SDK is a workspace; we need to build the specific library
QA_FLAGS_IGNORED="usr/lib.*/libwooting_analog_sdk.so"

src_unpack() {
	git-r3_src_unpack
	cargo_live_src_unpack
}

src_compile() {
	# Building the C-compatible shared library (cdylib)
	# This usually targets the 'wrapper/sdk' crate or the main workspace
	# if it's configured to output a .so
	cargo_src_compile
}

src_install() {
	# Locate and install the compiled .so from the target directory
	# Rust typically outputs to target/release/
	dolib.so "target/release/libwooting_analog_sdk.so"

	# Install headers if they exist (common for SDKs)
	if [[ -d "wrapper/sdk/include" ]]; then
		doheader wrapper/sdk/include/*.h
	fi

	einstalldocs
}
