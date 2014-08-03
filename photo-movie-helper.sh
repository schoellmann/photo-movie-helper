#!/opt/bin/bash

# This is a bash script to automatically transfer, rename, move and index
# photos and movies from SD cards to a Synology DiskStation. Can be used on
# other systems as well (without indexing).

# Copyright (C) 2013, Ron Schoellmann
# www.netsinn.de
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

#--------------------------------------------------

VERSION="2.0.2"

# DEFAULT VALUES

# Extensions that exiftool should look for
EXTENSIONS="" # e.g. "jpg,mts,mov"

# Photo output folder corresponding to EXTENSIONS or one folder for all
OUTPUT_FOLDER="" ##/volume1/photo/Date"

# Input directory where imported files can be found
INPUT_FOLDER="" ##/volume1/SDCopyFolder

# Log file location
LOG=/volume1/backup/photo-movie-helper.log

# Additional Exiftool options
EXIFTOOL_PARAMS="-P" ## -r

# File subfolder
# see here: http://owl.phy.queensu.ca/~phil/exiftool/exiftool_pod.html#renaming_examples
FILE_SUBFOLDER="%Y/%Y-%m-%d/"

# File name format for output files
FILENAME_FORMAT="%Y-%m-%d_%Hh%Mm%Ss_%%f"

# File name suffix
FILENAME_SUFFIX=""

# Folder name where DiskStation stores the content from the SD card afer copying it
# not a path, only used for grep
# only relevant if DO_SYNOLOGY_INDEXING is true
SD_COPY_FOLDER_PREFIX=SDCopy

# exiftool
exiftool="$(which exiftool)"
if [ ! -f "$exiftool" ] ; then
  exiftool="/lib/exiftool-folder/exiftool" # symlink to /lib/Image-ExifTool-9.xx/"
fi

# Renamed synousbcopy script
SYNOUSB_SCRIPT="/usr/syno/bin/synousbcopy_renamed_by_ron"

synoindex="$(which synoindex)"
if [ ! -z "$synoindex" -a -f "$synoindex" ] ; then
  DO_SYNOLOGY_INDEXING=true  # indexing and SD copying
else
  DO_SYNOLOGY_INDEXING=false
fi

# Flags
VERBOSE=false
KEEP_SOURCE=false
MOVE_ONLY=false
USE_SYNOUSB=false

#--------------------------------------------------

echo_usage(){

  echo -e "
  Simple bash script to automatically transfer, rename, move and index photos and movies from SD cards to a Synology DiskStation (version $VERSION)

  $(basename "$0") [-hvkmb] [-g <true|false>] [-eoilpsfx <string>]

    Options:

    -h  show this help text
    -v  verbose - show settings values
    -k  keep source files (copy files, \"false\" for erasing, default: $KEEP_SOURCE)
    -m  move only, don't rename (default: $MOVE_ONLY)
    -b  use Synousb - copy from Synology SD/ USB (default: $USE_SYNOUSB)
    -g  do Synology DiskStation indexing - indexing and SD copying if needed (<true|false> default: $DO_SYNOLOGY_INDEXING)

    -e  file extensions that exiftool should look for (comma separated, default: $EXTENSIONS)
    -o  set the output folder paths (comma separated & corresponding to extensions or 1 folder for all, 
        will be created if necessary, default: $OUTPUT_FOLDER)
    -i  set the input folder path (default: $INPUT_FOLDER)
    -l  set the log file location with path and name (will be created, default: $LOG)

    -p  set parameters for Exiftool (default: \"$EXIFTOOL_PARAMS\")
    -s  set file subfolder, e.g. \"%Y/%Y%m%d/\" for 2013/20130101 (exiftool, default: \"$FILE_SUBFOLDER\")
        see here: http://owl.phy.queensu.ca/~phil/exiftool/exiftool_pod.html#renaming_examples
    -f  set file name format, omitted if -m is set (exiftool, default: \"$FILENAME_FORMAT\")
    -x  set file name suffix, omitted if -m is set (exiftool, e.g. \"_\\\${model;}\", default: \"$FILENAME_SUFFIX\")
    "
}

#--------------------------------------------------

error(){
  echo -e "\nERROR: $1\n"
}

error_show_usage(){
  echo -e "\nERROR: $1"
  echo_usage
}

#--------------------------------------------------

# OPTIONS


while getopts ":hvkmbg:e:p:i:l:o:s:f:x:" option
do
  case "${option}"
  in
    h)  echo_usage
        exit 1
        ;;
    v)  VERBOSE=true ;;
    k)  KEEP_SOURCE=true;;
    m)  MOVE_ONLY=true;;
    b)  USE_SYNOUSB=true;;
    g)  DO_SYNOLOGY_INDEXING=${OPTARG}
        if [[ $DO_SYNOLOGY_INDEXING != true && $DO_SYNOLOGY_INDEXING != false ]] ; then
          error_show_usage "Option -b has to be \"true\" or \"false\""
          exit 1
        fi;;
    e)  EXTENSIONS=${OPTARG};;
    o)  OUTPUT_FOLDER=${OPTARG};;
    i)  INPUT_FOLDER=${OPTARG}
        ;;
    l)  LOG=${OPTARG};;
    p)  EXIFTOOL_PARAMS=${OPTARG};;
    s)  FILE_SUBFOLDER=${OPTARG};;
    f)  FILENAME_FORMAT=${OPTARG};;
    x)  FILENAME_SUFFIX=${OPTARG};;
    :)  printf "\nERROR: missing argument for -%s\n" "$OPTARG" >&2
        echo_usage >&2
        exit 1
        ;;
    \?) printf "\nERROR: illegal option: -%s\n" "$OPTARG" >&2
        echo_usage >&2
        exit 1
        ;;
  esac
done

shift $((OPTIND - 1))

#-------------------------------------------------

# SET EXTENSIONS AND OUTPUT FOLDER ARRAYS

OLD_IFS=$IFS
IFS=',' read -ra EXT_ARR <<< "${EXTENSIONS}"
  
IFS=',' read -ra OUTPUT_FOLDER_ARR <<< "${OUTPUT_FOLDER}"
IFS=$OLD_IFS

if (( ${#OUTPUT_FOLDER_ARR[@]} != 1 && ${#OUTPUT_FOLDER_ARR[@]} != ${#EXT_ARR[@]} )) ; then
  error_show_usage "Number of output folders (-o) has to be 1 or equal to number of extensions (-e)"
  exit 1
fi

# Fill up output folder array if just one entry exists
if (( ${#OUTPUT_FOLDER_ARR[@]} != ${#EXT_ARR[@]} )) ; then
  i=0
  for ext in "${EXT_ARR[@]}"
  do
    if (( $i > 0 )) ; then
      OUTPUT_FOLDER_ARR[$i]=${OUTPUT_FOLDER_ARR[0]}
    fi
    ((i=$i+1))
  done
fi

#-------------------------------------------------

# MOVE ONLY

if $MOVE_ONLY ; then
  FILENAME_FORMAT="%%f"
  FILENAME_SUFFIX=""
fi

#-------------------------------------------------

# MORE CHECKS

if [ -f "$exiftool" ] ; then
  perl="$(which perl)"
  if [ ! -f "$perl" ]; then
    error "Perl is missing."
    exit 1
  else
    exiftool="$perl $exiftool"
  fi
else
  error "Exiftool was not found."
  exit 1
fi

if (( ${#EXT_ARR[@]} == 0 )) ; then
  error_show_usage "No extensions (-e) defined."
  exit 1
fi

if [ -z "$INPUT_FOLDER" ] ; then
  error_show_usage "No input folder (-i) defined."
  exit 1
fi

if [ ! -d "$INPUT_FOLDER" ] ; then
  error_show_usage "Input folder (-i) does not exist."
  exit 1
fi

#-------------------------------------------------

# Insert log info
date_formatted=$(date +"%Y-%m-%d %H:%M:%S")
echo -e "\n\n######### $date_formatted (v$VERSION) ##########\n\n" >> $LOG

#-------------------------------------------------

# SHOW OPTIONS

if $VERBOSE ; then
  printf "\n" | tee -a $LOG
  printf "%-35s " "Extensions and folder:" | tee -a $LOG

  i=0
  for ext  in "${EXT_ARR[@]}"
  do
    if (( $i == 0 )) ; then
      printf "%s\n" "$ext: ${OUTPUT_FOLDER_ARR[$i]}" | tee -a $LOG
    else
      printf "%-35s %s\n" "" "$ext: ${OUTPUT_FOLDER_ARR[$i]}" | tee -a $LOG
    fi
    ((i=$i+1))
  done

  printf "%-35s %s\n" "Input folder:" "$INPUT_FOLDER" | tee -a $LOG
  printf "%-35s %s\n" "Log file:" "$LOG" | tee -a $LOG
  printf "%-35s %s\n" "Additional Exiftool parameters:" "$EXIFTOOL_PARAMS" | tee -a $LOG
  printf "%-35s %s\n" "File subfolder:" "$FILE_SUBFOLDER" | tee -a $LOG
  printf "%-35s %s\n" "File name format:" "$FILENAME_FORMAT" | tee -a $LOG
  printf "%-35s %s\n" "File name suffix:" "$FILENAME_SUFFIX" | tee -a $LOG
  printf "%-35s %s\n" "Keep source (copy files):" "$KEEP_SOURCE" | tee -a $LOG
  printf "%-35s %s\n" "Move only:" "$MOVE_ONLY" | tee -a $LOG
  printf "%-35s %s\n" "Do Synology DiskStation indexing:" "$DO_SYNOLOGY_INDEXING" | tee -a $LOG
  printf "%-35s %s\n" "Copy from Synology SD/ USB:" "$USE_SYNOUSB" | tee -a $LOG
  printf "%-35s %s\n" "Script version:" "$VERSION" | tee -a $LOG
  printf "\n" | tee -a $LOG
fi

#-------------------------------------------------

beep() {
  if $DO_SYNOLOGY_INDEXING ; then
    echo 2 > /dev/ttyS1;
  fi
}

#--------------------------------------------------

process_files()
{

  FILE_EXTENSION=$1
  TARGET_FOLDER=$2
  
  echo -e "\n########## $FILE_EXTENSION ##########\n" >> $LOG
  
  # Create tmp folder to put files into
  TMP_FOLDER="${TARGET_FOLDER}/tmp_${FILE_EXTENSION}_$(date +"%Y-%m-%d")"
  
  mkdir $TMP_FOLDER 2>> $LOG

  if [ ! -d "$TMP_FOLDER" ] ; then
    error "Could not create tmp folder for $FILE_EXTENSION" >> $LOG
    exit 1
  fi
  
  if $USE_SYNOUSB && $DO_SYNOLOGY_INDEXING ; then
  
    # Only use newest folder as input
    cd $INPUT_FOLDER/ 2>> $LOG
    DIR_INPUT="$(ls -tr | grep $SD_COPY_FOLDER_PREFIX | tail -n1)"
  
    if [ ! -d "$DIR_INPUT" ] ; then
      error "No input folder found." >> $LOG
      exit 1
    fi
  
    echo -e "Input folder: $DIR_INPUT\n" >> $LOG

  else

    # input folder defined manually
    DIR_INPUT=$INPUT_FOLDER

  fi
  
  # Exiftool processing
  if $KEEP_SOURCE ; then
    COPY_PARAM="-o $DIR_INPUT"
  else
    COPY_PARAM=""
  fi

  echo -e "\nExiftool output start ---\n" >> $LOG
  
  # Last valid assignment supersedes the others
  $exiftool $EXIFTOOL_PARAMS $COPY_PARAM -d "${TMP_FOLDER}/${FILE_SUBFOLDER}${FILENAME_FORMAT}" "$DIR_INPUT" -ext "$FILE_EXTENSION" \
    '-FileName<${CreateDate}.'"$FILE_EXTENSION" \
    '-FileName<${DateTimeOriginal}.'"$FILE_EXTENSION" \
    '-FileName<${CreateDate}'$FILENAME_SUFFIX'.'"$FILE_EXTENSION" \
    '-FileName<${DateTimeOriginal}'$FILENAME_SUFFIX'.'"$FILE_EXTENSION" \
    >> $LOG 2>&1

  echo -e "\n--- Exiftool output end\n" >> $LOG

  cd $TMP_FOLDER/ 2>> $LOG
  
  # IFS is taking care of splitting by new line to handle spaces in file names
  IFS=$(echo -en "\n\b") FILES="$(find * -type f)"
    
  if $VERBOSE; then
    printf "Processing these $FILE_EXTENSION files:\n" | tee -a $LOG
    for file_w_subpath in "${FILES[@]}"
    do
      printf "  %s\n" $file_w_subpath | tee -a $LOG
    done
    printf "\n" | tee -a $LOG
  fi

  for file_w_subpath in ${FILES[*]} ## NOT "${FILES[@]}"
  do
    DIRECTORY="$(dirname $file_w_subpath)"
    FILE="$(basename $file_w_subpath)"
    TARGET_PATH=$TARGET_FOLDER/$DIRECTORY

    if [ "$(ls -A $TMP_FOLDER/$DIRECTORY)" ] ; then  ## "$(ls -A $DIR)" checks if dir is not empty

      # Create folder if needed
      if [ ! -d "$TARGET_PATH" ] ; then
        mkdir -p $TARGET_PATH >> $LOG 2>&1 
        if [ $? -eq 0 ]; then
          echo "Created directory: $TARGET_PATH" >> $LOG
        fi

        # Add folder to index
        if $DO_SYNOLOGY_INDEXING ; then
          $synoindex -A $TARGET_PATH >> $LOG 2>&1
        fi
      fi

      # Check files and mv/ add individually
      if [ ! -f "$TARGET_FOLDER/$file_w_subpath" ]; then 
        mv $TMP_FOLDER/$file_w_subpath $TARGET_PATH/ 2>> $LOG
        if [ $? -eq 0 ]; then
          echo "Moved file: $FILE to $TARGET_PATH" >> $LOG
        else
          echo "Could not move file: $FILE to $TARGET_PATH" >> $LOG
        fi

        # Add file to index
        if $DO_SYNOLOGY_INDEXING ; then
          $synoindex -a $TARGET_FOLDER/$file_w_subpath >> $LOG 2>&1
        fi

      else
        echo "File existed: $TARGET_FOLDER/$file_w_subpath" >> $LOG
      fi
      
    fi
  done

  # Remove tmp folder (if empty)
  if [ -z "$( find $TMP_FOLDER -type f )" ] ; then
    rm -r $TMP_FOLDER 2>> $LOG
  else
    error "tmp folder not empty" >> $LOG

    # Remove empty subfolders
    # IFS is taking care of splitting by new line to handle spaces in file names
    IFS=$(echo -en "\n\b") DIRS="$(find $TMP_FOLDER -type d)"

    for dir in ${DIRS[*]}
    do
      [ -d "$dir" ] && [ -z "`find $dir -type f`" ] && rm -r $dir
    done
  fi

  # Reset IFS
  IFS=$OLD_IFS
}

#--------------------------------------------------

# ACTUAL PROCESSING START

STARTTIME=$(date +%s)

# Call original files
if $USE_SYNOUSB ; then
  $SYNOUSB_SCRIPT >> $LOG
fi

# Create output folder if necessary
for folder in "${OUTPUT_FOLDER_ARR[@]}"
do
  if [ ! -d "$folder" ] ; then
    mkdir -p $folder 2>> $LOG

    # Add folder to index
    if $DO_SYNOLOGY_INDEXING ; then
      $synoindex -A $folder >> $LOG 2>&1
    fi
  fi
done

i=0
for ext in "${EXT_ARR[@]}"
do
   if [ "$ext" != "" ] ; then
     process_files "$ext" "${OUTPUT_FOLDER_ARR[$i]}"
   fi
  ((i=$i+1))
  echo -e "" >> $LOG
done

# Re-index input folder
if $DO_SYNOLOGY_INDEXING; then
  $synoindex -R $INPUT_FOLDER >> $LOG 2>&1
fi

# Reset IFS
IFS=$OLD_IFS

ENDTIME=$(date +%s)
T=$(( $ENDTIME - $STARTTIME ))
printf "######### Took %02dh%02dm%02ds ##########\n\n" "$((T/3600%24))" "$((T/60%60))" "$((T%60))" >> $LOG

beep
