#!/usr/bin

# TODO: export settings to a encyrpte file
: ${FTP_URL="https://earth.tail-f.com:8443"}
: ${SETUP_FILE_DIR="setup_files"}
: ${PROJECT_DIR="projects"}
: ${INSTALL_DIR="install"}
: ${NETSIM_DIR="netsim"}
: ${NETSIM_INFO_FILE=".netsiminfo"}
: ${RUN_DIR="run"}
: ${SCRIPT_DIR=`pwd`}
: ${SCRIPT_NAME="nso_auto.sh"}
: ${LATEST_VERSION_PATH="https://wwwin-gitlab-sjc.cisco.com/release/nso/raw/master/VERSION"}
: ${SCRIPT_ONLINE_PATH="https://wwwin-gitlab-sjc.cisco.com/release/nso/raw/master/${SCRIPT_NAME}"}
: ${VERSION="1.1.3"}

##### Functions Library
parse_file_name(){
  file_path=$1
  file_name="${file_path##*/}"
  echo ${file_name}
}

get_file_list_from_ftp(){
  username=$1
  password=$2

  curl --insecure --user ${username}:${password} ${FTP_URL}/dir.txt
}

check_archive(){
  file_name=$1

  if [ -e "${SETUP_FILE_DIR}/${file_name}" ]; then
    echo "True"
  else
    echo "False"
  fi
}

download_file_from_ftp(){
  username=$1
  password=$2
  file_path=$3

  file_name=$(parse_file_name ${file_path})

  if [ $(check_archive ${file_name}) == 'False' ]; then
    curl --insecure -u ${username}:${password} -o "${SETUP_FILE_DIR}/${file_name}" "${FTP_URL}/${file_path}"
  fi
}

install_nso(){
  project_id=$1
  nso_setup_file_name=$2

  project_directory="${PROJECT_DIR}/${project_id}"
  rm -rf ${project_directory}
  mkdir ${project_directory}

  cp "${SETUP_FILE_DIR}/${nso_setup_file_name}" ${project_directory}

  cd ${project_directory}

  if [[ ${nso_setup_file_name} == *signed.bin ]]; then
    sh ${nso_setup_file_name} --skip-verification
    nso_setup_file_name=${nso_setup_file_name//signed.bin/installer.bin}
  fi

  sh ${nso_setup_file_name} ${INSTALL_DIR}
  rm -f *
  rm -rf ${INSTALL_DIR}/packages/neds/*
}

install_ned(){
  project_id=$1
  ned_setup_file_name=$2

  project_directory="${PROJECT_DIR}/${project_id}"

  if [[ ! -d "${project_directory}/${NETSIM_DIR}" ]]; then
    cp "${SETUP_FILE_DIR}/${ned_setup_file_name}" ${project_directory}

    cd ${project_directory}

    if [[ ${ned_setup_file_name} == *signed.bin ]]; then
      sh ${ned_setup_file_name} --skip-verification
      ned_setup_file_name=${ned_setup_file_name//signed.bin/tar.gz}
    fi

    tar -xf ${ned_setup_file_name} -C ${INSTALL_DIR}/packages/neds/
    rm -f *
  fi
}

add_netsim_device(){
  project_id=$1
  device_name=$2
  device_type=$3

  project_directory="${PROJECT_DIR}/${project_id}"
  cd ${project_directory}

  . ${INSTALL_DIR}/ncsrc
  if [[ ! -d netsim ]]; then
    ncs-netsim create-device ${device_type} ${device_name}
  else
    ncs-netsim add-device ${device_type} ${device_name}
  fi

  cd ../../
  restart_netsim_device ${project_id} ${device_name}
}

restart_netsim_device(){
  project_id=$1
  device_name=$2

  project_directory="${PROJECT_DIR}/${project_id}"
  cd ${project_directory}

  . ${INSTALL_DIR}/ncsrc

  ncs-netsim restart ${device_name}
  cd ../../
}

setup_nso(){
  project_id=$1
  netsim_enabled=${2:-True}

  project_directory="${PROJECT_DIR}/${project_id}"
  cd ${project_directory}

  . ${INSTALL_DIR}/ncsrc

  if [ ${netsim_enabled} == True ]; then
    ncs-setup --netsim-dir netsim --dest run
  else
    ncs-setup --dest run
  fi

  cd ../../
}

check_file_name(){
  file_name=$1
  if echo "${file_name}" | grep -w "^[a-zA-Z0-9_\-]*$" >/dev/null && [ ! -z ${file_name} ]; then
    echo "True"
  else
    echo "False"
  fi
}

##### Interactive Mode Functions
# Define the dialog exit status codes
: ${DIALOG_OK=0}
: ${DIALOG_CANCEL=1}
: ${DIALOG_HELP=2}
: ${DIALOG_EXTRA=3}
: ${DIALOG_ITEM_HELP=4}
: ${DIALOG_ESC=255}

: ${SIG_NONE=0}
: ${SIG_HUP=1}
: ${SIG_INT=2}
: ${SIG_QUIT=3}
: ${SIG_KILL=9}
: ${SIG_TERM=15}

# Define interactive mode settings
: ${BACK_TITLE="NSO Auto Setup by euronso"}
: ${X_Y_POSITION="2 3"}
: ${DEFAULT_SIZE="20 55"}

# Menu options for redirecting
: ${MENU_LOGIN="login"}
: ${MENU_MAIN="main"}
: ${MENU_ADD_PROJECT="add_project"}
: ${MENU_SET_PROJECT_NAME="set_project_name"}
: ${MENU_SETUP_PROJECT="setup_project"}
: ${MENU_SET_NSO_VERSION="set_NSO_version"}
: ${MENU_ADD_NETSIM="add_netsim"}
: ${MENU_DELETE_NETSIM="delete_netsim"}
: ${MENU_UPDATE_LIST="update_list"}
: ${MENU_LIST_PROJECT="list_project"}
: ${MENU_CHECK_VERSION="check_version"}

# Project information holders
NSO_SETUP_FILE_LIST=()
NED_SETUP_FILE_LIST=()
NSO_VERSION_LIST=()
NED_VERSION_LIST=()
PROJECT_NAME=""
NSO_VERSION=""
DEVICE_NAME_LIST=()
DEVICE_VERSION_LIST=()

# Simple message box
message_box(){
  message=$1
  # width and height values, they have default values if not provided
  width=${2:-50}
  height=${3:-10}

  dialog \
    --clear \
    --begin ${X_Y_POSITION} \
    --backtitle "${BACK_TITLE}" --no-collapse \
    --msgbox "${message}" ${height} ${width}
}
# Confirmation box for quit events
quit_box(){
  dialog \
    --clear \
    --begin ${X_Y_POSITION} \
    --backtitle "${BACK_TITLE}" \
    --yesno "Do you want to quit?" 10 50

  case $? in
    ${DIALOG_OK})
      clear; exit
      ;;
  esac
}

# Set project name form
set_project_name(){
  name=$(dialog --title "Project Form | Set Project Name" \
      --backtitle "${BACK_TITLE}" \
      --begin ${X_Y_POSITION} \
      --no-cancel \
      --inputbox  "Project Name" ${DEFAULT_SIZE} "${PROJECT_NAME}" \
    3>&1 1>&2 2>&3)

  # check project name
  if [[ ${name} != "" ]] &&
  [[ "$(check_file_name "${name}")" == "False" ]]; then
    message_box "Project name can contain only [a-z][A-Z][0-9][_-] characters!"
  else
    PROJECT_NAME=${name}
    CURRENT_MENU=${MENU_ADD_PROJECT}
  fi
}
# Set project NSO version form
set_NSO_version(){
  i=${#NSO_SETUP_FILE_LIST[@]}
  if [[ ${i} != 0 ]]; then
    if [[ ${#NSO_VERSION_LIST[@]} == 0 ]]; then
      for file_path in ${NSO_SETUP_FILE_LIST[@]}; do
        file_name=$(parse_file_name ${file_path})
        NSO_VERSION_LIST+=( "${file_name}" "" on )
      done
    fi
  else
    message_box "NSO version list is empty!"
    CURRENT_MENU=${MENU_ADD_PROJECT}
    return
  fi

  version=$(dialog --title "Project Form | Select NSO version" \
      --backtitle "${BACK_TITLE}" \
      --begin ${X_Y_POSITION} \
      --radiolist "Please select NSO version" ${DEFAULT_SIZE} ${i} \
      "${NSO_VERSION_LIST[@]}" \
    3>&1 1>&2 2>&3)

  if [[ $? == ${DIALOG_OK} ]]; then
    NSO_VERSION=${version}

    # new NSO version is selected reset all related data
    NED_VERSION_LIST=()
    DEVICE_NAME_LIST=()
    DEVICE_VERSION_LIST=()
  fi

  CURRENT_MENU=${MENU_ADD_PROJECT}
}
# Add Netsim device form
add_netsim(){
  device_name=$(dialog --title "Project Form | Add Device | Device Name" \
      --backtitle "${BACK_TITLE}" \
      --begin ${X_Y_POSITION} \
      --ok-label "Select NED Version" \
      --inputbox "Please enter a device name" ${DEFAULT_SIZE} \
    3>&1 1>&2 2>&3)

  case $? in
    ${DIALOG_OK})
      if [[ ${device_name} != '' ]]; then
        if [[ "$(check_file_name "${device_name}")" == "False" ]]; then
          message_box "Device name can contain only [a-z][A-Z][0-9][_-] characters!"
        elif [[ ${DEVICE_NAME_LIST[@]} == *${device_name}* ]]; then
          # TODO: if d1 is in th list, can't add d, check condition
          message_box "$device_name is already in the list, please give another name!"
        else
          select_ned ${device_name}
        fi
      fi
      ;;
    *)
      CURRENT_MENU=${MENU_ADD_PROJECT}
      ;;
  esac
}
# Select Netsim device NED version form
select_ned(){
  device_name=$1

  # filter NED list base on selected NSO version and list =< versions of NEDs
  i=${#NED_VERSION_LIST[@]}
  if [[ ${i} == 0 ]]; then
    # TODO: bug can't list NED version which has more than 2 decimal in NSO version
    # NSO 4.4 can only list 4.4.1.1 version of NEDs
    NSO_ver=$(echo ${NSO_VERSION} | grep -oP "^nso-(\d\.){2}")
    NED_prefix=${NSO_ver//nso/ncs}
    ned_file_list=( $( for i in ${NED_SETUP_FILE_LIST[@]} ; do echo $i ; done | sort | grep -E "^*${NED_prefix}.*$" ) )

    i=0
    for file_path in ${ned_file_list[@]}; do
      file_name=$(parse_file_name ${file_path})
      NED_VERSION_LIST+=( "${file_name}" "" on )
      let i++
    done
  fi

  ned_version=$(dialog --title "Project Form | Add Device | Select NED Version" \
      --backtitle "${BACK_TITLE}" \
      --begin ${X_Y_POSITION} \
      --radiolist "Please select NED version" ${DEFAULT_SIZE} ${i} \
      "${NED_VERSION_LIST[@]}" \
    3>&1 1>&2 2>&3)

  if [[ $? == ${DIALOG_OK} ]] && [[ ${ned_version} != '' ]]; then
    DEVICE_NAME_LIST+=( "${device_name}" )
    DEVICE_VERSION_LIST+=( "${ned_version}" )
    CURRENT_MENU=${MENU_ADD_PROJECT}
  fi
  CURRENT_MENU=${MENU_ADD_PROJECT}
}
# Delete Netsim device form
delete_netsim(){
  i=${#DEVICE_NAME_LIST[@]}
  device_list=()
  for (( j=0; j<${i}; j++ )); do
    device_list+=( "${DEVICE_NAME_LIST[$j]}" "${DEVICE_VERSION_LIST[$j]}" on )
  done

  device_name=$(dialog --title "Project Form | Delete Device" \
      --backtitle "${BACK_TITLE}" \
      --begin ${X_Y_POSITION} \
      --extra-button --extra-label "Delete All" \
      --radiolist "Please select Device" ${DEFAULT_SIZE} ${i} \
      "${device_list[@]}" \
    3>&1 1>&2 2>&3)

  case $? in
    ${DIALOG_OK})
      for (( j=0; j<${i}; j++ )); do
        if [[ ${DEVICE_NAME_LIST[${j}]} == ${device_name} ]]; then
          DEVICE_NAME_LIST=(${DEVICE_NAME_LIST[@]:0:${j}} ${DEVICE_NAME_LIST[@]:$(expr ${j} + 1)})
          DEVICE_VERSION_LIST=(${DEVICE_VERSION_LIST[@]:0:${j}} ${DEVICE_VERSION_LIST[@]:$(expr ${j} + 1)})
          break
        fi
      done
      ;;
    ${DIALOG_EXTRA})
      DEVICE_NAME_LIST=()
      DEVICE_VERSION_LIST=()
      ;;
  esac

  CURRENT_MENU=${MENU_ADD_PROJECT}
}
# Display project information details
list_project_information(){
  echo "Project Name: ${PROJECT_NAME}"
  echo "NSO Version: ${NSO_VERSION}"

  device_count=${#DEVICE_NAME_LIST[@]}
  if [[ ${device_count} != 0 ]]; then
    echo "Netsim Device List:"
    for (( j=0; j<${device_count}; j++ )); do
      echo "${DEVICE_NAME_LIST[$j]} [${DEVICE_VERSION_LIST[$j]}]"
    done
  fi
}
# Project add form main menu
add_project(){
  selected_option=$(dialog --title "Project Information" \
      --backtitle "${BACK_TITLE}" \
      --begin 2 29 --no-shadow \
      --infobox "`list_project_information`" ${DEFAULT_SIZE} \
      --and-widget --begin ${X_Y_POSITION} --no-shadow \
      --cancel-label "Main Menu" \
      --menu "Choose your option" 20 25 15 \
      "1" "Add Name" \
      "2" "Select NSO" \
      "3" "Add Netsim" \
      "4" "Delete Netsim" \
      "5" "Update List" \
      "6" "Setup Project" \
    3>&1 1>&2 2>&3)

  case ${selected_option} in
    "1")
      CURRENT_MENU=${MENU_SET_PROJECT_NAME}
      ;;
    "2")
      CURRENT_MENU=${MENU_SET_NSO_VERSION}
      ;;
    "3")
      if [[ ${NSO_VERSION} == '' ]]; then
        message_box "Please select NSO version first!"
      else
        CURRENT_MENU=${MENU_ADD_NETSIM}
      fi
      ;;
    "4")
      if [[ ${DEVICE_NAME_LIST} == '' ]]; then
        message_box "Netsim list is empty!"
      else
        CURRENT_MENU=${MENU_DELETE_NETSIM}
      fi
      ;;
    "5")
      CURRENT_MENU=${MENU_UPDATE_LIST}
      ;;
    "6")
      CURRENT_MENU=${MENU_SETUP_PROJECT}
      ;;
    *)
      # TODO: ask user to cancel operation
      PROJECT_NAME=""
      NSO_VERSION=""
      DEVICE_NAME_LIST=()
      DEVICE_VERSION_LIST=()
      NSO_VERSION_LIST=()
      NED_VERSION_LIST=()
      CURRENT_MENU=${MENU_MAIN}
      ;;
  esac
}
# Setup project
setup_project(){
  device_count=${#DEVICE_NAME_LIST[@]}
  netsim_device=$([[ ${device_count} == 0 ]] && echo "" || echo "\nNetsim Device List:\n")
  for (( i=0; i<${device_count} ; i++ )); do
    netsim_device+="${DEVICE_NAME_LIST[$i]}: ${DEVICE_VERSION_LIST[$i]}\n"
  done

  dialog --title "Project Form | Setup Confirmation" \
    --backtitle "${BACK_TITLE}" \
    --begin ${X_Y_POSITION} \
    --ok-label "Setup Project" \
    --yesno "Project Informations\n\nProject Name: ${PROJECT_NAME}\nNSO Version: ${NSO_VERSION}\n${netsim_device}" ${DEFAULT_SIZE}

  if [[ $? == ${DIALOG_OK} ]]; then
    (
      device_count=${#DEVICE_NAME_LIST[@]}
      step=$(( 90/((3*${device_count})+4) ))
      device_index=0
      current_step="download_nso"
      progress=10
      while [ ${progress} -lt 101 ]; do
        cd ${SCRIPT_DIR}
        case ${current_step} in
          "download_nso")
            message="Check archive and if required download NSO setup:\n ${NSO_VERSION}"
            nso_file_path=$((for path in ${NSO_SETUP_FILE_LIST[@]}; do echo ${path}; done) | grep ${NSO_VERSION})
            download_file_from_ftp ${USERNAME} ${PASSWORD} ${nso_file_path} >/dev/null 2>&1
            current_step="install_nso"
            ;;
          "install_nso")
            message="Install NSO:\n ${NSO_VERSION}"
            install_nso ${PROJECT_NAME} ${NSO_VERSION} >/dev/null 2>&1
            if [[ ${device_count} == 0 ]]; then
              current_step="setup_nso"
            else
              current_step="download_ned"
            fi
            ;;
          "download_ned")
            ned_version=${DEVICE_VERSION_LIST[device_index]}
            message="Check archive and if required download NED setup:\n ${ned_version}"
            ned_file_path=$((for path in ${NED_SETUP_FILE_LIST[@]}; do echo ${path}; done) | grep ${ned_version})
            download_file_from_ftp ${USERNAME} ${PASSWORD} ${ned_file_path} >/dev/null 2>&1
            let device_index++
            if [[ ${device_index} == ${device_count} ]]; then
              current_step="install_ned"
              device_index=0
            else
              current_step="download_ned"
            fi
            ;;
          "install_ned")
            ned_version=${DEVICE_VERSION_LIST[device_index]}
            message="Install NED:\n ${ned_version}"
            install_ned ${PROJECT_NAME} ${ned_version} >/dev/null 2>&1
            let device_index++
            if [[ ${device_index} == ${device_count} ]]; then
              current_step="add_netsim"
              device_index=0
            else
              current_step="install_ned"
            fi
            ;;
          "add_netsim")
            device_name=${DEVICE_NAME_LIST[device_index]}
            ned_version=${DEVICE_VERSION_LIST[device_index]}
            ned_version=$(echo ${ned_version} | grep -oP "(?<=\d-).*(?=-\d)")
            message="Add and restart netsim device:\n ${device_name} [${ned_version}]"
            add_netsim_device ${PROJECT_NAME} ${device_name} ${ned_version} >/dev/null 2>&1
            let device_index++
            if [[ ${device_index} == ${device_count} ]]; then
              current_step="setup_nso"
              device_index=0
            else
              current_step="add_netsim"
            fi
            ;;
          "setup_nso")
            message='Setup NSO running directory'
            setup_nso ${PROJECT_NAME} $([[ ${device_count} == 0 ]] && echo "False") >/dev/null 2>&1
            progress=100
            ;;
          *)
            message="DONE!"
            ;;
        esac

        echo ${progress}
        echo "XXX"
        echo "${message}"
        echo "XXX"

        progress=`expr ${progress} + ${step}`

        sleep 1
      done
    ) |
    dialog --title "Project Form | Setup Project" \
      --backtitle "${BACK_TITLE}" \
      --begin ${X_Y_POSITION} \
      --gauge "Check archive and if required download NSO setup:\n ${NSO_VERSION}" ${DEFAULT_SIZE} 10

    PROJECT_NAME=""
    NSO_VERSION=""
    DEVICE_NAME_LIST=()
    DEVICE_VERSION_LIST=()
    NSO_VERSION_LIST=()
    NED_VERSION_LIST=()
    CURRENT_MENU=${MENU_MAIN}
  elif [[ $? == ${DIALOG_CANCEL} ]];then
    CURRENT_MENU=${MENU_ADD_PROJECT}
  fi
}

# Get NSO and NED file list from local archive directory
get_file_list_from_local(){
  NSO_SETUP_FILE_LIST=( $( for i in `ls ${SCRIPT_DIR}/${SETUP_FILE_DIR}` ; do
  echo $i ; done | sort -r | grep -E "^nso-4.*(installer.bin|signed.bin)$" ) )
  NED_SETUP_FILE_LIST=( $( for i in `ls ${SCRIPT_DIR}/${SETUP_FILE_DIR}` ; do
  echo $i ; done | sort | grep -E "^ncs-4.*(tar.gz|signed.bin)$" ) )
}
# Update NSO and NED lists from online repository
update_list(){
  # Check password
  if [[ ${PASSWORD} == "" ]]; then
    user_info=$(dialog --title "Login Form" \
        --backtitle "${BACK_TITLE}" \
        --begin ${X_Y_POSITION} \
        --insecure "$@"\
        --mixedform "Please enter your user information" ${DEFAULT_SIZE} 0 \
        "CEC Id          :" 1 1	"${USERNAME}" 1 20 40 0 0 \
        "Password        :" 2 1	"" 2 20 40 0 1 \
      3>&1 1>&2 2>&3)

    return_code=$?

    user_info_array=( ${user_info} )
    USERNAME=${user_info_array[0]}
    PASSWORD=${user_info_array[1]}

    case ${return_code} in
      ${DIALOG_OK})
        parse_ftp_list
        ;;
      *)
        CURRENT_MENU=${MENU_ADD_PROJECT}
        ;;
    esac
  else
    parse_ftp_list
  fi
}
# parse ftp list into arrays
parse_ftp_list(){
  result=$(get_file_list_from_ftp ${USERNAME} ${PASSWORD})
  if [[ ${result} == *"401 Authorization Required"* ]]; then
    unset PASSWORD
    message_box "Wrong username or password!"
  else
    result_array=(`echo ${result}`)

    NSO_VERSION_LIST=()
    NED_VERSION_LIST=()
    NSO_SETUP_FILE_LIST=( $( for i in ${result_array[@]} ; do echo $i ; done | sort -r | grep -E "^./ncs/.*nso-4.*(installer.bin|signed.bin)$" ) )
    NED_SETUP_FILE_LIST=( $( for i in ${result_array[@]} ; do echo $i ; done | sort | grep -E "^./ncs-pkgs/.*ncs-4.*(tar.gz|signed.bin)$" ) )

    if [[ ${#NSO_SETUP_FILE_LIST[@]} == 0 ]]; then
      parse_ftp_list
    else
      CURRENT_MENU=${MENU_ADD_PROJECT}
    fi
  fi
}

# List project and give details about projects
list_project(){
  project_name=$1

  projects_dir=${SCRIPT_DIR}/${PROJECT_DIR}
  dir_list=$(ls ${projects_dir})
  project_list=()
  i=1
  ncs_process=$(ps -fC ncs)
  for dir in ${dir_list}; do
    check_dir=($(ls ${projects_dir}/${dir} | grep "${INSTALL_DIR}\|${RUN_DIR}"))
    if [[ ${#check_dir[@]} -eq 2 ]]; then
      if [[ ${project_name} == "" ]]; then
        project_name=${dir}
      elif [[ ${project_name} == ${i} ]]; then
        project_name=${dir}
      fi

      nso_version=$(more ${projects_dir}/${dir}/${INSTALL_DIR}/VERSION | grep -oP "^NSO (([0-9]+\.?){2,3})")
      current=$([[ ${ncs_process} == *${projects_dir}/${dir}* ]] && echo "[R]" )
      project_list+=("${i}" "${current} ${dir}")
      let i++
    fi
  done

  if [[ ${i} -eq 1 ]]; then
    message_box "You don't have any project yet!"
    CURRENT_MENU=${MENU_MAIN}
  fi

  selected_option=$(dialog --title "Project Information" \
      --backtitle "${BACK_TITLE}" \
      --begin 2 29 --no-shadow \
      --infobox "`project_details ${project_name}`" ${DEFAULT_SIZE} \
      --and-widget --begin ${X_Y_POSITION} --no-shadow \
      --cancel-label "Main Menu" \
      --menu "Project List" 20 25 15 \
      "${project_list[@]}" \
    3>&1 1>&2 2>&3)

  case $? in
    ${DIALOG_OK})
      list_project $selected_option
      ;;
    *)
      CURRENT_MENU=${MENU_MAIN}
      ;;
  esac
}
# Get project details
project_details(){
  project_name=$1
  project_dir=${SCRIPT_DIR}/${PROJECT_DIR}/${project_name}
  nso_version=($(more ${project_dir}/${INSTALL_DIR}/VERSION | grep -oP "(([0-9]+\.?){2,3})"))
  message="Project Name: $project_name\n"
  message+="NSO Version: ${nso_version[0]}\n"
  message+="Project Path: ${project_dir}\n\n"
  if [[ -d ${project_dir}/${NETSIM_DIR} ]]; then
    source ${project_dir}/${NETSIM_DIR}/${NETSIM_INFO_FILE}
    i=0
    message+="Netsim Device List:\n"
    for device in ${devices[@]}; do
      ned_name=${packagedirs[${i}]##*/}
      ned_version=$(more ${project_dir}/${INSTALL_DIR}/packages/neds/${ned_name}/package-meta-data.xml | grep -oP "(?<=<package-version>).*?(?=</package-version>)")
      . ${project_dir}/${INSTALL_DIR}/ncsrc
      status=$(ncs-netsim --dir ${project_dir}/${NETSIM_DIR} status ${device} | grep -oP "(?<=status: ).*")
      status=$([[ ${status} == "" ]] && echo "stopped" || echo ${status})
      message+="${device} [${ned_name} ${ned_version}]: ${status}\n"
      let i++
    done
    devices=()
  else
    message+="Netsim list is empty!"
  fi

  echo ${message}
}

# Check latest version of the script from gotlab repository
check_version(){
  # TODO: control return code
  latest_version=`curl ${LATEST_VERSION_PATH}`
  if [[ ${VERSION} != ${latest_version} ]]; then
    dialog \
      --clear \
      --begin ${X_Y_POSITION} \
      --backtitle "${BACK_TITLE}" \
      --yesno "New version of script is avaialble. Your script version is ${VERSION}.\n\n
    Do you want to update version ${latest_version}?" 10 50

    case $? in
      ${DIALOG_OK})
        if ! wget --quiet --output-document=${SCRIPT_NAME}.tmp ${SCRIPT_ONLINE_PATH} ; then
          message_box "Error while downloading the script!"
        else
          mv ${SCRIPT_NAME}.tmp ${SCRIPT_NAME}
          message_box "Script has been updated! New version is ${latest_version}"
          bash ${SCRIPT_NAME}
          exit
        fi
        ;;
    esac
  else
    message_box "Your script version [${VERSION}] is up to date!"
  fi

  CURRENT_MENU=${MENU_MAIN}
}

# Log user activities
log_activities(){
  process_name=$1

  tracking_id="UA-113889841-1"
  category="NSO_Auto"
  action="Menu"
  label="${process_name}"
  value="1"

  curl -d 'v=1&tid='"$tracking_id"'&cid=555&t=event&ec='"$category"'&ea='"$action"'&el='"$label"'&ev='"$value"'' \
    -H "User-Agent: AppSpecific" "https://www.google-analytics.com/collect"
}

# Main onboarding menu
main_menu(){
  # TODO: add about to give more information
  # TODO: check update
  selected_option=$(dialog --title "Main Menu" \
      --backtitle "${BACK_TITLE}" \
      --begin ${X_Y_POSITION} \
      --cancel-label "Exit" \
      --menu "Choose your option" ${DEFAULT_SIZE} 0 \
      "1" "Add Project" \
      "2" "List Project" \
      "3" "Check Update" \
    3>&1 1>&2 2>&3)

  case $? in
    ${DIALOG_OK})
      case ${selected_option} in
        "1")
          CURRENT_MENU=${MENU_ADD_PROJECT}
          ;;
        "2")
          CURRENT_MENU=${MENU_LIST_PROJECT}
          ;;
        "3")
          CURRENT_MENU=${MENU_CHECK_VERSION}
          ;;
      esac
      ;;
    *)
      quit_box
      ;;
  esac
}
# Main routing function
interactive_mode(){
  # read NSO and NED setup file list from local
  get_file_list_from_local

  return_code=0
  while test ${return_code} != 250
  do
    log_activities ${CURRENT_MENU}

    case ${CURRENT_MENU} in
      ${MENU_MAIN})
        main_menu
        ;;
      ${MENU_ADD_PROJECT})
        add_project
        ;;
      ${MENU_SET_PROJECT_NAME})
        set_project_name
        ;;
      ${MENU_SET_NSO_VERSION})
        set_NSO_version
        ;;
      ${MENU_ADD_NETSIM})
        add_netsim
        ;;
      ${MENU_DELETE_NETSIM})
        delete_netsim
        ;;
      ${MENU_UPDATE_LIST})
        update_list
        ;;
      ${MENU_SETUP_PROJECT})
        setup_project
        ;;
      ${MENU_LIST_PROJECT})
        list_project
        ;;
      ${MENU_CHECK_VERSION})
        check_version
        ;;
      *)
        main_menu
        ;;
    esac
  done
}

##### Main
# check diolog utility
which dialog &> /dev/null
[ $? -ne 0 ]  &&
echo "Dialog utility is not available, Install Dialog to use the script" && exit

# check directories
[ -d ${SETUP_FILE_DIR} ] || mkdir ${SETUP_FILE_DIR}
[ -d ${PROJECT_DIR} ] || mkdir ${PROJECT_DIR}

# base on input run functions or interactive mode
[ $# -eq 0 ] && interactive_mode || $@

