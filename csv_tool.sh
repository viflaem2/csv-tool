#!/bin/bash
set -euo pipefail
CSV_FILE="$1"
DELIMITER=","
declare -a MATRIX=()
COLUMNS=0
while IFS=$DELIMITER read -r -a ROW_ARRAY; do
	MATRIX+=("${ROW_ARRAY[@]}")
	COLUMNS="${#ROW_ARRAY[@]}"
done < "$CSV_FILE"
#Avem fisierul csv in MATRIX ca un vector simplu
#Folosind columns il putem trata ca un matrix dupa formula i*COLUMNS+j
help(){
echo "Usage: csv_filename [OPTION]"
echo ""
echo "Options:"
echo "--help : prints the help menu"
#To add more stuff when more features are added
exit 1
}
case "${2}" in
  --help)
    help
    ;;
  *)
    echo "Invalid option: ${2}" >&2
    help
    ;;
esac
