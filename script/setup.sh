#!/bin/sh

echo setup starting.....
docker-compose rm

echo build docker image
cd ../ && docker build --rm -t sage/mysql_framework_test_runner .

echo setup complete
