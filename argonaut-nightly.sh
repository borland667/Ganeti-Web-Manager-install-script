#!/bin/bash
argonaut_pkg_list="libpoe-component-schedule-perl libpoe-component-server-jsonrpc-perl argonaut-fuse argonaut-fai-client argonaut-fai-mirror argonaut-fai-nfsroot argonaut-common argonaut-server"
zulutime=`date -u +%y%m%d%H%M`
repo_dir="/var/www/argonaut-beta"
repo_origin="Fusion Directory"
repo_label="Argonaut"
repo_description="Argonaut APT Repository"
builddir="$HOME/builder"
git_repo="http://git.fusiondirectory.org/main/argonaut.git"
#build_tool="pdebuild"
build_tool="dpkg-buildpackage -b"
version="1.0"
make_repo="1"
###################### DON'T TOUCH AFTER THIS LINE ######################################
if [ "$USER" != "root" ]; then
        echo "Must be root to execute script..."
        exit 1
fi

if [ ! -d "$builddir" ]; then
  echo "Current build directory does not exist:"
  echo $builddir
  echo "Configure and/or create a build directory then try again..."
  exit 1
fi

cd $builddir
rm -Rf argonaut/argonaut-agents
#FIXME: For the moment we use the development branch.  Perhaps in future this
#       will not be wise?
git clone -b develop $git_repo
cd argonaut
apt-get install reprepro

if [ ! -d /var/cache/pbuilder/base.tgz ] && [ "$build_tool" = "pdebuild" ]; then
  echo "No pbuilder cache.  Building one will require time, and"
  echo "downloading an entire build environment from the net."
  echo "Ctrl-C to exit, or any other key to continue..."
  read dummy
  pbuilder create
fi

if [ "$build_tool" = "dpkg-buildpackage -b" ]; then
  apt-get -y --allow-unauthenticated install libclass-singleton-perl libpoe-perl libdatetime-locale-perl libparams-validate-perl libset-infinite-perl libdatetime-timezone-perl libdatetime-locale-perl libfilter-perl liblist-moreutils-perl libparams-validate-perl libset-infinite-perl libdatetime-set-perl libdatetime-perl libpoe-perl dpkg-dev
fi

echo $argonaut_pkg_list|tr [:blank:] '\n'|while read package
do
  cd $package
  # Change package version to include tilde (ie. ~) and time in zulu format
  sed -i 's@'$package' ([-.[:digit:]]*@&~'$zulutime'@' ./debian/changelog
  #version=`cut -d' ' -f2 ./debian/changelog | sed -e 's/[()]//g' | sed -e 's/--//g'`
  echo $version
  echo $package
  tar --exclude=debian -cvzf ../"$package"_"$version".orig.tar.gz ../$package/
  $build_tool
  cd ..
done

if [ $make_repo = 1 ]; then

  rm -Rf $repo_dir

  mkdir -p $repo_dir/conf
  mkdir $repo_dir/override
  
  touch $repo_dir/conf/override.squeeze
  
  cat > $repo_dir/conf/distributions <<-EOF
	Origin: $repo_origin
	Label: $repo_label
	Codename: squeeze
	Architectures: i386 amd64 source
	Components: main
	Description: $repo_description
	DebOverride: override.squeeze
	DscOverride: override.squeeze
	DebIndices: Packages Release . .gz .bz2
	UDebIndices: Packages . .gz .bz2
	DscIndices: Sources Release .gz .bz2
	Contents: . .gz .bz2
EOF
  
  cd $repo_dir
  reprepro includedeb squeeze $builddir/argonaut/*.deb
fi
