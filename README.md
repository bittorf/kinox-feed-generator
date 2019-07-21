=== why a kinox.to parser ===

* for each new uploaded file, generate a commit-log with "link", "title" and "IMDB-rating", e.g.:

```
user@box:~/software/kinox-feed-generator$ git show 4f8c1ec4fcd85f6ef0f0bb9b0056e43fb06e8f42
commit 4f8c1ec4fcd85f6ef0f0bb9b0056e43fb06e8f42
Author: bot <bot@intercity-vpn.de>
Date:   Sat Jul 20 16:46:17 2019 +0200

    http://kinox.to/Stream/Haus_des_Geldes.html
    IMDB: Rating: 8.6 http://www.imdb.com/title/tt6468322/

    Haus des Geldes
    ===============
    In Haus des Geldes geht es um einen Raubüberfall, der in monatelanger
    Vorbereitung geplant und schließlich mit unvergleichlicher Perfektion
    durchgeführt wurde. Doch nun gilt es, mit der Beute zu entkommen und sich auf
    Dauer vor dem Gesetz zu verstecken. Kreiert wurde die Serie von Álex Pina.
    ...

```

=== so we can search good movies and have a feed ===

./kinox_get_news.sh --news

=== setup ===

```
cd kinox-feed-generator
git config user.name 'bot'
git config user.email 'bot@nas.bwireless.mooo.com'
./kinox_get_news.sh --cron
```
