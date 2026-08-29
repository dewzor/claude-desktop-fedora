Name:           claude-desktop-builder
Version:        1.0.0
Release:        1%{?dist}
Summary:        Builds and updates Claude Desktop for Fedora from the official upstream build

License:        MIT
URL:            https://github.com/dewzor/claude-desktop-fedora
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  systemd-rpm-macros

# Everything build-official.sh needs, plus dnf to install what it produces.
Requires:       rpm-build
Requires:       binutils
Requires:       file
Requires:       xz
Requires:       curl
Requires:       dnf

%description
Claude Desktop is proprietary and cannot be redistributed, so the application
itself is not in this package and never will be. This package ships the build
script instead.

It installs build-official.sh, a claude-desktop-update command and a systemd
timer. Once a day the timer asks Anthropic's download endpoint which Linux
build is current. If that build is already installed it stops there and
downloads nothing. If a newer build has shipped, it fetches Anthropic's
official .deb on this machine, repackages the payload as an RPM and installs
the result.

The result is the same package build-official.sh produces by hand. Nothing
proprietary is redistributed.

%prep
%setup -q

%build
# Nothing to compile.

%install
install -Dpm 0755 build-official.sh \
    %{buildroot}%{_libexecdir}/%{name}/build-official.sh
install -Dpm 0755 copr/claude-desktop-update \
    %{buildroot}%{_bindir}/claude-desktop-update
install -Dpm 0644 copr/claude-desktop-update.service \
    %{buildroot}%{_unitdir}/claude-desktop-update.service
install -Dpm 0644 copr/claude-desktop-update.timer \
    %{buildroot}%{_unitdir}/claude-desktop-update.timer
install -Dpm 0644 copr/claude-desktop-update.1 \
    %{buildroot}%{_mandir}/man1/claude-desktop-update.1
install -dm 0755 %{buildroot}%{_sharedstatedir}/%{name}

%check
# The package ships two shell scripts. Parse them; there is nothing to run.
bash -n build-official.sh
bash -n copr/claude-desktop-update

%post
%systemd_post claude-desktop-update.timer
if [ $1 -eq 1 ]; then
    systemctl daemon-reload >/dev/null 2>&1 || :
    systemctl enable --now claude-desktop-update.timer >/dev/null 2>&1 || :
fi

%preun
%systemd_preun claude-desktop-update.timer

%postun
%systemd_postun_with_restart claude-desktop-update.timer

%files
%license LICENSE-MIT
%doc README.md
%{_bindir}/claude-desktop-update
%dir %{_libexecdir}/%{name}
%{_libexecdir}/%{name}/build-official.sh
%{_unitdir}/claude-desktop-update.service
%{_unitdir}/claude-desktop-update.timer
%{_mandir}/man1/claude-desktop-update.1*
%dir %{_sharedstatedir}/%{name}

%changelog
* Sat Aug 29 2026 Henrik Berglund <16418668+dewzor@users.noreply.github.com> - 1.0.0-1
- First release: build script, updater CLI and daily systemd timer
