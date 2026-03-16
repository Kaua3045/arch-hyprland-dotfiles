#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="$HOME/.config/waybar/scripts/weather.env"
source "$ENV_FILE"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-weather"
mkdir -p "$CACHE_DIR"

GEO_JSON="$CACHE_DIR/geo.json"
WX_JSON="$CACHE_DIR/weather.json"

# cache simples
GEO_TTL=86400
WX_TTL=900

now=$(date +%s)

need_geo=1
if [[ -f "$GEO_JSON" ]]; then
  mtime=$(stat -c %Y "$GEO_JSON" 2>/dev/null || echo 0)
  if (( now - mtime < GEO_TTL )); then
    need_geo=0
  fi
fi

if (( need_geo == 1 )); then
  curl -fsS "https://geocoding-api.open-meteo.com/v1/search?name=${WEATHER_POSTAL_CODE}&count=1&language=pt&format=json&countryCode=${WEATHER_COUNTRY_CODE}" > "$GEO_JSON"
fi

lat=$(jq -r '.results[0].latitude // empty' "$GEO_JSON")
lon=$(jq -r '.results[0].longitude // empty' "$GEO_JSON")
city=$(jq -r '.results[0].name // "Local"' "$GEO_JSON")
admin1=$(jq -r '.results[0].admin1 // ""' "$GEO_JSON")

if [[ -z "${lat}" || -z "${lon}" ]]; then
  echo '{"text":"󰖐 N/A","tooltip":"Não foi possível localizar o CEP"}'
  exit 0
fi

need_wx=1
if [[ -f "$WX_JSON" ]]; then
  mtime=$(stat -c %Y "$WX_JSON" 2>/dev/null || echo 0)
  if (( now - mtime < WX_TTL )); then
    need_wx=0
  fi
fi

if (( need_wx == 1 )); then
  curl -fsS "https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&timezone=auto&current=temperature_2m,apparent_temperature,is_day,weather_code,precipitation,rain,showers,snowfall&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&forecast_days=7" > "$WX_JSON"
fi

timezone=$(jq -r '.timezone // "UTC"' "$WX_JSON")
temp=$(jq -r '.current.temperature_2m | floor' "$WX_JSON")
feels=$(jq -r '.current.apparent_temperature | floor' "$WX_JSON")
is_day=$(jq -r '.current.is_day // 1' "$WX_JSON")
code=$(jq -r '.current.weather_code // -1' "$WX_JSON")

precip=$(jq -r '.current.precipitation // 0' "$WX_JSON")
rain=$(jq -r '.current.rain // 0' "$WX_JSON")
showers=$(jq -r '.current.showers // 0' "$WX_JSON")
snowfall=$(jq -r '.current.snowfall // 0' "$WX_JSON")

weather_icon() {
  local code="$1"
  local is_day="$2"
  local precip="$3"
  local rain="$4"
  local showers="$5"
  local snowfall="$6"

  # primeiro prioriza precipitação real agora
  awk_check=$(awk -v p="$precip" -v r="$rain" -v s="$showers" -v sn="$snowfall" 'BEGIN { if (p>0 || r>0 || s>0 || sn>0) print 1; else print 0 }')
  if [[ "$awk_check" == "1" ]]; then
    if awk -v sn="$snowfall" 'BEGIN { exit !(sn>0) }'; then
      echo "󰼶"   # neve
      return
    fi
    echo "󰖗"     # chuva agora
    return
  fi

  case "$code" in
    0)   [[ "$is_day" == "1" ]] && echo "󰖙" || echo "󰖔" ;; # limpo
    1|2) [[ "$is_day" == "1" ]] && echo "󰖕" || echo "󰼱" ;; # principalmente limpo/parcial
    3)   echo "󰖐" ;;                                       # nublado
    45|48) echo "󰖑" ;;                                    # neblina
    51|53|55|56|57) echo "󰖖" ;;                           # garoa
    61|63|65|66|67|80|81|82) echo "󰖗" ;;                 # chuva
    71|73|75|77|85|86) echo "󰼶" ;;                       # neve
    95|96|99) echo "󰖓" ;;                                # trovoada
    *) echo "󰖐" ;;
  esac
}

weather_desc_pt() {
  local code="$1"
  local is_day="$2"
  case "$code" in
    0)   [[ "$is_day" == "1" ]] && echo "Céu limpo" || echo "Céu limpo à noite" ;;
    1)   echo "Predominantemente limpo" ;;
    2)   echo "Parcialmente nublado" ;;
    3)   echo "Nublado" ;;
    45|48) echo "Neblina" ;;
    51|53|55|56|57) echo "Garoa" ;;
    61|63|65|66|67|80|81|82) echo "Chuva" ;;
    71|73|75|77|85|86) echo "Neve" ;;
    95|96|99) echo "Trovoada" ;;
    *) echo "Tempo indefinido" ;;
  esac
}

icon=$(weather_icon "$code" "$is_day" "$precip" "$rain" "$showers" "$snowfall")
desc=$(weather_desc_pt "$code" "$is_day")

# se estiver precipitando agora, forçamos a descrição
if awk -v p="$precip" -v r="$rain" -v s="$showers" -v sn="$snowfall" 'BEGIN { exit !(p>0 || r>0 || s>0 || sn>0) }'; then
  if awk -v sn="$snowfall" 'BEGIN { exit !(sn>0) }'; then
    desc="Nevando agora"
  else
    desc="Chovendo agora"
  fi
fi

tooltip_header="${city}"
if [[ -n "$admin1" && "$admin1" != "null" ]]; then
  tooltip_header="${city}, ${admin1}"
fi

# tooltip de 7 dias
daily_lines=$(
  jq -r --arg tz "$timezone" '
    .daily.time as $t
    | .daily.weather_code as $c
    | .daily.temperature_2m_min as $min
    | .daily.temperature_2m_max as $max
    | .daily.precipitation_probability_max as $pp
    | [range(0; ($t|length))] 
    | .[]
    | "\($t[.])|\($c[.])|\($min[.])|\($max[.])|\($pp[.])"
  ' "$WX_JSON" | while IFS='|' read -r day code_d min_d max_d pp_d; do
      # ícone diário simples
      case "$code_d" in
        0) icon_d="󰖙" ;;
        1|2) icon_d="󰖕" ;;
        3) icon_d="󰖐" ;;
        45|48) icon_d="󰖑" ;;
        51|53|55|56|57) icon_d="󰖖" ;;
        61|63|65|66|67|80|81|82) icon_d="󰖗" ;;
        71|73|75|77|85|86) icon_d="󰼶" ;;
        95|96|99) icon_d="󰖓" ;;
        *) icon_d="󰖐" ;;
      esac

      day_fmt=$(TZ="$timezone" date -d "$day" "+%a %d/%m")
      printf "%s  %s  %s°/%s°  %s%%\n" "$day_fmt" "$icon_d" "$min_d" "$max_d" "$pp_d"
    done
)

tooltip=$(printf "%s\n%s  %s°  sensação %s°\n\n%s" "$tooltip_header" "$desc" "$temp" "$feels" "$daily_lines")

jq -cn \
  --arg text "$icon ${temp}°" \
  --arg tooltip "$tooltip" \
  '{text:$text, tooltip:$tooltip}'
