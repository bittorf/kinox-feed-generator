#!/bin/sh
#
# TODO: check dependencies: POSIX-sh, wget, git, recode, imdbpy
# TODO: erscheinungsjahr/monat
# TODO: remove 'search' function
# TODO: Link zur Kritik? Wikipedia? Extract text...
# TODO: new = last entry unknown or older than 30 days?
# TODO: ohne beschreibung: http://kinox.to/Stream/The_Nesting.html
# TODO: change imdb-language? (for plot)
# http://webapps.stackexchange.com/questions/11003/how-can-i-disable-reconfigure-imdbs-automatic-geo-location-so-it-does-not-defau

ARG1="$1"		# e.g. '--cron' or 'Alien' -> search specific entry

URL='http://kinox.to'
DB='database.txt'
I=0
NEW=0

IMDBPY_GETMOVIE="$( command -v 'get_movie.py' )" || {
	echo "please install 'http://imdbpy.sourceforge.net/' and set maybe:"
	echo "e.g. export PATH=\"\$PATH:/home/bastian/software/imdbpy/bin"
	echo
	echo "hints:"
	echo "sudo apt-get install python-pip"
	echo "sudo pip install IMDbPY"

	exit 1
}

case "$ARG1" in
	'--cron')
		while :; do git pull; ./"$0" ; git push; git gc; date; sleep 7200; done
	;;
	'--news')
		for HASH in $( git log --oneline | grep 'Rating: [8-9]' | grep -v 'html,s' | cut -d' ' -f1 ); do git show --name-only "$HASH"; done | less
	;;
esac

# works best with v1.15+ (needed when http is redirected to https
WGET='wget --user-agent=AmigaVoyager --content-on-error --no-check-certificate'

kinox_description_get()
{
	local url="$1"

	$WGET -O - "$url" | grep ^'<div class="Descriptore">' | sed 's/<[^>]*>//g' | fold -w 80 -s
}

kinox_imdb_link_get()
{
	local url="$1"

	# <tr> <td class="Label" nowrap>IMDb Wertung:</td> <td class="Value"><div class="IMDBRatingOuter" onclick="runPopup('http://www.imdb.com/title/tt4061908/', '', '_blank');"><div class="IMDBRatinInner" style="width: 82px"></div></div><div class="IMDBRatingLabel">4.1 / 10 :: 0 Votes <div class="IMDBRatingLinks"><a href="/tt4061908">&nbsp;</a></div></div> </td></tr><tr> <td class="Label" nowrap>Genre:</td> <td class="Value"><a href="/Genre/Crime">Krimi</a> </td></tr><tr> <td class="Label" nowrap>Produzent:</td> <td class="Value">Ken Brown</td></tr>
	$WGET -O - "$url" | grep 'IMDb Wertung' | sed -n "s|.*'\(http://www.imdb.com.*\)'.*|\1|p" | cut -d"'" -f1
}

imdb_get_rating()
{
	local link="$1"		# e.g. http://www.imdb.com/title/tt4061908/
	local id word
	local list="$( echo "$link" | tr '/' ' ' )"

	for word in $list; do {
		case "$word" in
			'tt'[0-9]*)
				id="$( echo "$word" | cut -b3- )"
			;;
		esac
	} done

	# e.g. 'Rating: 7.7 (148196 votes).'
	$IMDBPY_GETMOVIE "$id" | grep ^'Rating: ' || {
		imdb_getmovie_rating "$link" | grep ^'Rating: ' || {
			echo 'Rating: ?'
		}
	}
}

imdb_getmovie_rating()
{
	local link="$1"

	$WGET -O - "$link" | sed -n 's|.*span itemprop="ratingValue">\([0-9\.]*\)</span>.*|Rating: \1|p'
}

underliner()
{
	local string="$1"
	local out=
	local i=0

	while [ $i -lt ${#string} ]; do out="$out="; i=$(( i + 1 )); done
	printf '%s\n' "$out"
}

# TODO: search
# http://kinox.to/Search.html?q=Spiderwick
# <td class="Title"><a href="/Stream/Die_Geheimnisse_der_Spiderwicks.html" onclick="return false;">Die Geheimnisse der Spiderwicks</a> <span class="Year">2008</span></td>

PATTERN='<td class="Title img_preview" rel='
{ $WGET -O - "$URL" || logger -s "[ERROR:$?] $WGET -O - '$URL'"; printf '\n%s' "$PATTERN - EOF"; } |
 grep ^"$PATTERN" | recode 'UTF8..ISO-8859-15' | while read -r LINE; do {
	LINK=
	TITLE=
	PARSE_TITLE=
	[ "$LINE" = "$PATTERN - EOF" ] && logger -s "[OK] examined $I titles / $NEW are new"

	# ... <a href="/Stream/Die_Schoene_und_das_Biest_2017.html" title="Die Schöne und das Biest 2017" class= ...
	# ... <a href="/Stream/Masters_of_Horror_The_Black_Cat.html" title=""Masters of Horror" The Black Cat" class= ...
	# ... <a href="/Stream/Fortitude.html,s2e5" title="Fortitude" class= ...
	for WORD in $LINE; do {
		case "$WORD" in
			'href="'*)
				I=$(( I + 1 ))
				LINK="$( echo "$WORD" | cut -d'"' -f2 )"
			;;
			'title="'*)
				PARSE_TITLE='true'
			;;
		esac

		[ -n "$PARSE_TITLE" ] && {
			case "$WORD" in
				'class='*)
					PRINT='true'

					[ -n "$ARG1" ] && {
						echo "$TITLE $LINK" | grep -qi "$ARG1" || PRINT=
					}

					[ -n "$PRINT" ] && {
						case "$TITLE" in *'"') TITLE="${TITLE%?}" ;; esac	# remove last char

						case "$LINK" in
							*'.html,s'*)
								SEASON="$( echo "$LINK" | cut -d',' -f2 )"
								printf '%s' "# Serie: $TITLE ($SEASON) - "
								TITLE_PRE='Serie: '
								TITLE_POST=" ($SEASON)"
							;;
							*)
								TITLE_PRE=
								TITLE_POST=
								printf '%s' "# $TITLE - "
							;;
						esac

						grep -sq " - $LINK - " "$DB" || {
							NEW=$(( NEW + 1 ))
							echo "$( LC_ALL=C date +%s ) - $( LC_ALL=C date ) - $LINK - $TITLE" >>"$DB"
							git add "$DB"

							RC_ERROR404=8
							$WGET -qO /dev/null "${URL}${LINK}"
							[ $? -eq $RC_ERROR404 ] && {
								# auto-correct wrong 'Serie'-detection
								LINK="$( echo "$LINK" | sed -n 's/\(^.*\.html\),s.*$/\1/p' )"
								TITLE_PRE=
								TITLE_POST=
							}

							IMDB_LINK="$( kinox_imdb_link_get "${URL}${LINK}" )"
							IMDB_RATE="$( imdb_get_rating "$IMDB_LINK" )"
							IMDB_RATE="IMDB: $IMDB_RATE $IMDB_LINK"
							DESCRIPTION="$( kinox_description_get "${URL}${LINK}" )"
							[ "$DESCRIPTION" = 'Keine Beschreibung vorhanden' ] && DESCRIPTION=

							git commit -m "
${URL}${LINK}
$IMDB_RATE

${TITLE_PRE}${TITLE}${TITLE_POST}
$( underliner "${TITLE_PRE}${TITLE}${TITLE_POST}" )
${DESCRIPTION:-...}"
						}

						echo "Link: ${URL}${LINK}"
					}

					break
				;;
				'title='*)
					# first word
					TITLE="$( echo "$WORD" | cut -b8- )"
				;;
				*)
					TITLE="${TITLE}${TITLE:+ }${WORD}"
				;;
			esac
		}
	} done
} done
