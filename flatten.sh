#!/bin/bash - 
#===============================================================================
#
#          FILE: flatten.sh
#
#         USAGE: ./flatten.sh <<infile>>
#
#   DESCRIPTION: - Replaces all lines starting with ". somefile" with the
#                  functions contained in "somefile" **IF** they are used in
#                  <<infile>>.
#
#                  This is useful if you keep a file "lazy.lib" which in turn
#                  sources ALL the functions you use.  Source it in your scripts
#                  while developing, but DO NOT put comments on the same line!
#
#                  You could create one file ending in ".bash" for each function
#                  and then do:
#
#                  printf '. %s\n' $(realpath your/library/*.bash) > lazy.lib
#
#                - Replaces all lines starting with '###Include:'
#                  with the contents of the file specified after ':'.
#                  DO NOT put comments on the same line!
#                  This is useful to unconditionally include things.
#
#       OPTIONS: a file as positional argument "$1"
#
#  REQUIREMENTS: /bin/bash . This won't work in /bin/sh
#
#          BUGS: likely...
#
#        AUTHOR: Marco Markgraf (mm), Marco.Markgraf@gmx.de
#
#       LICENSE: BSD-2-Clause
#                Copyright 2019 Marco Markgraf
#
#       CREATED: 2019-04-18 19:38
#
#===============================================================================

#=== Init ======================================================================
set -o nounset     # Treat unset variables as an error
set -o errexit     # exit on any error

unalias -a         # avoid rm being aliased to rm -rf and similar issues
LANG=C             # avoid locale issues

#=== Variables =================================================================
infile="${1?Need a file please}"
needed_funcs=''
processed_funcs=''

declare -A floc

#=== Functions =================================================================
_subfuncs () {
  local my_subfunc="$1"
  local my_subfunc_location="$2"
  local sub_items
  local test_me
  local item
  needed_funcs+=" $my_subfunc"
  # Does my_subfunc need any other functions?
  # Get the function definition (loosing any comments):
  test_me="$(_get_fn_def "$my_subfunc" "$my_subfunc_location")"
  # "${test_me//$my_subfunc/}" eliminates the current function from
  # the list of subfunctions to prevent endless loops.
  test_me="${test_me//$my_subfunc/}"
  # Sanitizing:
  # Function names may contain letters, numbers and underscores.
  # Throw away everything else to speed up processing and avoid errors.
  test_me="$(echo $test_me | tr ' ' '\n' \
    | sort --unique \
    | grep '^[a-zA-Z1-9_]' \
    | grep --invert-match '[^a-zA-Z1-9_]')"
  # Then get the list of functions it needs:
  #
  # 'declare' below will complain "cannot use `-f' to make functions"
  # when $test_me does contain things that are not functions.
  # Thats okay though, it simply means that nothing will be added to
  # our list of sub_items.
  #
  sub_items="$(for item in $test_me ; do \
    declare -F $item 2> /dev/null ; done |sort -u)"
  # Now we have a (possibly empty) list of functions needed by my_subfunc.
  # We need to process those the same as my_subfunc.
  for item in $sub_items ; do
    _subfuncs "$item"
  done
} # ----------  end of function _subfuncs  ----------

_get_fn_location () {
  local file2source
  # The invocation env -i bash --noprofile --norc is meant to prevent bash
  # from reading any initialization files.
  # Otherwise, you might get functions defined in, e.g., ~/.bashrc.
  # ':' are not allowed in func-names, so I'm using :: as a separator
  env -i bash --norc --noprofile -c '
  shopt -s extdebug;
  source "'"$file2source"'";
  declare -F \
    | cut -d " " -f3 \
    | while read fname; do declare -F $fname; done \
    | cut -d " " -f1,3 \
    | sed "s/ /::/"
  '
}

_get_fn_def () { # Keep the comments contained in the function definition.
  local fn_name="$1"
  local fn_location="$2"
  # In what file is my function defined?  This needs 'shopt -s extdebug'
  shopt -s extdebug
  # 'grep'-output will be the function definition plus a trailing nullbyte.
  # The nullbyte is needed, so grep can slurp the whole file
  # and do multi-line matching.
  # The 'sed'-statement removes the trailing nullbyte.
  printf '%s\n\n' \
    "$(grep \
    --no-filename \
    --null-data \
    --only-matching \
    --perl-regexp \
    "${fn_name}.*(\{([^{}]++|(?1))*\}.*)" "$fn_location" \
    | sed 's/\(}*\)\x0$/\1/' )"
  shopt -u extdebug
}

#=== Main ======================================================================
while IFS= read -r line; do
  if echo "$line" | grep --quiet --extended-regexp '^(\.|source) '; then
    # Found a file to be sourced
    my_file="${line#* }" # equivalent to cut -d ' ' -f2-
    # get the function-names and locations
		for func_and_loc in $(_get_fn_location "$my_file") ; do
			key="${func_and_loc%%::*}"
			value="${func_and_loc#*::}"
			floc[$key]="$value"
		done
    # Iterate over said functions and work with those needed by infile.
    for item in ${!floc[@]}; do
      if sed -e '/^[[:space:]]*#/d' -e 's/ # .*$//' "$infile" \
        | grep --extended-regexp --invert-match '^(\.|source) '\
        | grep --quiet --fixed-strings "$item" ; then
        # Add the function and all the functions it needs to "needed_funcs".
        _subfuncs "$item" "${floc[$item]}"
      fi
    done
    # Make sure every function is in the list only once.
    needed_funcs="$(echo "$needed_funcs" | tr ' ' '\n' | sort -u)"
    for item in $needed_funcs ; do
      regex="$(echo $processed_funcs | xargs | tr ' ' '|')"
      if [[ ! $item =~ ^($regex)$ ]]; then
        _get_fn_def "$item" "${floc[$item]}"
        # Safeguard against functions defined in multiple sourced files.
        # First declarations wins.  DO NOT RESET.
        processed_funcs+=" ${item}"
        unset -f "$item"
      fi
    done
    # Clean up now. Could be we need to source another file...
    needed_funcs=''
    continue # This bit skips the line we want to replace in the output.
  elif echo "$line" | grep --quiet --ignore-case '^###Include:'; then
    # Found a file to be included unconditionally.
    my_file="${line#*:}"
    cat "$my_file"
    continue # This bit skips the line we want to replace in the output.
  fi
  printf "%s\n" "$line"
done < "$infile" | cat --squeeze-blank
#=== End =======================================================================
