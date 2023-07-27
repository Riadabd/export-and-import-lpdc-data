#!/bin/bash
# NOTE: Before usage, make sure executable permission are set `chmod +x <name>.sh`

# Variable defaults
FAILED=0
OUT_FOLDER_LOKET="tmp_count_loket/"
OUT_FOLDER_LPDC="tmp_count_lpdc/"

LPDC_SPARQL_ENDPOINT="http://localhost:8890/sparql"

WRITE_TEMP_GRAPH=false

while :; do
  case $1 in
    --lpdc-sparql-endpoint)
       if [ -z "$2" ] || [[ "$2" == -* ]]; then
        echo "[Error] --sparql-endpoint option requires a value"
        exit 1
      fi
      LPDC_SPARQL_ENDPOINT="$2"
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

for path in sanity_queries/*.sparql; do
    filename=$(basename "$path" .sparql)

    # Create a turtle file and its corresponding graph with the current timestamp
    current_date=$(date '+%Y%m%d%H%M%S')
    mkdir -p "$OUT_FOLDER_LOKET"/"$current_date-$filename"
    count_ttl_filename="$current_date-$filename.ttl"
    count_graph_filename="$current_date-$filename.graph"

    query=$(cat "$path")
    echo "[INFO] Generating count for $filename ..."
    if curl --fail -X POST "$LPDC_SPARQL_ENDPOINT" \
      -H 'Accept: text/plain' \
      --form-string "query=$query" >> "$OUT_FOLDER_LOKET"/"$current_date-$filename"/"$count_ttl_filename"; then

      echo "Count was successful!"
      count=$(cat "$OUT_FOLDER_LOKET"/"$current_date-$filename"/"$count_ttl_filename" | grep value | cut -d ' ' -f 3 | awk -F'[""]' '{print $2}')
      echo "Count is $count"
    else
      echo "[ERROR] Count for $filename failed!"
      FAILED+=1
    fi;

    echo -e "================================================================================\n"
done

echo "[INFO] Export done! You can find your count export(s) in $OUT_FOLDER_LOKET and $OUT_FOLDER_LPDC."

if ((FAILED > 0)); then
  echo "[WARNING] $FAILED queries failed, export incomplete ..."
fi;