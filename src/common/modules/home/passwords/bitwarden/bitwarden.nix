args@{
  lib,
  pkgs,
  pkgs-unstable,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "bitwarden";

  group = "passwords";
  input = "common";
  namespace = "home";

  unfree = [ "bws" ];

  settings = {
    autoSyncEnabled = true;
    syncIntervalMinutes = 30;
    serverURL = "https://vault.bitwarden.eu";
    withSecretManager = true;
  };

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");

      customPkgs = self.pkgs {
        overlays = [
          (final: prev: {
            bitwarden-cli = prev.bitwarden-cli.overrideAttrs (oldAttrs: {
              nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
              postInstall = (oldAttrs.postInstall or "") + ''
                wrapProgram $out/bin/bw \
                  --set BITWARDENCLI_APPDATA_DIR "${config.home.homeDirectory}/.config/Bitwarden-CLI"
              '';
            });
          })
        ];
      };
    in
    {
      sops.secrets."bitwarden-api-token" = lib.mkIf self.settings.withSecretManager {
        format = "binary";
        sopsFile = self.config.secretsPath "bitwarden-api-token";
        mode = "0400";
      };

      home.file.".local/bin/bitwarden-get-secret" = lib.mkIf self.settings.withSecretManager {
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          SECRET_UUID="''${1:-}"
          if [[ -z "$SECRET_UUID" ]]; then
            echo "Usage: bitwarden-get-secret <SECRET_UUID>" >&2
            exit 1
          fi

          if [[ ! "$SECRET_UUID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
            echo "Error: Invalid UUID format" >&2
            exit 2
          fi

          TOKEN_FILE="${self.user.home}/.config/sops-nix/secrets/bitwarden-api-token"
          if [[ ! -r "$TOKEN_FILE" ]]; then
            echo "Error: Cannot read token file" >&2
            exit 3
          fi

          export BWS_ACCESS_TOKEN="$(cat "$TOKEN_FILE")"
          SECRET="$(${pkgs.bws}/bin/bws secret get --server-url "${self.settings.serverURL}" "$SECRET_UUID" 2>/dev/null | ${pkgs.jq}/bin/jq -r ".value" 2>/dev/null)"

          if [[ -n "$SECRET" && "$SECRET" != "null" ]]; then
            cat <<< "$SECRET"
          else
            echo "Error: Failed to retrieve secret" >&2
            exit 4
          fi
        '';
        executable = true;
      };

      home.packages =
        lib.optionals self.isLinux [
          pkgs.bitwarden-desktop
        ]
        ++ [
          customPkgs.bitwarden-cli
        ]
        ++ lib.optionals self.settings.withSecretManager [
          pkgs.bws
          pkgs.jq
        ];

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+K" = {
              action = spawn-sh "niri-scratchpad --app-id Bitwarden --all-windows --spawn bitwarden";
              hotkey-overlay.title = "Apps:Bitwarden";
            };
          };

          window-rules = [
            {
              matches = [
                {
                  app-id = "Bitwarden";
                }
              ];
              open-on-workspace = "scratch";
              open-floating = true;
              open-focused = false;
              block-out-from = "screencast";
            }
          ];
        };
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/Bitwarden"
          ".config/Bitwarden-CLI"
        ];
      };

      systemd.user.services = lib.mkIf (self.isLinux && self.settings.autoSyncEnabled) {
        bitwarden-sync = {
          Unit = {
            Description = "Bitwarden CLI Vault Sync";
          };

          Service = {
            Type = "oneshot";
            ExecStart = "${customPkgs.bitwarden-cli}/bin/bw sync";
            Environment = [
              "BITWARDENCLI_APPDATA_DIR=${config.home.homeDirectory}/.config/Bitwarden-CLI"
            ];
            ExecCondition = pkgs.writeShellScript "check-bw-status" ''
              set -euo pipefail
              [[ -f "${config.home.homeDirectory}/.config/Bitwarden-CLI/data.json" && -r "${config.home.homeDirectory}/.config/Bitwarden-CLI/data.json" ]] || exit 1
              response=$(${customPkgs.bitwarden-cli}/bin/bw status 2>/dev/null || echo '{}')
              userId=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.userId // ""')
              [[ -n "$userId" && "$userId" != "null" ]]

              serverUrl=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.serverUrl // ""')
              if [[ -n "$serverUrl" && "$serverUrl" != "null" ]]; then
                serverHost=$(echo "$serverUrl" | ${pkgs.gnused}/bin/sed 's|https\?://||' | ${pkgs.gnused}/bin/sed 's|/.*||')
                ${pkgs.iputils}/bin/ping -c 1 -W 5 "$serverHost" >/dev/null 2>&1
              fi
            '';
          };
        };
      };

      systemd.user.timers = lib.mkIf (self.isLinux && self.settings.autoSyncEnabled) {
        bitwarden-sync = {
          Unit = {
            Description = "Bitwarden CLI Vault Sync Timer";
            Requires = [ "bitwarden-sync.service" ];
          };

          Timer = {
            OnCalendar = "*:0/${toString self.settings.syncIntervalMinutes}";
            Persistent = true;
            RandomizedDelaySec = "5min";
          };

          Install = {
            WantedBy = [ "timers.target" ];
          };
        };
      };

      home.file.".local/bin/scripts/convert-keepassxc-to-bitwarden" = {
        text = ''
          #!/usr/bin/env python3

          import xml.etree.ElementTree as ET
          import json
          import uuid
          import datetime
          import sys
          import os
          import base64
          import struct
          import argparse
          from typing import Dict, List, Optional, Tuple, Any


          class Colors:
              @staticmethod
              def green(text: str, *args, bold: bool = False, **kwargs) -> str:
                  color_code = "\033[1;32m" if bold else "\033[0;32m"
                  return f"{color_code}{text.format(*args, **kwargs)}\033[0m"

              @staticmethod
              def white(text: str, *args, bold: bool = False, **kwargs) -> str:
                  color_code = "\033[1;37m" if bold else "\033[0;37m"
                  return f"{color_code}{text.format(*args, **kwargs)}\033[0m"

              @staticmethod
              def yellow(text: str, *args, bold: bool = False, **kwargs) -> str:
                  color_code = "\033[1;33m" if bold else "\033[0;33m"
                  return f"{color_code}{text.format(*args, **kwargs)}\033[0m"

              @staticmethod
              def blue(text: str, *args, bold: bool = False, **kwargs) -> str:
                  color_code = "\033[1;34m" if bold else "\033[0;34m"
                  return f"{color_code}{text.format(*args, **kwargs)}\033[0m"

              @staticmethod
              def red(text: str, *args, bold: bool = False, **kwargs) -> str:
                  color_code = "\033[1;31m" if bold else "\033[0;31m"
                  return f"{color_code}{text.format(*args, **kwargs)}\033[0m"

              @staticmethod
              def grey(text: str, *args, bold: bool = False, **kwargs) -> str:
                  color_code = "\033[1;90m" if bold else "\033[0;90m"
                  return f"{color_code}{text.format(*args, **kwargs)}\033[0m"


          class KeePassXCToBitwardenConverter:
              def __init__(self, debug: bool = False, quiet: bool = False) -> None:
                  self.folder_map: Dict[str, str] = {}
                  self.folders: List[Dict[str, str]] = []
                  self.items: List[Dict[str, Any]] = []
                  self.debug = debug
                  self.quiet = quiet
                  self.notifications: List[str] = []

              def generate_uuid4(self) -> str:
                  return str(uuid.uuid4())

              def log(self, message: str, exception: Optional[Exception] = None, is_error: bool = False) -> None:
                  if exception or is_error:
                      if exception:
                          print(Colors.red("{}: {}", message, exception), file=sys.stderr)
                      else:
                          print(Colors.red(message), file=sys.stderr)
                  elif self.debug:
                      print(Colors.grey(message), file=sys.stderr)

              def error(self, message: str, exception: Optional[Exception] = None) -> None:
                  self.log(message, exception, is_error=True)

              def notify(self, message: str) -> None:
                  self.notifications.append(message)
                  if not self.quiet:
                      formatted_message = Colors.white("*", bold=True) + " " + Colors.green("Note: ") + message
                      print(formatted_message, file=sys.stderr)

              def get_current_iso_timestamp(self) -> str:
                  return datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z')

              def convert_keepass_time(self, base64_time: str) -> str:
                  try:
                      binary_data = base64.b64decode(base64_time)
                      seconds = struct.unpack('<Q', binary_data)[0]

                      epoch = datetime.datetime(1, 1, 1, tzinfo=datetime.timezone.utc)
                      timestamp_utc = epoch + datetime.timedelta(seconds=seconds)

                      local_tz = datetime.datetime.now().astimezone().tzinfo
                      local_now = datetime.datetime.now(local_tz)
                      utc_offset = local_now.utcoffset()
                      offset_seconds = int(utc_offset.total_seconds()) if utc_offset is not None else 0

                      timestamp_adjusted = timestamp_utc + datetime.timedelta(seconds=offset_seconds)

                      return timestamp_adjusted.isoformat(timespec='milliseconds').replace('+00:00', 'Z')
                  except Exception as e:
                      self.log(f"Warning: Failed to convert timestamp '{base64_time}'", e)
                      return self.get_current_iso_timestamp()

              def ensure_folder_exists(self, folder_path: str) -> Optional[str]:
                  if not folder_path or folder_path == "/":
                      return None

                  if folder_path not in self.folder_map:
                      folder_id = self.generate_uuid4()
                      self.folder_map[folder_path] = folder_id
                      self.folders.append({
                          "id": folder_id,
                          "name": folder_path
                      })

                  return self.folder_map[folder_path]

              def extract_string_value(self, entry_elem: ET.Element, key: str) -> Tuple[str, bool]:
                  for string_elem in entry_elem.findall('String'):
                      key_elem = string_elem.find('Key')
                      if key_elem is not None and key_elem.text == key:
                          value_elem = string_elem.find('Value')
                          if value_elem is not None:
                              value = value_elem.text or ""
                              is_protected = value_elem.get('ProtectInMemory') == 'True'
                              return value, is_protected
                  return "", False

              def get_standard_fields(self, entry_elem: ET.Element) -> Dict[str, Tuple[str, bool]]:
                  standard_keys = ['Title', 'UserName', 'Password', 'URL', 'Notes', 'otp']
                  fields = {}
                  for key in standard_keys:
                      value, is_protected = self.extract_string_value(entry_elem, key)
                      fields[key] = (value, is_protected)
                  return fields

              def get_custom_fields_and_notes_additions(self, entry_elem: ET.Element, folder_path: str) -> Tuple[List[Dict[str, Any]], List[str]]:
                  standard_keys = {'Title', 'UserName', 'Password', 'URL', 'Notes', 'otp'}
                  custom_fields = []
                  notes_additions = []

                  for string_elem in entry_elem.findall('String'):
                      key_elem = string_elem.find('Key')
                      if key_elem is not None and key_elem.text not in standard_keys:
                          value_elem = string_elem.find('Value')
                          if value_elem is not None:
                              value = value_elem.text or ""
                              is_protected = value_elem.get('ProtectInMemory') == 'True'

                              if '\n' in value:
                                  title = self.get_entry_title(entry_elem)
                                  folder_info = f" in folder {Colors.yellow(folder_path, bold=True)}" if folder_path else ""
                                  message = f"Entry {Colors.yellow(title, bold=True)}{folder_info} has custom field {Colors.blue(key_elem.text, bold=True)} with line breaks merged into notes"
                                  self.notify(message)
                                  notes_additions.append(f"# {key_elem.text}\n\n{value}")
                              else:
                                  custom_fields.append({
                                      "name": key_elem.text,
                                      "value": value,
                                      "type": 1 if is_protected else 0,
                                      "linkedId": None
                                  })

                  return custom_fields, notes_additions

              def check_attachments(self, entry_elem: ET.Element, folder_path: str) -> None:
                  binary_elements = entry_elem.findall('Binary')
                  if binary_elements:
                      title = self.get_entry_title(entry_elem)
                      attachment_names = []
                      for binary_elem in binary_elements:
                          key_elem = binary_elem.find('Key')
                          if key_elem is not None and key_elem.text:
                              attachment_names.append(key_elem.text)

                      if attachment_names:
                          folder_info = f" in folder {Colors.yellow(folder_path, bold=True)}" if folder_path else ""
                          attachments_str = ", ".join([Colors.blue(name, bold=True) for name in attachment_names])
                          message = f"Entry {Colors.yellow(title, bold=True)}{folder_info} has attachments: {attachments_str}"
                          self.notify(message)

              def get_entry_title(self, entry_elem: ET.Element) -> str:
                  for string_elem in entry_elem.findall('String'):
                      key_elem = string_elem.find('Key')
                      if key_elem is not None and key_elem.text == 'Title':
                          value_elem = string_elem.find('Value')
                          if value_elem is not None and value_elem.text:
                              return value_elem.text
                  return "Untitled Entry"

              def create_bitwarden_item(self, entry_elem: ET.Element, folder_path: str) -> Dict[str, Any]:
                  uuid_elem = entry_elem.find('UUID')
                  entry_uuid = uuid_elem.text if uuid_elem is not None else "unknown"
                  self.log(f"Processing entry UUID: {entry_uuid}")

                  standard_fields = self.get_standard_fields(entry_elem)
                  custom_fields, notes_additions = self.get_custom_fields_and_notes_additions(entry_elem, folder_path)

                  self.check_attachments(entry_elem, folder_path)

                  title = standard_fields['Title'][0] or "Untitled Entry"
                  username = standard_fields['UserName'][0]
                  password = standard_fields['Password'][0]
                  url = standard_fields['URL'][0]
                  notes = standard_fields['Notes'][0]
                  totp = standard_fields['otp'][0]

                  self.log(f"Entry '{title}' - found {len(custom_fields)} custom fields, {len(notes_additions)} notes additions")
                  if folder_path:
                      self.log(f"Entry '{title}' - assigned to folder: {folder_path}")

                  final_notes_parts = []
                  if notes.strip():
                      final_notes_parts.append(notes.strip())
                  if notes_additions:
                      final_notes_parts.extend(notes_additions)

                  final_notes = "\n\n".join(final_notes_parts)

                  uris = []
                  if url.strip():
                      uris.append({
                          "match": None,
                          "uri": url.strip()
                      })

                  login = {
                      "uris": uris,
                      "username": username,
                      "password": password,
                      "totp": totp if totp.strip() else None
                  }

                  folder_id = self.ensure_folder_exists(folder_path) if folder_path else None

                  times_elem = entry_elem.find('Times')
                  creation_time = self.get_current_iso_timestamp()
                  revision_time = self.get_current_iso_timestamp()

                  if times_elem is not None:
                      creation_time_elem = times_elem.find('CreationTime')
                      if creation_time_elem is not None and creation_time_elem.text:
                          self.log(f"Entry '{title}' - Found CreationTime: {creation_time_elem.text}")
                          creation_time = self.convert_keepass_time(creation_time_elem.text)
                          self.log(f"Entry '{title}' - Converted CreationTime to: {creation_time}")
                      else:
                          self.error(f"Entry '{title}' - No CreationTime found")

                      modification_time_elem = times_elem.find('LastModificationTime')
                      if modification_time_elem is not None and modification_time_elem.text:
                          self.log(f"Entry '{title}' - Found LastModificationTime: {modification_time_elem.text}")
                          revision_time = self.convert_keepass_time(modification_time_elem.text)
                          self.log(f"Entry '{title}' - Converted LastModificationTime to: {revision_time}")
                      else:
                          self.error(f"Entry '{title}' - No LastModificationTime found")
                  else:
                      self.error(f"Entry '{title}' - No Times element found")

                  try:
                      creation_dt = datetime.datetime.fromisoformat(creation_time.replace('Z', '+00:00'))
                      revision_dt = datetime.datetime.fromisoformat(revision_time.replace('Z', '+00:00'))

                      if revision_dt < creation_dt:
                          self.error(f"Entry '{title}' - Revision date {revision_time} is before creation date {creation_time}, using creation date for both")
                          revision_time = creation_time
                  except Exception as e:
                      self.log(f"Entry '{title}' - Failed to validate timestamps", e)

                  item = {
                      "passwordHistory": [],
                      "revisionDate": revision_time,
                      "creationDate": creation_time,
                      "organizationId": None,
                      "folderId": folder_id,
                      "type": 1,
                      "reprompt": 0,
                      "name": title,
                      "notes": final_notes,
                      "favorite": False,
                      "fields": custom_fields,
                      "login": login,
                      "collectionIds": None
                  }

                  return item

              def process_group(self, group_elem: ET.Element, parent_path: str = "") -> None:
                  name_elem = group_elem.find('Name')
                  if name_elem is None:
                      return

                  group_name = name_elem.text
                  if not group_name:
                      return

                  if group_name == "Recycle Bin":
                      self.log(f"Skipping Recycle Bin group")
                      return

                  current_path = f"{parent_path}/{group_name}" if parent_path else group_name
                  self.log(f"Processing group: {current_path}")

                  has_entries = self.group_has_entries(group_elem)

                  entries_processed = 0
                  for entry_elem in group_elem.findall('Entry'):
                      item = self.create_bitwarden_item(entry_elem, current_path)
                      self.items.append(item)
                      entries_processed += 1

                  self.log(f"Group '{current_path}' - processed {entries_processed} entries")

                  if entries_processed > 0:
                      self.ensure_folder_exists(current_path)

                  for subgroup_elem in group_elem.findall('Group'):
                      self.process_group(subgroup_elem, current_path)

                  if not has_entries and current_path in self.folder_map:
                      self.log(f"Removing empty folder: {current_path}")
                      folder_id = self.folder_map[current_path]
                      self.folder_map.pop(current_path)
                      self.folders = [f for f in self.folders if f['id'] != folder_id]

              def group_has_entries(self, group_elem: ET.Element) -> bool:
                  if group_elem.findall('Entry'):
                      return True

                  for subgroup_elem in group_elem.findall('Group'):
                      name_elem = subgroup_elem.find('Name')
                      if name_elem is not None and name_elem.text == "Recycle Bin":
                          continue

                      if self.group_has_entries(subgroup_elem):
                          return True

                  return False

              def convert(self, keepassxc_file: str) -> str:
                  try:
                      self.log(f"Starting conversion of: {keepassxc_file}")
                      tree = ET.parse(keepassxc_file)
                      root = tree.getroot()

                      root_elem = root.find('Root')
                      if root_elem is None:
                          raise ValueError("No Root element found in KeePassXC file")

                      main_groups = root_elem.findall('Group')
                      if not main_groups:
                          raise ValueError("No main group found under Root")

                      main_group = main_groups[0]
                      main_group_name = main_group.find('Name')
                      main_name = main_group_name.text if main_group_name is not None else "Unknown"
                      self.log(f"Found main group: {main_name}")

                      root_entries = main_group.findall('Entry')
                      self.log(f"Processing {len(root_entries)} entries at root level")
                      for entry_elem in root_entries:
                          item = self.create_bitwarden_item(entry_elem, "")
                          self.items.append(item)

                      subgroups = main_group.findall('Group')
                      self.log(f"Processing {len(subgroups)} subgroups")
                      for subgroup_elem in subgroups:
                          self.process_group(subgroup_elem)

                      self.log(f"Conversion complete - {len(self.items)} items, {len(self.folders)} folders")

                      bitwarden_export = {
                          "encrypted": False,
                          "folders": self.folders,
                          "items": self.items
                      }

                      return json.dumps(bitwarden_export, indent=2)

                  except ET.ParseError as e:
                      raise ValueError(f"Failed to parse XML file: {e}")
                  except Exception as e:
                      raise ValueError(f"Conversion failed: {e}")


          def main() -> None:
              parser = argparse.ArgumentParser(description='Convert KeePassXC XML export to Bitwarden JSON format')
              parser.add_argument('input_file', help='Input KeePassXC XML file')
              parser.add_argument('output_file', nargs='?', help='Output Bitwarden JSON file')
              parser.add_argument('--debug', action='store_true', help='Enable debug output')
              parser.add_argument('--quiet', action='store_true', help='Suppress notification messages')
              parser.add_argument('--no-output', action='store_true', help='Do not write output file, only show notifications and errors')

              args = parser.parse_args()

              if not args.input_file.endswith('.xml'):
                  print(f"Error: Input file must have .xml extension", file=sys.stderr)
                  sys.exit(1)

              if not args.no_output:
                  if not args.output_file:
                      print("Error: Output file required unless --no-output is used", file=sys.stderr)
                      sys.exit(1)
                  if not args.output_file.endswith('.json'):
                      print(f"Error: Output file must have .json extension", file=sys.stderr)
                      sys.exit(1)

              if not os.path.isfile(args.input_file):
                  print(f"Error: Input file '{args.input_file}' does not exist", file=sys.stderr)
                  sys.exit(1)

              if not args.no_output and os.path.exists(args.output_file):
                  response = input(f"Output file '{args.output_file}' already exists. Overwrite? (y/N): ")
                  if response not in ('y', 'Y'):
                      print("Operation cancelled", file=sys.stderr)
                      sys.exit(1)

              try:
                  converter = KeePassXCToBitwardenConverter(debug=args.debug, quiet=args.quiet)
                  result_json = converter.convert(args.input_file)

                  if not args.no_output:
                      with open(args.output_file, 'w', encoding='utf-8') as f:
                          f.write(result_json)

                      print(Colors.green("\nSuccessfully converted '{}' to '{}'", args.input_file, args.output_file, bold=True))
                      print(Colors.green("Converted {} items and {} folders", len(converter.items), len(converter.folders), bold=True))
                  else:
                      print(Colors.green("\nAnalyzed '{}' - {} items and {} folders found", args.input_file, len(converter.items), len(converter.folders), bold=True))

              except Exception as e:
                  print(Colors.red("Error: {}", e), file=sys.stderr)
                  sys.exit(1)


          if __name__ == "__main__":
              main()
        '';
        executable = true;
      };
    };
}
