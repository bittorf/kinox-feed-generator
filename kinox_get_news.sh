#!/bin/sh

ARG1="$1"		# e.g. '--cron' or 'Alient' -> search specific entry
URL='http://kinox.to'
DB='database.txt'
I=0
NEW=0

[ "$ARG1" = '--cron' ] && while :; do git pull; ./$0 ; git push; date; sleep $(( 2 * 3600 )); done

# TODO: new = last entry unknown or older than 30 days?
# TODO: imdb-link: http://kinox.to/Stream/The_Hateful_Eight-1.html
# TODO: ohne beschreibung: http://kinox.to/Stream/The_Nesting.html

kinox_description_get()
{
	local url="$1"

	wget -O - "$url" | grep ^'<div class="Descriptore">' | sed 's/<[^>]*>//g' | fold -w 80 -s
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
{ wget -qO - "$URL" || logger -s "[ERROR:$?] wget '$URL'"; printf '\n%s' "$PATTERN - EOF"; } | grep ^"$PATTERN" | while read -r LINE; do {
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

							IMDB_RATE="rated 7.6/10 (8757 persons) http://link_imdb"
							IMDB_RATE="rated ?/10"
							DESCRIPTION="$( kinox_description_get "${URL}${LINK}" )"
							[ "$DESCRIPTION" = 'Keine Beschreibung vorhanden' ] && DESCRIPTION='...'

							git commit -m "
${URL}${LINK}
IMDB: $IMDB_RATE

${TITLE_PRE}${TITLE}${TITLE_POST}
$( underliner "${TITLE_PRE}${TITLE}${TITLE_POST}" )
$DESCRIPTION"
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
