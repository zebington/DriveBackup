#!/usr/bin/env bash
rvm all do rvm use 2.2.1@drivebackup
gem install bundler
bundle install
ruby /home/charlotte/Code/Ruby/DriveBackup/drivebackup.rb
