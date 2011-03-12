Summary: imapsync a tool to migrate across IMAP servers
URL: http://freshmeat.net/projects/imapsync/
Name: imapsync
Version: 1.217
Release: 1
License: GPL
Group: DICE/Utils
Source: http://www.linux-france.org/prj/imapsync/dist/imapsync-1.217.tgz
Source99: filter-requires-imapsync.sh
BuildArch: noarch
BuildRoot: /var/tmp/%{name}-build
Packager: Neil Brown <neilb@inf.ed.ac.uk>
Requires: perl(Mail::IMAPClient), perl(Net::SSLeay), perl(IO::Socket::SSL)

# Working around perl dependency problem, its wrongly matching
# on "use --prefix" in the docs embeded in the code
%define __perl_requires %{SOURCE99}

%description
imapsync is a tool for facilitating incremental recursive IMAP
transfers from one mailbox to another. It is useful for mailbox
migration, and reduces the amount of data transferred by only copying
messages that are not present on both servers. Read, unread, and
deleted flags are preserved, and the process can be stopped and
resumed. The original messages can optionally be deleted after a
successful transfer.

%prep
%setup

%build

%install
make DESTDIR=$RPM_BUILD_ROOT install

%files
%defattr(-,root,root)
%doc ChangeLog README INSTALL FAQ CREDITS TODO GPL
/usr/bin/imapsync
/usr/share/man

%clean
rm -rf $RPM_BUILD_ROOT

%changelog
* Mon Mar 19 2007 Neil Brown <neilb@inf.ed.ac.uk>
- Packaged up source tarball into the RPM. Had to add a fix
- to stop the perl_requires script wrongly matching on "use --prefix"
- in the docs as a genuine perl "use module;"



