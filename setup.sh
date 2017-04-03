#!/bin/bash

# download S.M.B. rom
wget 'http://23.227.191.210/997ajxXXajs13jJKPxOa/may/120/NES%20Roms/Super%20Mario%20Bros.%20(Japan,%20USA).zip' -O SuperMarioBros.zip
unzip SuperMarioBros.zip
rm SuperMarioBros.zip
mv 'Super Mario Bros. (Japan, USA).nes' roms/SuperMarioBros.nes

# copy savestate file to fceux(s) folder(s)
if [ ! `which fceux` ]; then
	echo 'Please install fceux (e.g. apt-get install fceux)'
	exit 0
fi

if [ ! `which th` ]; then
	echo 'Please install torch from "http://torch.ch/docs/getting-started.html#_" and add package.path and package.cpath to .bashrc file'
	exit 0
fi

echo 'Do you want to run the test now? [y/N]'
read -n 1 answer
if [ $answer == 'y' ]; then
	wine fceux roms/SuperMarioBros.nes --loadlua test.lua
fi
