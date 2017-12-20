#!/usr/bin/env bash

# INFO: requires bash, shntools and flac
#	requires optionally mac (Monkey's Audio Codec for .ape file support)
#	https://askubuntu.com/questions/800622/ape-files-monkeys-audio-how-to-create-them-under-trusty-and-xenial#804263
# Usage: somewhat like
#	cd target_dir; ~/Music/flac2flacs.sh
#	or
#	find . -iname "*.cue" -printf '%h\0' | uniq -z | xargs -0 -I^^ bash -c 'cd "^^"; ~/Music/flac2flacs.sh'

### EDIT this up to you needs
export outfiletype=flac
export outdir="/storage/7.7/music/outflac"
export tmpdir="tmp"
export stuffdir="stuff"
export pregapfile_ipattern="*00*pregap*.*"				# To be removed
export stufffile_exts="jpg jpeg png gif htm html pdf gp4 gp5 tg"	# To be saved

### DO NOT EDIT the following unless absolutely sure
export me=`basename "$0"`
function filesearch() {
	# search the first matched file name in the current dir
	local filename=$1	# like myfile
	local filext=$2		# like .txt
  # escape square brackets
	local search_pattern=`echo "$filename$filext" | sed -re 's/([][])/\\\\\\1/g'`
	# DEBUG: echo -e "\n\nDEBUG: ___ $search_pattern ___ \n" >/dev/stderr
	local search_result=`find "$PWD" -maxdepth 1 -type f -iname "$search_pattern" | head -n 1`
	echo $search_result
}
export -f filesearch

function getfiletype() {
	# determine the file type
	local infile=$1
	local type=
	local type_fromfile=`file -b "$infile"`
	# return lower-case type or err
	case $type_fromfile in
		"FLAC"*)
			type=flac
			;;
		"Monkey's"*)
			type=ape
			;;
		*"No such file"*)
			echo $me [${FUNCNAME[0]}]: "no file name given" >/dev/stderr
			exit 1
			;;
		*)
			echo $me [${FUNCNAME[0]}]: "couldn't determine \"$infile\" file type" >/dev/stderr
			exit 1
			;;
	esac
	echo $type
}
export -f getfiletype

function getfilefromcue() {
	# get the target sound file name from the CUE file data
	local cuefile=$1
	local filename_fromcue=`grep FILE "$cuefile" | sed 's/FILE\ *"\(.*\)".*/\1/'`
	local filename=`filesearch "$filename_fromcue"`
	if [ "xxx$filename" = "xxx" ] ; then
		echo $me [${FUNCNAME[0]}]: "can't find file \"$filename_fromcue\" got from this cue sheet" >/dev/stderr
		exit 1
	fi
	echo $filename
}
export -f getfilefromcue

function splitfile() {
	local cuefile=$1
	local tmpdir=$2
	local infile=`getfilefromcue "$cuefile"`
	local infiletype=`getfiletype "$infile"`
	mkdir -p "$tmpdir"
	# split based on the infile type
	case  $infiletype in
		ape|flac)
			shntool split 					\
				-q					\
				-P dot					\
				-o "flac flac -s --best -o %f -" 	\
				-O always 				\
				-f "$cuefile" 				\
				-t "%p~%a~%n~%t" 			\
				-m '/-' 				\
				-d "$tmpdir" 				\
				"$infile"
			;;
		"")
			echo $me [${FUNCNAME[0]}]: "no file to split" >/dev/stderr
			exit 1
			;;
		*)
			echo $me [${FUNCNAME[0]}]: "unknown input file  \"${infile}\" type \"${infiletype}\", no idea how to split it" >/dev/stderr
			exit 1
			;;
	esac
	# remove "pregap" artifacts from the result
	cleanup "$tmpdir" "$pregapfile_ipattern"
}
export -f splitfile

function cleanup() {
	# remove "pregap" artifacts, etc.
	local targetdir=$1
	local targetfilename=$2
	find "$targetdir" -type f -iname "$targetfilename" -delete
}
export -f cleanup

function copystuff() {
	# find and copy (stuff) files to target dir
	# join_by function is got from
	# https://stackoverflow.com/questions/1527049/join-elements-of-an-array#17841619
	function join_by() {
		local d=$1
		shift
		echo -n "$1"
		shift
		printf "%s" "${@/#/$d}"
	}
	local stufffile_exts=$1
	local stuffdir=$2
	# jpg|png|gif|etc
	local stufffile_ipattern=`join_by '\|' $stufffile_exts`
	# .*\.(jpg|png|gif|etc)
	# i.e. *.jpg OR *.png OR *.gif OR *.etc
	stufffile_ipattern='.*\.\('${stufffile_ipattern}'\)'
	mkdir -p "$tmpdir/$stuffdir" && 							\
	find "$PWD" -type f \! -wholename "*/$tmpdir/*" -iregex "$stufffile_ipattern" -print0 |	\
	xargs -0 -I^^ 										\
	cp -f "^^" "$tmpdir/$stuffdir"
}
export -f copystuff

function tagoutfiles() {
	function tagfile() {
		local outfile=$1
		# the file name without extension and the path
		local name=`basename -s ".$outfiletype" "$outfile"`
		# sanitizer (backslasher) for possible symbols  ` ! $ " / \
		# 	sed -re 's/([\`!$"/\])/\\1/g'
		# maybe need to expand to  re_forbidden_chars = re.compile(r'["\*\/:<>\?\\|]')
		# the second sed us used to lowercase then Capitalize First Letters of the Artist:
		#    sed 's/\(.*\)/\L\1/;s/\b[a-z]/\U&/g'
		# DEBUG: name='Borgne"~Royaume Des Ombres~04~Only the Dead Can Be Heard.flac'
		local    tag_year=`echo $tag_year_fromcue            | sed -re 's/([\`!$"/\])/\\1/g'`
		local  tag_artist=`echo $name | awk -F~ '{print $1}' | sed -re 's/([\`!$"/\])/\\1/g' | sed 's/\(.*\)/\L\1/;s/\b[a-z]/\U&/g'`
		local   tag_album=`echo $name | awk -F~ '{print $2}' | sed -re 's/([\`!$"/\])/\\1/g' | sed 's/\b[a-z]/\U&/g'`
		local tag_trackno=`echo $name | awk -F~ '{print $3}' | sed -re 's/([\`!$"/\])/\\1/g'`
		local   tag_title=`echo $name | awk -F~ '{print $4}' | sed -re 's/([\`!$"/\])/\\1/g' | sed 's/\b[a-z]/\U&/g'`
		case $outfiletype in
			flac)
				metaflac --remove-tag=ARTIST  \
					 --remove-tag=DATE          \
					 --remove-tag=ALBUM         \
					 --remove-tag=TRACKNUMBER   \
					 --remove-tag=TITLE         \
					 "$outfile"
				metaflac --set-tag="ARTIST=${tag_artist}"  \
					 --set-tag="DATE=${tag_year}"            \
					 --set-tag="ALBUM=${tag_album}"          \
					 --set-tag="TRACKNUMBER=${tag_trackno}"  \
					 --set-tag="TITLE=${tag_title}"          \
					 "$outfile"
				# DEBUG: metaflac --list "$filename"
				;;
			*)
				echo $me [${FUNCNAME[0]}]: "unknown output file \"${outfile}\" type \"${outfiletype}\", no idea how to tag it" >/dev/stderr
				exit 1
				;;
		esac
	}
	export -f tagfile
	local cuefile=$1
	local dir=$2
	export tag_year_fromcue=`grep DATE "$cuefile" | head -n 1 | awk '{print $3}' | tr -d '\r'`
	find "$dir" -type f -iname "*~*~*~*.$outfiletype" -exec bash -c 'tagfile "{}"' \;
}
export -f tagoutfiles

function renametaggedfiles() {
	function renamefile() {
		function readfiletags() {
			local filename=$1
			# try to get metadata needed to rename from file tag
			case $filetype in
				flac)	metaflac --show-tag=ARTIST 		\
						 --show-tag=DATE 		\
						 --show-tag=ALBUM 		\
						 --show-tag=TRACKNUMBER 	\
						 --show-tag=TITLE 		\
						 "$filename"
					# DEBUG: metaflac --list "$filename"
					;;
				*)
					echo $me [${FUNCNAME[0]}]: "unknown source file \"${filename}\" type \"${filetype}\", no idea how to get tags from it" >/dev/stderr
					exit 1
					;;
			esac
		}
		local srcfile=$1
		# first, try file tag
		export filetype=`getfiletype "$srcfile"`
		local tags=`readfiletags "$srcfile"`
		# extract tags from the metaflac output having format as
		# Make tag contents FAT-friendly (implies music players and other portable devices)
		# replacing characters < > : " / \ | ? *
		# (as per https://msdn.microsoft.com/en-us/library/aa365247(VS.85).aspx)
		# with _ and deleting newlines/returns as well
		# so should be ok particularly with *nix common FS'es
		# DEBUG:
		# tags="
		# 	ARTIST=Cool Band
		# 	DATE=2012
		# 	ALBUM=Debut Album\/<
		# 	TRACKNUMBER=01
		# 	TITLE=First Song About Something
		# "
		local  artist=`echo "$tags" | grep ARTIST      | head -n 1 | tr -d '<>:"/|?*\n\r\\\' | sed -re 's/^\s*ARTIST=(.*)/\1/'`
		local    year=`echo "$tags" | grep DATE        | head -n 1 | tr -d '<>:"/|?*\n\r\\\' | sed -re 's/^\s*DATE=(.*)/\1/'`
		local   album=`echo "$tags" | grep ALBUM       | head -n 1 | tr -d '<>:"/|?*\n\r\\\' | sed -re 's/^\s*ALBUM=(.*)/\1/'`
		local trackno=`echo "$tags" | grep TRACKNUMBER | head -n 1 | tr -d '<>:"/|?*\n\r\\\' | sed -re 's/^\s*TRACKNUMBER=(.*)/\1/'`
		local   title=`echo "$tags" | grep TITLE       | head -n 1 | tr -d '<>:"/|?*\n\r\\\' | sed -re 's/^\s*TITLE=(.*)/\1/'`
		# TODO: if tags are not enough, try to get the metadata from the file name (TBD some kind of scoring?)
		# TODO: try to get the metadata from the file path as well
		# TODO: IMPORTANT: need to check if the names will be ok to rename, otherwise error stop
		local  dstdir="${outdir}/${artist}/${year} - ${album}"
		local dstfile="${dstdir}/${trackno} - ${title}.${filetype}"
		# make the destination dir we'll have all files into
		# and return it up on success
		mkdir -p "$dstdir" && echo "$dstdir"
		# finally, rename
		mv -fu "$srcfile" "$dstfile"
		echo "$dstdir"
	}
	# for further execution withing `find'
	export -f renamefile
	local  srcdir=$1
	export outdir=$2
	# dst dir from metadata of the some (last?) file to be renamed, should be the same across all the files in srcdir, otherwise...
	# find and rename inside :)
	local dstdir=`find "$srcdir" -maxdepth 1 -type f -iname "*.$outfiletype" -exec bash -c 'renamefile "{}"' \; | tail -n 1`
	#echo -n "-> \"$dstdir\" ... "
  if [[ ! -z $dstdir ]] ; then
	  # if dstdir is not null, copy/"rename" the stuff as well
		mkdir -p "${dstdir}/${stuffdir}" &&\
		# TODO: add check if the source files exist for copying
		# to prevent non-critical messages like
		# 	cp: cannot stat 'tmp/stuff/*': No such file or directory
		find "$tmpdir/$stuffdir" -mindepth 1 -print0 | 	\
		xargs -0 -I^^				\
		cp -fu "^^" "${dstdir}/${stuffdir}"/
  else
		echo $me [${FUNCNAME[0]}]: "no (stuff) final destination possible" > /dev/stderr
		exit 1
		rm -rf "$tmpdir/$stuffdir"
	fi
	rm -rf "$tmpdir/$stuffdir"
}
export -f renametaggedfiles

function process() {
	local cuefile=$1
	echo -n "processing \"$cuefile\" ... "
	# split sound file having its filename got from the CUE file
	# and put resulting files into output dir
	# then perform copy of media stuff (covers, lyrics, etc.) if the successful split
	splitfile         "$cuefile"        "$tmpdir"   &&\
	copystuff         "$stufffile_exts" "$stuffdir"
	tagoutfiles       "$cuefile"        "$tmpdir"   &&\
	renametaggedfiles "$tmpdir"	    "$outdir"   &&\
	rmdir             "$tmpdir"
}
export -f process

find "$PWD" -maxdepth 1 -type f -iname "*.cue" -execdir bash -c 'process "{}" && echo done.' \;

exit 0
