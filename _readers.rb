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

require 'json'
require 'pandoc-ruby'
require 'erb'
require 'ostruct'

# # # # # # # # # # # # # # # #
# Reader Functions
# # # # # # # # # # # # # # # #

# Define a class to wrap the different data.
# We do not want to use plain hashes because we
# have some methods that depend on the type.
#
# Implementations follow below.
class DHData
  def initialize(data)
    if data.kind_of?(Hash)
      @data = data
    else
      raise "You need to pass a hash!"
    end
  end
  
  # Imitate a hash
  def method_missing(method, *args)
    if @data.respond_to?(method)
      @data.send(method, *args)
    else
      super
    end
  end

  # Returns all image files reference by
  # this object.
  def images
    []
  end  
end

# # #
# Characters
# # #
class DHChar < DHData
  def initialize(data)
    super(data)
  end
  
  def images
    [self["image"]].compact
  end
end

def read_char(file, quiet=true)
  char = nil 
  
  puts "\nReading character #{file}" unless quiet

  File.open(file, "r") { |f|
    char = JSON.parse(f.read)
  }

  if char.nil? || char.empty?
    return nil
  end  
  
  char["filename"] = file

  # Perform sanity checks
  allowed_values = [4,6,8,10,12]
  allowed_disciplines = ["combat", "covert", "mystic", "research", "social", "fringe"]

  if char["aspects"]["discipline"].size > 3
    puts "Warning: only three discipline aspects allowed" unless quiet
  elsif char["aspects"]["discipline"].keys.size != char["aspects"]["discipline"].keys.uniq.size
    puts "Warning: only one aspect per discipline allowed!" unless quiet
  end
  char["aspects"]["discipline"].each_key { |k|
    if !allowed_disciplines.include?(k)
      puts "Warning: illegal discipline identifier '#{k}'" unless quiet
    end
    if (char["disciplines"][k].kind_of?(Array) ? char["disciplines"][k][2] : char["disciplines"][k]) < 6 
      puts "Warning: only discplines with values >=6 should have aspects" unless quiet
    end
  }

  char["approaches"].merge(char["disciplines"]).each_pair { |k,v|
    if k != "fringe" && !allowed_values.include?(v.to_i)
      puts "Warning: illegal #{k} value '#{v.to_s}'." unless quiet
    end
  } 

  fringe = char["disciplines"]["fringe"]
  if ![nil, false].include?(fringe) && ( !fringe.kind_of?(Array) || (fringe.kind_of?(Array) && (fringe.size < 3 || !fringe[0].kind_of?(String) || !fringe[1].kind_of?(String) || !allowed_values.include?(fringe[2].to_i))) )
    puts "Warning: fringe value needs to be null, false, or an array with two strings and one of 4,6,8,10,12." unless quiet
    fringe = nil
  end

  if char["devotion"].to_i < 1
    puts "Warning: illegal devotion value '#{char["devotion"].to_s}'."
  end

  if !char["chapter"].kind_of?(Array) || char["chapter"].size < 2
    puts "Warning: chapter needs to be an array with a greek letter and a number." unless quiet
  else
    char["chapter"][0].capitalize!
  end
  
  if !char["conditions"].kind_of?(Array)
    puts "Warning: conditions needs to be an array (of integers)." unless quiet
    char["conditions"] = []
  end
  char["conditions"].map! { |e| e.to_i }
  char["conditions"] += [0,0,0] # pad for robustness


  # Restructure discipline aspects
  char["aspects"]["discipline"] = char["aspects"]["discipline"].to_a
  char["aspects"]["discipline"].sort_by! { |v| 
    if char["disciplines"][v[0]].kind_of?(Array)
      -char["disciplines"][v[0]][2] 
    else
      -char["disciplines"][v[0]] 
    end
  }
  if char["aspects"]["discipline"].size < 3
    char["aspects"]["discipline"] += [["",""], ["",""], ["",""]]
  end
  char["aspects"]["discipline"].each { |v| v[0] = key2discipline(v[0], char=char).upcase }


  # Translate formatted strings
  char["name"] = to_latex(char["name"])
  char["description"] = to_latex(char["description"])
  char["aspects"]["concept"] = to_latex(char["aspects"]["concept"])
  char["aspects"]["trouble"] = to_latex(char["aspects"]["trouble"])
  char["aspects"]["discipline"].each { |v| v[1] = to_latex(v[1]) }
  char["stunts"].map! { |e| to_latex(e) }
  if char["disciplines"]["fringe"].kind_of?(Array)
    char["disciplines"]["fringe"][0].upcase! if char["disciplines"]["fringe"][0].kind_of?(String)
    char["disciplines"]["fringe"][1].upcase! if char["disciplines"]["fringe"][0].kind_of?(String)
  else
    char["disciplines"]["fringe"] = ""
  end
  
  return DHChar.new(char)
end


# # #
# Chapter
# # #
class DHChapter < DHData
  def initialize(data)
    super(data)
  end
  
  def images
    (self["members"] + self["temps"] + self["gear"]).map { |m| 
      if m.kind_of?(DHData) 
        m.images 
      else
        nil 
      end 
    }.compact.flatten.uniq
  end
end

def read_chapter(file, quiet=true)
  chapter = nil 

  puts "\nReading chapter #{file}"

  File.open(file, "r") { |f|
    chapter = JSON.parse(f.read)
  }

  if chapter.nil? || chapter.empty?
    return nil
  end
  
  # Perform sanity checks
  if chapter["aspects"].size > (0.5 * chapter["members"].size).ceil
    puts "Warning: chapters should have at most #players / 2 (rounded up) aspects." unless quiet
  end
  ["aspects", "members", "gear", "temps"].each { |i|
    if !chapter.has_key?(i) || !chapter[i].kind_of?(Array)
      puts "Warning: #{i} has to be an array" unless quiet
      chapter[i] = [chapter[i]].compact
    end
  }

  # Read characters
  characters = []
  chapter["members"].each { |char|
    if File.exist?("#{char}.char")
      c = read_char("#{char}.char")
      chapter["leader"] = c if chapter["leader"] == char
      characters.push(c) 
    else
      puts "\nWarning: character file #{char}.char not found; skipping." unless quiet
    end
  }
  chapter["members"] = characters
  if !chapter["leader"].kind_of?(DHChar)
    chapter["leader"] = { "name" => chapter["leader"].to_s.capitalize }
  end
  
  # Read temps
  characters = []
  chapter["temps"].each { |char|
    if File.exist?("#{char}.char")
      c = read_char("#{char}.char")
      characters.push(c) 
    else
      puts "\nWarning: character file #{char}.char not found; skipping." unless quiet
    end
  }
  chapter["temps"] = characters
  
  # Read items
  items = []
  chapter["gear"].each { |gear|
    if File.exist?("#{gear}.gear")
      g = read_gear("#{gear}.gear")
      items.push(g) 
    else
      puts "\nWarning: gear file #{gear}.gear not found; skipping." unless quiet
    end
  }
  chapter["gear"] = items

  # Translate formatted strings

  chapter["description"] = to_latex(chapter["description"])
  
  return DHChapter.new(chapter)
end


# # #
# Gear
# # #
class DHGear < DHData
  def initialize(data)
    super(data)
  end
  
  def images
    [self["image"]].compact
  end
end

def read_gear(file, quiet=true)
  item = nil 

  puts "\nReading item #{file}"

  File.open(file, "r") { |f|
    item = JSON.parse(f.read)
  }

  if item.nil? || item.empty?
    return nil
  end
  
  item["filename"] = file

  if File.exist?("#{item["owner"]}.char")
    owner = read_char("#{item["owner"]}.char")

    if !owner.nil? && !owner.empty?
      #item["owner"] = owner.merge({ "filename" => item["owner"] })
      owner["filename"] = item["owner"]
      item["owner"] = owner
    end
  end

  # Translate formatted strings
  item["name"] = to_latex(item["name"])
  if item["owner"].kind_of?(DHChar)
    item["owner"]["linkedname"] = to_latex("[#{item["owner"]["name"]}](#{item["owner"]["filename"]}.pdf)")
  else 
    item["owner"] = { "name" => item["owner"].to_s.capitalize }
  end
  item["aspects"]["function"] = to_latex(item["aspects"]["function"])
  item["aspects"]["flaw"] = to_latex(item["aspects"]["flaw"])
  item["stunts"].map! { |e| to_latex(e) }

  if item["image"].nil? || item["image"].empty? || !File.exist?(item["image"])
    item["image"] = ""
  end

  if item["certified"].nil? || item["certified"].empty?
    item["certified"] = {}
  else
    item["certified"] =  { "use" => false, "civilians" => false, "public" => false, "reproduction" => false }.merge(item["certified"])

    item["certified"].keys.each { |k| 
      item["certified"][k] = item["certified"][k] ? "X" : "\\phantom{X}"
    }
  end
  
  return DHGear.new(item)
end

# # #
# Encounter
# # #
class DHEncounter < DHData
  def initialize(data)
    super(data)
  end
  
  def images
    [] # TODO collect images from all contained creatures
  end
end

def read_encounter(file, quiet=true)
  encounter = nil 

  puts "\nReading encounter #{file}"

  File.open(file, "r") { |f|
    encounter = JSON.parse(f.read)
  }

  if encounter.nil? || encounter.empty?
    return nil
  end
  
  if !encounter.has_key?("title")
    puts "Warning: encounter has no title" unless quiet
    encounter["title"] = ""
  end
  
  encounter["groups"].each_value { |group| 
    group.each_with_index { |creature,i|
      if !creature.kind_of?(Hash)
        if File.exist?("#{creature.to_s}.char") # TODO extend to DMCs
          group[i] = read_char("#{creature.to_s}.char")
          puts "" unless quiet
          group[i]["number"] = 1
        else
          puts "Warning: file #{creature.to_s}.char not found" unless quiet
          group[i] = { "name" => creature.to_s }
        end
        creature = group[i]
      end
      
      if !creature.has_key?("mob")
        creature["mob"] = 0
      end
      creature["mob"] = creature["mob"].to_i
      
      if creature["mob"] > 0
        creature["name"] = "Mob of #{creature["mob"]} #{creature["name"]}s"
      end
      
      if !creature.has_key?("conditions")
        puts "Warning: #{creature["name"]} has no conditions" unless quiet
        creature["conditions"] = creature["mob"] > 0 ? 0 : []
      end
      
      if creature["mob"] > 0
        creature["conditions"] = creature["conditions"].to_i
      else
        creature["conditions"].map! { |e| e.to_i }
        creature["conditions"] += [0,0,0]
      end
      
      if !creature.has_key?("number")
        creature["number"] = 1
      end
    }
  }
  
  return DHEncounter.new(encounter)
end

# # # # # # # # # # # # # # # #
# Helper Functions
# # # # # # # # # # # # # # # #

def key2discipline(key, char, short=true)
  case key
  when "combat"
    short ? "Combat" : "Combat & Tactics"
  when "covert"
    short ? "Covert" : "Covert Ops"
  when "mystic"
    short ? "Mystic" : "Mystic Arts"
  when "research" 
    short ? "Research" : "Research & Development"
  when "social"
    short ? "Social" : "Social Engineering"
  when "fringe"
    if !char["disciplines"]["fringe"].empty?
      short ? char["disciplines"]["fringe"][1] : char["disciplines"]["fringe"][0]
    else
      ""
    end
  when ""
    ""
  else
    short ? "???" : "Unknown Discipline"
  end
end

def to_latex(string)
  PandocRuby.markdown(string).to_latex.strip
end

# From http://stackoverflow.com/a/8955121/539599
# This makes passing data from different scopes and s
# sources to ERB a lot easier.
class ErbalT < OpenStruct
  def render(*args)
    ERB.new(*args).result(binding)
  end
end
