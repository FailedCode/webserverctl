#!/bin/bash
# - list available websites
# - enable/disable websites
# - restart webserver

# find the directory the script is in
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# load config
CONFIG_FILE="config"
if [ -f "$DIR/$CONFIG_FILE" ]; then
	source "$DIR/$CONFIG_FILE"
elif [ -f "$DIR/$CONFIG_FILE.dist" ]; then
	echo "copying default config..."
	cp "$CONFIG_FILE.dist" "$CONFIG_FILE"
	source "$DIR/$CONFIG_FILE"
else
	echo >&2 "Error: Neither $CONFIG_FILE nor $CONFIG_FILE.dist found!"
	exit 1
fi

TMP_FILE=$(mktemp)

# Handle possible garbage
function onExit {
	if [ -e "${TMP_FILE}" ]; then
		rm "${TMP_FILE}"
	fi
}
trap onExit EXIT

# sanity checks
command -v ${WEBSERVER_CMD} >/dev/null 2>&1
cmdTest=$?
if [ "$cmdTest" != "0" ]; then
	echo >&2 "It seems '${WEBSERVER_CMD}' is not available."
	echo >&2 "Check the permissons or change the config"
	exit 1
fi

cmdPid=$(pgrep ${WEBSERVER_CMD})
if [ "$cmdPid" == "0" ]; then
	echo >&2 "'${WEBSERVER_CMD}' is not running right now.\nPlease start it first."
	exit 1
fi

if [ ! -d "$SITE_AVAILABLE" ]; then
	echo >&2 "$SITE_AVAILABLE does not exist - is '${WEBSERVER_CMD}' installed correctly?"
	exit 1
fi
if [ ! -d "$SITE_ENABLED" ]; then
	echo >&2 "$SITE_ENABLED does not exist - is '${WEBSERVER_CMD}' installed correctly?"
	exit 1
fi

filesInsteadOfLinksEnabled=$(find $SITE_ENABLED -type f -print0)
if [ "${filesInsteadOfLinksEnabled}" != "" ]; then
	whiptail --title "WARNING" --msgbox "There are files instead of symlinks in \n${SITE_ENABLED}\nYou may want to fix that first.\n${#filesInsteadOfLinksEnabled[@]}\n$filesInsteadOfLinksEnabled" 10 78
	#exit 0
fi

# fetch config files
sitesAvailable=$(ls $SITE_AVAILABLE)
sitesEnabled=$(ls $SITE_ENABLED)

if [ "${#sitesAvailable[@]}" == "0" ]; then
	whiptail --msgbox "There are no config files in ${SITE_AVAILABLE}\n" 10 78
	exit 0
fi

# build list of config files with enabled files marked as such
options=""
for site in ${sitesAvailable[@]}
do
	enabled="off"
	for siteEnabled in ${sitesEnabled[@]}
	do
		if [ "${siteEnabled}" == "${site}" ]; then
			enabled="on"
			break
		fi
	done
	options+=" ${site} ${enabled}"
done

# the user (de)selects configfiles, all enabled end up in "choices"
whiptail --noitem --nocancel \
	--ok-button "DONE" \
	--title "Active Sites" \
	--separate-output \
	--checklist "use <SPACE> to (de)activate sites" 20 78 10 \
	$options 2>${TMP_FILE}
choices=$(cat ${TMP_FILE})


# process user input
# create and delete symlinks
configChanged="no"
for siteAvailable in ${sitesAvailable[@]}
do
	shouldBeEnabled="no"
	for siteEnabled in ${choices[@]}
	do
		if [ "${siteEnabled}" == "${siteAvailable}" ]; then
			shouldBeEnabled="yes"
			# site is already enabled, so skip
			if [ -L "${SITE_ENABLED}${siteEnabled}" ]; then
				continue
			fi
			# site is not enabled, but should be - new symlink
			ln -s "${SITE_AVAILABLE}${siteEnabled}" "${SITE_ENABLED}"
			configChanged="yes"
			break
		fi
	done

	if [ "${shouldBeEnabled}" == "no" ] && [ -L "${SITE_ENABLED}${siteAvailable}" ]; then
		# site is enabled but should not be
		rm "${SITE_ENABLED}${siteAvailable}"
		configChanged="yes"
	fi
done

# if the config was changed we probably want to use it
if [ "${configChanged}" == "yes" ]; then

	# any obvious errors?
	${WEBSERVER_CMD_CONFIGTEST} 2>${TMP_FILE}
	configTestExitcode=$?
	configTestResult=$(cat ${TMP_FILE})

	whiptail --yesno --defaultno \
		--title "Restart Webserver now?" \
		--scrolltext "Config result:\nexitcode: ${configTestExitcode}\n${configTestResult}" 10 78

	if [ "$?" == "0" ]; then
		echo "Restarting the webserver now!"
		${WEBSERVER_CMD_RESTART}
	else
		echo "The config was changed but the webserver was NOT restarted!"
	fi
else
	whiptail --msgbox "The config was not changed" 10 78
fi
