#! /bin/bash -e

# This script installs and runs RightLink at boot and is meant to be run as an
# include-script for cloud-init. For further details, see
# http://docs.rightscale.com/rl10/reference/rl10_cloud_init_installation.html

# Create a log file
echo "Logging to /var/log/rightlink.log" 1>&2
exec > >(tee -a /var/log/rightlink.log)
exec 2>&1
# Sleep command added on exit ensure output to stdout finishes before returning to command prompt
trap "sleep 1" EXIT
touch /var/log/rightlink.log && chmod 600 /var/log/rightlink.log

# Determine if /usr/local/bin is read-only. If so, use /opt/bin to install executables
mkdir -p /usr/local/bin || true
[ -w /usr/local/bin ] && BIN_DIR=/usr/local/bin || BIN_DIR=/opt/bin

# Where to download the install package from, note that 10.6.0 and df38b3076ff28866daccf125e0fc71c120f670da
# gets replaced by the branch name in the CI build process
RL_INSTALL_VERSION=10.6.0
RL_INSTALL_SHA=df38b3076ff28866daccf125e0fc71c120f670da
URL="https://github.com/gonzalez/rll/raw/master/rightlink.tgz"
RL=$BIN_DIR/rightlink
RSC=$BIN_DIR/rsc

if [[ ! "$PATH" =~ $BIN_DIR ]]; then
  export PATH="$PATH:$BIN_DIR"
fi

echo "`date` Starting launch-time RightLink 10.6.0 install."

# We check this early to avoid unneeded s3 calls
# If a version of RightLink is already installed we compare it to the downloaded version and use the
# downloaded version if it is different than the current installed version
if [[ -x "$RL" && -x "$RSC" ]]; then
  current_version_info=$($RL --version | cut -d" " -f2,7)
  if [[ "$current_version_info" == "$RL_INSTALL_VERSION $RL_INSTALL_SHA" ]]; then
    echo "RightLink $current_version_info is already installed in $RL"
    echo "Skipping re-installation. RightLink should be started by existing init script."
    exit 0
  else
    echo "Installed version of RightLink is different than version specified by tag."
    echo "RightLink $current_version_info found, installing RightLink $RL_INSTALL_VERSION $RL_INSTALL_SHA."
  fi
fi

# ===== Download and Expand RightLink
echo "Downloading tarball from $URL, extracting into /tmp/rightlink"
cd /tmp
rm -rf rightlink rightlink.tgz
for s in 2 4 6 8 12 16 20 24 32 64; do
  if wget -q -O rightlink.tgz $URL 2>/dev/null || curl -s -o rightlink.tgz $URL ; then
    break
  fi
  echo "`date` Download error, sleeping $s seconds"
  sleep $s
done
# Expand the archive into /tmp/rightlink
tar zxf rightlink.tgz
cd rightlink

# ===== Install RightLink
# Upgrade style scenario -- keep whats already there
install_networking_scripts_flag="-n"
if ! [[ -e /usr/local/share/rightnetwork/uninstall.sh ]]; then
  install_networking_scripts_flag="-n"
fi

# install and start
chmod +x ./install.sh
./install.sh -s $install_networking_scripts_flag

# clean up
rm -fr /tmp/rightlink /tmp/rightlink.tgz

echo "`date` Launch-time RightLink 10.6.0 install complete."
