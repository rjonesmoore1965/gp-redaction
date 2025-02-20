_APP_PATH=app
_PERM_USER=$$USER
_SUDO=

up: docker-up
down: docker-down
restart: docker-down docker-up
init: docker-down-clear clear docker-pull docker-build docker-up init
test-coverage: test-coverage
test-unit: test-unit
test-unit-coverage: test-unit-coverage

clear-cache:
	docker-compose run --rm php-cli php bin/console cache:clear

docker-up:
	docker-compose up -d

docker-down:
	docker-compose down --remove-orphans

# удаление только системных томов
docker-down-clear:
	docker-compose down -v --remove-orphans

docker-pull:
	docker-compose pull

docker-build:
	docker-compose build

init: composer-install composer-dump-autoload wait-db migrations-migrate fixtures ready

composer-dump-autoload:
	docker-compose run --rm php-cli composer dump-autoload

clear:
	docker run --rm -v ${PWD}/app:/app --workdir=/app alpine rm -f .ready

composer-install:
	docker-compose run --rm php-cli composer install

wait-db:
	until docker-compose exec -T postgres pg_isready --timeout=0 --dbname=app ; do sleep 1 ; done

migrations-migrate:
	docker-compose run --rm php-cli php bin/console doctrine:migrations:migrate --no-interaction

fixtures:
	docker-compose run --rm php-cli php bin/console doctrine:fixtures:load --no-interaction

ready:
	docker run --rm -v ${PWD}/app:/app --workdir=/app alpine touch .ready

migrations-status:
	docker-compose run --rm php-cli php bin/console doctrine:migrations:status
migrations-diff: # преимущественно
	docker-compose run --rm php-cli php bin/console doctrine:migrations:diff
migrations-generate: # создать новую пустую
	docker-compose run --rm php-cli php bin/console doctrine:migrations:generate

SHELL := /bin/bash

test: tests

test-prepare:
	docker-compose restart postgres-test
	docker-compose run --rm php-cli bin/console doctrine:database:drop --env=test --force || true
	docker-compose run --rm php-cli bin/console doctrine:database:create --env=test
	docker-compose run --rm php-cli bin/console doctrine:migrations:migrate --env=test -n
	docker-compose run --rm php-cli bin/console doctrine:fixtures:load --env=test -n

tests: export APP_ENV=test
tests: test-prepare
	docker-compose run --rm php-cli php bin/phpunit $@
.PHONY: tests

test-single-class: export APP_ENV=test
test-single-class: test-prepare
	docker-compose run --rm php-cli php bin/phpunit ${cmd}
.PHONY: test-single-class

test-unit:
	docker-compose run --rm php-cli php bin/phpunit tests/unit
test-feature:
	docker-compose run --rm php-cli php bin/phpunit tests/feature

test-coverage:
	docker-compose run --rm php-cli php bin/phpunit --coverage-clover var/clover.xml --coverage-html var/coverage

test-unit-coverage:
	docker-compose run --rm php-cli php bin/phpunit --testsuite=unit --coverage-clover var/clover.xml --coverage-html var/coverage

perm:
	echo 'user-$(_PERM_USER)';
	$(_SUDO) chown -f -R $(_PERM_USER):$(_PERM_USER) $(_APP_PATH);
	$(_SUDO) find $(_APP_PATH) -type f -exec chmod 644 {} \;
	$(_SUDO) find $(_APP_PATH) -type d -exec chmod 755 {} \;
	$(_SUDO) chgrp -f -R $(_PERM_USER) $(_APP_PATH)/vendor;
	$(_SUDO) chmod -R 777 $(_APP_PATH)/var/cache;
	$(_SUDO) chmod -R 777 $(_APP_PATH)/var/log;
	$(_SUDO) chmod +x $(_APP_PATH)/bin/console;
