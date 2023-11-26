#!/usr/bin/env bash

APP_NAME='E5_ALIVE'
PERMISSIONS_FILE='./required-resource-accesses.json'
CONFIG_PATH='../config'

jq() {
  echo "$1" | python3 -c "import sys, json; print(json.load(sys.stdin)$2)"
}

register_app() {
  config_file="$CONFIG_PATH/app$1.json"
  reply_uri="http://localhost:1000$1/"
  username=$2
  password=$3

  # Install CLI
  # [ "$(command -v az)" ] || sudo apt install -y azure-cli
  sudo apt-get update
  sudo apt-get -y install ca-certificates curl apt-transport-https lsb-release gnupg
  curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null

  AZ_REPO=$(lsb_release -cs)
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
  sudo apt-get update
  sudo apt-get -y --allow-downgrades install azure-cli=2.36.0-1~focal

  # Separate Multiple Account
  export AZURE_CONFIG_DIR=/tmp/az-cli/$1
  mkdir -p "$AZURE_CONFIG_DIR"

  # Login
  ret="$(
    az login \
      --allow-no-subscriptions \
      -u "$username" \
      -p "$password" 2>/dev/null
  )"

  # Delete The Existing App
  ret=$(az ad app list --display-name "$APP_NAME")
  [ "$ret" != "[]" ] && {
    az ad app delete --id "$(jq "$ret" "[0]['appId']")"
  }

  # Create A New App
  ret="$(
    az ad app create \
      --display-name "$APP_NAME" \
      --reply-urls "$reply_uri" \
      --available-to-other-tenants true \
      --required-resource-accesses "@$PERMISSIONS_FILE"
  )"

  app_id="$(jq "$ret" "['appId']")"
  user_id="$(jq "$(az ad user list)" "[0]['objectId']")"

  # Wait Azure System To Refresh
  sleep 20

  # Set Owner
  az ad app owner add \
    --id "$app_id" \
    --owner-object-id "$user_id"

  # Grant Admin Consent
  az ad app permission admin-consent --id "$app_id"

  # Generate Client Secret
  ret="$(
    az ad app credential reset \
      --id "$app_id" \
      --years 100
  )"
  client_secret="$(jq "$ret" "['password']")"

  # Wait Azure System To Refresh
  sleep 60

  # Save App Detail
  cat >"$config_file" <<EOF
{
    "username": "$username",
    "password": "$password",
    "client_id": "$app_id",
    "client_secret": "$client_secret",
    "redirect_uri": "$reply_uri"
}
EOF
}

get_refresh_token() {
  config_file="$CONFIG_PATH/app$1.json"
  node server.js "$config_file" &
  node client.js "$config_file"
}

handle_single_account() {
  register_app "$@"
  get_refresh_token "$1"
}

[ "$USER" ] && [ "$PASSWD" ] && {
  [ -d "$CONFIG_PATH" ] || mkdir -p "$CONFIG_PATH"

  mapfile -t users < <(echo -e "$USER")
  mapfile -t passwords < <(echo -e "$PASSWD")

  for ((i = 0; i < "${#users[@]}"; i++)); do
    handle_single_account "$i" "${users[$i]}" "${passwords[$i]}" &
  done

  wait
  exit
}

echo "尚未設定帳號密碼 無法執行應用註冊"
exit 1
