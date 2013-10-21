# photo-movie-helper

(Renamed from photo-movie-helper-for-dsm to photo-movie-helper to reflect wider usability after upgrade.)

This is a bash script to automatically transfer, rename, move and index photos and movies from SD cards to a Synology DiskStation. It can be used on other systems as well (without indexing functionality).

For help type `bash photo-movie-helper.sh -h`

Usage:

>bash photo-movie-helper.sh [OPTIONS]
>
>    Options:
>
>    -h  show this help text
>    -v  verbose - show settings values
>    -k  keep source files ("false" for erasing)
>    -m  move only, don't rename
>    -b  use Synousb - copy from Synology SD/ USB
>    -g  do Synology DiskStation indexing - indexing and SD copying if needed (<true|false>)
>
>    -e  file extensions that exiftool should look for (comma separated)
>    -o  set the output folder paths (comma separated & corresponding to extensions or 1 folder for all)
>        will be created if necessary
>    -i  set the input folder path
>    -l  set the log file location with path and name
>
>    -p  set parameters for Exiftool
>    -s  set file subfolder, e.g. "%Y/%Y%m%d/" for 2013/20130101 (exiftool)
>        see here: http://owl.phy.queensu.ca/~phil/exiftool/exiftool_pod.html#renaming_examples
>    -f  set file name format, omitted if -m ist set (exiftool)
>    -x  set file name suffix, omitted if -m ist set (exiftool, e.g. "_\${model;}")

For more information and an installation guide, please refer to this [blog post](http://www.netsinn.de/en/how-to-set-up-synologys-diskstation-to-automatically-transfer-rename-move-and-index-photos-movies/).
