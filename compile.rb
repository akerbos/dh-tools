#!/usr/bin/ruby

# Copyright 2016, Raphael Reitzig
#
# dh-tools is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# dh-tools is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with dh-tools. If not, see <http://www.gnu.org/licenses/>.

# Requires json, net/http, fileutils, erb, ostruct
#          pandoc-ruby
#          [gs], [pdftk]

# Get the directory of this here script (even if accessed through a symlink).
# We'll need this to copy fonts and such to our working directory.
SCRIPTDIR = File.absolute_path(File.dirname(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__))
USERDIR = Dir.pwd

# First, there are things we need for building the documents.
CONSTANTS = {
  :charsheet      => "DHRPG_Character_Sheet_Print-n-Fill.pdf",
  :logo           => "dh_logo.png",

  :header_font    => "ARJULIAN.ttf",
  :form_font      => "futurabt-light.otf",
  :boxlabel_font  => "futura_lt_condensed_light.ttf",
  :fill_font      => "Felt Tip"
}

# Now let's see what the user has for us.
if ARGV.size == 0
  puts "Usage: compile [--debug] [--fold] [--concat=file] file.." 
  Process.exit
end

# Extract options
files = []
fold = false
debug = false
small = false
concat = nil
ARGV.each { |arg|
  case arg
  when /^--fold$/
    fold = true
  when /^--debug$/
    debug = true
  when /^--concat=(.+)$/
    concat = $1
    concat += ".pdf" unless concat.end_with?(".pdf")
  when /^--small$/
    small = true
  else
    if File.exist?(arg)
      files << arg
    else
      puts "Warning: '#{arg}' is neither a file not a valid option; ignoring."
    end
  end
}

Process.exit if files.empty?

# This is where all the JSON-parsing and -sanitization happens.
require "#{SCRIPTDIR}/_readers.rb"

# Create a temporary folder
tmpdir = Dir.mktmpdir("dhtools-")
puts "Info: Find temporary files in #{tmpdir}" if debug

# Process all the files!
pdfs = []
files.each { |file|

  jobname = file.sub(/\.[^.]+$/, "")
  jobtype = file.sub(/.*?\.([^.]+)$/, "\\1").to_sym
  latex_aux = [:logo, :header_font, :boxlabel_font, :form_font]
  variables = {}
  
  if ![:char, :chapter, :encounter, :gear].include?(jobtype)
    puts "Error: File '#{file}' does not seem to have a supported type."
    next
  end
  
  # Some type-specific preparations
  case jobtype
  when :char
    # Aquire blank charsheet
    if !File.exist?("#{SCRIPTDIR}/resources/#{CONSTANTS[:charsheet]}")
      require 'net/http'
      File.write("#{SCRIPTDIR}/resources/#{CONSTANTS[:charsheet]}", 
                 Net::HTTP.get(URI.parse("http://demonhuntersrpg.com/downloads/PDFs/#{CONSTANTS[:charsheet]}")))
    end
    latex_aux << :charsheet
  when :chapter
    variables[:pagelatex] = File.open("#{SCRIPTDIR}/templates/chapter_page_template.tex", "r") { |f| f.read }
    variables[:chaplatex] = File.open("#{SCRIPTDIR}/templates/chapter_chap_template.tex", "r") { |f| f.read }
    variables[:charlatex] = File.open("#{SCRIPTDIR}/templates/chapter_char_template.tex", "r") { |f| f.read }
    #latex_aux << :pagetemplate << :chaptemplate << :chartemplate
  when :encounter
    variables[:fold] = fold
  when :gear
  else
    puts "Error: How did you get in here?!"
    Process.exit
  end
  
  # Now we parse the JSON
  data = send("read_#{jobtype.to_s}", file)
  if data.nil? || data.empty?
    puts "Error: #{jobtype.to_s} data could not be read."
    next
  end
  variables[jobtype] = data

  # Fill out the template
  latex  = File.open("#{SCRIPTDIR}/templates/#{jobtype}_template.tex", "r") { |f|
    f.read
  }

  allvals = CONSTANTS.merge(variables)
  latex = ErbalT.new(allvals).render(latex, nil, '-')
  
  FileUtils::mkdir("#{tmpdir}/#{file}")
  Dir.chdir("#{tmpdir}/#{file}")
  
  File.open("#{jobname}.tex", "w") { |f| 
    f.write(latex)
  }

  # Convert to PDF   
  puts "\nCompiling #{jobtype.to_s} sheet for #{jobname}!"
  puts latex_aux.map { |k| allvals[k] }.to_s if debug
  latex_aux.map { |k| allvals[k] }.each { |f| FileUtils::cp("#{SCRIPTDIR}/resources/#{f}", "./") }
  puts data.images.to_s if debug
  data.images.each { |f| FileUtils::cp("#{USERDIR}/#{f}", "./") }
  `lualatex -file-line-error -interaction=nonstopmode "#{jobname}.tex"`
  `lualatex -file-line-error -interaction=nonstopmode "#{jobname}.tex"` if jobtype == :chapter


  # Create a small version
  if File.exist?("#{jobname}.pdf")
    pdfs << "#{jobname}.pdf"
    
    # The original character sheet has a big-ass background graphic;
    # we want a version we can actually mail and print.
    if jobtype == :char && small
      `gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen -dNOPAUSE -dQUIET -dBATCH -sOutputFile=#{jobname}_small.pdf #{jobname}.pdf`
      FileUtils::mv("#{jobname}_small.pdf", "#{jobname}.pdf")
    end
    
    FileUtils::mv("#{jobname}.pdf", "..")
    
    Dir.chdir(USERDIR)
  end
}

# Concatenate all PDFs if so desired
if !concat.nil?
  Dir.chdir("#{tmpdir}")
   puts "\nConcatenating all PDFs..."
  `pdftk #{pdfs.map { |pdf| "\"#{pdf}\"" }.join(" ")} cat output "#{concat}"`
  
  if File.exist?(concat)
    FileUtils::cp(concat, "#{USERDIR}/")
    pdfs.clear
  else
    puts "Error: PDF concatenation failed"
  end
  Dir.chdir(USERDIR)
end

pdfs.each { |pdf| FileUtils.cp("#{tmpdir}/#{pdf}", "./") }
FileUtils::rm_rf(tmpdir) unless debug
