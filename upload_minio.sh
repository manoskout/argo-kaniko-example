#!/bin/bas
# Usage: ./minio-upload my-bucket my-file.zip
# author: @koutoulakis
showHelp() {
    # `cat << EOF` This means that cat should stop reading when EOF is detected
    cat <<EOF
Install OpenBio Execution Environment
-h --help                  : Display help
-b --bucket                : Specify the bucket 
-d --directory            : Context directory that contains dockerfiles
EOF
    # EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
}

# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "help,bucket:,directory:" -o "hb:d: " -a -- "$@")

# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"

while true; do
    case $1 in
    -h | --help)
        showHelp
        exit 0
        ;;
    -b | --bucket)
        export bucket=$2
        shift 2
        ;;
    -d | --directory)
        export file=$2
        shift 2
        ;; 
    --)
        shift
        break
        ;;
    *) break ;;

    esac
done


if [ $(uname) = "Linux" ]; then
    echo "OS: $(lsb_release -d | awk '{if($1=="Description:")print $2,$3}')"
    host="$(hostname -I | awk '{print $1}'):9000"
elif [ $(uname) = "Darwin" ]; then
    echo "OS: MacOS $(sw_vers | awk '{if($1=="ProductVersion:")print $2}') "
    host="$(ipconfig getifaddr en0):9000"
fi

s3_key=$(kubectl get secret argo-artifacts --namespace argo -o jsonpath="{.data.accesskey}" | base64 --decode)
s3_secret=$(kubectl get secret argo-artifacts --namespace argo -o jsonpath="{.data.secretkey}" | base64 --decode)

resource="/${bucket}/${file}"
content_type="application/octet-stream"
date=$(date -R)
_signature="PUT\n\n${content_type}\n${date}\n${resource}"
signature=$(echo -en ${_signature} | openssl sha1 -hmac ${s3_secret} -binary | base64)

curl -s -f -X PUT -T "${file}" \
    -H "Host: $host" \
    -H "Date: ${date}" \
    -H "Content-Type: ${content_type}" \
    -H "Authorization: AWS ${s3_key}:${signature}" \
    http://$host${resource} \
    >/dev/null

curl_err_code=$?

if [ $curl_err_code -eq 0 ]; then
    echo "The file uploaded succesfully"
else
    echo "Something goes wrong, ERROR : $curl_err_code"
fi