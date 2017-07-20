#!/bin/bash

#  Copyright 2017 The WWU eLectures Team All rights reserved.
#
#  Licensed under the Educational Community License, Version 2.0
#  (the "License"); you may not use this file except in compliance with
#  the License. You may obtain a copy of the License at
#
#     http://opensource.org/licenses/ECL-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.


# Notes:
#  - thread_queue_size needs to be increased to prevent alsa buffer underruns.
#  - itsoffset can be used to synchronize inputs
#  - the first complex filter compresses & limits the audio input quite hard.
#    try to set the input level to about -12dbFS for optimal results
#  - the second complex filter overlays the camera stream in the lower right
#    corner over the capture card input. change the last scale= parameter for
#    desired output size. The overlay= calculations position the overlay in
#    reference to a 1920x1080 frame. The first scale= parameter scales the
#    overlay in reference to a 1920x1080 frame to be 500px wide.
#  - For livestreaming you want small GOPs to improve start-time (-g 25 = 1 second).


ffmpeg -loglevel fatal \
  -itsoffset {{ livestream_role.offset.tracking }} -i "rtsp://{{ livestream_role.camera.user }}:{{ livestream_role.camera.pass }}@{{ livestream_role.camera.host }}:554/axis-media/media.amp?camera=2" \
	-f v4l2 -i /dev/video0 \
  -thread_queue_size 2048 -itsoffset {{ livestream_role.offset.audio }} -f alsa -i dsnoop \
	-filter_complex "highpass=f=120,acompressor=threshold=0.3:makeup=4:release=20:attack=5:knee=4:ratio=10:detection=peak,alimiter=limit=0.8" \
  -filter_complex "[0:v]scale=w=500:h=-1[a];[1:v][a]overlay=(W-w-20):(H-h-20)[b];[b]scale=w=1280:h=720[x]" \
	-map "[x]:0" -map "2:0" \
  -c:a aac \
	-c:v libx264 -bf 0 -g 25 -crf 25 -preset veryfast \
	-f flv {{ livestream_role.target }}
