#!/usr/bin/perl

use Switch;

use CSS::Packer;
use JavaScript::Packer;
use HTML::Packer;

use Gzip::Faster ':all';
use MIME::Types;
use File::MimeInfo;
use File::Basename;
use File::Slurp;

$gz = Gzip::Faster->new();
$gz->level(9);

my $outfile = "webfiles.h";
my $webdir = "www";
my $find_exe = "/usr/bin/find";
my $findcmd = $find_exe . " " . $webdir . " -type f ";

my $mt = MIME::Types->new();
my $files = open(FINDSTRM, "$findcmd|") || die $!;
my @filelist;
while(my $line = <FINDSTRM>) {
    chomp($line);
    my %fileinfo;
    $fileinfo{path} = $line;
    ($fileinfo{url} = $line) =~ s|^/?$webdir/?||;
    print "processing file: $fileinfo{path}:\n";
    (my $hName = $fileinfo{url}) =~ s|/|__|g;
    $hName =~ s/[\.\s]/_/g;
    print "  using header name: $hName\n";
    $fileinfo{name} = $hName;
    $fileinfo{type} = mimetype($fileinfo{path});


    my $bindat;
    # read file normal
    my $rawdat = read_file($fileinfo{path});
    switch($fileinfo{type}) {
        case /^text\/(html|xml|sgml)$/ {
            $bindat = processHTML($rawdat, basename($fileinfo{path}));
        }
        # handle svg files as xml data - use html minifier and gzip
        case /^(image|application)\/svg\+xml$/ {
            $bindat = processHTML($rawdat, basename($fileinfo{path}));
        }
        case "text/css" {
            $bindat = processCSS($rawdat, basename($fileinfo{path}));
        }
        case /^application\/(javascript|ecmascript)&/ {
            $bindat = processJS($rawdat, basename($fileinfo{path}));
        }
        case /^text\/(plain|richtext|csv)$/ {
            $bindat = processTxt($rawdat, basename($fileinfo{path}));
        }
    }

    if(length($bindat) == 0) {
        print "  raw-reading file $fileinfo{path}\n";
        # assume binary file and read file direct in binmode
        $bindat = read_file($fileinfo{path}, { binmode => ':raw' });
        if($fileinfo{type} eq "application/gzip") {
            $fileinfo{enc} = "gzip";
        } elsif($fileinfo{type} eq "application/x-compress")
        {
            $fileinfo{enc} = "compress"
        } else {
            $fileinfo{enc} = ""
        }
    } else {
        use bytes;
        my $rawlen = length($rawdat);
        my $binlen = length($bindat);
        # use raw data if compressed isn't at least 10% smaller
        if(($rawlen > 0) && ($binlen > ($rawlen * 0.9))) {
            print "  -- compressed version not smaller, using raw data!\n";
            $bindat = $rawdat;
            $fileinfo{enc} = ""
        } else {
            $fileinfo{enc} = "gzip";
        }
    }

    {
        use bytes;
        $fileinfo{len} = length($bindat);
    }

    $fileinfo{hexdat} = hexArray($bindat, 16);
    push(@filelist,\%fileinfo);
}
close FINDSTRM;

open(OUTFILE, ">", $outfile) || die $!;
print OUTFILE '
#ifndef __WEBFLASH_H__
#include "WebFlash.h"
#endif
';

foreach $f (@filelist) {
    printf OUTFILE '
FLASH_ARRAY(uint8_t, %s,
%s
);

', $f->{name}, $f->{hexdat};
}

print OUTFILE '
struct t_websitefiles {;
  const char* path;
  const char* mime;
  const unsigned int len;
  const char* enc;
  const _FLASH_ARRAY<uint8_t>* content;
} files[] = {
';

foreach $f (@filelist) {
    printf OUTFILE '
  {
    .path    = "%s",
    .mime    = "%s",
    .len     = %d,
    .enc     = "%s",
    .content = &%s,
  },', $f->{url}, $f->{type}, $f->{len}, $f->{enc}, $f->{name};
}

print OUTFILE '
};
';
close OUTFILE;

sub processTxt {
    my $txt   = shift @_;
    my $fName = shift @_;
    print "  compressing text in $fName\n";
    $gz->file_name($fName);
    return $gz->zip($txt);

}
sub processHTML {
    my $html  = shift @_;
    my $fName = shift @_;
    my $htmMin;
    if($fName =~ /\.min\./) {
        print "  minified html detected!\n";
        $htmMin = $html;
    } else {
        print "  html minifying $fName\n";
        my $packer = HTML::Packer->init();
        $htmMin = $packer->minify( \$html, { remove_newlines => 1, remove_comments => 1, do_javascript => 'best', do_stylesheet => 'minify' } );
        # don't use minified version if it's not at least 10% smaller
        if(length($htmMin) > (length($html)*0.9)) {
            print "  - minifying didn't help.\n";
            $htmMin = $html;
        }
    }

    $gz->file_name($fName);
    return $gz->zip($htmMin);
}
sub processCSS {
    my $css   = shift @_;
    my $fName = shift @_;
    my $packer = CSS::Packer->init();
    my $cssMin;
    if($fName =~ /\.min\./) {
        print "  minified css detected!\n";
        $cssMin = $css;
    } else {
        print "  css minifying $fName\n";
        $cssMin = $packer->minify(\$css, { compress => 'minify', remove_comments => 1 } );
        # don't use minified version if it's not at least 10% smaller
        if(length($cssMin) > (length($css)*0.9)){
            print "  - minifying didn't help.\n";
            $cssMin = $css;
        }
    }
    $gz->file_name($fName);
    return $gz->zip($cssMin);
}
sub processJS {
    my $js    = shift @_;
    my $fName = shift @_;
    my $jsMin;
    if($fName =~ /\.min\./) {
        print "  minified js detected!\n";
        $jsMin = $js;
    } else {
        print "  javascript minifying $fName\n";
        my $packer = JavaScript::Packer->init();
        my $jsMin = $packer->minify(\$js, { compress => 'best', remove_comments => 1, remove_copyright => 1 } );
        # don't use minified version if it's not at least 10% smaller
        if(length($jsMin) > (length($js)*0.9)) {
            print "  - minifying didn't help.\n";
            $jsMin = $js;
        }
    }
    $gz->file_name($fName);
    return $gz->zip($jsMin);
}

sub hexArray {
    my ($d, $maxCol) = @_;
    if(!($maxCol > 0)) { $maxCol = 12 }; # default to 12 columns
    my @fCol = ();
    my @fRow = ();
    for my $hc (unpack('(H2)*', $d)) {
        push(@fCol, '0x'.$hc);
        if(scalar @fCol >= $maxCol) {
            push(@fRow, join(", ", @fCol));
            @fCol = ();
        }
    }
    return "  " . join(",\n  ", @fRow);
}
