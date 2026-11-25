# GEMS w Dockerze

Uruchamiaj polecenia z katalogu głównego `gems-model`. Potrzebujesz Dockera z Compose 2.17 lub nowszym. Na Windowsie Docker Desktop powinien pracować w trybie kontenerów Linux. Julia działa wewnątrz kontenera. [Konteksty budowania Compose](https://docs.docker.com/reference/compose-file/build/#additional_contexts)

```sh
docker compose -f docker-run/compose.yaml build gems
docker compose -f docker-run/compose.yaml run --rm gems
```

Krótki przebieg kontrolny używa syntetycznej populacji i ogranicza liczbę kroków.

```sh
docker compose -f docker-run/compose.yaml run --rm -e GEMS_POP_SIZE=1000 -e GEMS_TICKS=5 gems
```

Domyślna konfiguracja pochodzi z `data/DefaultConf.toml` w klonowanej wersji GEMS. Własne pliki można umieścić w `docker-run/input/`. Ustawienia są opcjonalne. Skopiuj `.env.example` do `docker-run/.env` i podaj np. `GEMS_CONFIG=/input/simulation.toml`. Przy własnym `.env` dodaj do polecenia `--env-file docker-run/.env` przed `-f`.

Wyniki każdego przebiegu trafiają do osobnego katalogu w `docker-run/output/`. Plik `runinfo.toml` zawiera status `completed` po udanym przebiegu. Obok zapisują się wersje zależności Julii i sumy kontrolne plików GEMS użytych do budowy obrazu. Wejście w kontenerze jest tylko do odczytu. Git ignoruje lokalne dane wejściowe, wyniki i `.env`.

Przy pierwszym przetwarzaniu wyników GEMS może pobrać publiczne dane geograficzne. Kolejne uruchomienia korzystają z lokalnego wolumenu Dockera.

## Aktualizacja z IMMIDD/GEMS

W tym klonie `origin` wskazuje Twoje repozytorium, a `upstream` repozytorium źródłowe. W świeżym klonie dodaj `upstream` jednorazowo poleceniem `git remote add upstream https://github.com/IMMIDD/GEMS.git`. [Repozytorium źródłowe GEMS](https://github.com/IMMIDD/GEMS)

Sprawdź, jakie commity są dostępne, będąc na gałęzi z konfiguracją Docker.

```sh
git fetch upstream
git log --oneline HEAD..upstream/main
```

Jeżeli lista pokazuje nowe commity, scal je i przebuduj obraz. Scalenie zachowuje lokalną konfigurację w `docker-run/`.

```sh
git merge upstream/main
docker compose -f docker-run/compose.yaml build gems
```

Uruchom krótki przebieg kontrolny po każdej aktualizacji. Pierwsze budowanie obrazu może potrwać kilkanaście minut z powodu pobierania i prekompilacji pakietów Julii.
