# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit optfeature systemd unpacker

MY_PN="${PN%-bin}"

DESCRIPTION="Pritunl client daemon and command line interface"
HOMEPAGE="https://client.pritunl.com/ https://github.com/pritunl/pritunl-client"
SRC_URI="https://github.com/pritunl/${MY_PN}/releases/download/${PV}/${MY_PN}-${PV}-1-x86_64.pkg.tar.zst -> ${P}.pkg.tar.zst"
S="${WORKDIR}"

# Pritunl: the client itself; the rest: statically linked Go dependencies
LICENSE="Pritunl Apache-2.0 BSD BSD-2 MIT"
SLOT="0"
KEYWORDS="-* ~amd64"
IUSE="systemd"
RESTRICT="bindist mirror strip"

RDEPEND="
	net-vpn/openvpn
	sys-apps/iproute2
	sys-apps/net-tools
"
BDEPEND="$(unpacker_src_uri_depends)"

QA_PREBUILT="usr/bin/pritunl-client*"

src_install() {
	dobin usr/bin/pritunl-client{,-service}
	# The name `go install` gives the CLI
	dosym pritunl-client /usr/bin/pritunl-cli

	newinitd "${FILESDIR}"/pritunl-client.initd pritunl-client
	use systemd && systemd_dounit etc/systemd/system/pritunl-client.service
}

pkg_postinst() {
	optfeature "WireGuard profiles" net-vpn/wireguard-tools

	if [[ -z ${REPLACING_VERSIONS} ]]; then
		elog "Start the daemon the CLI talks to:"
		if use systemd; then
			elog "  systemctl enable --now pritunl-client"
		else
			elog "  rc-update add pritunl-client default"
			elog "  rc-service pritunl-client start"
		fi
	fi
}
