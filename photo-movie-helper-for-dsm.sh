#!/opt/bin/bash

# This is a simple bash script to automatically transfer, rename, move and index
# photos and movies from SD cards to a Synology DiskStation.

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

# Log file location
LOG=/volume1/backup/photo-movie-helper.log

# Input directory where imported files can be found
INPUT_FOLDER=/volume1/SDCopyFolder

SD_COPY_FOLDER_PREFIX=SDCopy

# Photo output folder
PHOTO_FOLDER=/volume1/photo/Date

# Video output folder
VIDEO_FOLDER=/volume1/video/MTS

#--------------------------------------------------

beep() {
  echo 2 > /dev/ttyS1;
}

#--------------------------------------------------

# Insert log info
echo ------------------------- >> $LOG
date +"%Y-%m-%d %H:%M:%S" >> $LOG
echo "" >> $LOG

# Call original files
/usr/syno/bin/synousbcopy_renamed_by_ron >> $LOG


# Create output folder if necessary
if [ ! -d $PHOTO_FOLDER ] ; then
  mkdir -p $PHOTO_FOLDER 2>> $LOG
fi

if [ ! -d $VIDEO_FOLDER ] ; then
  mkdir -p $VIDEO_FOLDER 2>> $LOG
fi


# JPG #
echo "PHOTOS" >> $LOG
echo "" >> $LOG

# Create tmp folder to put files into
TMP_FOLDER="$INPUT_FOLDER/tmp_$(date +"%Y-%m-%d")"
mkdir $TMP_FOLDER 2>> $LOG
TMP_FILE="$INPUT_FOLDER/tmp_file"

# Only use newest folder as input
cd $INPUT_FOLDER/ 2>> $LOG
DIR_INPUT="$(ls -tr | grep $SD_COPY_FOLDER_PREFIX | tail -n1)"
echo "Input folder: $DIR_INPUT" >> $LOG
echo "" >> $LOG

# File processing
exiftool -P -r '-FileName<${DateTimeOriginal}.jpg' -d "$TMP_FOLDER/%Y/%Y%m%d/%Y-%m-%d_%Hh%Mm%Ss_%%f" "$DIR_INPUT" -ext jpg >> $LOG 2>&1

# Get created directories (but exclude year folders via regex)
cd $TMP_FOLDER/ 2>> $LOG
find * -type d -regex ".\{5,\}" > $TMP_FILE 2>> $LOG

DIRECTORIES=""
i=0 
while read LINE ; do
  DIRECTORIES[$((i=i+1))]="$LINE" 
done < $TMP_FILE

echo "" >> $LOG

for directory in ${DIRECTORIES[*]}
do
  TARGET_DIR=$PHOTO_FOLDER/$directory

  # Move folder/ contents to target
  if [ ! -d $TARGET_DIR ] ; then
    echo "Moved content of folder: $TARGET_DIR" >> $LOG
    mkdir $TARGET_DIR >> $LOG 2>&1 
    mv $TMP_FOLDER/$directory/* $TARGET_DIR/ 2>> $LOG
    # Add folder to index
    /usr/syno/bin/synoindex -A $TARGET_DIR >> $LOG 2>&1
  else
    echo "Folder existed: $TARGET_DIR" >> $LOG

    # Check files and mv/ add individually
    cd $TMP_FOLDER/$directory 2>> $LOG
    FILES=($(find * -type f)) 

    for file in ${FILES[*]}
    do
      if [ ! -f $PHOTO_FOLDER/$directory/$file ]; then 
        echo "Moved file: $file to $TARGET_DIR" >> $LOG
        mv $TMP_FOLDER/$directory/$file $TARGET_DIR/ 2>> $LOG
        # Add file to index
        /usr/syno/bin/synoindex -a $TARGET_DIR/$file>> $LOG 2>&1
      else
        echo "File existed: $file" >> $LOG
      fi
    done
  fi
done

# Remove tmp folder and tmp file
rm -r $TMP_FOLDER 2>> $LOG
rm $TMP_FILE 2>> $LOG

# PHOTOS END


# MTS/movie #
echo "" >> $LOG
echo "VIDEOS" >> $LOG
echo "" >> $LOG

# Create tmp folder to put files into
TMP_FOLDER="$INPUT_FOLDER/tmp_$(date +"%Y-%m-%d")"
mkdir $TMP_FOLDER 2>> $LOG
TMP_FILE="$INPUT_FOLDER/tmp_file"

# Only use newest folder as input
cd $INPUT_FOLDER/ 2>> $LOG
DIR_INPUT="$(ls -tr | grep $SD_COPY_FOLDER_PREFIX | tail -n1)"
echo "Input folder: $DIR_INPUT" >> $LOG
echo "" >> $LOG

# File processing
exiftool -P -r '-FileName<${DateTimeOriginal}.mts' -d "$TMP_FOLDER/%Y%m%d/%#Y-%m-%d_%Hh%Mm%Ss_%%f" "$DIR_INPUT" -ext mts >> $LOG 2>&1

# Get created directories (but exclude year folders via regex)
cd $TMP_FOLDER/ 2>> $LOG
find * -type d -regex ".\{5,\}" > $TMP_FILE 2>> $LOG

DIRECTORIES_MTS=""
i=0 
while read LINE ; do
  DIRECTORIES_MTS[$((i=i+1))]="$LINE" 
done < $TMP_FILE

echo "" >> $LOG

for directory in ${DIRECTORIES_MTS[*]}
do
  TARGET_DIR=$VIDEO_FOLDER/$directory

  # Move folder/ contents to target
  if [ ! -d $TARGET_DIR ] ; then
    echo "Moved content of folder: $TARGET_DIR" >> $LOG
    mkdir $TARGET_DIR >> $LOG 2>&1 
    mv $TMP_FOLDER/$directory/* $TARGET_DIR/ 2>> $LOG
    # Add folder to index
    /usr/syno/bin/synoindex -A $TARGET_DIR >> $LOG 2>&1
  else
    echo "Folder existed: $TARGET_DIR" >> $LOG

    # Check files and mv/ add individually
    cd $TMP_FOLDER/$directory 2>> $LOG
    FILES=($(find * -type f)) 

    for file in ${FILES[*]}
    do
      if [ ! -f $VIDEO_FOLDER/$directory/$file ]; then 
        echo "Moved file: $file to $TARGET_DIR" >> $LOG
        mv $TMP_FOLDER/$directory/$file $TARGET_DIR/ 2>> $LOG
        # Add file to index
        /usr/syno/bin/synoindex -a $TARGET_DIR/$file>> $LOG 2>&1
      else
        echo "File existed: $file" >> $LOG
      fi
    done
  fi
done

# Remove tmp folder and tmp file
rm -r $TMP_FOLDER 2>> $LOG
rm $TMP_FILE 2>> $LOG

# MTS END

beep
