#!/bin/sh
# Moto RSD Lite - Flash Motorola RSD / fastboot XML packages
# Windows: use rsd-flash.bat / rsd-flash.ps1
# macOS / Linux:
#   ./rsd-flash.sh [XML file]
#   ./rsd-flash.sh [firmware directory] [XML file]
#   ./rsd-flash.sh                 # interactive: pick directory + XML
#
# Bundled platform-tools live in files/ (adb + fastboot for each OS).
# If no args (or incomplete args) are given, you can interactively choose
# the flash package directory and the XML flashing script inside it.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR" || exit 1

platform()
{
	platform=$(uname)
	case "$platform" in
		MINGW*|MSYS*|CYGWIN*)
			echo "[-] On Windows use rsd-flash.bat (or rsd-flash.ps1), not this shell script."
			exit 1
			;;
	esac
	if [ "$(uname -p 2>/dev/null)" = 'powerpc' ]; then
		echo "[-] PowerPC is not supported."
		exit 1
	fi

	if [ "$platform" = 'Darwin' ]; then
		ADB="files/./adbosx"
		FASTBOOT="files/./fastbootosx"
		MD5SUM="md5 -r"
		version="macOS"
	else
		ADB="files/./adblinux"
		FASTBOOT="files/./fastbootlinux"
		MD5SUM="md5sum"
		version="Linux"
	fi
}

getValue(){
	val=$(echo "$1" | sed "s/.*$2=\"\([^\"]*\).*/\1/")
	echo "$val" | grep -q " "
	if [ $? -ne 1 ]; then
		val=""
	fi
	echo "$val"
}

# Expand ~ and resolve to absolute path when possible
resolve_path(){
	_p=$1
	# Trim leading/trailing whitespace
	_p=$(printf '%s' "$_p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
	# Strip surrounding quotes from paste (e.g. '/path/to/fw' or "/path/to/fw")
	case "$_p" in
		\'*\') _p=${_p#\'}; _p=${_p%\'} ;;
		\"*\") _p=${_p#\"}; _p=${_p%\"} ;;
	esac
	case "$_p" in
		"~"|"~/"*) _p=$HOME${_p#\~} ;;
	esac
	if [ -d "$_p" ]; then
		(CDPATH= cd -- "$_p" && pwd)
	elif [ -f "$_p" ]; then
		_dir=$(dirname -- "$_p")
		_base=$(basename -- "$_p")
		printf '%s/%s\n' "$(CDPATH= cd -- "$_dir" && pwd)" "$_base"
	else
		echo "$_p"
	fi
}

prompt_package_dir(){
	echo "----------------------------------------------------------------------------"
	echo "Select flash package directory"
	echo "  - Press Enter to use current tool folder:"
	echo "    $SCRIPT_DIR"
	echo "  - Or type/paste a path to the Motorola firmware folder"
	echo "----------------------------------------------------------------------------"
	printf "Package directory: "
	read -r PACKAGE_DIR
	if [ -z "$PACKAGE_DIR" ]; then
		PACKAGE_DIR=$SCRIPT_DIR
	else
		PACKAGE_DIR=$(resolve_path "$PACKAGE_DIR")
	fi

	if [ ! -d "$PACKAGE_DIR" ]; then
		echo "[-] Directory not found: $PACKAGE_DIR"
		exit 1
	fi
}

list_xml_files(){
	# Populate XML_FILES (newline-separated) and XML_COUNT
	XML_FILES=""
	XML_COUNT=0
	# Non-recursive. Prefer *.xml; fall back to *.XML if needed.
	set -- "$PACKAGE_DIR"/*.xml
	if [ ! -f "$1" ]; then
		set -- "$PACKAGE_DIR"/*.XML
	fi
	for f in "$@"; do
		[ -f "$f" ] || continue
		XML_COUNT=$((XML_COUNT + 1))
		if [ -z "$XML_FILES" ]; then
			XML_FILES=$f
		else
			XML_FILES="$XML_FILES
$f"
		fi
	done
}

xml_label(){
	# Annotate common Motorola flash XMLs for the interactive menu
	_base=$(basename -- "$1")
	_lower=$(printf '%s' "$_base" | tr '[:upper:]' '[:lower:]')
	case "$_lower" in
		flashfile.xml) printf '%s (Erase Data !!!)\n' "$_base" ;;
		servicefile.xml) printf '%s (Update Only)\n' "$_base" ;;
		*) printf '%s\n' "$_base" ;;
	esac
}

pick_xml_interactive(){
	list_xml_files
	if [ "$XML_COUNT" -eq 0 ]; then
		echo "[-] No .xml flash file found in: $PACKAGE_DIR"
		echo "    Put the Motorola firmware XML (and image files) in that folder."
		exit 1
	fi

	if [ "$XML_COUNT" -eq 1 ]; then
		XML_FILE=$XML_FILES
		echo "[*] Found XML: $(xml_label "$XML_FILE")"
		printf "Use this file? [Y/n]: "
		read -r ans
		case "$ans" in
			n|N|no|NO) echo "Aborted."; exit 1 ;;
		esac
		return
	fi

	echo "----------------------------------------------------------------------------"
	echo "Select XML flash file in:"
	echo "  $PACKAGE_DIR"
	echo "----------------------------------------------------------------------------"
	i=1
	echo "$XML_FILES" | while IFS= read -r f; do
		printf "  %2d) %s\n" "$i" "$(xml_label "$f")"
		i=$((i + 1))
	done
	echo "----------------------------------------------------------------------------"
	printf "Enter number [1-%d]: " "$XML_COUNT"
	read -r choice
	case "$choice" in
		''|*[!0-9]*)
			echo "[-] Invalid selection."
			exit 1
			;;
	esac
	if [ "$choice" -lt 1 ] || [ "$choice" -gt "$XML_COUNT" ]; then
		echo "[-] Invalid selection."
		exit 1
	fi
	XML_FILE=$(echo "$XML_FILES" | sed -n "${choice}p")
}

resolve_args(){
	PACKAGE_DIR=""
	XML_FILE=""

	case $# in
		0)
			prompt_package_dir
			pick_xml_interactive
			;;
		1)
			arg1=$(resolve_path "$1")
			if [ -d "$arg1" ]; then
				PACKAGE_DIR=$arg1
				pick_xml_interactive
			elif [ -f "$arg1" ]; then
				XML_FILE=$arg1
				PACKAGE_DIR=$(CDPATH= cd -- "$(dirname -- "$XML_FILE")" && pwd)
			else
				# Treat as relative XML name under tool dir, or ask interactively
				if [ -f "$SCRIPT_DIR/$1" ]; then
					XML_FILE=$SCRIPT_DIR/$1
					PACKAGE_DIR=$SCRIPT_DIR
				else
					echo "[-] Not found: $1"
					echo "[*] Falling back to interactive selection..."
					prompt_package_dir
					pick_xml_interactive
				fi
			fi
			;;
		*)
			arg1=$(resolve_path "$1")
			arg2=$2
			if [ -d "$arg1" ]; then
				PACKAGE_DIR=$arg1
			else
				echo "[-] Directory not found: $1"
				exit 1
			fi
			if [ -f "$arg2" ]; then
				XML_FILE=$(resolve_path "$arg2")
			elif [ -f "$PACKAGE_DIR/$arg2" ]; then
				XML_FILE=$PACKAGE_DIR/$arg2
			else
				echo "[-] XML not found: $arg2"
				echo "[*] Pick XML interactively..."
				pick_xml_interactive
			fi
			;;
	esac
}

echo_red(){
	printf '\033[31m%s\033[0m\n' "$*"
}

add_flash_error(){
	_msg=$1
	echo_red "$_msg"
	ERROR_COUNT=$((ERROR_COUNT + 1))
	if [ -z "$FLASH_ERRORS" ]; then
		FLASH_ERRORS=$_msg
	else
		FLASH_ERRORS="$FLASH_ERRORS
$_msg"
	fi
}

append_flash_error_quiet(){
	# Add to summary without reprinting (already shown via fastboot output)
	_msg=$1
	[ -z "$_msg" ] && return
	case "$FLASH_ERRORS" in
		*"$_msg"*) return ;;
	esac
	ERROR_COUNT=$((ERROR_COUNT + 1))
	if [ -z "$FLASH_ERRORS" ]; then
		FLASH_ERRORS=$_msg
	else
		FLASH_ERRORS="$FLASH_ERRORS
$_msg"
	fi
}

do_flash(){
	case "$FASTBOOT" in
		/*) ;;
		*) FASTBOOT="$SCRIPT_DIR/$FASTBOOT" ;;
	esac

	if [ ! -x "$FASTBOOT" ]; then
		echo_red "fastboot not found: $FASTBOOT"
		exit 1
	fi

	if [ ! -f "$XML_FILE" ]; then
		echo_red "[-] XML file not found: $XML_FILE"
		exit 1
	fi

	echo "----------------------------------------------------------------------------"
	echo "Package dir : $PACKAGE_DIR"
	echo "XML file    : $XML_FILE"
	echo "Platform    : $version"
	echo "----------------------------------------------------------------------------"
	echo "Welcome to Moto RSD Lite For Windows, Mac and Linux — press Enter to start your flash"
	echo "----------------------------------------------------------------------------"
	read -r _

	# Image filenames in the XML are relative to the package directory
	cd "$PACKAGE_DIR" || exit 1
	PATH="$SCRIPT_DIR:$SCRIPT_DIR/files:$PATH"

	FLASH_ERRORS=""
	ERROR_COUNT=0

	tmp_steps=$(mktemp 2>/dev/null || echo "/tmp/rsd-flash-steps.$$")
	grep 'step[^s]' "$XML_FILE" > "$tmp_steps" || true

	while IFS= read -r line; do
		[ -z "$line" ] && continue
		MD5=$(getValue "$line" "MD5")
		file=$(getValue "$line" "filename")
		op=$(getValue "$line" "operation")
		part=$(getValue "$line" "partition")
		var=$(getValue "$line" "var")
		if [ "$MD5" != "" ] && [ "$file" != "" ]; then
			if [ ! -f "$file" ]; then
				add_flash_error "$file: file not found in $PACKAGE_DIR"
				break
			fi
			fileMD5=$($MD5SUM "$file" | sed 's/ \(.*\)//')
			if [ "$MD5" != "$fileMD5" ]; then
				add_flash_error "$file: MD5 mismatch (expected $MD5, got $fileMD5)."
				break
			fi
		fi

		fb_cmd=$(echo "$op $part $file $var" | sed 's/[[:space:]]*$//;s/^[[:space:]]*//;s/  */ /g')
		# shellcheck disable=SC2086
		fb_out=$("$FASTBOOT" $op $part $file $var 2>&1)
		fb_rc=$?
		if [ -n "$fb_out" ]; then
			printf '%s\n' "$fb_out" | while IFS= read -r ol; do
				if printf '%s\n' "$ol" | grep -Eqi 'FAILED|error:'; then
					echo_red "$ol"
				else
					printf '%s\n' "$ol"
				fi
			done
		fi

		fb_bad=0
		[ "$fb_rc" -ne 0 ] && fb_bad=1
		printf '%s\n' "$fb_out" | grep -Eqi '(^|[[:space:]])FAILED([[:space:]]|$)|error:' >/dev/null 2>&1 && fb_bad=1

		if [ "$fb_bad" -ne 0 ]; then
			add_flash_error "fastboot failed: $fb_cmd (exit $fb_rc)"
			_detail=$(printf '%s\n' "$fb_out" | grep -Ei 'FAILED|error:' || true)
			if [ -n "$_detail" ]; then
				OLDIFS=$IFS
				IFS='
'
				for eline in $_detail; do
					append_flash_error_quiet "$eline"
				done
				IFS=$OLDIFS
			fi
			break
		fi
	done < "$tmp_steps"
	rm -f "$tmp_steps"

	echo "---------------------------------------------------------"
	if [ "$ERROR_COUNT" -eq 0 ]; then
		echo "Congratulations, no flashing errors found. Please press Enter to reboot device."
	else
		echo "Please check for errors then press Enter to reboot device"
		echo "Error summary ($ERROR_COUNT):"
		OLDIFS=$IFS
		IFS='
'
		for eline in $FLASH_ERRORS; do
			[ -n "$eline" ] && echo_red "  - $eline"
		done
		IFS=$OLDIFS
	fi
	echo "---------------------------------------------------------"
	read -r _
	"$FASTBOOT" reboot
}

# ---- main ----
platform

echo   """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
echo   "     _  _     ____  _____ ____    ___  ____ ____    __   _  _____ ___     "
echo   "   \/ \/ \  / _  \/_  _// _  \  / _ \/ __// _  \  / /  /_//_  _// _/      "
echo   "  / ,  , \ / |_|  / /  / |_|   / , _\__ \/ // /  / /__/ / / /  / _/       "
echo   " /_/ \/ \_\____//_/   \____/  /_/|_/___//____/  /____/_//_/   \___/       "
printf '                                                                     \033[3mBy LuoJuly\033[0m\n'
echo   """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

resolve_args "$@"
do_flash
