#!/bin/bash

search_url="https://anime-sama.fr/template-php/defaut/fetch.php"
base_url="https://anime-sama.fr/catalogue/"
echo "Please enter the anime name: "
read anime_name

curl -sL "$search_url" --compressed -X POST -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/116.0' -H 'Accept: */*' -H 'Accept-Language: tlh,en-US;q=0.8,fr-FR;q=0.5,en;q=0.3' -H 'Accept-Encoding: gzip, deflate, br' -H 'Referer: https://anime-sama.fr/' -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' -H 'X-Requested-With: XMLHttpRequest' -H 'Origin: https://anime-sama.fr' -H 'DNT: 1' -H 'Connection: keep-alive' -H 'Cookie: accepted_cookies=yes' -H 'Sec-Fetch-Dest: empty' -H 'Sec-Fetch-Mode: cors' -H 'Sec-Fetch-Site: same-origin' -H 'TE: trailers' --data-raw "query=$anime_name" > anime.html


grep -oP '(?<=href=")[^"]*' anime.html > anime_links.txt # extract all links from anime.html and put them in anime_links.txt

anime_link=$(cat anime_links.txt | fzf)

echo "Anime name: $anime_link"

curl -sL "$anime_link" > anime_page.html


url=$(grep -o 'panneauAnime(".*"' anime_page.html | cut -d'"' -f4 | fzf) # extract all url from anime_page.html and put them in anime_links.txt

curl -sL "$anime_link$url" > anime_episodes.html

id=$(grep -oP '(?<=filever=)\d*' anime_episodes.html)
if [ -z "$id" ]
then
    echo "No id found"
    exit 1
fi


# make a request https://anime-sama.fr/catalogue/naruto/saison1/vostfr/episodes.js?filever=12838 to get the json file
url="$anime_link$url/episodes.js?filever=$id"
wget -q "$url" -O anime.js

links=($(grep -oP '(?<=sibnet.ru/)[^"]*' anime.js)) # extract all links from anime.js and put them in links array


link=$(printf '%s\n' "${links[@]}" | fzf --layout=reverse)

link=$(echo $link | tr -d "'")
link="https://video.sibnet.ru/$link"
mpv "$link"