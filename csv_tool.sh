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
echo "--where: prints every line that matches a simple condition on a column"
echo "Usage: ./csv_tool.sh csv_filename --where \"header<op>value\""
echo "Supported operators: > < >= <= == !="
echo ""
echo "--sort-by: prints lines sorted numerically by a column"
echo "Usage: ./csv_tool.sh csv_filename --sort-by header asc|desc"
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

# ---------- helper: print header + a list of row-start offsets ----------
print_rows_by_offsets(){
  # prints header
  local j
  for ((j=0;j<NUM_COLS;j++)); do
    printf "%s" "${MATRIX[j]}"
    if ((j!=NUM_COLS-1)); then printf ","; fi
  done
  printf "\n"

  # then prints each row offset passed as args
  local row_start
  for row_start in "$@"; do
    for ((j=0;j<NUM_COLS;j++)); do
      printf "%s" "${MATRIX[row_start+j]}"
      if ((j!=NUM_COLS-1)); then printf ","; fi
    done
    printf "\n"
  done
}

######
# Masquerade a fost aici : "--where"  --_--
######
where(){
  local condition_raw="$1"
  local condition="${condition_raw//[[:space:]]/}"

  local header="" op="" rhs=""
  if [[ "$condition" =~ ^([^\<\>\=\!]+)(\>\=|\<\=|\=\=|\!\=|\>|\<)(.+)$ ]]; then
    header="${BASH_REMATCH[1]}"
    op="${BASH_REMATCH[2]}"
    rhs="${BASH_REMATCH[3]}"
  else
    echo "Invalid condition: '$condition_raw' (expected like: price>100 or category==Peripherals)" >&2
    return 1
  fi

  local header_index=-1
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

  is_number() { [[ "$1" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; }

  local -a OFFSETS=()
  local row
  for ((row=NUM_COLS;row<${#MATRIX[@]};row+=NUM_COLS)); do
    local selected_value="${MATRIX[header_index+row]}"
    local match=0

    if is_number "$selected_value" && is_number "$rhs"; then
      case "$op" in
        ">")  awk -v a="$selected_value" -v b="$rhs" 'BEGIN{exit !(a>b)}'  && match=1 ;;
        "<")  awk -v a="$selected_value" -v b="$rhs" 'BEGIN{exit !(a<b)}'  && match=1 ;;
        ">=") awk -v a="$selected_value" -v b="$rhs" 'BEGIN{exit !(a>=b)}' && match=1 ;;
        "<=") awk -v a="$selected_value" -v b="$rhs" 'BEGIN{exit !(a<=b)}' && match=1 ;;
        "==") awk -v a="$selected_value" -v b="$rhs" 'BEGIN{exit !(a==b)}' && match=1 ;;
        "!=") awk -v a="$selected_value" -v b="$rhs" 'BEGIN{exit !(a!=b)}' && match=1 ;;
        *) echo "Unsupported operator '$op'" >&2; return 1 ;;
      esac
    else
      case "$op" in
        "==") [[ "$selected_value" == "$rhs" ]] && match=1 ;;
        "!=") [[ "$selected_value" != "$rhs" ]] && match=1 ;;
        *) echo "Operator '$op' requires numeric values (got '$selected_value' and '$rhs')" >&2; return 1 ;;
      esac
    fi

    if ((match==1)); then
      OFFSETS+=("$row")
    fi
  done

  print_rows_by_offsets "${OFFSETS[@]}"
}

######
# Masquerade a fost aici : "--sort-by"  :(  )
######


sort_by(){
  local header="$1"
  local direction="${2:-asc}"

  if [[ "$direction" != "asc" && "$direction" != "desc" ]]; then
    echo "Invalid sort direction '$direction' (use asc or desc)" >&2
    return 1
  fi

  local header_index=-1
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

  # Build "key<TAB>row_start_offset" lines, sort them, then print in that order
  local tmpfile
  tmpfile="$(mktemp)"
  local row
  for ((row=NUM_COLS;row<${#MATRIX[@]};row+=NUM_COLS)); do
    local key="${MATRIX[header_index+row]}"
    printf "%s\t%d\n" "$key" "$row" >> "$tmpfile"
  done

  local sort_opts="-g"
  if [[ "$direction" == "desc" ]]; then
    sort_opts="-gr"
  fi

  local -a OFFSETS=()
  local line offset
  while IFS=$'\t' read -r _key offset; do
    OFFSETS+=("$offset")
  done < <(LC_ALL=C sort $sort_opts "$tmpfile")

  rm -f "$tmpfile"

  print_rows_by_offsets "${OFFSETS[@]}"
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
  --where)
    condition=${3}
    where "$condition"
    ;;
  --sort-by)
    header=${3}
    direction=${4:-asc}
    sort_by "$header" "$direction"
    ;;
  *)
    echo "Invalid option: ${2}" >&2
    help
    ;;
esac
