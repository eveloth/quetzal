# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module git-r3

DESCRIPTION="Switch Vial keyboard layouts from the command line"
HOMEPAGE="https://github.com/eveloth/viswitch"
EGIT_REPO_URI="https://github.com/eveloth/viswitch.git"

LICENSE="MIT BSD
	notify? ( BSD BSD-2 )
	hidapi? ( BSD-2 || ( BSD GPL-3 HIDAPI ) )
"
SLOT="0"
IUSE="hidapi notify"

DEPEND="hidapi? ( virtual/libudev:= )"
RDEPEND="${DEPEND}"
BDEPEND=">=dev-lang/go-1.26.0"

src_unpack() {
	git-r3_src_unpack
	go-module_live_vendor
}

src_compile() {
	# Without hidapi the keyboard is reached through /dev/hidraw directly,
	# so the binary needs no cgo.
	use hidapi || local -x CGO_ENABLED=0
	local tags=( $(usev hidapi) $(usev notify) )
	ego build -tags "${tags[*]}" -trimpath \
		-ldflags "-X main.version=${PV}-${EGIT_VERSION:0:7}" \
		-o viswitch .
}

src_test() {
	use hidapi || local -x CGO_ENABLED=0
	ego test ./...
}

src_install() {
	dobin viswitch
	einstalldocs
}

pkg_postinst() {
	elog "viswitch needs read/write access to the keyboard's /dev/hidraw node."
	elog "Vial's udev rule grants it; see README.md in /usr/share/doc/${PF}."
}
