#!/bin/bash
#
# AMP
#
# Copyright (c) 2012 David Persson
#
# Distributed under the terms of the MIT License.
# Redistributions of files must retain the above copyright notice.
#
# @COPYRIGHT 2012 David Persson <nperson@gmx.de>
# @LICENSE   http://www.opensource.org/licenses/mit-license.php The MIT License
# @LINK      http://github.com/davidpersson/amp
#

# -----------------------------------------------------------
# Functions
# -----------------------------------------------------------
# @FUNCTION: msg*
# @USAGE: <message> [replacement0..]
# @DESCRIPTION:
# Outputs status messages honoring QUIET flag.
msg()       { if [[ $QUIET != "y" ]];   then _msg ""     "$@"; fi }
msgok()     { if [[ $QUIET != "y" ]];   then _msg "ok"   "$@"; fi }
msgskip()   { if [[ $QUIET != "y" ]];   then _msg "skip" "$@"; fi }
msgwarn()   { _msg "warn" "$@" >&2; }
msgfail()   { _msg "fail" "$@" >&2; }

# @FUNCTION: _msg
# @USAGE: <status> <message> [replacement0..]
# @DESCRIPTION:
# Outputs status messages.
_msg() {
	local status=$1
	local message=$2
	shift 2

	local IFS=""
	printf "[\e[1;34m%s\e[0m] [%5s] \e[1;32m%s\e[0m\n" \
		"$(date +%T)" \
		"$status" \
		"$(printf "$message" $@)"
}

# @FUNCTION: usage
# @DESCRIPTION:
# Outputs usage info and command-list
usage() {
	echo "Usage: $0 [options] <command> [service]"
	echo
	echo "Options:"
	echo "  -V        Show current version."
	echo "  -d        Enable debug output."
	echo "  -q        Quiet mode, surpress most output except errors."
	echo
	echo "Commands:"
	echo "  status    Show the status of all known services."
	echo "  start     Starts selected currently not running services."
	echo "  stop      Stops all running services."
	echo "  restart   Restarts all running services."
	echo "  reload    Reloads all running services."
	echo
	echo "Service:"
	echo "  all       Selects all known services."
	for SERVICE in $SERVICES; do
		printf "  %-9s Selects just %s.\n" $SERVICE $SERVICE
	done
	echo
	exit 1
}

function control_service() {
	local action=$2

	if [[ $1 == "all" ]]; then
		for s in $SERVICES; do
			control_service $s $2
		done
	else
		case $2 in
			status)
				eval "service_${1}" $2
			;;
			start)
				if [[ $(control_service $1 status) != *"running" ]]; then
					msg "$action $1..."
					eval "service_${1}" $2
				fi
			;;
			stop | restart | reload)
				if [[ $(control_service $1 status) == *"running" ]]; then
					msg "$action $1..."
					eval "service_${1}" $2
				fi
			;;
		esac
	fi
}

# -----------------------------------------------------------
# Environment settings
# -----------------------------------------------------------
set -o nounset

# -----------------------------------------------------------
# Basic Configuration
# -----------------------------------------------------------
QUIET="n"
CONFIG="$HOME/.amp"
VERSION="0.5.0-head"

# -----------------------------------------------------------
# Service Configuration
# -----------------------------------------------------------
SERVICES=""
for file in $(ls $CONFIG/services/*.conf 2> /dev/null); do
   source $file
   SERVICES+=" $(basename -s .conf $file)"
done

# -----------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------
while getopts ":qdV" OPT; do
	case $OPT in
		q)  QUIET="y";;
		d)  set -x;;
		V)  echo "AMP $VERSION by David Persson."; exit;;
		\?) printf "Invalid option '%s'." $OPT; exit 1;;
	esac
done
shift $(expr $OPTIND - 1)

if [[ $# == 0 ]]; then
	usage
fi

COMMAND=$1

# -----------------------------------------------------------
# Main
# -----------------------------------------------------------

case $COMMAND in
	status)
		# If no specific service was given, all services status is shown.
		if [[ $# == 2 ]]; then
			SERVICE=$2
		else
			SERVICE="all"
		fi

		echo "Service        Status"
		echo "---------------------------"
		control_service $SERVICE status
		;;
	start)
		if [[ $# == 2 ]]; then
			SERVICE=$2
			control_service $SERVICE $COMMAND
		else
			# If no specific service was given prompt to select.
			OPTIONS="[quit]"
			for _SERVICE in $SERVICES; do
				if [[ $(control_service $_SERVICE status) != *"running" ]]; then
					OPTIONS+=" $_SERVICE"
				fi
			done
			PS3="Service to $COMMAND: "
			select OPTION in $OPTIONS; do
				if [[ $OPTION == *"quit"* ]]; then
					break
				else
					control_service $OPTION $COMMAND
				fi
			done
		fi
		;;
	stop | restart | reload)
		# If no specific service was given, all services are stopped/restarted/reloaded.
		if [[ $# == 2 ]]; then
			SERVICE=$2
		else
			SERVICE="all"
		fi

		control_service $SERVICE $COMMAND
		;;
	*)
		echo "Error: Invalid option '$1'."
		echo
		usage
		;;
esac
echo
