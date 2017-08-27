# ESPWebFlashServer
### Webserver code for the ESP8266 that stores web content in FLASH

After finding an example of using unix `xxd -i` in conjunction with a header file and `pgmspace.h` to write file data to flash,
I decided to put together a set of tools to make it easier for me to create and deliver web content on my ESP8266.

The goal was to come up with a method where I could solve a couple of standard problems:

1. allow editing files in place
2. avoid having to use an SD card or other additional storage space (and associated hardware)
3. if possible, decrease the size to speed up the delivery and avoid timeouts serving large files (this is especially important if you want to use any kind of framework or canned script libraries that may be large and cumbersome)

This approach seems to solve all of the above problems, especially on the ESP8266. (from what I understand, the flash code is specific to the ESP8266 hardware, but the additional memory in devices such as the ESP-12e and ESP-12f that have 4Meg helps a lot!)

The `WebFlash.h` file is borrowed from poster [Torx](http://www.esp8266.com/memberlist.php?mode=viewprofile&u=9636) on the esp8266 forums from the thread [WEBSERVER ON ESP8266, SERVING FILES FROM FLASH](http://www.esp8266.com/viewtopic.php?f=32&t=3780). I modified it slightly to serve my needs and renamed it. (NOTE: I have tried multiple times to contact the user for permission to repost but can't seem to get a response. The code is simple enough and so useful, I am posting here)

The bulk of my contribution, however, is in the `hexify.pl` perl script, which as currently configured, will look through a folder called `www` in the directory where it is run and find any regular files to drop into a header file that can be used by the esp8266 code to add to the finished sketch.  It uses a unix 'find' currently (I may update it to use internal perl find as I recently removed the need for external `xxd -i` call to create the hexidecimal array content also) but I have verified that it does work on windows with cygwin. (it may be necessary to modify the paths near the top of the perl file. It may also be possible to hardcode the output folder with an absolute path reference or otherwise make it work from `./` instead of looking for a `www/` folder).

It uses the perl/CPAN `*::Packer` modules to minify html (including xml and sgml), css and javascript (ecmascript) files. It will then try to gzip (with maximum level 9 compression) any text files including those types, txt, rtf and csv. It will also run any svg+xml files through the html minifier and try to compress them as well. I say 'try' because it tests the end result against the original in both cases (minifying and gzip'ing) and only use the attempted compression if the file shrinks by 10% or more. Otherwise it uses the original content. Binary and all other file types not specified are read in binmode and encoded to hexidecimal as-is.
The script then creates the `FLASH_ARRAY` instances then builds an array of structs including their original path/filename, final size, encoding (none or 'gzip' if compression was used) and their corresponding mimetype. This information can then be used by the server to provide the files either raw or compressed (as encoded) and if they are encoded with gzip, the user's browser should decompress the files as needed.  It also tries to detect files already gzip'd or compressed and include an encoding type with those files as well.
The end result is dropped into the directory where the script is run (should be the same folder as the `www/` web tree as currently configured) as `webfiles.h` which can be then imported with an include line in your arduino sketch.

To make things as easy as possible and to allow it to work in conjunction with other encoded server `handle*` methods, I set up the server code to actually check the array of structs for the requested path only after all other methods have failed (actually inside of the `handleNotFound()` method before spitting out a 404 error). An example of this in action is in the bare-bones server code included in `ESPWebFlashServer.ino`.  A sample `www/` tree is also included along with the output from `hexify.pl` in the included `webfiles.h`.

`hexify.pl` utilizes (and requires) the following CPAN libraries be installed:

* [Switch](http://search.cpan.org/~chorny/Switch-2.17/Switch.pm) a case/switch addon
* [HTML::Packer](http://search.cpan.org/~leejo/HTML-Packer-2.05/lib/HTML/Packer.pm)
* [CSS::Packer](http://search.cpan.org/~leejo/CSS-Packer-2.03/lib/CSS/Packer.pm)
* [JavaScript::Packer](http://search.cpan.org/~leejo/JavaScript-Packer-2.03/lib/JavaScript/Packer.pm)
* [Gzip::Faster](http://search.cpan.org/~bkb/Gzip-Faster-0.20/lib/Gzip/Faster.pod)
* [MIME::Types](http://search.cpan.org/~markov/MIME-Types-2.13/lib/MIME/Types.pod)
* [File::MimeInfo](http://search.cpan.org/~michielb/File-MimeInfo-0.28/lib/File/MimeInfo.pm)
* [File::Slurp](http://search.cpan.org/~uri/File-Slurp-9999.19/lib/File/Slurp.pm)
* [File::Basename](http://search.cpan.org/~shay/perl-5.24.2/lib/File/Basename.pm) {built-in}

The example files in www includes the following that are not mine strictly for examples:

* [min css toolkit](https://mincss.com/) as a sample of using a small css toolkit already minified
* [zepto.js](http://zeptojs.com/) as an example of having a minimalist javascript library already minified
* a copy of the ESP8266 logo in gif format
* a copy of the Arduino circle logo in svg format

I have also used this in conjunction with platformio by putting the www tree in the project root and modifying the output file to include `src/` in front of it so it puts it in with the other source files.

Any suggestions or improvements, bug reports or potential fixes are always appreciated.
