#!/usr/bin/env bash

shopt -s nullglob
files=(*\ *)
shopt -u nullglob

if [ ${#files[@]} -eq 0 ]; then
    echo "No files with spaces found in this directory."
    exit 0
fi

echo "The following files will be renamed:"
for f in "${files[@]}"; do
    echo "  '$f'  ->  '${f// /-}'"
done

echo ""

read -p "Do you want to proceed with renaming? (y/n): " confirm

if [[ "$confirm" =~ ^[Yy](es)?$ ]]; then
    for f in "${files[@]}"; do
        mv "$f" "${f// /-}"
    done
    echo "Done! Files have been renamed."
else
    echo "Operation cancelled. Nothing was changed."
fi
