#!/bin/sh

# for autoadd new entries to git run: while :; do ./kinox_get_news.sh ;sleep 900; done

ARG1="$1"		# e.g. 'Alient' -> search specific entry
URL='http://kinox.to'
DB='database.txt'
I=0

# TODO: search
# http://kinox.to/Search.html?q=Spiderwick
# <td class="Title"><a href="/Stream/Die_Geheimnisse_der_Spiderwicks.html" onclick="return false;">Die Geheimnisse der Spiderwicks</a> <span class="Year">2008</span></td>

PATTERN='<td class="Title img_preview" rel='
{ wget -qO - "$URL" || logger -s "[ERROR:$?] wget '$URL'"; printf '\n%s' "$PATTERN - EOF"; } | grep ^"$PATTERN" | while read -r LINE; do {
	LINK=
	TITLE=
	PARSE_TITLE=
	[ "$LINE" = "$PATTERN - EOF" ] && logger -s "[OK] examined $I titles"

	# ... <a href="/Stream/Die_Schoene_und_das_Biest_2017.html" title="Die Schöne und das Biest 2017" class=
	# ... <a href="/Stream/Masters_of_Horror_The_Black_Cat.html" title=""Masters of Horror" The Black Cat" class=
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
						case "$LINK" in
							*'.html,s'*)
								SEASON="$( echo "$LINK" | cut -d',' -f2 )"
								printf '%s' "# Serie: $TITLE ($SEASON) - "
							;;
							*)
								printf '%s' "# $TITLE - "
							;;
						esac

						grep -sq " - $LINK - " "$DB" || {
							echo "$( LC_ALL=C date ) - $LINK - $TITLE" >>"$DB"
							git add "$DB"
							git commit -m "new: $TITLE - see: ${URL}${LINK}"
							git push
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
					TITLE="${TITLE}${TITLE:+ }${WORD%?}"	# remove last character = '"'
				;;
			esac
		}
	} done
} done
