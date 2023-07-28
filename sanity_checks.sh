#!/bin/bash
# NOTE: Before usage, make sure executable permission are set `chmod +x <name>.sh`

# Variable defaults
FAILED=0
OUT_FOLDER_LOKET="tmp_count_loket"
OUT_FOLDER_LPDC="tmp_count_lpdc"

LPDC_SPARQL_ENDPOINT="http://localhost:8890/sparql"
LOKET_SPARQL_ENDPOINT="http://localhost:8892/sparql"

while :; do
  case $1 in
    --lpdc-sparql-endpoint)
       if [ -z "$2" ] || [[ "$2" == -* ]]; then
        echo "[Error] --lpdc-sparql-endpoint option requires a value"
        exit 1
      fi
      LPDC_SPARQL_ENDPOINT="$2"
      shift 1
      ;;
      --loket-sparql-endpoint)
       if [ -z "$2" ] || [[ "$2" == -* ]]; then
        echo "[Error] --loket-sparql-endpoint option requires a value"
        exit 1
      fi
      LOKET_SPARQL_ENDPOINT="$2"
      shift 1
      ;;
    -?*)
      printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
      ;;
    # Default case: No more options, so break out of the loop
    *)
      break
  esac
  shift
done

mkdir -p "$OUT_FOLDER_LOKET"
rm -rf "$OUT_FOLDER_LOKET"/*

mkdir -p "$OUT_FOLDER_LPDC"
rm -rf "$OUT_FOLDER_LPDC"/*

# Store Loket and LPDC count results in a CSV file
mkdir -p "results/"
touch "./results/results.csv"
echo "type,loket_count,lpdc_count,equal" > "./results/results.csv"

for path in sanity_queries/*.sparql; do
    filename=$(basename "$path" .sparql)
    type=$(echo $filename | rev | cut -d '-' -f 1 | rev)

    # Create a folder containing a turtle file with the current timestamp
    current_date=$(date '+%Y%m%d%H%M%S')
    mkdir -p "$OUT_FOLDER_LOKET"/"$current_date-$filename"
    mkdir -p "$OUT_FOLDER_LPDC"/"$current_date-$filename"
    count_ttl_filename="$current_date-$filename.ttl"

    lpdc_type_count=0
    loket_type_count=0

    query=$(cat "$path")
    echo "[INFO] Generating lpdc count for $filename ..."
    if curl --fail -X POST "$LPDC_SPARQL_ENDPOINT" \
      -H 'Accept: text/plain' \
      --form-string "query=$query" >> "$OUT_FOLDER_LPDC"/"$current_date-$filename"/"$count_ttl_filename"; then

      echo "Count was successful!"
      lpdc_type_count=$(cat "$OUT_FOLDER_LPDC"/"$current_date-$filename"/"$count_ttl_filename" | grep value | cut -d ' ' -f 3 | awk -F'[""]' '{print $2}')
    else
      echo "[ERROR] Count for $type in LPDC failed!"
      FAILED+=1
    fi;

    echo -e "\n"

    echo "[INFO] Generating loket count for $filename ..."
    if curl --fail -X POST "$LOKET_SPARQL_ENDPOINT" \
      -H 'Accept: text/plain' \
      --form-string "query=$query" >> "$OUT_FOLDER_LOKET"/"$current_date-$filename"/"$count_ttl_filename"; then

      echo "Count was successful!"
      loket_type_count=$(cat "$OUT_FOLDER_LOKET"/"$current_date-$filename"/"$count_ttl_filename" | grep value | cut -d ' ' -f 3 | awk -F'[""]' '{print $2}')
    else
      echo "[ERROR] Count for $type in Loket failed!"
      FAILED+=1
    fi;

    if [ $lpdc_type_count == $loket_type_count ]; then
      echo "$type,$loket_type_count,$lpdc_type_count,✅" >> "./results/results.csv"
    else
      echo "$type,$loket_type_count,$lpdc_type_count,❌" >> "./results/results.csv"
    fi;

    echo -e "================================================================================\n"
done

echo "[INFO] Export done! You can find your count export(s) in $OUT_FOLDER_LOKET and $OUT_FOLDER_LPDC."
echo "[INFO] Count results are in results/results.csv"

if ((FAILED > 0)); then
  echo "[WARNING] $FAILED queries failed, export incomplete ..."
fi;