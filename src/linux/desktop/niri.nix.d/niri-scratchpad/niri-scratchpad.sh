#! /usr/bin/env bash

##############################################################################################
#        _        _                                  _          _                        _   #
#       (_)      (_)                                | |        | |                      | |  #
# _ __   _  _ __  _          ___   ___  _ __   __ _ | |_   ___ | |__   _ __    __ _   __| |  #
#| '_ \ | || '__|| | ______ / __| / __|| '__| / _` || __| / __|| '_ \ | '_ \  / _` | / _` |  #
#| | | || || |   | ||______|\__ \| (__ | |   | (_| || |_ | (__ | | | || |_) || (_| || (_| |  #
#|_| |_||_||_|   |_|        |___/ \___||_|    \__,_| \__| \___||_| |_|| .__/  \__,_| \__,_|  #
#                                                                     | |                    #
#                                                                     |_|                    #
#                                                                                            #
##############################################################################################
#
################################################################################################
# Original source: https://github.com/gvolpe/niri-scratchpad
# Licensed under the Apache License, Version 2.0
# - Clean-up argument parsing to allow adding new functionality (leah.nixdev@gmail.com)
# - Added functionality to move all windows of an application (leah.nixdev@gmail.com)
# - Fixed workspace ID vs index issue for window movement (leah.nixdev@gmail.com)
################################################################################################
#
# Adapted from the many ideas shared at: https://github.com/YaLTeR/niri/discussions/329

SCRATCH_WORKSPACE_NAME=scratch

ALL_WINDOWS_FLAG=""
SEARCH_METHOD_FLAG=""
SCRATCH_WIN_NAME=""
SPAWN_FLAG=""
PROCESS_NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --all-windows)
      ALL_WINDOWS_FLAG="--all-windows"
      shift
      ;;
    --app-id|--title)
      SEARCH_METHOD_FLAG=$1
      SCRATCH_WIN_NAME=$2
      shift 2
      ;;
    --spawn)
      SPAWN_FLAG=$1
      PROCESS_NAME=$2
      shift 2
      ;;
    --help|--version)
      SEARCH_METHOD_FLAG=$1
      shift
      ;;
    *)
      if [[ -z $SCRATCH_WIN_NAME ]]; then
        SCRATCH_WIN_NAME=$1
      fi
      shift
      ;;
  esac
done

showHelp() {
  echo "[niri-scratchpad]"
  echo ""
  echo "  Open scratchpad app by app-id:"
  echo "    - 'niri-scratchpad spotify'"
  echo "    - 'niri-scratchpad --app-id spotify'"
  echo ""
  echo "  Open scratchpad by title (some apps do not support app-id):"
  echo "    - 'niri-scratchpad --title Telegram'"
  echo ""
  echo "  Move all windows of an application:"
  echo "    - 'niri-scratchpad --all-windows firefox'"
  echo "    - 'niri-scratchpad --app-id firefox --all-windows'"
  echo "    - 'niri-scratchpad --title Firefox --all-windows'"
  echo ""
  echo "  Spawn process on first request if it does not exist:"
  echo "    - 'niri-scratchpad --app-id Audacious --spawn audacious'"
  echo ""
  echo "  NOTE: when using the '--spawn' flag, you MUST indicate either '--app-id' or 'title' flag as well."
}

windows=$(niri msg -j windows)

case $SEARCH_METHOD_FLAG in
  "--app-id")
    if [[ -n $ALL_WINDOWS_FLAG ]]; then
      app_windows=$(echo "$windows" | jq "[.[] | select(.app_id == \"$SCRATCH_WIN_NAME\")]")
    else
      app_window=$(echo "$windows" | jq ".[] | select(.app_id == \"$SCRATCH_WIN_NAME\")")
    fi
    ;;
  "--title")
    if [[ -n $ALL_WINDOWS_FLAG ]]; then
      app_windows=$(echo "$windows" | jq "[.[] | select(.title == \"$SCRATCH_WIN_NAME\")]")
    else
      app_window=$(echo "$windows" | jq ".[] | select(.title == \"$SCRATCH_WIN_NAME\")")
    fi
    ;;
  "--help")
    showHelp
    exit 0
    ;;
  "--version")
    echo "niri-scratchpad v0.0.1"
    exit 0
    ;;
  *)
    if [[ -n $ALL_WINDOWS_FLAG ]]; then
      app_windows=$(echo "$windows" | jq "[.[] | select(.app_id == \"$SCRATCH_WIN_NAME\")]")
    else
      app_window=$(echo "$windows" | jq ".[] | select(.app_id == \"$SCRATCH_WIN_NAME\")")
    fi
    ;;
esac

if [[ -n $ALL_WINDOWS_FLAG ]]; then
  win_count=$(echo "$app_windows" | jq length)
  if [[ $win_count -eq 0 ]]; then
    no_windows_found=true
  fi
else
  win_id=$(echo "$app_window" | jq .id)
  if [[ -z $win_id || $win_id == "null" ]]; then
    no_windows_found=true
  fi
fi

if [[ $no_windows_found == "true" ]]; then
  case $SPAWN_FLAG in
    "--spawn")
      if [[ -z $PROCESS_NAME ]]; then
        showHelp
        exit 1
      else
        niri msg action spawn -- "$PROCESS_NAME"
        exit 0
      fi
      ;;
    *)
      showHelp
      exit 1
      ;;
  esac
fi

moveWindowToScratchpad() {
  niri msg action move-window-to-workspace --window-id "$win_id" "$SCRATCH_WORKSPACE_NAME" --focus=false
  if [[ -n $NIRI_SCRATCHPAD_ANIMATIONS ]]; then
    niri msg action move-window-to-tiling --id "$win_id"
  fi
}

moveAllWindowsToScratchpad() {
  local window_count
  window_count=$(echo "$app_windows" | jq length)
  for ((i=0; i<window_count; i++)); do
    local current_win_id
    current_win_id=$(echo "$app_windows" | jq ".[$i].id")
    niri msg action move-window-to-workspace --window-id "$current_win_id" "$SCRATCH_WORKSPACE_NAME" --focus=false
    if [[ -n $NIRI_SCRATCHPAD_ANIMATIONS ]]; then
      niri msg action move-window-to-tiling --id "$current_win_id"
    fi
  done
}

bringScratchpadWindowToFocus() {
  is_win_floating=$(echo "$app_window" | jq .is_floating)
  niri msg action move-window-to-workspace --window-id "$win_id" "$work_idx"
  if [[ $is_win_floating == "false" && -n $NIRI_SCRATCHPAD_ANIMATIONS ]]; then
    niri msg action move-window-to-floating --id "$win_id"
  fi
  niri msg action focus-window --id "$win_id"
}

bringAllScratchpadWindowsToFocus() {
  local window_count
  window_count=$(echo "$app_windows" | jq length)
  for ((i=0; i<window_count; i++)); do
    local current_win_id
    current_win_id=$(echo "$app_windows" | jq ".[$i].id")
    local is_win_floating
    is_win_floating=$(echo "$app_windows" | jq ".[$i].is_floating")
    niri msg action move-window-to-workspace --window-id "$current_win_id" "$work_idx"
    if [[ $is_win_floating == "false" && -n $NIRI_SCRATCHPAD_ANIMATIONS ]]; then
      niri msg action move-window-to-floating --id "$current_win_id"
    fi
  done
  if [[ $window_count -gt 0 ]]; then
    local first_win_id
    first_win_id=$(echo "$app_windows" | jq ".[0].id")
    niri msg action focus-window --id "$first_win_id"
  fi
}

if [[ -n $ALL_WINDOWS_FLAG ]]; then
  focused_workspace=$(niri msg -j workspaces | jq '.[] | select(.is_focused == true)')
  work_id=$(echo "$focused_workspace" | jq .id)
  work_idx=$(echo "$focused_workspace" | jq .idx)

  windows_on_current=$(echo "$app_windows" | jq "[.[] | select(.workspace_id == $work_id)]")
  windows_on_current_count=$(echo "$windows_on_current" | jq length)

  if [[ $windows_on_current_count -gt 0 ]]; then
    moveAllWindowsToScratchpad
  else
    bringAllScratchpadWindowsToFocus
  fi
else
  if [[ $(echo "$app_window" | jq .is_focused) == "false" ]]; then
    focused_workspace=$(niri msg -j workspaces | jq '.[] | select(.is_focused == true)')
    work_id=$(echo "$focused_workspace" | jq .id)
    work_idx=$(echo "$focused_workspace" | jq .idx)
    win_work_id=$(echo "$app_window" | jq .workspace_id)

    if [[ "$win_work_id" == "$work_id" ]]; then
      moveWindowToScratchpad
    else
      bringScratchpadWindowToFocus
    fi
  else
    moveWindowToScratchpad
  fi
fi
