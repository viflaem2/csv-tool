#!/bin/bash
set -euo pipefail
CSV_FILE="$1"
DELIMITER=","
declare -a MATRIX=()
NUM_COLS=0
while IFS=$DELIMITER read -r -a ROW_ARRAY; do
	MATRIX+=("${ROW_ARRAY[@]}")
	NUM_COLS="${#ROW_ARRAY[@]}"
done < "$CSV_FILE"
#Avem fisierul csv in MATRIX ca un vector simplu
#Folosind columns il putem trata ca un matrix dupa formula i*NUM_COLS+j

help(){
echo "Usage: ./csv_tool.sh csv_filename [OPTION]"
echo ""
echo "Options:"
echo "--help : prints the help menu"
echo ""
echo "--remove: removes every line where value matches header"
echo "Usage: ./csv_tool.sh csv_filename --remove header value"
echo "Output will be saved in csv_filename, backup will be automatically saved in csv_filename.old"
echo ""
#To add more stuff when more features are added
exit 1
}

remove(){
local header="$1"
local value="$2"
local header_index=-1;
local i
for ((i=0;i<=NUM_COLS-1;i++)); do
  if [[ "${MATRIX[$i]}" == "$header" ]]; then
    header_index=$i
    break
  fi
done
if ((header_index==-1)); then
  echo "header '$header' does not exist" >&2
  return 1
fi
local obs=0
local MATRIX_UPDATED=("${MATRIX[@]:0:NUM_COLS}")
local row
for ((row=NUM_COLS;row<${#MATRIX[@]};row+=NUM_COLS)); do
  local selected_value="${MATRIX[header_index+row]}"
  if [[ "$selected_value" == "$value" ]]; then
    ((obs+=1))
    continue
  fi
  MATRIX_UPDATED+=("${MATRIX[@]:row:NUM_COLS}")
done
if ((obs==0)); then
  echo "Warning: No occurrence of $value has been found in column $header" >&2
  return 0
fi
MATRIX=("${MATRIX_UPDATED[@]}")
echo "Removed $obs occurences of value $value in column $header"
return 0
}

save_csv(){
  mv "$CSV_FILE" "$CSV_FILE".old
  touch "$CSV_FILE"
  for ((i=0;i<${#MATRIX[@]}/NUM_COLS;i++)); do
    for ((j=0;j<=NUM_COLS-1;j++)); do
      echo -n "${MATRIX[i*NUM_COLS+j]}" >> "$CSV_FILE"
      if ((j!=NUM_COLS-1)); then
        echo -n "," >> "$CSV_FILE"
      fi
    done
    echo "" >> "$CSV_FILE"
  done
}

case "${2}" in
  --help)
    help
    ;;
  --remove)
    header=${3}
    value=${4}
    remove "$header" "$value"
    save_csv
    ;;
  *)
    echo "Invalid option: ${2}" >&2
    help
    ;;
esac
