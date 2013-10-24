require 'rubygems'
require 'sinatra'
require 'bundler'
Bundler.setup
require 'dotenv'
Dotenv.load

require './instaplaces'

run Instaplaces
