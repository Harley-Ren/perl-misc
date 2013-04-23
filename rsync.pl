#!/usr/bin/env perl

##
#$Id$
# 
##

use strict;
use warnings;
use utf8;
use Encode;
use Getopt::Long;

my $encoding = "UTF-8";
my $relativeFilePath;
my $rsync_server;

my $options = GetOptions("encoding:s" => \$encoding,"rsync-server|server=s" => \$rsync_server,);
print "Encoding: $encoding\n";

if (not $rsync_server) {
   print "rsync server is missing!\n"; 
   exit(-1);
}

$relativeFilePath = shift @ARGV;
print "File: $relativeFilePath\n";

if (not uc($encoding) eq "UTF-8") {
    $relativeFilePath = encode("GBK",decode("utf-8",$relativeFilePath));
}

print "File: $relativeFilePath\n";

my $cmd = "rsync --list-only " . $rsync_server . "::siteroot/$relativeFilePath";
my $output = `$cmd`;

print "rsync output: $output\n";
exit(0);

