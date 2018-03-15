#!/bin/bash
#set -x

check_error() {
	error_code=$1
	if [ $error_code -ne 0 ]
	then
		echo "Error code : $error_code"
		exit 1
	fi
}

convert_seconds() {
	array=$1
	if [ ${#array[@]} -lt 2 ]
	then
		array[2]=${array[0]}
		array[1]=0
		array[0]=0
	elif [ ${#array[@]} -lt 3 ]
	then
		array[2]=${array[1]}
		array[1]=${array[0]}
		array[0]=0;
	fi
	t=$((3600 * ${array[0]} + 60 * ${array[1]} + ${array[2]}))
	echo $t
}
	

flag=0;
while getopts "i:t:d:o:" opt;
do
	case $opt in
		i)
			file=$OPTARG
			((flag++));
			;;
		t)
			offset=$OPTARG
			((flag++));
			;;
		d)
			duration=$OPTARG
			((flag++));
			;;
		o)
			output=$OPTARG
			((flag++));
			;;
		h|\?)
			echo "Usage : \"$0 -i filename -t offset -d duration -o output_folder\"" >&2
			exit 1
			;;
	esac
done

if [ $flag -ne 4 ]
then
	echo "Usage : \"$0 -i file_name -t offset(hh:mm:ss) -d duration(seconds) -o output_folder\"" >&2
	exit 1
fi

mkdir -p frame_extractor_frames
mkdir -p $output

rm -f frame_extractor_frames/*
rm -f $output/*


ffmpeg -i $file -ss $offset -t $duration frame_extractor_frames/frame%06d.jpg 2>&1
error_code=$?
check_error $error_code

ffprobe $file -show_frames -select_streams v -show_entries frame=pkt_pts_time,pkt_pts,pict_type|egrep "(pict_type|pkt_pts_time|pkt_pts)"|cut -d'=' -f'2'>frame_extractor_data 2>&1
error_code=$?
check_error $error_code

fps=$(ffprobe $file -v error -select_streams v -show_entries stream=avg_frame_rate|grep -m 1 'avg_frame_rate'|cut -d'=' -f'2')
error_code=$?
check_error $error_code

IFS='/' read -r -a array <<< $fps
fps=$(((${array[0]}+${array[1]}/2)/${array[1]}))

IFS=':' read -r -a array <<< $offset
t=$(convert_seconds $array)

start=$(($t*$fps+1))
IFS=':' read -r -a array <<< $duration
duration=$(convert_seconds $array)
end=$((($t+$duration)*$fps))

for((i=$start;i<=$end;i++))
do
	number=$(printf %06d $(($i-$start+1)))
	pts1="$(sed -n $(($i*3-2))p frame_extractor_data)"
	pts2="$(sed -n $(($i*3-1))p frame_extractor_data)"
	type="Frame = $(sed -n $(($i*3))p frame_extractor_data)"
	
	ffmpeg -i frame_extractor_frames/frame$number.jpg -vf drawtext="text='$pts1, $pts2, $type':fontcolor=red:y=50:fontsize=30:fontfile='Ubuntu-M.ttf'" $output/frame$number.jpg 2>&1
	if [ $? -ne 0 ]
	then
		break
	fi
done
rm -rf frame_extractor_frames
rm frame_extractor_data
exit 0
