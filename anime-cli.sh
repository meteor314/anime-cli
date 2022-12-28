#!/bin/bash
# scrape data from toonaime.com and play anime in mpv
# requires: mpv, curl, jq, youtub-dl, (fzf for interactive mode is optional)
# usage: anime-cli.sh [anime name] [episode number]
# example: anime-cli.sh "one piece" 1
# for download only: anime-cli.sh "one piece" 1 -d

##########
# Config #
##########
cache_dir="$HOME/.cache/anime-cli"
version="1.0.1"
logo="logo.png"
github_source="https://raw.githubusercontent.com/meteor314/anime-cli/master/anime.cli.sh"
######€€€#
# colors #
##########

color_yellow(){
  echo -e "\e[33m$1\e[0m"
}

color_red(){
  echo -e "\e[31m$1\e[0m"
}

color_green(){
  echo -e "\e[32m$1\e[0m"
}

color_blue(){
  echo -e "\e[34m$1\e[0m"
}
no_color() {
  echo -e "$1"
}

######################
# Auxilary functions #
######################

show_help() {
	while IFS= read -r line; do
		printf "%s\n" "${line}"
	done <<-EOF
	
    anime-cli ${version} ( github.com/meteor314/anime-cli ). Bash script for  watch anime via terminal
	Usage:
	  anime-cli [Options]
	Options:
	  -h, --help		Print this help page
	  -V, --version		Print version number
	  -u, --update		Fetch latest version from the Github repository
	  -c, --cache-size	Print cache size (${cache_dir})
	  -C, --clear-cache	Clear cache (${cache_dir})
	  -d, --download	Download only (example usage: anime-cli "one piece" -d )
	  -v, ---vlc        Use vlc instead of mpv
	  -f, --fzf         Use fzf for interactive mode
	EOF
}

check_dependencies() 
{
    for i in "$@"; do
        if ! command -v "$i" &> /dev/null; then
            echo "$i could not be found"
            exit
        fi
    done
}

welcome_msg() {
	while IFS= read -r line; do
		printf "%s\n" "${line}"
	done <<-EOF
	anime-cli ${version}
	It seems like you are using anime-cli for the first time.
	Please try anime-cli -h for help and another options.
	EOF
}

show_version() {
	color_green "Version: ${version}"
}


show_cache_size() {
	cache_size="$(du -sh "${cache_dir}" | awk '{print $1}')"
	color_green "Cache size: ${cache_size} (${cache_dir})"
}

clear_cache() {
	show_cache_size
	prompt "Proceed with clearing the cache?" "[Y/N]: "
	# Convert user input to lowercase
	user_input="$(printf "%s" "${reply}" | tr "[:upper:]" "[:lower:]")"
	if [[ "${user_input}" == "y" ]]; then
		rm -r "${cache_dir:?}/"
		color_green "Cache successfully cleared"
	fi
}


create_cache_folder() {
	# If cache_dir does not exist, create it
	if [[ ! -d "${cache_dir}" ]]; then
		welcome_msg
		mkdir --parents "${cache_dir}"
	fi
	
	cd ${cache_dir}
	if [[ ! -f "${logo}" ]];then
		curl --silent -o logo.png "https://raw.githubusercontent.com/meteor314/anime-cli/master/src/anime-cli.png"
	fi
}
create_cache_folder
#################
# Update Script #
#################

update_script() {
	color_green "Fetching Github repository..."
	# Get latest source code and compare it with this script
	changes="$(curl --silent "${github_source}" | diff -u "${0}" -)"
	if [[ -z "${changes}" ]]; then # If variable 'changes' is empty 
		color_green "Script is up to date"
	else
		if printf '%s\n' "${changes}" | patch --silent "${0}" -; then
		    color_green "Script successfully updated"
		else
			color_red "ERROR: Something went wrong"
		fi
	fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            show_help
            exit
            ;;
        -V | --version)
            show_version
            exit
            ;;
        -u | --update)
            update_script
            exit
            ;;
        -c | --cache-size)
            show_cache_size
            exit
            ;;
        -C | --clear-cache)
            clear_cache
            exit
            ;;
        -d | --download)
            download_only=true
            shift
            ;;
        -v | --vlc)
            player="vlc"
            shift
            ;;
        -f | --fzf)
            fzf=true
            shift
            ;;
        *)
            break
            ;;
    esac
    shift
done

check_dependencies curl jq mpv youtube-dl wget
anime_name=""
if [ -z "$1" ]; then
   while [ ${#anime_name} -lt 4 ]; do
     read -p "Enter anime name (at least 4 charactars long!): " anime_name
   done
    # encode spaces
    anime_name=${anime_name// /+}
else
    anime_name="$1"
fi 
url="https://wvvw.toonanime.cc/?story=$anime_name&do=search&subaction=search"

curl -sL "$url" | grep -o "https://wvvw.toonanime.cc/[^.]*.html" | sort -u > anime_list.txt

if [ ! -s anime_list.txt ]; then
    color_red "No anime found"
    exit
fi

anime_list=$(cat anime_list.txt | sed 's/https:\/\/wvvw.toonanime.cc\///g' | sed 's/.html//g' | sed 's/-/ /g' |  nl -s  ") ")
if [ -z "$1" ]; then
    color_yellow "Anime list:"
    echo "$anime_list" 
    read -p "Enter anime number: " anime_number
else
    anime_number=1
fi
anime_url=$(cat anime_list.txt | sed -n "$anime_number"p)
anime_id=$(echo "$anime_url" | grep -o "[0-9]*")

(wget -qO- "https://wvvw.toonanime.cc/engine/ajax/full-story.php?newsId=$anime_id" | jq -r '.html') > episodes.html

episode_list=$(cat episodes.html | grep -o "title=\"[^\"]*\"" | grep -o "Episode" | sed 's/title="//g' | sed 's/"//g' | nl -s  ") ")

number_of_episodes=$(echo "$episode_list" | wc -l)

episode_number=1
episode_url=$(cat episodes.html | grep -o "https://wvvw.toonanime.cc/[^.]*.html" | sed -n "$episode_number"p)

curl -sL "$episode_url" > tmp.html

data_server_id=$(cat tmp.html | grep -o "data-server-id=\"[^\"]*\"" | grep -o "[0-9]*")

player_box=$(cat episodes.html | grep -o "content_player_[0-9]*" | grep -f data_server_id.txt)

echo "$player_box" > player_box.txt
echo "" > player_box.html
cat episodes.html | grep -o "content_player_[0-9]*" | grep -f player_box.txt | while read -r line; do
    cat episodes.html | grep -o "<div id=\"$line\" class=\"player_box\">.*</div>" >> player_box.html
done

video_id=$(cat player_box.html | grep -o ">[0-9]*<" | sed 's/>//g' | sed 's/<//g' | sed 's/ //g')
echo "$video_id" > video_id.txt
sed -i '/^$/d' video_id.txt

color_blue "Processing video links, please wait..."
while read -r line; do
    if ! grep -q "$line" video_id.txt; then
        echo "$line" >> video_id.txt
    fi
done < video_id.txt

if [ -z "$2" ]; then
    echo "Chose an episode beetween 1 -" $number_of_episodes
    read -p "Enter episode number: " episode_number
else
    episode_number="$2"
fi

video_id=$(cat video_id.txt | sed -n "$episode_number"p)
sib_url="https://video.sibnet.ru/shell.php?videoid=$video_id"

shift
download_video() {
    episode_number="$1"
    # extract  videon number  example :  1-3,  means  1st video of 3 videos, if number do not separted by - then it is the only video
    video_number=$(echo "$episode_number" | grep -o "[0-9]*-[0-9]*" | grep -o "[0-9]*" | sed -n 1p)
  
    cd ~/Downloads
    curl -L "$sib_url" -o "$anime_name-$episode_number.mp4"
}

# n for next episode
# p for previous episode
# d for download episode
# q for quit
# r for replay episode

if [ "$download_only" = true ]; then
    download_video "$episode_number"
    exit
fi

if [ "$fzf" = true ]; then
    episode_number=$(echo "$episode_list" | fzf --height 40% --layout=reverse --border --reverse --cycle --preview "curl -sL $sib_url | grep -o 'https://video.sibnet.ru/sys/player/[^.]*.mp4' | xargs -I {} mpv {} --no-audio --no-video --frames=1 --vo=null --ao=null --screenshot-format=jpg --screenshot-template=preview.jpg --screenshot-directory=/tmp/ && feh /tmp/preview.jpg")
fi

if [ "$download_only" =  false]; then
  $player "$sib_url" "$@"
fi

color_blue " press n for next episode
       enter p for previous episode
       enter d for download episode
       enter q for quit
       enter r for replay episode.
       "

while true; do
  color_yellow "Playing episode $episode_number, please wait..."
  read -rsn1 input
  if [ "$input" = "q" ]; then
    break
  fi
  if [ "$input" = "n" ]; then
    episode_number=$((episode_number + 1))
    if [ "$episode_number" -gt "$number_of_episodes" ]; then
        episode_number=1
    fi
  fi
  if [ "$input" = "p" ]; then
    episode_number=$((episode_number - 1))
    if [ "$episode_number" -lt 1 ]; then
        episode_number=$number_of_episodes
    fi
  fi
  if [ "$input" = "d" ]; then
    download_video "$episode_number"
  fi
  if [ "$input" = "r" ]; then
    episode_number=$((episode_number))
  fi
  episode=$(cat video_id.txt | sed -n "$episode_number"p)
  sib_url="https://video.sibnet.ru/shell.php?videoid=$episode"
  mpv "$sib_url" "$@"
done

