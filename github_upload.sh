#!/bin/bash


help()
{
  Usage="Usage: github_upload.sh [OPTION]  \n\
  Options:\n\
        [ -r | --repo REPO]  \t\t-- The repository you want to use as gentoo-binhost. Eg: night-every/gentoo-binhost \n \
        [ -t | --token TOKEN] \t\t-- Your personal GitHub access token \n \
        [ -e | --email EMAIL]  \t\t-- Your email \n \
        [ -h | --help ]  \t\t-- Print this text and exit  \n \
        "
  echo -e ${green} $Usage
  exit 2
}

ARGS=$(getopt -a  -o r:t:e:h --long repo:,token:,email:,help -- "$@")
VALID_ARGS=$?

if [ "$VALID_ARGS" != "0" ] || [ -z "$1" ]; then
  help
fi

eval set -- "$ARGS"
while :
do
  case "$1" in
    -r | --repo)             REPO="$2"    ; shift 2  ;;
    -t | --token)            TOKEN="$2"   ; shift 2  ;;
    -e | --email)            EMAIL="$2"   ; shift 2  ;;
    -h | --help)             help; exit 0 ; shift    ;;
    --) shift; break ;;
  esac
done

if [[ -z "${REPO// /}" ]]
then
	help
fi

if [[ -z "${TOKEN// /}" ]]
then
	help
fi

if [[ -z "${EMAIL// /}" ]]
then
	help
fi

NAME=$(echo ${REPO} | cut -d'/' -f1)
BRANCH=$(echo $(EMERGE_DEFAULT_OPTS="--keep-going --with-bdeps=y --verbose --deep" emerge --info --verbose | grep -w CHOST | grep -o '".*"' | cut -d '"' -f 2)"("$(readlink /etc/portage/make.profile | cut -d'/' -f12-)")")
BINPKG_FORMAT=$(EMERGE_DEFAULT_OPTS="--keep-going --with-bdeps=y --verbose --deep" emerge --info --verbose | grep -w BINPKG_FORMAT | grep -o '".*"' | cut -d '"' -f 2)
BINPKG_DIR=$(EMERGE_DEFAULT_OPTS="--keep-going --with-bdeps=y --verbose --deep" emerge --info --verbose | grep -w PKGDIR | grep -o '".*"' | cut -d '"' -f 2 )
RELEASE_TAGS="${BRANCH}/${CATEGORY}/${PN}"
# Set GitHub API URL and repository information
API_URL="https://api.github.com/repos/${REPO}"

#if "gpkg" format
if [[ ${BINPKG_FORMAT} == gpkg ]]; then
    BINPKG_FORMAT=${BINPKG_FORMAT}.tar
fi



#Check if the binary package exists
if [ -f ${BINPKG_DIR}/${CATEGORY}/${PN}/${PF}-${BUILD_ID}.${BINPKG_FORMAT} ]
then
   echo "${PF}-${BUILD_ID}.${BINPKG_FORMAT} exists"
else
   echo "${BINPKG_DIR}/${CATEGORY}/${PN}/${PF}-${BUILD_ID}.${BINPKG_FORMAT} does not exist"
   exit 1
fi

_json_file=/etc/portage/offline_mode.json

if [ ! -f $_json_file ]
then
    jq -n '[]' > $_json_file
fi

function offline_mode {
    jq --null-input --slurpfile exist_binpkg "$_json_file" \
    --arg PN "$PN" \
    --arg PF "$PF" \
    --arg CATEGORY "$CATEGORY" \
    --arg EBUILD "$EBUILD" \
    --arg BUILD_ID "$BUILD_ID" \
    '$exist_binpkg[] + [{"PN": $PN, "PF": $PF, "CATEGORY": $CATEGORY, "EBUILD":  $EBUILD, "BUILD_ID": $BUILD_ID}]' \
    $_json_file > $_json_file.tmp

    mv $_json_file.tmp $_json_file

    exit 0
}

function startup_mode {

    if [ $(jq length $_json_file) ==  "0" ]
    then
        echo "No binpkg that have not yet been uploaded that need to be processed."
    else
        _PN=$PN
        _PF=$PF
        _CATEGORY=$CATEGORY
        _EBUILD=$EBUILD
        _BUILD_ID=$BUILD_ID
        _RELEASE_TAGS="$RELEASE_TAGS"
        while IFS= read -r line; do
            
            declare -g PN=$(echo "$line" | jq -r '.PN')
            declare -g PF=$(echo "$line" | jq -r '.PF')
            declare -g CATEGORY=$(echo "$line" | jq -r '.CATEGORY')
            declare -g EBUILD=$(echo "$line" | jq -r '.EBUILD')
            declare -g BUILD_ID=$(echo "$line" | jq -r '.BUILD_ID')
            declare -g RELEASE_TAGS="${BRANCH}/${CATEGORY}/${PN}"
            
            get_branch
            get_release
            upload_assets
            update_packages_file
            
            jq 'del(.[0])' "$_json_file" > "$_json_file.tmp"
            mv "$_json_file.tmp" "$_json_file"
        done < <(jq -c '.[]' "$_json_file")
        
        declare -g PN=$_PN
        declare -g PF=$_PF
        declare -g CATEGORY=$_CATEGORY
        declare -g EBUILD=$_EBUILD
        declare -g BUILD_ID=$_BUILD_ID
        declare -g RELEASE_TAGS=$_RELEASE_TAGS
        
        unset _PN _PF _CATEGORY _EBUILD _BUILD_ID _RELEASE_TAGS
    fi
}

function get_branch {
    echo "GETTING BRANCH"
    # Make the API request to get the repository branches
    local response=$(curl -L --silent --fail -o /dev/null -w "%{http_code}\n" \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        ${API_URL}/branches/${BRANCH})
    # Check if the API request was successful
    if [ ${response} -eq "200" ]
    then
        echo "GET_BRANCH SUCCESS: ${BRANCH}"
        return 0
    elif [ ${response} -eq "404" ]
    then
        echo -e "Target branch does not exist: ${BRANCH}\n"
        create_branch
    elif [ ${response} -eq "301" ]
    then
        echo -e "Target branch: ${BRANCH} moved permanently"
        exit 1
    else
        echo 'Unknown Error ! '
        echo "HTTP STATUS CODE: ${response}"
        exit 1
    fi

}

function create_branch {
    echo -e "Branch not found \nCreating git branch: ${BRANCH} "
    local _main_branch_sha=$(curl -L --silent \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${TOKEN}"\
        -H "X-GitHub-Api-Version: 2022-11-28" \
        ${API_URL}/branches | jq -r '.[].commit.sha' | head -n1 2>/dev/null)
    local _create_git_branch=$(curl -L --silent --fail -o /dev/null -w "%{http_code}\n" \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${TOKEN}"\
        -H "X-GitHub-Api-Version: 2022-11-28" \
        ${API_URL}/git/refs \
        -d "{\"ref\":\"refs/heads/${BRANCH}\",\"sha\":\"${_main_branch_sha}\"}")
    if [ ${_create_git_branch} -eq "201" ]
    then
        echo "Created git branch: ${BRANCH} "
    elif [ ${_create_git_branch} -eq "422" ]
    then
        echo "Error,Cannot create git branch: ${BRANCH} validation failed, or the endpoint has been spammed."
        echo " HTTP STATUS CODE: ${_create_git_branch}"
        exit 1
    else
        echo "Error,Cannot create git branch: ${BRANCH} "
        echo "HTTP STATUS CODE: ${_create_git_branch}"
        exit 1
    fi
}

function get_release {
    echo "GETTING_RELEASE"
    local _status=$(curl -L --silent --fail -o /dev/null -w "%{http_code}\n" \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${TOKEN}"\
      -H "X-GitHub-Api-Version: 2022-11-28" \
      $API_URL/releases/tags/${RELEASE_TAGS})
    if [ "$_status" -eq 200 ]; then
        release_id=$(curl -L --silent \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${TOKEN}"\
            -H "X-GitHub-Api-Version: 2022-11-28" \
            ${API_URL}/releases/tags/${RELEASE_TAGS} | jq '.id // empty' )
        if [ -z "$(echo ${release_id} | tr -d '\n')" ]; then
            echo "Error: release_id is empty."
            exit 1
        else
            echo "GETTING_RELEASE SUCCESS"
            return 0
        fi
    elif [ "$_status" -eq 404 ]; then
        echo -e "Release does not exist. \nCREATING_RELEASE"
        create_release
    else
        echo 'Get release failed. HTTP STATUS CODE:'${_status}
        exit 1
    fi
}

function create_release {
    #local PKG_DESCRIPTION=$(cat $EBUILD | grep -i "DESCRIPTION" | grep -o '".*"' | cut -d '"' -f 2)

    if [ $(cat ${EBUILD} | grep -i "DESCRIPTION" | grep -o '".*"' | grep -o '"' | wc -l) -gt 2 ]
    then
        local PKG_DESCRIPTION=$(cat $EBUILD | grep -i "DESCRIPTION" | grep -o '".*"')
        local PKG_DESCRIPTION=$(echo ${PKG_DESCRIPTION//\\\"/\'} | cut -d '"' -f2)
    else
        local PKG_DESCRIPTION=$(cat $EBUILD | grep -i "DESCRIPTION" | grep -o '".*"' | cut -d '"' -f 2)
    fi

    if [ -z "$PKG_DESCRIPTION" ]
    then
        PKG_DESCRIPTION="$CATEGORY/${PF} from $(basename $(echo $(dirname $(dirname $(dirname ${EBUILD})))))"
    else
        :
    fi


    local PKG_DESCRIPTION=$(echo ${PKG_DESCRIPTION} | sed -e 's/\$/\\\$/g')

    local _creating_release=$(curl -L -silent --fail -o /dev/null -w "%{http_code}\n" \
      -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${TOKEN}"\
      -H "X-GitHub-Api-Version: 2022-11-28" \
      ${API_URL}/releases \
      --data-raw "{    \"tag_name\": \"${RELEASE_TAGS}\",    \"target_commitish\": \"${BRANCH}\",    \"name\": \"${CATEGORY}\/${PN}\",    \"body\": \"${PKG_DESCRIPTION}\"}")

    if [ ${_creating_release} -eq "201" ]
    then
        echo -e "Created $CATEGORY/${PN} release"
    elif [ ${_creating_release} -eq "422" ]
    then
        echo -e "Failed to create release. HTTP STATUS CODE: ${_creating_release}\n"
        echo "Validation failed, or the endpoint has been spammed."
        exit 1
    elif [ ${_creating_release} -eq "404" ]
    then
        echo -e "Failed to create release. HTTP STATUS CODE: ${_creating_release}\n"
        echo "Not Found if the discussion category name is invalid"
        exit 1
    else
        echo 'Unknown Error ! '
        echo "HTTP STATUS CODE: ${_create_release}"
        exit 1
    fi

    release_id=$(curl -L --silent \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${TOKEN}"\
            -H "X-GitHub-Api-Version: 2022-11-28" \
            ${API_URL}/releases/tags/${RELEASE_TAGS} | jq '.id // empty' )

    if [ -z "$(echo ${release_id} | tr -d '\n')" ]
    then
        echo "Error: release_id is empty."
        exit 1
    fi
}

function upload_assets {
    echo "CHECKING ASSETS"
    local _assets_packages_list=$(curl -L --silent \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${TOKEN}"\
        -H "X-GitHub-Api-Version: 2022-11-28" \
        ${API_URL}/releases/tags/${RELEASE_TAGS} | jq '.assets[].name // empty' )

    local _local_packages_list=$(ls "${BINPKG_DIR}/${CATEGORY}/${PN}" | awk '{printf "\"%s\" ", $0}')

    if [ -z "$(echo ${_assets_packages_list} | tr -d '\n')" ]
    then
        #--data-binary "@${BINPKG_DIR}/${CATEGORY}/${PN}/${PF}-${BUILD_ID}.${BINPKG_FORMAT}"
        echo "No assets found"
        for file in ${BINPKG_DIR}/${CATEGORY}/${PN}/*
        do
            echo "Uploading asset: $file"
            local _upload_release_asset=$(curl -L --silent --fail -o /dev/null -w "%{http_code}\n" \
                    -X POST \
                    -H "Accept: application/vnd.github+json" \
                    -H "Authorization: Bearer ${TOKEN}"\
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    -H "Content-Type: application/octet-stream" \
                    -T "$file" \
                    https://uploads.github.com/repos/${REPO}/releases/${release_id}/assets?name=${file##*/})
            if [ ${_upload_release_asset} -eq "201" ]
            then
                echo "Asset successful upload"
            elif [ ${_upload_release_asset} -eq "422" ]
            then
                echo "ERROR: Upload an asset with the same filename as another uploaded asset, you must delete the old file before you can re-upload the new asset."
                exit 1
            else
                echo 'Unknown Error ! '
                echo "HTTP STATUS CODE: ${_upload_release_asset}"
                exit 1

            fi
            PKG_STATUS=' uploaded.'
        done
#        curl -L \
#            -X POST \
#            -H "Accept: application/vnd.github+json" \
#            -H "Authorization: Bearer ${TOKEN}"\
#            -H "X-GitHub-Api-Version: 2022-11-28" \
#            -H "Content-Type: application/octet-stream" \
#            -T "${BINPKG_DIR}/${CATEGORY}/${PN}/${PF}-${BUILD_ID}.${BINPKG_FORMAT}" \
#            https://uploads.github.com/repos/${REPO}/releases/${release_id}/assets?name="${PF}-${BUILD_ID}.${BINPKG_FORMAT}" | cat

    else
        echo -e "Asset found \n"
        # 声明关联数组
        typeset -A assets_name_id_arr

        # 将 status 中的数据按行分割成数组元素，并存储到数组中
        readarray -t assets_arr_name <<< "$(curl -L --silent \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${TOKEN}"\
            -H "X-GitHub-Api-Version: 2022-11-28" \
            ${API_URL}/releases/tags/${RELEASE_TAGS} | jq -r '.assets[].name' )"

        readarray -t assets_arr_id <<< "$(curl -L --silent \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${TOKEN}"\
            -H "X-GitHub-Api-Version: 2022-11-28" \
            ${API_URL}/releases/tags/${RELEASE_TAGS} | jq -r '.assets[].id' )"

        for i in "${!assets_arr_name[@]}"; do
            assets_name_id_arr["${assets_arr_name[$i]}"]="${assets_arr_id[$i]}"
        done

        # 打印结果
#        for key in "${!assets_name_id_arr[@]}"; do
#            echo "$key: ${assets_name_id_arr[$key]}"
#        done
#
#        echo ${assets_name_id_arr["floppy-0-1.xpak"]}

        diff_output=$(diff -b -u <(echo $_assets_packages_list  | tr ' ' '\n' | sort) <(echo $_local_packages_list | tr ' ' '\n' | sort) | grep -v '^\(---\|+++\|@@\) ' | grep '^[+-]')
        if [ -z "$diff_output" ]; then
            echo -e "NOTHING CHANGE\n"
            local _delete_release_asset=$(curl -L --silent --fail -o /dev/null -w "%{http_code}\n" \
                -X DELETE \
                -H "Accept: application/vnd.github+json" \
                -H "Authorization: Bearer ${TOKEN}"\
                -H "X-GitHub-Api-Version: 2022-11-28" \
                ${API_URL}/releases/assets/${assets_name_id_arr["${PF}-${BUILD_ID}.${BINPKG_FORMAT}"]})
            if [ ${_delete_release_asset} -eq "204" ]
            then
                echo "Delete asset successful: ${PF}-${BUILD_ID}.${BINPKG_FORMAT}"
            else
                echo 'Unknown Error ! '
                echo "HTTP STATUS CODE: ${_delete_release_asset}"
                exit 1
            fi
            local _upload_release_asset=$(curl -L --silent --fail -o /dev/null -w "%{http_code}\n" \
                    -X POST \
                    -H "Accept: application/vnd.github+json" \
                    -H "Authorization: Bearer ${TOKEN}"\
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    -H "Content-Type: application/octet-stream" \
                    -T "${BINPKG_DIR}/${CATEGORY}/${PN}/${PF}-${BUILD_ID}.${BINPKG_FORMAT}" \
                    https://uploads.github.com/repos/${REPO}/releases/${release_id}/assets?name="${PF}-${BUILD_ID}.${BINPKG_FORMAT}")
            if [ ${_upload_release_asset} -eq "201" ]
            then
                echo "Asset successful upload: ${PF}-${BUILD_ID}.${BINPKG_FORMAT}"
            elif [ ${_upload_release_asset} -eq "422" ]
            then
                echo "ERROR: Upload an asset with the same filename as another uploaded asset, you must delete the old file before you can re-upload the new asset."
                exit 1
            else
                echo 'Unknown Error ! '
                echo "HTTP STATUS CODE: ${_upload_release_asset}"
                exit 1
            fi
            PKG_STATUS=' uploaded.'
        else
            while read line; do
                case $line in
                    +*) # File need to add
                        local _filename=$(echo "$line" | cut -c 2- | tr -d '"')
                        local _upload_release_asset=$(curl -L --silent --fail -o /dev/null -w "%{http_code}\n" \
                            -X POST \
                            -H "Accept: application/vnd.github+json" \
                            -H "Authorization: Bearer ${TOKEN}"\
                            -H "X-GitHub-Api-Version: 2022-11-28" \
                            -H "Content-Type: application/octet-stream" \
                            -T "${BINPKG_DIR}/${CATEGORY}/${PN}/${PF}-${BUILD_ID}.${BINPKG_FORMAT}" \
                            https://uploads.github.com/repos/${REPO}/releases/${release_id}/assets?name="${_filename}")
                        if [ ${_upload_release_asset} -eq "201" ]
                        then
                            echo -e "Asset successful upload: ${_filename}\n"
                        elif [ ${_upload_release_asset} -eq "422" ]
                        then
                            echo "ERROR: Upload an asset with the same filename as another uploaded asset, you must delete the old file before you can re-upload the new asset."
                            exit 1
                        else
                            echo 'Unknown Error ! '
                            echo "HTTP STATUS CODE: ${_upload_release_asset}"
                            exit 1
                        fi
                        PKG_STATUS=' uploaded.'
                        ;;
                    -*) # File need to remove
                        local _filename=$(echo "$line" | cut -c 2- | tr -d '"')
                        local _delete_release_asset=$(curl -L --silent --fail -o /dev/null -w "%{http_code}\n"\
                            -X DELETE \
                            -H "Accept: application/vnd.github+json" \
                            -H "Authorization: Bearer ${TOKEN}"\
                            -H "X-GitHub-Api-Version: 2022-11-28" \
                            ${API_URL}/releases/assets/${assets_name_id_arr["$_filename"]})
                        if [ ${_delete_release_asset} -eq "204" ]
                        then
                            echo -e "Delete asset successful: ${_filename}\n"
                        else
                            echo 'Unknown Error ! '
                            echo "HTTP STATUS CODE: ${_upload_release_asset}"
                            exit 1
                        fi
                        PKG_STATUS=' deleted.'
                        ;;
                    *) # Other lines, do nothing
                        ;;
                esac
            done < <(echo "$diff_output" | tr ' ' '\n')
        fi
    fi
}

function update_packages_file {
    local _commit_message="${CATEGORY}/${PF} $PKG_STATUS"

#    if grep -q 'URI:' ${BINPKG_DIR}/Packages | awk '{print $2}' | grep -w $(readlink /etc/portage/make.profile | cut -d'/' -f12-)
#    then
#        echo "URI value has already been modified: $(grep -w 'URI:' ${BINPKG_DIR}/Packages | awk '{print $2}' | grep -w $(readlink /etc/portage/make.profile | cut -d'/' -f12-))"
#    else
#        echo -e "CHANGING URI VALUE TO THE SAME NAME AS THE BRANCH: ${BRANCH}"
#        sed -i "s|\(URI:.*\)|\1($(readlink /etc/portage/make.profile | cut -d'/' -f12- | sed 's/\//\//g'))|" ${BINPKG_DIR}/Packages
#        echo "URI value has been modified: $(grep -w 'URI:' ${BINPKG_DIR}/Packages | awk '{print $2}') "
#    fi
    
    _change_package_file_uri=$(grep -w "URI:.*" ${BINPKG_DIR}/Packages | cut -d ":" -f 2-)
    _change_package_file_uri=${_change_package_file_uri%%(*}
    _change_package_file_uri=${_change_package_file_uri}"("$(readlink /etc/portage/make.profile | cut -d'/' -f12-)")"
    sed -i "s#URI:.*#URI: ${_change_package_file_uri}#" ${BINPKG_DIR}/Packages 
    echo "URI value has been modified: $(grep -w 'URI:' ${BINPKG_DIR}/Packages | awk '{print $2}') "
    
    local _github_packages_file_sha=$(curl -L --silent \
                                    -H "Accept: application/vnd.github+json" \
                                    -H "Authorization: Bearer ${TOKEN}"\
                                    -H "X-GitHub-Api-Version: 2022-11-28" \
                                    ${API_URL}/contents/Packages\?ref\=$(echo ${BRANCH} | sed 's/[(]/\(/g; s/[)]/\)/g') | jq -r '.sha // empty'  )
    local _local_packages_file_base64=$(cat "${BINPKG_DIR}/Packages" | base64 | tr -d '\n')
    local _date=$(date '+%d/%m/%+Y')
    if [ -z "$(echo ${_github_packages_file_sha} | tr -d '\n')" ]
    then
        echo "Packages file doesn't exist in ${BRANCH}"
        echo "Upload the Packages file to ${BRANCH} as it doesn't exist there."
        #Upload the Package file to github as it doesn't exist there.
        #To prevent curl: Argument list too long
        local _upload_packages_file_output=$(
        echo ${_local_packages_file_base64} | jq -Rc --arg message "${_commit_message}" \
            --arg name "${NAME}" \
            --arg email "${EMAIL}" \
            --arg date "${_date}" \
            --arg branch "${BRANCH}" \
            '{$message,committer:{$name,$email,$date},$branch,content:.}' |
        curl -L --silent --fail -o /dev/null -w "%{http_code}\n"\
            -X PUT \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${TOKEN}"\
            -H "X-GitHub-Api-Version: 2022-11-28" \
            ${API_URL}/contents/Packages \
            -d @- )
        if [ ${_upload_packages_file_output} -eq "201" ]
        then
            echo "Packages file uploded"
        else
            echo 'Unknown Error !'
            echo "HTTP STATUS CODE: ${_upload_packages_file_output}"
        fi
    else
        local _update_packages_file_output=$(
        echo ${_local_packages_file_base64} | jq -Rc --arg message "${_commit_message}" \
            --arg name "${NAME}" \
            --arg email "${EMAIL}" \
            --arg date "${_date}" \
            --arg branch "${BRANCH}" \
            --arg sha "${_github_packages_file_sha}" \
            '{$message,committer:{$name,$email,$date},$branch,content:.,$sha}' |
        curl -L --silent --fail -o /dev/null -w "%{http_code}\n"\
            -X PUT \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${TOKEN}"\
            -H "X-GitHub-Api-Version: 2022-11-28" \
            ${API_URL}/contents/Packages \
            -d @- )
        if [ ${_update_packages_file_output} -eq "200" ]
        then
            echo "Packages file updated"
        elif [ ${_update_packages_file_output} -eq "409" ]
        then
            echo "Conflict happened. Try uploading the file again with the next compile"
            exit 1
        else
            echo 'Unknown Error ! '
            echo "HTTP STATUS CODE: ${_update_packages_file_output}"
        fi
    fi

}



ping -c3 8.8.8.8 >/dev/null
if [ $? -eq "0" ]
then
    startup_mode
    get_branch
    get_release
    upload_assets
    update_packages_file
else
    echo "No network, get into offline mode and wait for network before uploading"
    offline_mode
fi
