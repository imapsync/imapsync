# The source cannot be distributed:
%{!?nosrc: %define nosrc 1}
# to include the source use:
# rpm -bs --define 'nosrc 0'

%{?!imapsyncver:   %define imapsyncver   1.434}

Summary: Tool to migrate across IMAP servers
Name: imapsync
Version: %{imapsyncver}
Release: 1%{?dist}
License: WTFPL
Group: Applications/Internet
URL: http://www.linux-france.org/prj/imapsync/

Source: http://www.linux-france.org/prj/imapsync/dist/imapsync-%{version}.tgz
# The source cannot be distributed:
%if %{nosrc}
NoSource: 0
%endif

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildArch: noarch
BuildRequires: make
BuildRequires: perl(Mail::IMAPClient) >= 3.19
BuildRequires: perl(Test::More)
Requires: perl(Date::Manip)
Requires: perl(Digest::MD5)
Requires: perl(IO::Socket::SSL)
Requires: perl(Mail::IMAPClient) >= 3.19
Requires: perl(Term::ReadKey)
Requires: perl(Digest::HMAC_MD5)
#Requires: perl(Digest::MD5::M4p)
#Requires: perl(Net::SSLeay)

# http://fedoraproject.org/wiki/Packaging:AutoProvidesAndRequiresFiltering
%{?filter_setup:
%filter_from_requires /^perl(--prefix2)/d
%filter_setup
}
%{!?filter_setup:
# filter_setup undefined
%define __perl_requires %{_builddir}/%{buildsubdir}/filter-requires-imapsync.sh
}

%description
imapsync is a tool for facilitating incremental recursive IMAP
transfers from one mailbox to another. It is useful for mailbox
migration, and reduces the amount of data transferred by only copying
messages that are not present on both servers. Read, unread, and
deleted flags are preserved, and the process can be stopped and
resumed. The original messages can optionally be deleted after a
successful transfer.

%prep
%setup -q

%{!?filter_setup:
%{__cat} <<'EOF' >filter-requires-imapsync.sh
#!/bin/sh
/usr/lib/rpm/perl.req $* | sed -e '/perl(--prefix2)/d'
EOF
%{__chmod} a+x filter-requires-imapsync.sh
}

%build

%install
%{__rm} -rf %{buildroot}
%{__make} install DESTDIR="%{buildroot}"

%files
%defattr(-, root, root, 0755)
%doc ChangeLog COPYING CREDITS FAQ INSTALL README TODO
%doc %{_mandir}/man1/imapsync.1*
%{_bindir}/imapsync

%clean
%{__rm} -rf %{buildroot}

%changelog
* Fri Mar 25 2011 Marcin Dulak <Marcin.Dulak@gmail.com> - 1.440-1
- Updated to release 1.440.
- introduced nosrc variable: source must not be distributed
- license is WTFPL: see ChangeLog
- use filter-requires-imapsync.sh when filter_setup undefined
- removed Authority: dag

* Tue Sep 07 2010 Dag Wieers <dag@wieers.com> - 1.350-1
- Updated to release 1.350.

* Wed Jan 13 2010 Steve Huff <shuff@vecna.org> - 1.293-1
- Updated to version 1.293.

* Sun Dec 20 2009 Steve Huff <shuff@vecna.org> - 1.286-2
- Added missing Perl dependencies (reported by John Thomas).

* Thu Sep 10 2009 Dag Wieers <dag@wieers.com> - 1.286-1
- Updated to release 1.286.

* Thu Jul 09 2009 Christoph Maser <cmr@financial.com> - 1.285-1
- Updated to release 1.285.

* Mon Jun 30 2008 Dag Wieers <dag@wieers.com> - 1.255-1
- Updated to release 1.255.

* Fri May 09 2008 Dag Wieers <dag@wieers.com> - 1.252-1
- Updated to release 1.252.

* Sun Apr 27 2008 Dag Wieers <dag@wieers.com> - 1.250-1
- Updated to release 1.250.

* Wed Mar 26 2008 Dag Wieers <dag@wieers.com> - 1.249-1
- Updated to release 1.249.

* Mon Feb 11 2008 Dag Wieers <dag@wieers.com> - 1.241-1
- Updated to release 1.241.

* Thu Nov 22 2007 Dag Wieers <dag@wieers.com> - 1.233-1
- Updated to release 1.233.

* Thu Sep 13 2007 Dag Wieers <dag@wieers.com> - 1.223-1
- Updated to release 1.223.

* Thu Aug 16 2007 Fabian Arrotin <fabian.arrotin@arrfab.net> - 1.219-1
- Update to 1.219.
- Cosmetic changes for Requires: specific to RHEL/CentOS.

* Mon Mar 19 2007 Neil Brown <neilb@inf.ed.ac.uk>
- Packaged up source tarball into the RPM. Had to add a fix
  to stop the perl_requires script wrongly matching on "use --prefix"
  in the docs as a genuine perl "use module;"
