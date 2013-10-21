#!/opt/bin/bash
#
# This is a bash script with config settings for the photo-movie-helper
# that can be used as an example
#
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
#
#--------------------------------------------------

/opt/bin/bash /volume1/ron/scripts/photo-movie-helper/photo-movie-helper.sh \
  -i /volume1/SDCopyFolder \
  -e jpg,mts,mov \
  -o "\
/volume1/photo/Date,\
/volume1/video/MTS,\
/volume1/video/MOV\
" \
  -l /volume1/backup/photo-movie-helper.log \
  -b \
  -v \
  -p "-P -r" \

