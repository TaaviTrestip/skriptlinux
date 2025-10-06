#!/bin/bash
# Script to backup a folder with many options
cleanup_old_backups() {
    pattern=$1
    ls -1t "$backup_dest/$src_base.backup."*"$pattern" 2>/dev/null | tail -n +4 | while read -r oldfile; do
        echo "Removing old backup: $oldfile"
        rm -f "$oldfile"
        if [ -f "$oldfile.sha256" ]; then
            echo "Removing checksum: $oldfile.sha256"
            rm -f "$oldfile.sha256"
        fi
    done
}

src=~/skriptlinux/praks2/src
src_base=$(basename "$src")
backup_dest=~/skriptlinux/praks2/backup
date=$(date +"%d%b%Y_%H-%M-%S" | tr '[:upper:]' '[:lower:]')
logfile=~/skriptlinux/praks2/backup/backup.log
backup_file="$src_base.backup.$date.tar.zst"
backup_file1="$src_base.backup.$date.tar.gz"
backup_file2="$src_base.backup.$date.tar.xz"
ignore_file="$src/.backupignore"

tempdir=$(mktemp -d)
trap 'echo "Cleaning temp files..."; rm -rf "$tempdir"' EXIT

src_size=$(du -sb "$src" | awk '{print $1}')
free_space=$(df -B1 "$backup_dest" | awk 'NR==2{print $4}')

if [ "$free_space" -lt "$src_size" ]; then
	echo "Not enough space to backup on your disk."
	echo "[ $(date '+%F %T') ] Not enough space for backup" >> "$logfile"
	exit 1
fi

ignore=()
if [ -f "$ignore_file" ]; then
  ignore=( --exclude-from="$ignore_file" )
fi

echo "Enough free space executing order 67."

echo "Dry run. Using .backupignore to not include something."
tar "${ignore[@]}" -cf - -C "$(dirname "$src")" "$src_base" | tar -tvf -

read -p "Would you like to continue with backup (yes or no): " answer

if [[ "$answer" =~ ^(yes)$ ]]; then
	echo "[ $(date '+%F %T') ] BACKUP START" >> "$logfile"
	if tar -I 'zstd -19 -T0' --exclude-from="$src/.backupignore" -cf "$tempdir/$backup_file" -C "$(dirname "$src")" "$src_base" 2>/dev/null; then
		tar --exclude-from="$src/.backupignore" -czf "$tempdir/$backup_file1" -C "$(dirname "$src")" "$src_base"
		tar --exclude-from="$src/.backupignore" -cJf "$tempdir/$backup_file2" -C "$(dirname "$src")" "$src_base"
		echo "Backup completed."
	else
		echo "Backup not completed. You might not have enough permissions."
		[ -f "$tempdir/$backup_file" ] && rm -f "$tempdir/$backup_file"
		[ -f "$tempdir/$backup_file1" ] && rm -f "$tempdir/$backup_file1"
		[ -f "$tempdir/$backup_file2" ] && rm -f "$tempdir/$backup_file2"
		exit 1
	fi

	echo "First five lines of completed backup for checking: "
	tar -I 'zstd -d' -tf "$tempdir/$backup_file" | head -n 5
	echo ""
	tar -z -tf "$tempdir/$backup_file1" | head -n 5
	echo ""
	tar -J -tf "$tempdir/$backup_file2" | head -n 5
	echo ""

	echo "Size of the archives is: "
	du -h "$tempdir/$backup_file" | awk '{print $1}'
	du -h "$tempdir/$backup_file1" | awk '{print $1}'
	du -h "$tempdir/$backup_file2" | awk '{print $1}'
	echo ""

	sha256_archive="$tempdir/$backup_file"
	sha256_archive1="$tempdir/$backup_file1"
	sha256_archive2="$tempdir/$backup_file2"
	sha256sum "$sha256_archive" > "$sha256_archive.sha256"
	sha256sum "$sha256_archive1" > "$sha256_archive1.sha256"
	sha256sum "$sha256_archive2" > "$sha256_archive2.sha256"

	echo "Checking SHA256 checksum..."
	sha256sum -c "$sha256_archive.sha256"
	sha256sum -c "$sha256_archive1.sha256"
	sha256sum -c "$sha256_archive2.sha256"

	mv "$tempdir"/*.tar.* "$backup_dest"/
	mv "$tempdir"/*.sha256 "$backup_dest"/

	echo "Deleting old backups. Leaving only 3 most recent backups."
	cleanup_old_backups ".tar.zst"
	cleanup_old_backups ".tar.gz"
	cleanup_old_backups ".tar.xz"

	echo "All done!"
	echo "[ $(date '+%F %T') ] BACKUP END" >> "$logfile"
else
	echo "Backup cancelled."
	exit 1
fi
