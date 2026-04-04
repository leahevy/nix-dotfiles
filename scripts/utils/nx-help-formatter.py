#!/usr/bin/env python3
import sys
import json

def format_command_groups(data):
    groups_map = {}

    for cmd_name, cmd_data in data.get("subcommands", {}).items():
        group = cmd_data.get("group", "")
        if group not in groups_map:
            groups_map[group] = []

        args_str = ""
        for arg in cmd_data.get("arguments", []):
            if arg.get("variadic"):
                args_str += f" <{arg['name']}>"
            elif arg.get("required", True):
                args_str += f" <{arg['name']}>"
            else:
                args_str += f" [{arg['name']}]"

        groups_map[group].append({
            "name": cmd_name,
            "args": args_str,
            "desc": cmd_data.get("description", "")
        })

    group_definitions = {g["id"]: g["label"] for g in data.get("groups", [])}
    group_order = [g["id"] for g in data.get("groups", [])] + [""]

    for group_id in group_order:
        if group_id not in groups_map:
            continue

        if group_id:
            label = group_definitions.get(group_id, group_id)
            print(f"  {label}:")

        for cmd in groups_map[group_id]:
            full_cmd = cmd["name"] + cmd["args"]
            if len(full_cmd) < 22:
                padding = 22 - len(full_cmd)
                print(f"    {full_cmd}{' ' * padding}{cmd['desc']}")
            else:
                print(f"    {full_cmd}")
                print(f"{' ' * 26}{cmd['desc']}")

        print()

if __name__ == "__main__":
    data = json.load(sys.stdin)
    format_command_groups(data)
