Name:      ozo-mariadb-backup
Version:   1.0.1
Release:   1%{?dist}
Summary:   Creates a dump of all MariaDB databases and performs history maintenance.
BuildArch: noarch

License:   GPL
Source0:   %{name}-%{version}.tar.gz

Requires:  bash

%description
This script creates a dump of all MariaDB databases and performs history maintenance.

%prep
%setup -q

%install
rm -rf $RPM_BUILD_ROOT

mkdir -p $RPM_BUILD_ROOT/etc
cp ozo-mariadb-backup.conf $RPM_BUILD_ROOT/etc

mkdir -p $RPM_BUILD_ROOT/etc/cron.d
cp ozo-mariadb-backup $RPM_BUILD_ROOT/etc/cron.d

mkdir -p $RPM_BUILD_ROOT/usr/sbin
cp ozo-mariadb-backup.sh $RPM_BUILD_ROOT/usr/sbin

%files
%attr (0644,root,root) /etc/ozo-mariadb-backup.conf
%attr (0644,root,root) %config(noreplace) /etc/cron.d/ozo-mariadb-backup
%attr (0700,root,root) /usr/sbin/ozo-mariadb-backup.sh

%changelog
* Sun Aug 03 2025 One Zero One RPM Manager <repositories@onezeroone.dev> - 1.0.1-1
- Minor docstring update
* Fri Mar 17 2023 One Zero One RPM Manager <repositories@onezeroone.dev> - 1.0.0-1
- Initial release
