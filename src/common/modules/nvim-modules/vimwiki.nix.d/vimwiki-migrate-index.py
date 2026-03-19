#!/usr/bin/env python3
import argparse
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple


def parse_date_from_filename(
    filename: str, parent_dirs: List[str] = []
) -> Optional[datetime]:
    match = re.match(r"(\d{4})-(\d{2})-(\d{2})\.md$", filename)
    if match:
        return datetime(int(match.group(1)), int(match.group(2)), int(match.group(3)))

    match = re.match(r"(\d{4})_(\d{2})_(\d{2})\.md$", filename)
    if match:
        return datetime(int(match.group(1)), int(match.group(2)), int(match.group(3)))

    match = re.match(r"\((\d{2})(\d{2})(\d{2})\).*\.md$", filename)
    if match:
        year = 2000 + int(match.group(1))
        month = int(match.group(2))
        day = int(match.group(3))
        return datetime(year, month, day)

    return None


def get_journal_entries(
    vault_path: Path, obsidian_diary_folder: str = "Daily"
) -> List[Tuple[datetime, str, str]]:
    entries = []

    daily_path = vault_path / obsidian_diary_folder
    if daily_path.exists():
        for year_dir in daily_path.iterdir():
            if year_dir.is_dir() and re.match(r"^\d{4}$", year_dir.name):
                for month_dir in year_dir.iterdir():
                    if month_dir.is_dir():
                        for file in month_dir.glob("*.md"):
                            date = parse_date_from_filename(file.name)
                            if date:
                                rel_path = file.relative_to(vault_path)
                                entries.append((date, file.name, str(rel_path)))

    journals_path = vault_path / "journals"
    if journals_path.exists():
        for file in journals_path.glob("*.md"):
            date = parse_date_from_filename(file.name)
            if date:
                rel_path = file.relative_to(vault_path)
                entries.append((date, file.name, str(rel_path)))

    diary_path = vault_path / "diary"
    if diary_path.exists():
        for file in diary_path.glob("*.md"):
            if file.name not in ["diary.md", "index.md"]:
                date = parse_date_from_filename(file.name)
                if date:
                    rel_path = file.relative_to(vault_path)
                    entries.append((date, file.name, str(rel_path)))

    return sorted(entries, key=lambda x: x[0], reverse=True)


def get_folder_structure(vault_path: Path) -> Dict:
    structure = {}

    exclude_dirs = {
        ".git",
        ".obsidian",
        ".vault-backups",
        "logseq",
        ".DS_Store",
        "whiteboards",
    }
    exclude_prefixes = (".",)

    for item in vault_path.iterdir():
        if item.name in exclude_dirs or item.name.startswith(exclude_prefixes):
            continue

        if item.is_dir():
            md_files = []
            subdirs = []

            try:
                for sub_item in item.iterdir():
                    if sub_item.is_file() and sub_item.suffix == ".md":
                        md_files.append(sub_item.name)
                    elif sub_item.is_dir() and not sub_item.name.startswith("."):
                        subdirs.append(sub_item.name)
            except PermissionError:
                continue

            structure[item.name] = {
                "files": sorted(md_files),
                "subdirs": sorted(subdirs),
            }

    return structure


def generate_index_content(vault_path: Path) -> str:
    content = []
    content.append("# Index\n")

    content.append("\n## Quick Links\n")
    content.append("- [[diary/diary|Diary Index]]\n")

    content.append("\n## Wiki\n")

    structure = get_folder_structure(vault_path)

    for folder_name in sorted(structure.keys()):
        folder_info = structure[folder_name]

        if not folder_info["files"] and not folder_info["subdirs"]:
            continue

        content.append(f"\n### {folder_name}\n")

        if folder_info["files"]:
            for file in folder_info["files"]:
                file_without_ext = file[:-3] if file.endswith(".md") else file
                content.append(
                    f"- [[{folder_name}/{file_without_ext}|{file_without_ext}]]\n"
                )

        if folder_info["subdirs"]:
            content.append("\n_Subdirectories:_\n")
            for subdir in folder_info["subdirs"]:
                content.append(f"- {folder_name}/{subdir}/\n")

    return "".join(content)


def generate_diary_content(
    vault_path: Path, obsidian_diary_folder: str = "Daily"
) -> str:
    content = []
    content.append("# Diary\n")
    content.append("\n[[../index|← Back to Main Index]]\n")

    entries = get_journal_entries(vault_path, obsidian_diary_folder)

    if entries:
        current_year = None
        current_month = None

        for date, filename, rel_path in entries:
            if current_year != date.year:
                current_year = date.year
                current_month = None
                content.append(f"\n## {current_year}\n")

            if current_month != date.month:
                current_month = date.month
                content.append(f"\n### {date.strftime('%B')}\n")

            date_str = date.strftime("%Y-%m-%d %A")
            link_path = rel_path[:-3] if rel_path.endswith(".md") else rel_path
            link_path = link_path.replace("\\", "/")
            content.append(f"- **{date_str}**: [[../{link_path}|{filename[:-3]}]]\n")

    return "".join(content)


def confirm_overwrite(file_path: Path) -> bool:
    if file_path.exists():
        response = input(f"File {file_path} exists. Overwrite? [y/N]: ").strip().lower()
        return response == "y"
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Generate vimwiki index files from Obsidian/Logseq vault"
    )
    parser.add_argument("vault_path", help="Path to the vault directory")
    parser.add_argument(
        "--obsidian-diary-folder",
        default="Daily",
        help="Relative path to Obsidian daily notes folder (default: Daily)",
    )

    args = parser.parse_args()

    vault_path = Path(args.vault_path).resolve()
    obsidian_diary_folder = args.obsidian_diary_folder

    if not vault_path.exists():
        print(f"Error: Vault path does not exist: {vault_path}")
        sys.exit(1)

    if not vault_path.is_dir():
        print(f"Error: Vault path is not a directory: {vault_path}")
        sys.exit(1)

    print(f"Processing vault: {vault_path}")

    index_path = vault_path / "index.md"
    diary_index_path = vault_path / "diary" / "diary.md"

    diary_dir = vault_path / "diary"
    if not diary_dir.exists():
        diary_dir.mkdir(parents=True, exist_ok=True)
        print(f"Created diary directory: {diary_dir}")

    if confirm_overwrite(index_path):
        index_content = generate_index_content(vault_path)

        with open(index_path, "w", encoding="utf-8") as f:
            f.write(index_content)

        print(f"✓ Generated: {index_path}")
    else:
        print(f"⊘ Skipped: {index_path}")

    if confirm_overwrite(diary_index_path):
        diary_content = generate_diary_content(vault_path, obsidian_diary_folder)

        with open(diary_index_path, "w", encoding="utf-8") as f:
            f.write(diary_content)

        print(f"✓ Generated: {diary_index_path}")
    else:
        print(f"⊘ Skipped: {diary_index_path}")

    print("\nVimwiki index generation complete!")


if __name__ == "__main__":
    main()
