# Tools for Demon Hunters

This project is an attempt to help GMs and Players of the 
  [Demon Hunters RPG](http://www.demonhuntersrpg.com/)
create useful supplements with little effort.

Currently, this includes

 * filled-out character sheets,
 * chapter overview sheets,
 * encounter sheets,
 * item cards, and
 * postage stamps.

If you have any questions or suggestions, don't hesitate to 
  [open an issue](https://github.com/akerbos/dh-tools/issues/new)!

## Setup

You need the following software.

 * Ruby 2.3 (or newer)
 
   With gem `pandoc-ruby`.
   
 * [Pandoc](http://pandoc.org/)
 
 * LuaLaTeX (e.g. from [TeX Live](https://www.tug.org/texlive/))
 
 * `pdftk` (optional)
 
 * `gs` (optional)

I recommend you put a (sym)link to `compile.rb` in some directory that is in
your `PATH`.

### Missing resources

You will have to provide the fonts since I can not distribute them due to
the respective licenses. Put them all into `resources`.
   
 * `ARJULIAN.ttf` -- used for headlines on all sheets.  
    Find it e.g. [here](http://www.fontzone.net/font-details/ar-julian).
 
 * `futurabt-light.otf` -- used on the character sheet for Fringe aspects,
    and on gear cards for permissions.  
    Find it e.g. [here](http://ufonts.com/fonts/futurabt-light-opentype.html).
    
 * `futura_lt_condensed_light.ttf` -- used on all sheets for inscribing aspect
    boxes.  
    Find it e.g. [here](http://ufonts.com/fonts/futura-lt-condensed-light.html).
 
*Note bene:* I do not redistribute the original character sheet, but the script
will download it (once) from the official site if it is missing.

### Using other resources

While you are certainly welcome to experiment with other images and fonts
(check out `CONSTANTS` in `compile.rb`),
note that the designs are tailored to the measures of the ones I have used. 
You will *probably* mess up the sheets in some way. 
If you don't know your way around TikZ, I recommend you stay clear.

### Paper format

Chapter, encounter and gear sheets use A4 resp. A6 paper formats. There is no
option for creating formats used in the US; that would be quite the effort.
I recommend you just create the A4/A6 sheets and let your printer driver
fit them onto whatever paper format you happen to have handy.


## Usage

Except for postage stamps, all supplements are created from JSON files. 
You use a command like this:

```bash
compile.rb [options] file1 file2 ...
```

You can pass arbitrarily many compatible JSON files.
The script uses custom file endings to decide which kind of supplement you want
to create, so stick to those given below.

You will get some messages printed to your command line, and after a little
while a PDF should appear.

As a general rules, the script tries to supply reasonable defaults or warn you
about problems with your JSON. Please take note of any messages that appear.

### Options

 * `--debug` -- if set, the temporary folder is not deleted so you can inspect
    the generated LaTeX and log files.

 * `--folded` -- this option affects chapter sheets only. If you want to punch
    the sheet on the left short side (and presumably fold it to A5), set this
    option. Otherwise, there won't be enough room for punching.
    
 * `--concat=file` -- by default, `compile.rb` will create one PDF per input
   file. If you want them all in one file, for instance to print them more
   easily or print multiple pages per sheet, set this option. `file` is the
   filename of the target file.
   
   Requires [`pdftk` from the pdf toolkit](https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/).

 * `--small` -- the original character sheet is quite large, thanks to a rather
   big background image. If a 3MB file is too large for your purposes, you
   can set this option.
   
   Requires [`gs` from Ghostscript](http://www.ghostscript.com/).
   

### Character Sheet

Files of the form `name.char` are translated into character sheets.  
See 
  [`examples/testC.char`](https://github.com/akerbos/dh-tools/blob/master/examples/testC.char) 
for a complete example.

The template basically fills in the official character sheet. I added some
cute details such as a short form of the Discipline's name in its Aspect box and
proper display of Fringe disciplines.

![Example character sheet](https://github.com/akerbos/dh-tools/blob/master/examples/example_char.png)

**Note:**

 * `chapter` has to be an array like e.g. `["Psi", 7]`: first the Greek letter,
    then the number.
 * Discipline `fringe` should be either `nil` or an array of the form
    `["Pyrokinetic", "Pyro", 6]`; the short string appears in the Aspect box,
    if there is any.
 * Discipline Aspects use the same keys as the list of Disciplines.
 * `conditions` should contain an array of the form `[3,2,1]` -- first the number 
   of mild, then moderate, then severe Conditions the character can take.
   
   This entry does not affect the character sheet; it is used for chapter and
   encounter sheets.
 * You can add as many stunts as you want, but they may overflow the sheet.
    

### Chapter Sheet

Files of the form `name.chapter` are translated into chapter sheets;
they are meant to summarize the most important information (for the GM)
about the whole chapter in compact form.  
See 
  [`examples/test.chapter`](https://github.com/akerbos/dh-tools/blob/master/examples/test.chapter) 
for a complete example.

![Example chapter](https://github.com/akerbos/dh-tools/blob/master/examples/example_chapter.png)

**Note:**

 * `members`, `temps`, `leader` and `gear` contain filenames of character
   resp. item files without the file endings.
 * Player characters should appear in `member`; `temps` is for important NPCs.
   The presentation is not different, but temps go last.

### Item Card

Files of the form `name.gear` are translated into item cards that players and
GMs can use to keep track of the cool property of the most precious gear.  
See 
  [`examples/testG.gear`](https://github.com/akerbos/dh-tools/blob/master/examples/testG.gear) 
for a complete example.

![Example item](https://github.com/akerbos/dh-tools/blob/master/examples/example_gear.png)

The Demon Hunters rulebook contains nothing about gear; we should model most
if not everything using Aspects. However, I found that special circumstance
can warrant characters having personalized items; for instance, mad scientists
probably gain something that is more than a prototype at some point.
I looked to the 
  [Gadgets and Gear](http://fate-srd.com/fate-system-toolkit/gadgets-and-gear)
section of the Fate System Toolkit for how to do it.

**Note:**

 * `owner` can contain either the name of a character file (without the ending)
    or any string.
    
 * `certified` informs whether the item fulfills some made-up paragraphs in
   a Brotherhood Codex (CBCT) I assume exists. If you don't want to use this
   feature, just set `"certified" : nil`.
   
 * The spade picture in `examples` comes from 
     [here](http://www.fancyicons.com/free-icon/232/garden-icon-set/free-spade-icon-png/).


### Encounter Sheet

Files of the form `name.encounter` are translated into encounter sheets;
they are meant to help GMs track data during combat encounters.  
See 
  [`examples/testE.encounter`](https://github.com/akerbos/dh-tools/blob/master/examples/testE.encounter) 
for a complete example.

Currently, the sheets support grouping characters and creatures,
repeating the same creature multiple times, tracking of conditions,
tracking of turns and some free text.

![Example encounter](https://github.com/akerbos/dh-tools/blob/master/examples/example_encounter.png)

**Note:**

 * Entries in each group are either a string (name of a character file
    without the ending) or an object `{ ... }` with at least a `name`
    and `conditions`.
 * Make an entry for mobs by setting `mob` to the number of creatures in the mob.
 * Create multiple entries of the same creature by setting `number` to the
   desired number.


### Postage Stamp

This is just a plain LaTeX file you can compile with `lualatex`.
The resulting PDF contains a made-up pre-paid stamp to use on in-game
artifacts sent by Brotherhood administrators.

Currently, there are English and German versions.

![Postage stamps](https://github.com/akerbos/dh-tools/blob/master/examples/example_postage.png)


## License

Copyright 2016-2017, Raphael Reitzig

dh-tools is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

dh-tools is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with dh-tools. If not, see <http://www.gnu.org/licenses/>.

---

Game terms have been taken from the publication *Demon Hunters: A Comedy of Terror*,
published by Dead Gentlemen Productions, LLC, in accordance with the
Open Game License.

Logo graphics republished with kind permission of Dead Gentlemen Productions.

Demon Hunters: A Comedy of Terrors, Copyright 2015, Dead Gentlemen
Productions, LLC; Authors Cam Banks, Jimmy McMichael, Don Early,
and Nathan Rockwood.
