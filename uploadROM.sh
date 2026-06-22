work_dir=$(pwd)
source $work_dir/functions.sh
RCLONE_CONFIG_1DRIVE="$work_dir/rclone.conf"
RCLONE_REMOTE_NAME="${RCLONE_REMOTE_NAME:-gdrive}"
RCLONE_UPLOAD_DIR="${RCLONE_UPLOAD_DIR:-DeadZoneBuilds/medo_lite}"
os_type=$(cat $work_dir/bin/ddevice/os_type.txt)
base_rom_code=$(cat $work_dir/bin/ddevice/base_rom_code.txt)
androidVER=$(cat $work_dir/bin/ddevice/androidver.txt)
rom_os=$(cat $work_dir/bin/ddevice/rom_os.txt)
regionTYPE=$(cat $work_dir/bin/ddevice/device_type.txt)
device_code=$(cat $work_dir/bin/ddevice/device_code.txt)
baserom_type=$(cat $work_dir/bin/ddevice/romtype.txt)
device_f=$(cat $work_dir/bin/ddevice/device_f.txt)

if [ "$1" == "setup" ]; then
  if [ -z "${RCLONE_CONFIG_BASE64:-}" ]; then
    echo "[ERROR] - Missing RCLONE_CONFIG_BASE64"
    exit 1
  fi

  if ! printf '%s' "$RCLONE_CONFIG_BASE64" | base64 -d > "$work_dir/rclone.conf" 2>/dev/null; then
    echo "[ERROR] - Invalid RCLONE_CONFIG_BASE64"
    rm -f "$work_dir/rclone.conf"
    exit 1
  fi

  if [ ! -s "$work_dir/rclone.conf" ]; then
    echo "[ERROR] - Failed to create rclone.conf"
    exit 1
  fi

  exit 0
fi


if [[ $(git branch --show-current) == "beta" ]]; then
    polyxver="$(cat Version)"
	status="Development"
else
    polyxver="$(cat Version)"
	status="Official"
fi

if [[ $rom_os == "MIUI" ]];then
    os_type="MIUI"
else
    os_type="HyperOS"
fi

repack "Compressing super.img"
zstd --rm $work_dir/build/baserom/images/super.img -o $work_dir/build/baserom/images/super.img.zst > /dev/null 2>&1

repack "Generating flashing script"
if [[ ${baserom_type} == 'payload' ]]; then
    mkdir -p $work_dir/out/${os_type}_${device_code}_${base_rom_code}/images/
	mv -f $work_dir/build/baserom/images/super.img.zst $work_dir/out/${os_type}_${device_code}_${base_rom_code}/
    mv -f $work_dir/build/baserom/images/*.img $work_dir/out/${os_type}_${device_code}_${base_rom_code}/images/
elif [[ ${baserom_type} == 'br' ]]; then
    mkdir -p $work_dir/out/${os_type}_${device_code}_${base_rom_code}/images/
    mv -f $work_dir/build/baserom/firmware-update/* $work_dir/out/${os_type}_${device_code}_${base_rom_code}/images/
    mv -f $work_dir/build/baserom/images/super.img.zst $work_dir/out/${os_type}_${device_code}_${base_rom_code}/
fi

# generate dynamic script
cp -rf $work_dir/bin/script2flash/META-INF $work_dir/out/${os_type}_${device_code}_${base_rom_code}/
cp -rf $work_dir/bin/script2flash/*.bat $work_dir/out/${os_type}_${device_code}_${base_rom_code}/
cp -rf $work_dir/bin/script2flash/cust.img $work_dir/out/${os_type}_${device_code}_${base_rom_code}/images/
echo $device_f > $work_dir/out/${os_type}_${device_code}_${base_rom_code}/META-INF/Data/DeviceCode
repack "Done"


find out/${os_type}_${device_code}_${base_rom_code} |xargs touch
pushd out/${os_type}_${device_code}_${base_rom_code}/ || exit
zip -r ${os_type}_${device_code}_${base_rom_code}.zip ./*
mv ${os_type}_${device_code}_${base_rom_code}.zip ../
popd || exit
hash=$(md5sum out/${os_type}_${device_code}_${base_rom_code}.zip |head -c 5)
mv out/${os_type}_${device_code}_${base_rom_code}.zip out/${os_type}_${polyxver}_${device_code}_${base_rom_code}_${hash}_${status}.zip
repack "Build completed"    
repack "Output: "
repack "$(pwd)/out/${os_type}_${polyxver}_${device_code}_${base_rom_code}_${hash}_${status}.zip"
upload "Uploading"
output_file="out/${os_type}_${polyxver}_${device_code}_${base_rom_code}_${hash}_${status}.zip"

if [[ $rom_os == "MIUI" ]];then
    uploaddir="MIUI"
else
    uploaddir="HyperOS"
fi

# 1drive
rclone -v --config="$RCLONE_CONFIG_1DRIVE" copy "$output_file" "$RCLONE_REMOTE_NAME:$RCLONE_UPLOAD_DIR/" || {
    upload "Error uploading file to remote: $output_file"
    exit 1
}

upload "Clean Workflow.."
rm -rf $work_dir/out
rm -rf $work_dir/build

upload "Build ${os_type}_${polyxver} for ${device_code} successfull!"
