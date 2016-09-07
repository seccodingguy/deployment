%define _arch noarch

%define __spec_prep_post	%{___build_post}
%define ___build_post	exit 0
%define __spec_prep_cmd /bin/sh
%define __build_cmd /bin/sh
%define __spec_build_cmd %{__build_cmd}
%define __spec_build_template	#!%{__spec_build_shell}

%define _target_os Linux


Summary: Submit/Dataserver java runtime libraries for Software Assurance Marketplace (SWAMP)
Name: swamp-rt-java
Version: %(perl -e 'print $ENV{RELEASE_NUMBER}')
Release: %(perl -e 'print $ENV{BUILD_NUMBER}')
License: Apache 2.0
Group: Development/Tools
Source: runtime.tar.gz
URL: http://www.continuousassurance.org
Vendor: The Morgridge Institute for Research
Packager: Support <support@continuousassurance.org>
BuildRoot: /tmp/%{name}-buildroot
BuildArch: noarch
Obsoletes: swamp-rt

%description
This RPM contains the runtime Java
A state-of-the-art facility designed to advance our nation's cybersecurity by improving the security and reliability of open source software.

%prep
%setup -c

%build
echo "Here's where I am at build $PWD"
cd ../BUILD/%{name}-%{version}
%install
echo rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/tmp
cp jre.tar $RPM_BUILD_ROOT/tmp


%clean
rm -rf $RPM_BUILD_ROOT

%post
cd $RPM_BUILD_ROOT/opt
tar xf $RPM_BUILD_ROOT/tmp/jre.tar
chown -R swa-daemon:swa-daemon /opt/jdk1.8.0_45

%postun 
# Only remove things if this is an uninstall
if [ "$1" = "0" ] 
then
/bin/rm -rf /opt/jdk1.8.0_45
fi


%files
%defattr(-,swa-daemon, swa-daemon)
#%doc README TODO COPYING ChangeLog
/tmp/jre.tar
