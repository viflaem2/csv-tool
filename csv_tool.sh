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

# We have the csv file in a MATRIX as a simple vector
# Using columns we can treat it as a MATRIX using the formula i * NUM_COLS + j

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
echo "--validate: it 'validates' the csv file by associating to every available collumn a corresponding indice,"
echo "as to let the user know which of the collumns will be available for processing with the other arguments."
echo "Usage: ./csv_tool.sh csv_filename --validate."
echo "Output will contain the validated collumns."
echo ""
echo "--select: outputs selected columns given by the user through a variable."
echo "Usage: ./csv_tool.sh csv_filename --select "column1,column2"."
echo "Output will be the whole selected columns or an error if any of the columns could not be found."
echo ""
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

validate() {
  ## This function is used to check if a csv file is 'valid' or not by printing the columns and associated indexes.
  IFS=$DELIMITER read -r -a HEADER < "$CSV_FILE"

  # Here we print column index and name
  for i in "${!HEADER[@]}"; do
    echo "$i: ${HEADER[$i]}"
  done
}

get_column_index() {
  ## This helper function is used to search for a given collumn by name. It is used inside the function 'select_columns'
  local col_name="$1"
  local i

  for i in "${!HEADER[@]}"; do
    if [[ "${HEADER[$i]}" == "$col_name" ]]; then
      echo "$i"
      return 0
    fi
  done

  # Return 1 if the column was not found
  return 1
}

select_columns() {
  local cols_string="$1"
  # Edge case if the user gives an empty variable.
  if [[ "$cols_string" == "" ]]; then
    return 0
  fi

  IFS=$DELIMITER read -r -a HEADER < "$CSV_FILE"

  # We split the requested columns.
  IFS=',' read -r -a REQ_COLS <<< "$cols_string"

  # We find the indices for the requested columns.
  SELECTED_INDICES=()
  for col in "${REQ_COLS[@]}"; do
    idx=$(get_column_index "$col") || {
      echo "Error: column '$col' not found" >&2 # Error in case the column is not found.
      exit 1
    }
    SELECTED_INDICES+=("$idx") # We store the found indices.
  done

  # We print the header
  for idx in "${SELECTED_INDICES[@]}"; do
    printf "| %s " "${HEADER[$idx]}"
  done
  echo "|"

  # We print the rows according to the indices we found previously.
  tail -n +2 "$CSV_FILE" | while IFS=$DELIMITER read -r -a ROW; do
    for idx in "${SELECTED_INDICES[@]}"; do
      printf "| %s " "${ROW[$idx]}"
    done
    echo "|"
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
  --validate)
    validate
    ;;
  --select)
    select_columns "$3"
    ;;
  *)
    echo "Invalid option: ${2}" >&2
    help
    ;;
esac
