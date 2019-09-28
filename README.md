# flatten.sh

## Usage
`./flatten.sh <<infile>>`

## Description
`flatten.sh` replaces all lines starting with `. somefile` or `source somefile`
with the functions contained in "somefile" **IF** they are used infile.

This is useful if you keep a file "lazy.lib" which in turn
sources ALL the functions you use.  Source it in your scripts
while developing, but DO NOT put comments on the same line!<br />
You could create one file ending in ".bash" for each function
and then do:
<pre>
printf '. %s\n' $(realpath your/library/*.bash) > lazy.lib
</pre>

It also replaces all lines starting with `###Include:`
with the contents of the file specified after `:`.  
DO NOT put comments on the same line!  
This is useful to unconditionally include things.

## Installation
Copy `flatten.sh` to your `$HOME/bin` and `indentme.vim` to `.vim/scripts`.

Add the following function to your `.bash_aliases` for convenience:

<pre>
flatten() {
  $HOME/bin/flatten.sh "$1" > "${1}.flattened"
  vim -s $HOME/.vim/scripts/indentme.vim "${1}.flattened"
}
</pre>

That will leave indentation of the flattened file to vim as you configured it.

If you need additional commands in indentme.vim type...
<pre>vim -w indentme.vim foo.c</pre>
...followed by the commands you need, then `rm foo.c` and copy `indentme.vim`
to `.vim/scripts/`.

