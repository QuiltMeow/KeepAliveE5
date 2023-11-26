#!/usr/bin/env bash

[ -d 'config' ] || {
  echo "找不到設定檔案 請先進行註冊"
  exit 1
}

poetry run python crypto.py d
poetry run python task.py
poetry run python crypto.py e
