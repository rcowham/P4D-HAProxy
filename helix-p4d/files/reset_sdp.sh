#!/bin/bash
#==============================================================================
# Copyright and license info is available in the LICENSE file included with
# this package, and also available online:
# https://swarm.workshop.perforce.com/view/guest/perforce_software/helix-installer/main/LICENSE
#------------------------------------------------------------------------------

#==============================================================================
# Declarations
set -u
declare Version=3.14.1

# The latest SDP release tarfile has a consistent name, SDP.Unix.tgz,
# alongside the version-named tarball (e.g. sdp.Unix.2019.2.25938.tgz).
# This is best when you want the latest officially released SDP.

# An alternate install method uses Helix native DVCS features to get the very
# latest code from a branch ('dev' by default) using a 'p4 clone' command.
# Alternately, the '-d' flag can be used to copy from a local directory.
declare SDPTar="sdp.Unix.tgz"
declare SDPDir="/sdp"
declare SDPURL="https://swarm.workshop.perforce.com/projects/perforce-software-sdp/download/downloads/$SDPTar"
declare SDPInstallMethod=FTP
declare SDPInstallBranch=Unset
declare FTPURL="http://ftp.perforce.com/perforce"
declare WorkshopPort="public.perforce.com:1666"
declare WorkshopUser=ftp
declare WorkshopRemote=
declare HelixInstallerBaseURL="https://swarm.workshop.perforce.com/download/guest/perforce_software/helix-installer"
declare HelixInstallerBranch="main"
declare HelixInstallerURL="$HelixInstallerBaseURL/$HelixInstallerBranch"
declare HelixInstallerFileURL=
declare HxDepots=/hxdepots
declare HelixInstallerFiles="NoTicketExpiration.group.p4s admin.user.p4s configure_sample_depot_for_sdp.sh p4broker_N.service.t p4broker_N.xml.t p4d_N.service.t p4d_N.xml.t p4p_N.service.t perforce_bash_profile perforce_bashrc protect.p4s r"
declare ResetHome="$HxDepots/reset"
declare HxMetadata=/hxmetadata
declare HxLogs=/hxlogs
declare SDPHome="$HxDepots/sdp"
declare TmpFile=/tmp/tmp.reset_sdp.$$.$RANDOM
declare TmpDir=/tmp/tmp.dir.reset_sdp.$$.$RANDOM
declare ShelvedChange=Unset
declare LocalShelvedChange=Unset
declare CmdLine="${0##*/} $*"
declare -i WarningCount=0
declare -i ErrorCount=0
declare InitMechanism=Unset
declare PackageManager=Unset
declare -A PackageList
declare -A Config ConfigDoc
declare ExesDir="$HxDepots/exes"
declare DownloadsDir="$HxDepots/downloads"
declare -i BlastDownloadsAndExes=0
declare -i StopAfterReset=0
declare -i ExtremeCleanup=0
declare -i FastMode=0
declare -i LoadSampleDepot=1
declare -i PullFromWebAsNeeded=1
declare -i UseSSL=1
declare -i GenDefaultConfig=0
declare -i UseConfigFile=0
declare ConfigFile=Unset
declare PreserveDirList=Unset
declare P4ExeRel=r19.2
declare P4APIRel=r19.2
declare RunUser=
declare RunUserNewHomeDir=
declare RunUserHomeDir=
declare RunGroup=Unset
declare UserAddCmd=
declare SudoersFile=
declare SudoersEntry=
declare P4YumRepo="/etc/yum.repos.d/perforce.repo"
declare P4AptGetRepo="/etc/apt/sources.list.d/perforce.list"
declare PerforcePackageRepoURL="https://package.perforce.com"
declare PerforcePackagePubkeyURL="$PerforcePackageRepoURL/perforce.pubkey"
declare TmpPubKey=/tmp/perforce.pubkey
declare -i AddPerforcePackageRepo=1
declare SampleDepotTar=
declare ApiArch=
declare ThisArch=
declare ThisHost=
declare ThisOS=
declare ThisOSName=
declare ThisOSDistro=
declare ThisOSMajorVersion=
declare FirewallType=
declare FirewallDir=
declare ThisUser=
declare RunArch="x86_64"
declare CBIN="/p4/common/bin"
declare CCFG="/p4/common/config"
declare SDPSetupDir="$SDPHome/Server/Unix/setup"
declare SDPConfigDir="$SDPHome/Server/Unix$CCFG"
declare ThisScript="${0##*/}"
declare SDPInstances="1"
declare SDPDefaultInstance=
declare OSTweaksScript="$SDPSetupDir/os_tweaks.sh"

#------------------------------------------------------------------------------
# Static Configuration - Package Lists

# The associative array 'PackageList' defines packages required for each
# package manager (yum, apt-get, or zypper).
PackageList['yum']="curl gcc gcc-c++ mailx make openssl openssl-devel rsync wget zlib zlib-devel"
PackageList['apt-get']="build-essential libssl-dev make zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev"
PackageList['zypper']="curl gcc gcc-c++ make openssl openssl-devel wget zlib zlib-devel"

#------------------------------------------------------------------------------
# Static Configuration - User Config Data

# User modifiable data is defined in the 'Config' associative array, with
# corresponding user documentation in the 'ConfigDoc' array, corresponding
# to the settings.cfg file the user modifies.

# To add a new setting, define values for both Config['YourNewValue] and
# ConfigDoc['YourNewValue]' in this block. Also, ensure the values are written
# in the appropriate section of the sample config file generated in the
# function gen_default_config().

ConfigDoc['OSUSER']="\\n# Specify the Linux Operating System account under which p4d and other Helix\\n# services will run as. This user will be created if it does not exist."
Config['OSUSER']="perforce"
ConfigDoc['OSGROUP']="\\n# Specify the primary group for the Linux Operating System account specified\\n# as OSUSER."
Config['OSGROUP']="perforce"
ConfigDoc['OSUSER_ADDITIONAL_GROUPS']="\\n#Specify a comma-delimited list of any additional groups the OSUSER to be\\n# created should be in.  This is passed to the 'useradd' command the '-G'\\n# flag. These groups must already exist."
Config['OSUSER_ADDITIONAL_GROUPS']=
ConfigDoc['OSUSER_HOME']="\\n# Specify home directory of the Linux account under which p4d and other Helix\\n# services will run as, and the group, in the form <user>:<group>.  This user\\n# and group will be created if they do not exist."
Config['OSUSER_HOME']="/home/perforce"
ConfigDoc['DNS_name_of_master_server']="\\n# Specify the DNS alias to refer to he master server, e.g. by end\\n# users. This might be 'perforce' but probably not an actual host name\\n# like 'perforce01', which would be known only to admins."
Config['DNS_name_of_master_server']="helix"
ConfigDoc['P4AdminList']="\\n# Specify an email address to receive updates from admin scripts. This may be\\n# a distribution list or comma-separated list of addresses (with no spaces)."
Config['P4AdminList']="P4AdminList@p4demo.com"
ConfigDoc['MailFrom']="\\n# Specify an email address from which emails from admin scripts are sent.\\n# This must be a single email address."
Config['MailFrom']="P4Admin@p4demo.com"
ConfigDoc['P4APIRel']="\\n# The version of the C++ API to be downloaded, for building dervied APIs such\\n# as P4Perl and P4Python.  This is typically the same as P4ExeRel, but\\n# sometimes behind as P4Perl and P4Python can lag behind Helix Core releases."
Config['P4APIRel']="$P4APIRel"
ConfigDoc['P4ExeRel']="\\n# The version Helix executables to be downloaded: p4, p4d, p4broker, and p4p."
Config['P4ExeRel']="$P4ExeRel"
ConfigDoc['SMTPServer']="\\n# Specify email server for the p4review script. Ignore if Helix Swarm is used."
Config['SMTPServer']="smtp.p4demo.com"
ConfigDoc['P4USER']="\\n# Set the P4USER value for the Perforce super user."
Config['P4USER']="perforce"
ConfigDoc['Password']="\\n# Set the password for the super user (see P4USER). If using this Helix Installer to\\n# bootstrap a production installation, replace this default password with your own."
Config['Password']="F@stSCM!"
ConfigDoc['P4_PORT']="\\n# Specify the TCP port for p4d to listen on. Typically this is 1999 if \\n# p4broker is used, or 1666 if only p4d is used."
Config['P4_PORT']="1999"
ConfigDoc['P4BROKER_PORT']="\\n# Specify the TCP port for p4broker to listen on. Must be different\\n# from the P4_PORT."
Config['P4BROKER_PORT']="1666"
ConfigDoc['SiteTag']="\\n# Specify a geographic site tag for the master server location,\\n# e.g. 'bos' for Boston, MA, USA."
Config['SiteTag']="bos"
ConfigDoc['SimulateEmail']="\\n# Specify '1' to avoid sending email from admin scripts, or 0 to send\\n# email from admin scripts."
Config['SimulateEmail']="1"
ConfigDoc['Instance']="\\n# Specify SDP instance name, e.g. '1' for /p4/1."
Config['Instance']="1"
ConfigDoc['CaseSensitive']="\\n# Helix Core case sensitivity, '1' (sensitive) or '0' (insensitive). If\\n# data from a checkpoint is to be migrated into this instance, set this\\n# CaseSensitive value to match the case handling of the incoming data set\\n# (as shown with 'p4 info')."
# value to match the incoming data set."
Config['CaseSensitive']="1"

#------------------------------------------------------------------------------
# Function: usage (required function)
#
# Input:
# $1 - style, either -h (for short form) or -man (for man-page like format).
#------------------------------------------------------------------------------
function usage
{
   declare style=${1:--h}

   msg "USAGE for $ThisScript v$Version:

$ThisScript [-B|-local] [-fast] [-c <cfg>] [-no_ssl] [-no_sd] [-no_ppr] [[-d <sdp_dir>] | [-b <branch>[,@cl]]] [-p <dir1>[,<dir2>,...]>] [-i <helix_installer_branch>] [-D] [-X|-R]

or

$ThisScript -C > settings.cfg

or

$ThisScript [-h|-man]
"
   if [[ $style == -man ]]; then
      msg "
SAFETY NOTICE:
	This script SHOULD NEVER EXIST on a Production Perforce server.

DESCRIPTION:
	This script simplifies the process of testing an SDP installation,
	repetitively blasting all process by the 'perforce' user and resetting
	the SDP from the ground up, blasting typical SDP folders each time.

	It installs the Perforce Helix Core server (P4D) with a P4Broker,
	and installs the Perforce Sample Depot data set used for training
	and PoC installations.

	It is helpful when bootstrapping a demo server with a sample data
	set, complete with broker, and optionally Perl/P4Perl and
	Python/P4Python.

	This script handles all aspects of installation. It does the
	following:
	* Creates the perforce OS user, if needed.
	* Creates the home directory for the perforce user, if needed.
	* Adds OS packages as needed for P4Perl/P4Python local builds.

	Following installation, it also does the following to be more
	convenient for demos, and also give a more production-like feel:
	* Grants the perforce user sudo access.
	* Creates default ~perforce/.bash_profile and .bashrc files.
	* Connects to the Perforce Package Repository (APT and YUM only).
	* Adds firewalld rules for Helix server and broker ports ('firewalld'
	only).

PLATFORM SUPPORT:
	This works on Red Hat Enterprise Linux, CentOS, and Mac OSX
	10.10+ thru Mojave platforms.  It works on RHEL/CentOS
	6.4-7.6, SuSE Linux 12, and likely on Ubuntu 18 and other Linux
	distros with little or no modification.

	This script currently supports the bin.linux26x86_64 (Linux) and
	bin.maxosx1010x86_64 (Mac OSX/Darwin) architectures.

	This script recognizes SysV, Systemd, and Launchd init mechanisms,
	though does not currently support Launchd on OSX.

	For Mac OSX, note that this requires bash 4.x, and the default
	bash on Mac OSX remains 3.x as of OSX Mojave.  For operating on
	Mac, the /bin/bash shebang line needs to be adjusted to reference
	a bash 4 version, e.g. /usr/local/bin/bash if installed with
	Homebrew.

REQUIREMENTS:
	The following OS packages are installed (unless '-fast' is
	used):

	* Yum: ${PackageList[yum]}

	* AptGet: ${PackageList[apt-get]}

	* Zypper: ${PackageList[zypper]}

	Development utilities such as 'make', the 'gcc' compiler,
	and 'curl' must be installed and available in the PATH (unless
	running with '-fast').  The package installation as noted
	above generally ensures these dependencies are available.

OPTIONS:
 -c <cfg>
	Specify a config file.  By default, values for various settings
	such as the email to send script logs to are configure with
	demo values, e.g. ${Config['P4AdminList']}.  Optionally, you can
	specify a config file to define your own values.

	For details on what settings you can define in this way, run:
	$ThisScript -C > setings.cfg

	Then modify the generated config file settings.cfg as desired.
	The generated config file contains documentation on settings and
	values.  If no changes are made to the generated file, running with
	'-c settings.cfg' is the equivalent of running without using '-c' at
	all.

 -C	See '-c <cfg>' above.

 -B	Specify '-B' to blast base SDP dirs, for a clean start.

	Otherwise without '-B', downloaded components from earlier
	runs will be used (which should be fine if they were run
	recently).

	The '-B' flag also replaces files in the $ResetHome
	directory, where this script lives, with those downloaded
	from The Workshop (the versions of which are affected
	by the '-i <helix_installer_branch>' flag, described
	below).

	The '-B' flag also blasts the /tmp/downloads and /tmp/p4perl
	directories, used by install_sdp_python.sh and
	install_sdp_perl.sh, if they exist.

 -local
	By default, various files and executables are downloaded from
	the Perforce Workshop or the Perforce FTP server as needed.
	With '-local', any missing files are treated as an error
	condition.

	The '-local' argument cannot be used with -B.

 -fast	Specify '-fast' to skip installation SDP Perl and
	SDP Python, to include P4Perl and P4Python.

	The '-fast' argument changes a check for GCC/G++
	from a fatal error to a warning message.

	The '-fast' option typically takes just a few minutes,
	as compared to 20+ minutes without due to the time
	needed to compile and test the Perl and Python bits.

	The '-fast' flag should not be used if you plan to
	deploy or develop triggers that use P4Python or P4Perl,
	such as the SDP CheckCaseTrigger.py.  Alternately, you
	can run with '-fast', and then afterward run the
	following as the configured OSUSER ('$RunUser' by default):

	cd $SDPSetupDir
	./install_sdp_python.sh
	./install_sdp_perl.sh

 -no_ssl
	By default, the Perforce server is setup SSL-enabled.  Specify
	'-no_ssl' to avoid using SSL feature.

 -no_sd
	By default, the Perforce Sample Depot data set is loaded.
	Specify '-no_sd' to skip loading the Sample Depot.

 -no_ppr
	Skip addition of the Perforce Package Repository for YUM/APT
	repos.  By default, the Package Repository is added.

 -p <dir1>[,<dir2>,...]>]
	Specify a comma-delimited list of directories under /p4/common
	to preserve that would otherwise be removed.  Directories must
	be specified as paths relative to /p4/common, and cannot contain
	spaces.

	For example, the value '-p config,bin/triggers' would preserve the
	$CCFG and $CBIN/triggers directories.

	Directories specified are moved aside to a temporary working area
	before the SDP folders are removed.  After installation, they are
	moved back via an 'rsync' command with no '--delete' option.  This
	means any files that overlap with the stock install are replaced
	by ones that originally existed, but non-overlapping files are not
	removed.

	This is intended to be useful for developing test suites that
	install server under $CBIN, e.g. Component Based Development
	scripts which install under $CBIN/cbd would use '-p bin/cbd'.

 -d <sdp_dir>
	Specify a directory on the local host containing the SDP to deploy.

	Use the special value '-d default' to use the /sdp directory (as per
	the Docker-based SDP Test Suite environment).

	The directory specified by '-d' is expected to contain either:
	* an SDP tarball ($SDPTar) file, or
	* an already-extracted SDP directory, which must include the SDP
	Version file.

 -b <branch>[,@cl]
	The default SDP install method is to use the latest released SDP
	tarball representing the main branch in The Workshop ($WorkshopPort).

	The latest tarball can be found on this server, consistently named
	$SDPTar. This file appears alongside a version-tagged file
	named something like sdp.Unix.2019.2.25938.tgz.  These appear here:
	https://swarm.workshop.perforce.com/projects/perforce-software-sdp/files/downloads

	Specify '-b' to use a different branch, typicall '-b dev'.  This
	changes the install method from a tarball to using a 'p4 clone'
	command using Helix native DVCS features to fetch the very latest
	unreleased files from the branch at any point in time. This is mainly
	of interest when testing the SDP or previewing specific up and
	coming features.

	If '-b' is specified with the optional @cl syntax, where @cl
	specifies a changelist with files shelved on the given branch,
	a form of unshelving is done, enabling a workflow for testing
	shelved changes with the Helix Installer.  So for example,
	specify '-b dev,@23123' to clone from the dev branch, and then
	followed by a fetch of shelved changelist @23123, which is
	expected to have files shelved in the dev branch.

DEBUGGING OPTIONS:
 -i	<helix_installer_branch>

	Specify the branch of the Helix Installer to use.  This affects the
	URL from which Helix Installer files in $ResetHome are pulled from
	The Workshop.  The default is main; an alternative is '-i dev'.

 -D     Set extreme debugging verbosity.

 -X	Extreme reset. This removes the user accout for the configured
	OSUSER ('$RunUser' by default) and blasts all SDP-related directories
	at the start of script operations, including the home directory
	for the configured OSUSER.

	This also clears firewall rules ('firewalld' only).

	Using '-X' does not blast the Helix Installer downloads or exes
	directories, and thus is compatible with either the '-B' or '-local'
	options.

 -R	Specify '-R' to reset.  The cleanup logic is the same as with
	-X.  Unlike -X, with -R, processing stops after the cleanup is
	done.

HELP OPTIONS:
 -h	Display short help message
 -man	Display man-style help message

EXAMPLES:
	=== FAST INSTALLATION (skipping Perl, Python) ===

	su -
    	mkdir -p /hxdepots/reset
	cd /hxdepots/reset
	curl -k -s -O $HelixInstallerURL/src/$ThisScript
	curl -k -s -O $HelixInstallerURL/src/r
	chmod +x ${ThisScript} r
	./r

	Note that the 'r' wrapper script calls the $ThisScript script with
	a pre-defined of flags optimized for fast opreration.  The 'r' wapper
	also handles log capture, writing to the file '${ThisScript/sh/log}'.

	=== COMPREHENSIVE INSTALLATION ===

	su -
    	mkdir -p /hxdepots/reset
	cd /hxdepots/reset
	curl -k -s -O $HelixInstallerURL/src/$ThisScript

	chmod +x $ThisScript
	./$ThisScript 2>&1 | tee ${ThisScript/sh/log}

	=== CONFIGURED INSTALLATION ===

	su -
    	mkdir -p /hxdepots/reset
	cd /hxdepots/reset
	curl -k -s -O $HelixInstallerURL/src/$ThisScript
	chmod +x $ThisScript

 	### Generate a default config file:
	./$ThisScript -C > settings.cfg

 	### Edit settings.cfg, changing the values as desired:
	vi settings.cfg

	./$ThisScript -c settings.cfg 2>&1 | tee log.reset_sdp

	=== SDP DEV BRANCH TESTING ===

	The Helix Installer can be used to test SDP changes shelved to the SDP
	dev branch in The Workshop.  The following example illustrates testing
	a change in shelved changelist 23123:

	su -
    	mkdir -p /hxdepots/reset
	cd /hxdepots/reset
	curl -k -s -O $HelixInstallerURL/src/reset_sdp.sh

	./reset_sdp.sh -b dev,@23123 2>&1 | tee log.reset_sdp.CL23123

	After the first test, an iterative test cycle may follow on the same
	shelved changelist. For each test iteration, the shelved changelist
	is first updated in the workspace from which the change was originally
	shelved, e.g. with a command like 'p4 shelve -f -c 23123'.

	Then a new test can be done by calling reset_sdp.sh with the same
	arguments. The script will re-install the SDP cleanly, and then
	re-apply the updated shelved changelist.

	=== SDP TEST SUITE SUPPORT ===

	The Helix Installer can install the SDP in the Docker-based SDP
	Test Suite.  In that environment, the directory /sdp appears on
	the test VMs, shared from the host machine.  To deploy that SDP,
	use the '-d <sdp_dir>' flag, something like this:

	./reset_sdp.sh -d /sdp -fast 2>&1 | tee log.reset_sdp.test

"
   fi

   exit 1
}

#------------------------------------------------------------------------------
# Functions msg(), dbg(), and bail().
# Sample Usage:
#    bail "Missing something important. Aborting."
#    bail "Aborting with exit code 3." 3
function msg () { echo -e "$*"; }
function warnmsg () { msg "\\nWarning: ${1:-Unknown Warning}\\n"; WarningCount+=1; }
function errmsg () { msg "\\nError: ${1:-Unknown Error}\\n"; ErrorCount+=1; }
function dbg () { msg "DEBUG: $*" >&2; }
function bail () { errmsg "${1:-Unknown Error}"; exit "${2:-1}"; }

#------------------------------------------------------------------------------
# Functions run($cmd, $desc)
#
# This function is similar to functions defined in SDP core libraries, but we
# need to duplicate them here since this script runs before the SDP is
# available on the machine (and we require dependencies for this
# script).
function run {
   cmd="${1:-echo Testing run}"
   desc="${2:-}"
   [[ -n "$desc" ]] && msg "$desc"
   msg "Running: $cmd"
   $cmd
   CMDEXITCODE=$?
   return $CMDEXITCODE
}

#------------------------------------------------------------------------------
# Function: gen_default_config()
#
# Generate a sample settings.cfg file.
function gen_default_config {
   echo -e "\
#------------------------------------------------------------------------------
# Config file for $ThisScript v$Version.
#------------------------------------------------------------------------------
# This file is in bash shell script syntax.
# Note: Avoid spaces before and after the '=' sign.

# For demo and training installations, usually all defaults in this file
# are fine.

# For Proof of Concept (PoC) installation, Section 1 (Localization) settings
# should all be changed to local values. Some settings in Section 2 (Data
# Specific) might also be changed.

# Changing settings in Section 3 (Deep Customization) is generally
# discouraged unless necessary when bootsraping a prodction installation or
# a high-realism PoC.

#------------------------------------------------------------------------------
# Section 1: Localization
#------------------------------------------------------------------------------
# Changing all these is typical and expected, even for PoC installations."

   for c in SMTPServer P4AdminList MailFrom DNS_name_of_master_server SiteTag; do
      echo -e "${ConfigDoc[$c]}"
      echo "$c=${Config[$c]}"
   done

echo -e "
#------------------------------------------------------------------------------
# Section 2: Data Specific
#------------------------------------------------------------------------------
# These settings can be changed to desired values, though default values are
# preferred for demo installations."

   for c in P4_PORT P4BROKER_PORT Instance CaseSensitive P4USER Password SimulateEmail; do
      echo -e "${ConfigDoc[$c]}"
      echo "$c=${Config[$c]}"
   done

echo -e "
#------------------------------------------------------------------------------
# Section 3: Deep Customization
#------------------------------------------------------------------------------
# Changing these settings is gently discouraged, but may be necessary for
# bootstrapping some production environments with hard-to-change default
# values for settings such as OSUSER, OSGROUP, etc."
   for c in OSUSER OSGROUP OSUSER_ADDITIONAL_GROUPS OSUSER_HOME P4ExeRel P4APIRel; do
      echo -e "${ConfigDoc[$c]}"
      echo "$c=${Config[$c]}"
   done
}

#==============================================================================
# Command Line Processing

declare -i shiftArgs=0
set +u

while [[ $# -gt 0 ]]; do
   case $1 in
      (-B) BlastDownloadsAndExes=1;;
      (-local) PullFromWebAsNeeded=0;;
      (-fast) FastMode=1;;
      (-no_ssl) UseSSL=0;;
      (-no_sd) LoadSampleDepot=0;;
      (-no_ppr) AddPerforcePackageRepo=0;;
      (-C) GenDefaultConfig=1;;
      (-c) ConfigFile="$2"; UseConfigFile=1; shiftArgs=1;;
      (-d)
         SDPInstallMethod=Copy
         [[ "$2" == "default" ]] || SDPDir="$2"
         shiftArgs=1
      ;;
      (-b)
         # If we are pulling from main and not using the ',@' sytnax,
         # stick with tarball installation. Otherwise, switch to cloning
         # from the specifiec branch (typically dev).
         if [[ "$2" == *",@"* ]]; then
            SDPInstallMethod=DVCS
            SDPInstallBranch=${2%%,@*};
            ShelvedChange=${2##*,@}
         else
            SDPInstallBranch=$2;
            [[ "$SDPInstallBranch" == "main" ]] || SDPInstallMethod=DVCS
         fi
         shiftArgs=1
      ;;
      (-p) PreserveDirList=$2; shiftArgs=1;;
      (-h) usage -h;;
      (-man) usage -man;;
      (-D) set -x;; # Debug; use 'set -x' mode.
      (-X) ExtremeCleanup=1;;
      (-R) ExtremeCleanup=1; StopAfterReset=1;;
      (-i) HelixInstallerBranch="$2"; shiftArgs=1;;
      (*) bail "Usage Error: Unknown arg ($1).";;
   esac

   # Shift (modify $#) the appropriate number of times.
   shift; while [[ $shiftArgs -gt 0 ]]; do
      [[ $# -eq 0 ]] && bail "Usage Error: Wrong number of args or flags to args."
      shiftArgs=$shiftArgs-1
      shift
   done
done
set -u

#------------------------------------------------------------------------------
# Command Line Validation

[[ "$UseConfigFile" -eq 1 && "$GenDefaultConfig" -eq 1 ]] && \
   bail "The '-c <cfg>' and '-C' options are mutually exclusive."

#------------------------------------------------------------------------------
# Main Program

ThisUser="$(whoami)"
ThisOS="$(uname -s)"
ThisArch="$(uname -m)"
ThisHost="$(hostname -s)"
declare -i CMDEXITCODE

#------------------------------------------------------------------------------
# Special Mode:  Generate Default Config File
# In this mode, generate a sample config file on stdout, and exit.

if [[ "$GenDefaultConfig" -eq 1 ]]; then
   gen_default_config
   exit 0
fi

#------------------------------------------------------------------------------
# Regular processing mode.

msg "Started $ThisScript v$Version on host $ThisHost at $(date), called as:\\n\\t$CmdLine"

if [[ "$UseConfigFile" -eq 1 ]]; then
   [[ -r "$ConfigFile" ]] || \
      bail "Config file specified with '-c $ConfigFile' is not readable."
   for c in "${!Config[@]}"; do
      value=$(grep ^$c= "$ConfigFile")
      value="${value#*=}"
      Config[$c]="$value"
   done
   SDPInstances="${Config['Instance']}"
   RunGroup="${Config['OSGROUP']}"
   RunUserNewHomeDir="${Config['OSUSER_HOME']}"
else
   # We want to know whether RunGroup was set explicitly in the settings.cfg
   # file or not.  If not, we set it to the value of 'Unset', enabling
   # OS-dependent logic to below to supply a platform-specific default.
   # We don't want platform-specific defaults to overrided values explicilty
   # defined in settings.cfg if that is used.
   RunGroup=Unset

   # Similarly, we want to apply the home directory specified in account
   # creation if it was defined in settings.cfg, but not otherwise.
   RunUserNewHomeDir=Unset
fi

# After theconfiguration data is loaded, set variables that depend on
# the loaded configuration.
SDPDefaultInstance="${SDPInstances%% *}"
RunUser="${Config['OSUSER']}"
SudoersFile="/etc/sudoers.d/$RunUser"
SudoersEntry="$RunUser ALL=(ALL) NOPASSWD: ALL"

# Get just enough detailed OS info in order to fill in
# details in the Perforce pacakge repository files.
if [[ "$ThisOS" == "Linux" ]]; then
   if [[ -r "/etc/redhat-release" ]]; then
      if grep ' 6\.' /etc/redhat-release > /dev/null; then
         ThisOSMajorVersion="6"
      elif grep ' 7\.' /etc/redhat-release > /dev/null; then
         ThisOSMajorVersion="7"
      fi
      [[ -n "$ThisOSMajorVersion" ]] || \
         warnmsg "Could not determine OS Major Version from contents of /etc/redhat-release."
   elif [[ -r "/etc/lsb-release" ]]; then
      ThisOSName=$(grep ^DISTRIB_ID= /etc/lsb-release)
      ThisOSName=${ThisOSName#*=}
      ThisOSName=${ThisOSName,,}
      ThisOSDistro=$(grep ^DISTRIB_CODENAME= /etc/lsb-release)
      ThisOSDistro=${ThisOSDistro#*=}

      [[ -n "$ThisOSName" && -n "$ThisOSDistro" ]] || \
         warnmsg "Could not determine OS Name and Distro from contents of /etc/lsb-release."
   fi

   if [[ -r "/etc/firewalld/services" ]]; then
      FirewallType="Firewalld"
      FirewallDir="/etc/firewalld/services"
   elif [[ -r "/etc/sysconfig/iptables" ]]; then
      FirewallType="IPTables"
      FirewallDir="/etc/sysconfig"
   fi
fi

if [[ "$ThisUser" != root ]]; then
   bail "Run as root, not $ThisUser."
else
   msg "Verified: Running as root user."
fi

[[ "$BlastDownloadsAndExes" -eq 1 && "$PullFromWebAsNeeded" -eq 0 ]] && \
   bail "The '-B' and '-local' arguments are mutually exclusive."

[[ "$SDPInstallBranch" != "Unset" && "$SDPInstallMethod" == "Copy" ]] && \
   bail "The '-b <branch>' and '-d <sdp_dir>' arguments are mutually exclusive."

[[ "$SDPInstallBranch" == Unset ]] && SDPInstallBranch=main

HelixInstallerURL="$HelixInstallerBaseURL/$HelixInstallerBranch"

#------------------------------------------------------------------------------
# Self-update

cd "$ResetHome" || bail "Could not cd to $HxDepots/ResetHome. Aborting."

msg "\\nEnsuring Helix Installer files are available."

for f in $HelixInstallerFiles; do
   HelixInstallerFileURL="$HelixInstallerURL/src/$f"
   if [[ ! -f "$f" ]]; then
      [[ "$PullFromWebAsNeeded" -eq 0 ]] && bail "Missing Helix Installer file [$f] and '-local' specified. Aborting."
      run "curl -k -s -O $HelixInstallerFileURL" "Getting file $f." ||\
         bail "Failed to download from [$HelixInstallerFileURL]. Aborting."
   else
      if [[ "$BlastDownloadsAndExes" -eq 1 ]]; then
         run "curl -k -s -O $HelixInstallerFileURL" \
            "Replacing Helix Installer file $f due to '-B'." ||\
            bail "Failed to download file [$PWD/$f]. Aborting."
      else
         msg "Using existing Helix Installer file $PWD/$f."
      fi
   fi

   if [[ ! -x "$f" ]]; then
      if [[ "$f" == *".sh" || "$f" == r ]]; then
         run "chmod +x $f" "chmod +x" || bail "Failed to do: chmod +x $f. Aborting."
      fi
   fi
done

#------------------------------------------------------------------------------
# Extreme Cleanup with -X
if [[ "$ExtremeCleanup" -eq 1 ]]; then
   msg "\\nStarted Extreme Cleanup due to -X."
   if id -u "$RunUser" > /dev/null 2>&1; then
      RunUserHomeDir="$(eval echo ~"$RunUser")"
      run "pkill -9 -u $RunUser" "Blasting processes by OS user $RunUser." ||\
         warnmsg "Failed to blast all processes by OS user $RunUser."
      sleep 1
      run "userdel $RunUser" "Removing OS user $RunUser." ||\
         warnmsg "Failed to remove OS user $RunUser."

      run "/bin/rm -rf $RunUserHomeDir" "Removing home dir $RunUserHomeDir" ||\
         warnmsg "Failed to remove $RunUserHomeDir."
   else
      msg "Extreme Cleanup: OS User $RunUser does not exist."
   fi

   run "/bin/rm -rf /p4 $HxDepots/p4 $HxMetadata/p4 $HxLogs/p4" \
      "Extreme Cleanup: Blasting several SDP dirs." ||\
      warnmsg "Failed to blast some SDP dirs."

   if [[ "$FirewallType" == "Firewalld" ]]; then
      cd "$FirewallDir" || bail "Could not cd to: $FirewallDir"
      msg "Extreme Cleanup: Removing p4*.xml firewall rules (if any).\\n"
      for svcFile in p4*.xml; do
         [[ -r "$svcFile" ]] || continue
         svcName="${svcFile%.xml}"
	 run "firewall-cmd --permanent --delete-service=$svcName" \
		 "Deleting firewall entry for $svcName" ||\
            warnmsg "Deleting firewall entry for $svcName failed."

         # Firewalld renames the *.xml files to *.xml.old upon deletion of the
         # rule.
         if [[ -r "$PWD/${svcFile}.old" ]]; then
            run "rm -f $PWD/${svcFile}.old" "Removing $PWD/${svcFile}.old" ||\
               warnmsg "Deleting file $PWD/${svcFile}.old failed."
         fi
      done
      run "firewall-cmd --reload" "Firewall reload after cleanup." ||\
         warnmsg "Firewall reload failed after cleanup."
   fi

   if [[ "$StopAfterReset" -eq 0 ]]; then
      msg "Extreme Cleanup complete. Continuing.\\n"
   else
      msg "Extreme Cleanup complete. Stopping.\\n"
      exit 0
   fi
fi

#------------------------------------------------------------------------------
# Digital asset acquisition and availability checks.
[[ ! -d "$HxDepots" ]] && run "/bin/mkdir -p $HxDepots"

cd "$HxDepots" || bail "Could not cd to [$HxDepots]."

if command -v yum > /dev/null; then
   PackageManager="yum"
elif command -v apt-get > /dev/null; then
   PackageManager="apt-get"
elif command -v zypper > /dev/null; then
   PackageManager="zypper"
fi

if [[ -d "/etc/systemd/system" ]]; then
   InitMechanism="Systemd"
elif [[ -x "/sbin/launchd" ]]; then
   InitMechanism="Launchd"
elif [[ -d "/etc/init.d" ]]; then
   InitMechanism="SysV"
fi

if [[ "$FastMode" -eq 0 ]]; then
   msg "Ensuring needed packages are installed."

   if [[ "$ThisOS" != "Darwin" ]]; then
      [[ "$PackageManager" == "Unset" ]] && \
         bail "Could not find one of these package managers: ${!PackageList[*]}"

      run "$PackageManager install -y ${PackageList[$PackageManager]}" \
         "Installing these pacakges with $PackageManager: ${PackageList[$PackageManager]}" ||\
         warnmsg "Not all packages installed successfully.  Proceeding."

      msg "Skipping package dependency checks in -fast mode."
      if ! command -v gcc > /dev/null || ! command -v g++ > /dev/null; then
         msg "Warning: No gcc found in the path.  You may need to install it.  Please\\n check that the gcc and gcc-c++ packages are\\n installed, e.g. with:\\n\\t$PackageManager install -y gcc gcc-c++\\nIgnoring missing gcc/g++ due to '-fast'.\\n"
      else
         msg "Verified: gcc and g++ are available and in the PATH."
      fi
   else
      warnmsg "Skipping package handling on Mac OSX/$ThisOS."
   fi
fi

if [[ "$PullFromWebAsNeeded" -eq 1 ]]; then
   if ! command -v curl > /dev/null; then
      bail "No 'curl' found in the path.  You may need to install it or adjust the PATH for the root user to find it.\\n\\n"
   fi
fi

if ! command -v su > /dev/null; then
   bail "No 'su' found in the path.  You may need to install it or adjust the PATH for the root user to find it.\\n\\n"
fi

if [[ "$ThisArch" == "$RunArch" ]]; then
   msg "Verified:  Running on a supported architecture [$ThisArch]."
   ApiArch=UNDEFINED_API_ARCH
   case $ThisOS in
      (Darwin)
         ApiArch="macosx1010x86_64"
         [[ "$RunGroup" == Unset ]] && RunGroup=staff
         SampleDepotTar=sampledepot.mac.tar.gz
      ;;
      (Linux)
         ApiArch="linux26x86_64"
         # Set a platform-specific value for RunGroup if it wasn't defined
         # explicitly in a settings.cfg file.
         if [[ "$RunGroup" == Unset ]]; then
            if [[ -r "/etc/SuSE-release" ]]; then
               RunGroup=users
            else
               # CentOS, RHEL, and Ubuntu default group is same as user name.
               RunGroup=perforce
            fi
         fi
         SampleDepotTar=sampledepot.tar.gz
      ;;
      (*) bail "Unsupported value returned by 'uname -m': $ThisOS. Aborting.";;
   esac
else
   bail "Running on architecture $ThisArch.  Run this only on hosts with '$RunArch' architecture. Aborting."
fi

# In this block, we just check that directories specified to be preserved
# with the '-p' flag actually exist, in which case we abort before further
# processing.
if [[ "$PreserveDirList" != Unset ]]; then
   for d in $(echo "$PreserveDirList"| tr ',' ' '); do
      preserveDir="$HxDepots/p4/common/$d"
      if [[ -d "$preserveDir" ]]; then
         parentDir=$(dirname "$TmpDir/$d")
         if [[ ! -d "$parentDir" ]]; then
            run "/bin/mkdir -p $parentDir" "Creating parent temp dir [$parentDir]." ||\
               bail "Failed to create parent temp dir [$parentDir]."
         fi
      fi
   done
fi

if [[ "$BlastDownloadsAndExes" -eq 1 ]]; then
   if [[ -d "$ExesDir" ]]; then
      run "/bin/rm -rf $ExesDir" \
         "Blasting exes dir [$ExesDir] due to '-B'." ||\
          warnmsg "Failed to blast exes dir."

      for d in /tmp/downloads /tmp/p4perl; do
         if [[ -d "$d" ]]; then
            run "/bin/rm -rf $d" \
               "Blasting $d dir due to '-B'." ||\
                warnmsg "Failed to blast dir $d."
         fi
      done
   fi
fi

if [[ ! -d "$ExesDir" ]]; then
   [[ "$PullFromWebAsNeeded" -eq 0 ]] && bail "ExesDir [$ExesDir] is missing and '-local' specified. Aborting."
   run "/bin/mkdir -p $ExesDir" ||\
      bail "Could not create dir [$ExesDir]."

   cd "$ExesDir" || bail "Could not cd to $ExesDir."
   msg "Working in [$PWD]."
   run "curl -k -s -O $FTPURL/${Config['P4ExeRel']}/bin.$ApiArch/p4" ||\
      bail "Could not get 'p4' executable."
   run "curl -k -s -O $FTPURL/${Config['P4ExeRel']}/bin.$ApiArch/p4d" ||\
      bail "Could not get 'p4d' executable."
   run "curl -k -s -O $FTPURL/${Config['P4ExeRel']}/bin.$ApiArch/p4p" ||\
      bail "Could not get 'p4p' executable."
   run "curl -k -s -O $FTPURL/${Config['P4ExeRel']}/bin.$ApiArch/p4broker" ||\
      bail "Could not get 'p4broker' executable."

   run "chmod +x p4 p4d p4p p4broker" \
      "Doing chmod +x for downloaded executables."
else
   msg "Using existing exes dir [$ExesDir]."
fi

#------------------------------------------------------------------------------
# Services Shutdown and Cleanup.

if command -v getent > /dev/null; then
   if getent group "$RunGroup" > /dev/null 2>&1; then
      msg "Verified: Group $RunGroup exists."
   else
      run "groupadd $RunGroup" "Creating group $RunGroup." ||\
         bail "Failed to create group $RunGroup."
   fi
fi

if id -u "$RunUser" > /dev/null 2>&1; then
   msg "Verified: User $RunUser exists."
else
   if command -v useradd > /dev/null; then
      UserAddCmd="useradd -s /bin/bash -g $RunGroup"

      # Specify the home dir only if explicitly defined in settings.cfg;
      # otherwise defer to the useradd default.
      [[ "$RunUserNewHomeDir" != Unset ]] && \
         UserAddCmd+=" -d $RunUserNewHomeDir"

      # Specify the -G value to useradd if and only if values for additional
      # groups were defined in settings.cfg.
      [[ -n "${Config['OSUSER_ADDITIONAL_GROUPS']}" ]] && \
         UserAddCmd+=" -G ${Config['OSUSER_ADDITIONAL_GROUPS']}"

      UserAddCmd+=" $RunUser"
      run "$UserAddCmd" "Creating user $RunUser with command: $UserAddCmd" ||\
         bail "Failed to create user $RunUser."

      RunUserHomeDir="$(eval echo ~"$RunUser")"
      if [[ -d "$RunUserHomeDir" ]]; then
         msg "Verified: Home directory for user $RunUser exists."
      else
         run "mkdir -p $RunUserHomeDir" \
            "Creating home dir for $RunUser" ||\
            bail "Failed to create home directory $RunUserHomeDir for OS user $RunUser."
         run "chmod -R $RunUser:$RunGroup $RunUserHomeDir" \
            "Ensuring $RunUser owns home dir $RunUserHomeDir." ||\
            warnmsg "Failed to change ownership of home directory $RunUserHomeDir for OS user $RunUser."
      fi

      run "cp $ResetHome/perforce_bash_profile $RunUserHomeDir/.bash_profile" \
         "Creating $RunUserHomeDir/.bash_profile." ||\
         warnmsg "Failed to copy to $RunUserHomeDir/.bash_profile."

      msg "Creating $RunUserHomeDir/.bashrc."
      sed "s:EDITME_SDP_INSTANCE:$SDPDefaultInstance:g" \
         "$ResetHome/perforce_bashrc" > "$RunUserHomeDir/.bashrc" ||\
         warnmsg "Failed to copy to $RunUserHomeDir/.bashrc."

      run "chown $RunUser:$RunGroup $(eval echo ~"$RunUser")/.bash_profile $(eval echo ~"$RunUser")/.bashrc" "Adjusting perms of .bash_profile and .bashrc." ||\
         warnmsg "Adjusting ownership failed."
   else
      bail "User $RunUser does not exist, and the 'useradd' utility was not found."
   fi
fi

for i in $SDPInstances; do
   if [[ "$ThisOS" == "Linux" || "$ThisOS" == "Darwin" ]]; then
      msg "Stopping Perforce-related servcies for Instance $i."
      for svc in p4d p4broker p4p p4web p4dtg; do
         processCmd="${svc}_${i}"

         # This 'ps' command should work on Linux and Mac (Yosemite+ at least).
         # shellcheck disable=SC2009
         Pids=$(ps -u "$RunUser" -f | grep -v grep | grep "/$processCmd "| awk '{print $2}')

         if [[ -z "$Pids" && $svc == p4d ]]; then
            msg "$processCmd not found for p4d service; looking for _bin variant instead."
            # For the p4d service, the process command may look like 'p4d_1_bin' or just 'p4d_1', so
            # we check for both.
            processCmd="${svc}_${i}_bin"
            # shellcheck disable=SC2009
            Pids=$(ps -u "$RunUser" -f | grep -v grep | grep "/$processCmd "| awk '{print $2}')
         fi

         if [[ -n "$Pids" ]]; then
            run "kill -9 $Pids" \
               "Killing user $RunUser processes for command $processCmd."
            sleep 1
         else
            msg "Verified: No processes by user $RunUser for command [$processCmd] are running."
         fi
      done
   fi

   if [[ "$InitMechanism" == "SysV" ]]; then
      cd /etc/init.d || bail "Could not cd to /etc/init.d."

      msg "Removing Perforce-related SysV services in $PWD."

      for svc in p4*_init; do
         run "chkconfig --del $svc"
         run "rm -f $svc"
      done
   elif [[ "$InitMechanism" == "Systemd" ]]; then
      cd /etc/systemd/system || bail "Could not cd to /etc/systemd/system."

      msg "Disabling and removing Perforce-related Systemd services in $PWD."
      for svcFile in p4*.service; do
         run "systemctl disable ${svcFile%.service}"
         run "rm -f $svcFile"
      done
   fi
done

#------------------------------------------------------------------------------
if [[ -d $DownloadsDir && $BlastDownloadsAndExes -eq 1 ]]; then
   run "/bin/rm -r -f $DownloadsDir" \
      "Blasting downloads dir [$DownloadsDir] due to '-B'."
fi

if [[ ! -d $DownloadsDir ]]; then
   [[ $PullFromWebAsNeeded -eq 0 ]] && bail "DownloadsDir [$DownloadsDir] is missing and '-local' specified. Aborting."
   run "/bin/mkdir -p $DownloadsDir"

   cd "$DownloadsDir" || bail "Could not cd to downloads dir: $DownloadsDir"

   msg "Working in [$PWD]."
   if [[ "$FastMode" -eq 0 ]]; then
      run "curl -k -s -O $FTPURL/${Config['P4APIRel']}/bin.$ApiArch/p4api.tgz" ||\
         bail "Could not get file 'p4api.tgz'"
   else
      msg "Skipping download of p4api.tgz due to '-fast'."
   fi

   if [[ "$SDPInstallMethod" == FTP ]]; then
      run "curl -k -s -O $SDPURL" ||\
         bail "Could not get SDP tar file from [$SDPURL]."
   fi

   if [[ "$LoadSampleDepot" -eq 1 ]]; then
      run "curl -k -s -O $FTPURL/tools/$SampleDepotTar" ||\
         bail "Could not get file [$SampleDepotTar]. Aborting."

      if [[ "$BlastDownloadsAndExes" -eq 1 && -d "PerforceSample" ]]; then
         run "rm -rf "PerforceSample "Blasting dir PerforceSample due to '-B'." ||\
            warnmsg "Failed to cleanly remove Sample Depot dir $PWD/PerforceSample."
      fi

      if [[ ! -d PerforceSample ]]; then
         run "tar -xzpf $SampleDepotTar" "Unpacking $SampleDepotTar in $PWD."
      else
         msg "Using existing extracted Sample Depot dir $PWD/PerforceSample."
      fi

      run "chown -R $RunUser:$RunGroup $DownloadsDir" \
         "Setting ownership on downloads dir." ||\
         bail "Failed to set ownership on downloads dir [$DownloadsDir]. Aborting."
   else
      msg "Skipping download of Sample Depot due to '-no_sd'."
   fi
else
   msg "Using existing downloads dir [$DownloadsDir]."

   cd "$DownloadsDir" || bail "Could not cd to downloads dir: $DownloadsDir"

   if [[ "$SDPInstallMethod" == FTP ]]; then
      if [[ -r "$SDPTar" ]]; then
         msg "Using existing SDP tarfile [$SDPTar]."
      else
         run "curl -k -s -O $SDPURL" ||\
            bail "Could not get SDP tar file from [$SDPURL]."
      fi
   fi
fi

#------------------------------------------------------------------------------
# Cleanup
cd "$HxDepots" || bail "Could not cd to [$HxDepots]. Aborting."

msg "Working in [$PWD]."

for d in $HxMetadata $HxLogs; do
   if [[ ! -d "$d" ]]; then
      run "/bin/mkdir -p $d" "Initialized empty dir [$d]." ||\
         bail "Failed to create dir [$d]."
   else
      msg "Verified: Dir [$d] exists."
   fi
done

if [[ $PreserveDirList != Unset ]]; then
   run "/bin/mkdir -p $TmpDir" "Creating temp dir [$TmpDir]." ||\
      bail "Failed to create temp dir [$TmpDir]."

   for d in $(echo "$PreserveDirList" | tr ',' ' '); do
      preserveDir="$HxDepots/p4/common/$d"
      if [[ -d "$preserveDir" ]]; then
         parentDir=$(dirname "$TmpDir/$d")
         if [[ ! -d "$parentDir" ]]; then
            run "/bin/mkdir -p $parentDir" "Creating parent temp dir [$parentDir]." ||\
               bail "Failed to create parent temp dir [$parentDir]."
         fi

         run "/bin/mv $preserveDir $TmpDir/$d" \
            "Moving preserved dir $preserveDir aside for safe keeping."
      else
         bail "Missing expected preserve dir [$preserveDir]. Check that paths specified with '-p' are relative to $HxDepots/p4/common."
      fi
   done
fi

for i in $SDPInstances; do
   run "/bin/rm -rf $HxDepots/p4/$i $HxMetadata/p4/$i $HxLogs/p4/$i" \
      "Blasting any existing SDP structures." ||\
      bail "Failed to blast existing SDP structures."
   if [[ -L "/p4/$i" ]]; then
      run "/bin/rm -f /p4/$i" "Blasting symlink /p4/$i." ||\
         bail "Failed to remove SDP symlink."
   elif [[ -d "/p4/$i" ]]; then
      run "/bin/rm -rf /p4/$i" "Blasting directory /p4/$i." ||\
         bail "Failed to remove SDP instance directory /p4/$i."
   fi
done

run "/bin/rm -rf $HxDepots/p4/common" \
   "Blasting SDP common folder." ||\
   bail "Failed to remove SDP common folder."

if [[ -L /p4/common ]]; then
   run "/bin/rm -f /p4/common" "Removing /p4/common symlink." ||\
      bail "Failed to remove /p4/common symlink."
elif [[ -d /p4/common ]]; then
   run "/bin/rm -rf /p4/common" "Removing /p4/common directory." ||\
      bail "Failed to remove /p4/common local directory."
else
   msg "Info: /p4/common did not exist as a directory or symlink."
fi

run "/bin/rm -rf $SDPHome /p4/ssl" \
   "Removing old SDP Home and /p4/ssl." ||\
   bail "Failed to remove old $SDPHome and /p4/ssl."

#------------------------------------------------------------------------------
# SDP Setup
if [[ "$SDPInstallMethod" == FTP ]]; then
   run "tar -xzpf $DownloadsDir/$SDPTar" "Unpacking $DownloadsDir/$SDPTar in $PWD." ||\
      bail "Failed to untar SDP tarfile."
elif [[ "$SDPInstallMethod" == Copy ]]; then
   if [[ -r "$SDPDir/$SDPTar" ]]; then
      if [[ -d "$SDPHome" ]]; then
         run "rm -rf $SDPHome/" \
            "Removing existing SDP directory [$SDPHome]." ||\
            bail "Failed to clean existing SDPHome dir: $SDPHome"
      fi
     
      cd "${SDHOME%/*}" ||\
         bail "Could not cd to parent of SDPHome dir: ${SDHOME%/*}"

      run "tar -xzf $SDPDir/$SDPTar" \
         "Extracting SDP tarball: $$SDPDir/$SDPTar" ||\
         bail "Failed to extract SDP tarball."

      cd - > /dev/null || bail "Could not cd back to: $OLDPWD"

   elif [[ -r "$SDPDir/Version" ]]; then
      run "rsync -a $SDPDir/ $SDPHome" "Deploying SDP from: $SDPDir" ||\
         bail "Failed to rsync SDP from $SDPDir."
   else
      bail "The SDP directory [$SDPDir] contains neither an SDP tarball file ($SDPTar) nor a Version file to indicate a pre-extracted SDP tarball. Aborting."
   fi
else
   # SDPInstallMethod is DVCS
   export PATH="$ExesDir:$PATH"
   export P4ENVIRO=/dev/null/.p4enviro
   export P4CONFIG=.p4config.local
   run "/bin/mkdir -p $SDPHome" "Creating dir $SDPHome" ||\
      bail "Failed to create dir $SDPHome. Aborting."
   cd "$SDPHome" || bail "Failed to cd to [$SDPHome]."
   WorkshopRemote=perforce_software-sdp_${SDPInstallBranch}

   run "$ExesDir/p4 -s -u $WorkshopUser clone -p $WorkshopPort -r $WorkshopRemote" \
      "Cloning SDP $SDPInstallBranch branch from The Workshop." ||\
      bail "Failed to clone SDP from The Workshop."

   run "$ExesDir/p4 -s sync -f .p4ignore" \
      "Force-sync .p4ignore file."

   if [[ "$ShelvedChange" != Unset ]]; then
      run "$ExesDir/p4 -s fetch -s $ShelvedChange" \
         "Fetching shelved change @$ShelvedChange from The Workshop." ||\
      bail "Failed to fetch shelved change @$ShelvedChange from The Workshop."

      LocalShelvedChange=$($ExesDir/p4 -ztag -F %change% changes -s shelved -m 1)

      [[ -n "$LocalShelvedChange" ]] || \
         bail "Could not determine local shelved change fetched for shelved change @$ShelvedChange."

      run "$ExesDir/p4 -s unshelve -s $LocalShelvedChange" \
         "Unshelving local shelved change @$LocalShelvedChange." ||\
         bail "Failed to unshelve local shelved change @$LocalShelvedChange."
   fi

   unset P4ENVIRO
   unset P4CONFIG
fi

if [[ -r "$SDPHome/Version" ]]; then
   if [[ "$SDPInstallMethod" == DVCS ]]; then
      msg "Version info not displayed as it is unreliable when using DVCS install method to get latest from the dev branch."
   else
      msg "SDP Version in $SDPHome is: $(cat "$SDPHome/Version")"
   fi
else
   bail "Cannot determine SDP Version; file $SDPHome/Version is missing."
fi

if [[ "${Config['SimulateEmail']}" == "1" ]]; then
   cd "$SDPConfigDir" ||\
   bail "Could not cd to [$SDPConfigDir]."

   msg "Generating custom p4_vars.template to simulate email in [$PWD]."

   run "/bin/mv -f p4_vars.template p4_vars.template.orig"
   run "chmod 444 p4_vars.template.orig"

   sed -e "s:SDPMAIL=mailx:SDPMAIL='/bin/echo Simulated mail':g" \
      -e "s:SDPMAIL=mail:SDPMAIL='/bin/echo Simulated mail':g" \
      p4_vars.template.orig > p4_vars.template

   msg "Changes in p4_vars.template:"
   diff p4_vars.template.orig p4_vars.template
else
   msg "Using standard p4_vars.template file."
fi

cd "$SDPSetupDir" ||\
   bail "Could not cd to [$SDPSetupDir]."

if [[ "${Config['SimulateEmail']}" == "1" ]]; then
   msg "Generating custom mkdirs.sh in $PWD."

   run "/bin/mv -f mkdirs.sh mkdirs.sh.orig"
   run "chmod 444 mkdirs.sh.orig"

   sed -e "s:export MAIL=mailx:export MAIL='/bin/echo Simulated mail':g" \
      -e "s:export MAIL=mail:export MAIL='/bin/echo Simulated mail':g" \
      mkdirs.sh.orig > mkdirs.sh
else
   msg "Using standard mkdirs.sh script."
fi

run "/bin/mv -f mkdirs.cfg mkdirs.cfg.orig" \
   "Generating custom mkdirs.cfg in $PWD."

sed -e "s:=DNS_name_of_master_server:=${Config['DNS_name_of_master_server']}:g" \
   -e "s:^MAILTO=.*:MAILTO=${Config['P4AdminList']}:g" \
   -e "s:^MAILFROM=.*:MAILFROM=${Config['MailFrom']}:g" \
   -e "s:mail.example.com:${Config['SMTPServer']}:g" \
   -e "s:^CASE_SENSITIVE=.*:CASE_SENSITIVE=${Config['CaseSensitive']}:g" \
   -e "s:^DB1=.*:DB1=${HxMetadata#/}:g" \
   -e "s:^DB2=.*:DB2=${HxMetadata#/}:g" \
   -e "s:^P4_PORT=.*:P4_PORT=SeeBelow:g" \
   -e "s:^P4BROKER_PORT=.*:P4BROKER_PORT=SeeBelow:g" \
   -e "s:# P4_PORT=1666:P4_PORT=${Config['P4_PORT']}:g" \
   -e "s:# P4BROKER_PORT=1667:P4BROKER_PORT=${Config['P4BROKER_PORT']}:g" \
   -e "s:=adminpass:=${Config['Password']}:g" \
   -e "s:=servicepass:=${Config['Password']}:g" \
   -e "s:ADMINUSER=perforce:ADMINUSER=${Config['P4USER']}:g" \
   -e "s:OSUSER=perforce:OSUSER=$RunUser:g" \
   -e "s:OSGROUP=perforce:OSGROUP=$RunGroup:g" \
   -e "s:REPLICA_ID=replica:REPLICA_ID=p4d_ha_${Config['SiteTag']}:g" \
   -e "s:SVCUSER=service:SVCUSER=svc_p4d_ha_${Config['SiteTag']}:g" \
   mkdirs.cfg.orig > mkdirs.cfg

if [[ $UseSSL -eq 0 ]]; then
   msg "Not using SSL feature due to '-no_ssl'."
   sed "s/SSL_PREFIX=ssl:/SSL_PREFIX=/g" mkdirs.cfg > $TmpFile
   run "mv -f $TmpFile mkdirs.cfg"
fi

chmod +x mkdirs.sh

msg "SDP Localizations in mkdirs.sh:"
diff mkdirs.sh.orig mkdirs.sh

msg "\\nSDP Localizations in mkdirs.cfg:"
diff mkdirs.cfg.orig mkdirs.cfg

run "cp -p $ExesDir/p4* $SDPHome/Server/Unix${CBIN}/." \
   "Copying perforce executables."

msg "Initializing SDP instances and configuring $InitMechanism services."

for i in $SDPInstances; do
   cd "$SDPSetupDir" || bail "Could not cd to [$SDPSetupDir]."
   log="$PWD/mkdirs.${i}.log"
   msg "Initializing SDP instance [$i], writing log [$log]."
   "$PWD/mkdirs.sh" "$i" > "$log" 2>&1
   cat "$log"

   if [[ "$InitMechanism" == "SysV" ]]; then
      msg "\\nConfiguring $InitMechanism services.\\n"
      cd /etc/init.d || bail "Could not cd to [/etc/init.d]."
      for svc in p4broker p4d; do
         initScript=${svc}_${i}_init
         if [[ -x /p4/${i}/bin/$initScript ]]; then
            run "ln -s /p4/${i}/bin/$initScript"
            run "chkconfig --add $initScript"
            run "chkconfig $initScript on"
         fi
      done
   elif [[ "$InitMechanism" == "Systemd" ]]; then
      msg "\\nConfiguring $InitMechanism services.\\n"
      cd /etc/systemd/system || bail "Could not cd to /etc/systemd/system."
      for exe in p4broker p4d p4p; do
         svcName="${exe}_${i}"
         svcFile="${svcName}.service"
         sed -e "s:__INSTANCE__:${i}:g" \
            -e "s:__OSUSER__:$RunUser:g" \
            "$ResetHome/${exe}_N.service.t" > "$svcFile" ||\
            bail "Failed to generate $PWD/$svcFile."

         # The p4p *.service file will be put in place, but not enabled.
         [[ "$exe" == p4p ]] && continue
         run "systemctl enable $svcName" "Enabling $svcName to start on boot." ||\
            warnmsg "Failed to enable $svcName with $InitMechanism."
      done
   fi

   run "chown -R $RunUser:$RunGroup $HxDepots" \
      "Adjusting ownership of $HxDepots to $RunUser:$RunGroup." ||\
       bail "Failed to adjust ownership of $HxDepots."

   msg "\\nGenerating broker config for instance $i.\\n"
   su -l "$RunUser" -c "$CBIN/gen_default_broker_cfg.sh ${i} > $CCFG/p4_${i}.broker.cfg"
done

if [[ "$UseSSL" -eq 1 ]]; then
   msg "Generating /p4/ssl/config.txt SSL config file for autogen cert."
   sed -e "s/REPL_DNSNAME/helix/g" /p4/ssl/config.txt > $TmpFile ||\
      bail "Failed to substitute content in /p4/ssl/config.txt."
   run "mv -f $TmpFile /p4/ssl/config.txt"
   msg "Contents of /p4/ssl/config.txt:\\n$(cat /p4/ssl/config.txt)\\n"
fi

if [[ "$PreserveDirList" != Unset ]]; then
   for d in $(echo "$PreserveDirList" | tr ',' ' '); do
      preserveDir=$HxDepots/p4/common/$d
      tempCopyDir=$TmpDir/$d
      run "rsync -av --exclude=.p4root --exclude=.p4ignore --exclude=.p4config $tempCopyDir/ $preserveDir" \
         "Restoring $preserveDir" ||\
         bail "Failed to restore $preserveDir."
   done

   run "/bin/rm -rf $TmpDir" "Cleanup: Removing temp dir [$TmpDir]." ||\
      bail "Failed to remove temp dir [$TmpDir]."
fi

#------------------------------------------------------------------------------
# Install P4Perl and P4Python.
if [[ "$FastMode" -eq 0 ]]; then
   msg "\\nInstalling P4Python for SDP."
   su -l "$RunUser" -c '/hxdepots/sdp/Server/Unix/setup/install_sdp_python.sh' ||\
      warnmsg "Failed to install P4Python"

   msg "\\nInstalling P4Perl for SDP."
   su -l "$RunUser" -c '/hxdepots/sdp/Server/Unix/setup/install_sdp_perl.sh' ||\
      warnmsg "Failed to install P4Perl."
fi

msg "Preparing to run Sample Depot configuration script."
if [[ ! -d "$ResetHome" ]]; then
   run "/bin/mkdir -p $ResetHome" "Creating reset home dir [$ResetHome]." ||\
      bail "Could not create reset home dir [$ResetHome]. Aborting."
fi

cd "$ResetHome" || bail "Could not cd to $HxDepots/ResetHome. Aborting."

if [[ "$LoadSampleDepot" -eq 1 ]]; then
   for i in $SDPInstances; do
      msg "Configuring Sample Depot for SDP on Instance $i."
      if su -l "$RunUser" -c "$ResetHome/configure_sample_depot_for_sdp.sh -i $i -d $ResetHome -u $RunUser"; then
         msg "\\nSample Depot configured successfully for instance $i.\\n"
      else
         bail "Failed to load the Sample Depot."
      fi
   done
else
   msg "\\nSkipping configuration of Sample Depot due to '-no_sd'.\\n"
fi

#------------------------------------------------------------------------------
# Add sudoers to /etc/sudoers.d if the directory exists and the user file doesn't.
if [[ -d "${SudoersFile%/*}" && ! -e "$SudoersFile" ]]; then
   msg "Adding $RunUser to sudoers."
   if echo -e "$SudoersEntry" > "$SudoersFile"; then
      run "chmod 0400 $SudoersFile" "Setting perms on sudoers file, $SudoersFile." ||\
         warnmsg "Failed to set perms on $SudoersFile."
   else
      warnmsg "Failed to create $SudoersFile."
   fi
fi

#------------------------------------------------------------------------------
# Add Perforce Package Repository to repo list (YUM and APT only).

if [[ "$AddPerforcePackageRepo" -eq 1 ]]; then
   if [[ -d "${P4YumRepo%/*}" ]]; then
      if [[ -n "$ThisOSMajorVersion" ]]; then
         run "rpm --import $PerforcePackagePubkeyURL" \
            "Adding Perforce's packaging key to RPM keyring." ||\
            warnmsg "Failed to add Perforce packaging key to RPM keyring."

         msg "Generating $P4YumRepo."
         if ! echo -e "[perforce]\\nname=Perforce\\nbaseurl=$PerforcePackageRepoURL/yum/rhel/$ThisOSMajorVersion/x86_64\\nenabled=1\\ngpgcheck=1\\n" > "$P4YumRepo"; then
            warnmsg "Unable to generate $P4YumRepo."
         fi
      else
         warnmsg "Skipping generation of $P4YumRepo due to lack of OS Major Version info."
      fi
   elif [[ -d "${P4AptGetRepo%/*}" ]]; then # /etc/apt/sources.list.d
      if [[ -n "$ThisOSName" && -n "$ThisOSDistro" ]]; then
         msg "Acquiring Perforce's package repository public key."
         if wget -qO - $PerforcePackagePubkeyURL > $TmpPubKey; then
            msg "Public key for Perforce package repo acquired as: $TmpPubKey"

            msg "Adding Perforce's packaging key to APT keyring."
            if apt-key add < /tmp/perforce.pubkey; then
               msg "APT keyring added successfully."
            else
               warnmsg "Failed to add Perforce packaging key to APT keyring."
            fi

            msg "Doing apt-get update after adding the new perforce.list repo."
            if apt-get update; then
               msg "Update completed."
            else
               warnmsg "What if apt-get did not return a zero exit code."
            fi
         else
            warnmsg "Failed to acquire Perforce package repo public key."
         fi

         msg "Generating $P4AptGetRepo."
         if ! echo "deb $PerforcePackageRepoURL/apt/$ThisOSName $ThisOSDistro release" > "$P4AptGetRepo"; then
            warnmsg "Unable to generate $P4AptGetRepo."
         fi
      else
         warnmsg "Skipping generation of $P4AptGetRepo due to lack of OS Name and Distro info."
      fi
   else
      warnmsg "No Perforce supported package repository, RPM or APT, found to add. Skipping."
   fi
else
   msg "Skipping addition of Perforce Package repository due to '-no_ppr'."
fi

#------------------------------------------------------------------------------
# Add Firewall rules (Firewalld only).

if [[ "$FirewallType" == "Firewalld" ]]; then
   msg "\\nConfiguring $FirewallType services.\\n"
   cd "$FirewallDir" || bail "Could not cd to $FirewallDir."
   for i in $SDPInstances; do
      for exe in p4broker p4d; do
         svcName="${exe}_${i}"
         svcFile="${svcName}.xml"
         sed -e "s:__INSTANCE__:${i}:g" \
            -e "s:__P4PORT__:${Config['P4_PORT']}:g" \
            -e "s:__P4BROKER_PORT__:${Config['P4BROKER_PORT']}:g" \
            "$ResetHome/${exe}_N.xml.t" > "$svcFile" ||\
            bail "Failed to generate $PWD/$svcFile."
         run "firewall-cmd --add-service=$svcName" \
            "Adding firewall entry for $svcName" ||\
            warnmsg "Adding firewall entry for $svcName failed."
         run "firewall-cmd --permanent --add-service=$svcName" \
            "Permanently adding firewall entry for $svcName" ||\
            warnmsg "Adding firewall entry for $svcName failed."
      done
   done
   run "firewall-cmd --reload" "Firewall reload." ||\
      warnmsg "Firewall reload failed."
   run "iptables-save" "Showing firewall rules." ||\
      warnmsg "Showing firewall failed."
elif [[ "$FirewallType" == "IPTables" ]]; then
   warnmsg "IPtables firewall detected, but not handled."
fi

#------------------------------------------------------------------------------
# Apply Support-recommended OS Tweaks to Linux kernel paraemters
# (e.g. KHugePage, etc.)
if [[ "$ThisOS" == "Linux" ]]; then
   if [[ -x "$OSTweaksScript" ]]; then
      run "$OSTweaksScript" "Making recommended Linux OS tweaks." ||\
      warnmsg "Non-zero exit code ($CMDEXITCODE) returned from $SDPSetupDir/os_tweaks.sh"
   else
      msg "Not making OS tweaks, $OSTweaksScript is missing or not executable."
   fi
else
   msg "Skipping OS tweaks on non-Linux OS."
fi

if [[ "$ErrorCount" -eq 0 ]]; then
   if [[ "$WarningCount" -eq 0 ]]; then
      msg "\\nSUCCESS:  SDP Configuration complete."
   else
      msg "\\nSUCCESS:  SDP Configuration complete with $WarningCount warnings."
   fi

   run "chmod -x $ResetHome/reset_sdp.sh" \
      "Removing execute permissions from $ThisScript." ||\
      warnmsg "Failed to remove execute permissions from $ResetHome/reset_sdp.sh"

   run "mv $ResetHome/reset_sdp.sh $ResetHome/reset_sdp.sh.txt" \
      "Renamed to clarify this should not be executed again." ||\
      warnmsg "Failed to rename to $ResetHome/reset_sdp.sh.txt"

else
   msg "\\nSDP Configuration completed, but with $ErrorCount errors and $WarningCount warnings."
fi

exit "$ErrorCount"
