# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop fcaps systemd unpacker xdg

DESCRIPTION="Sota Connect — secure and private internet connectivity"
HOMEPAGE="https://sotavpn.net/"
# Upstream only publishes the latest build under a fixed name, so the
# Manifest checksum breaks as soon as a new build replaces it.
SRC_URI="https://storage.sota.ac/api/v1/public/storage/sotavpn-latest-x64.pkg.tar.zst -> ${P}.pkg.tar.zst"
S="${WORKDIR}"

# sotavpn: the app; GPL-3+: sing-box; BSD: Flutter; MIT: sentry;
# OFL-1.1: bundled Rubik and Noto Sans fonts
LICENSE="sotavpn BSD GPL-3+ MIT OFL-1.1"
SLOT="0"
KEYWORDS="-* ~amd64"
IUSE="selinux systemd"
RESTRICT="bindist mirror strip"

RDEPEND="
	acct-group/sotavpn
	app-accessibility/at-spi2-core:2
	dev-libs/ayatana-ido
	dev-libs/glib:2
	dev-libs/libayatana-appindicator
	dev-libs/libayatana-indicator
	dev-libs/libdbusmenu
	media-libs/fontconfig
	media-libs/harfbuzz
	media-libs/libepoxy
	net-misc/curl
	virtual/zlib
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
	x11-libs/pango
	selinux? ( sys-apps/policycoreutils )
"
BDEPEND="
	$(unpacker_src_uri_depends)
	acct-group/sotavpn
	dev-util/patchelf
"

QA_PREBUILT="
	opt/sotavpn/*
	usr/libexec/sota-daemon/*
"

src_prepare() {
	default

	# Plugins carry the build host's RUNPATH (/home/.../flutter/ephemeral)
	# instead of the directory with libflutter_linux_gtk.so next to them;
	# crashpad_handler has an empty one, meaning the current directory.
	local f
	for f in usr/lib/sota-connect/lib/lib*_plugin.so; do
		patchelf --set-rpath '$ORIGIN' "${f}" || die
	done
	for f in usr/lib/sota-connect/lib/{libdartjni.so,crashpad_handler}; do
		patchelf --remove-rpath "${f}" || die
	done
}

src_install() {
	insinto /opt/sotavpn
	doins -r usr/lib/sota-connect/{data,lib}
	exeinto /opt/sotavpn
	doexe usr/lib/sota-connect/sotavpn
	fperms +x /opt/sotavpn/lib/crashpad_handler
	dosym -r /opt/sotavpn/sotavpn /usr/bin/sotavpn

	# The path is hardcoded in the systemd unit
	exeinto /usr/libexec/sota-daemon
	doexe usr/libexec/sota-daemon/{sotad,sing-box}
	dosym -r /usr/libexec/sota-daemon/sotad /usr/bin/sotad

	domenu usr/share/applications/org.interhive.sota.connect.desktop
	insinto /usr/share
	doins -r usr/share/icons

	# sotad has this state directory hardcoded; the group lets members run
	# it as an OpenRC user service
	keepdir /var/lib/sota-connect
	fowners root:sotavpn /var/lib/sota-connect
	fperms 2770 /var/lib/sota-connect

	newinitd "${FILESDIR}"/sotad.initd sotad
	exeinto /etc/user/init.d
	newexe "${FILESDIR}"/sotad.user.initd sotad
	use systemd && systemd_dounit etc/systemd/system/sotad.service

	if use selinux; then
		insinto /usr/share/selinux/packages
		doins usr/share/selinux/packages/sota-daemon.pp
	fi
}

pkg_postinst() {
	xdg_pkg_postinst

	# Lets the OpenRC user service manage TUN and routes without root.
	# sotad execs sing-box, and file caps don't carry over exec.
	# Upstream's unit also grants dac_read_search and sys_ptrace, so a root
	# daemon can read users' rule sets and processes; a user's own daemon
	# doesn't need them, and as file caps they'd go to every local user.
	fcaps cap_net_admin,cap_net_raw usr/libexec/sota-daemon/{sotad,sing-box}

	if use selinux && [[ -z ${ROOT} ]]; then
		# Built upstream against Fedora's targeted policy
		semodule -i "${EROOT}"/usr/share/selinux/packages/sota-daemon.pp ||
			ewarn "Loading the sota-daemon SELinux module failed"
	fi

	if [[ -z ${REPLACING_VERSIONS} ]]; then
		elog "The GUI needs the sotad daemon running."
		if use systemd; then
			elog "  systemctl enable --now sotad"
		else
			elog "It tries to start it through systemctl, so start it yourself,"
			elog "as an OpenRC user service (members of the sotavpn group only,"
			elog "log in again after joining it):"
			elog "  gpasswd -a <user> sotavpn"
			elog "  rc-update --user add sotad default"
			elog "  rc-service --user sotad start"
			elog "or as a system service running as root:"
			elog "  rc-update add sotad default"
			elog "  rc-service sotad start"
		fi
	fi
}

pkg_postrm() {
	xdg_pkg_postrm

	if use selinux && [[ -z ${ROOT} && -z ${REPLACED_BY_VERSION} ]]; then
		semodule -r sota-daemon 2>/dev/null
	fi
}
