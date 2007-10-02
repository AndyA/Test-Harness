#!/bin/sh
for set in pt/fast pt/fickle pt/greedy pt/gross pt/lazy pt
do
    for args in '' '-j9' '-j9 --fork' '-j4 --fork'
    do
        echo "Running prove -rQ $args $set"
        prove -rQ $args $set
    done
	echo ----------------------------------------
done
