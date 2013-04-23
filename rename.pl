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
use File::Basename qw/dirname/;

my $encoding;
my $action = "rename";

my $options = GetOptions("encoding=s" => \$encoding,"action:s" => \$action);
print "Encoding: $encoding\n";

if (not $encoding) {
   print "Dest encoding is required !\n"; 
   exit(-1);
}

my $file = shift @ARGV;
print "File: $file\n";

my $encoded_file = encode($encoding,decode("utf-8",$file));
my $encoded_dirname = dirname($encoded_file);

if( lc($action) eq "rename") {
    if(not -e $encoded_dirname) {
        `mkdir -p $encoded_dirname`;
    }

    `ln -s $file $encoded_file`;
    
} elsif (lc($action) eq "delete") {
    if ( -l $encoded_file ) {
        unlink $encoded_file;
    }
}
