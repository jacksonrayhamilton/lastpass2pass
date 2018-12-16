#!/usr/bin/env ruby

# Copyright (C) 2012 Alex Sayers <alex.sayers@gmail.com>.  All Rights Reserved.
# This file is licensed under the GPLv2+.  Please see COPYING for more
# information.

# LastPass Importer
#
# Reads CSV files exported from LastPass and imports them into pass.

# Usage:
#
# Go to lastpass.com and sign in.  Next click on your username in the top-right
# corner. In the drop-down menu that appears, click “Export”.  After filling in
# your details again, copy the text and save it somewhere on your disk.  Make
# sure you copy the whole thing, and resist the temptation to “Save Page As” —
# the script doesn’t like HTML.
#
# Fire up a terminal and run the script, passing the file you saved as an
# argument.  It should look something like this:
#
# $ ./lastpass2pass.rb path/to/passwords_file.csv

require 'csv'
require 'English'
require 'optparse'

# Parse flags
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options] filename"

  FORCE = false
  opts.on('-f', '--force', 'Overwrite existing records') { FORCE = true }
  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end

  opts.parse!
end

# Check for a filename
if ARGV.empty?
  puts optparse
  exit 0
end

# Get filename of CSV file
filename = ARGV.join(' ')
puts "Reading “#{filename}”..."

# Represent 1 password from LastPass imported from a LastPass CSV
class Record
  def initialize(name, url, username, password, extra)
    @name = name
    @url = url
    @username = username
    @password = password
    @extra = extra
  end

  def name
    s = ''
    s << 'Secure Notes/' if secure_note?
    s << @name unless @name.nil?
    s.delete("'")
  end

  def to_s
    s = ''
    s << "#{@password}\n"
    s << "username: #{@username}\n" unless @username.nil? || @username.empty?
    s << "url: #{@url}\n" unless secure_note?
    s << "#{@extra}\n" unless @extra.nil?
    s
  end

  private

  def secure_note?
    @url == 'http://sn'
  end
end

unless File.exist?(filename)
  puts "Couldn’t find “#{filename}”!"
  exit 1
end

# Parse records and create Record objects
records = []
rows = CSV.read(filename)
rows.shift
rows.each do |args|
  url = args.shift
  username = args.shift
  password = args.shift
  args.pop # Ignore “fav”
  args.pop # Ignore “grouping”
  name = args.pop
  extra = args.join(',')

  records << Record.new(name, url, username, password, extra)
end
puts "Records parsed: #{records.length}"

successful = 0
errors = []
records.each do |r|
  name = r.name
  copy = 1
  while File.exist?("#{Dir.home}/.password-store/#{name}.gpg")
    break if FORCE
    copy += 1
    name = "#{r.name} (#{copy})"
  end
  print "Creating record “#{name}”..."
  IO.popen("pass insert -m '#{name}' > /dev/null", 'w') do |io|
    io.puts r
  end
  if $CHILD_STATUS == 0
    puts ' done!'
    successful += 1
  else
    puts ' error!'
    errors << r
  end
end
puts "#{successful} records successfully imported!"

unless errors.empty?
  puts "There were #{errors.length} errors:"
  errors.each { |e| print e.name + (e == errors.last ? ".\n" : ', ') }
  puts 'These probably occurred because an identically-named record already \
existed, or because there were multiple entries with the same name \
in the CSV file.'
  exit 1
end
