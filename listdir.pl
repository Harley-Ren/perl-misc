#!/usr/bin/env perl

# $Id$
#
# 列出目录下的所有文件，并打印出它的md5值。
#
# Author Harley Ren. 2010

use strict;
use warnings;

#my $some_dir = "/home/harley/workspaces/perl/";
my $some_dir = shift || die "Argument missing: directory name\n";

opendir(DIR, $some_dir) || die "can't opendir $some_dir: $!";
my @files = readdir(DIR);
closedir DIR;

foreach my $file (@files) {
    next if ($file =~ "(.*?).md5") or (-d $file);
    my $fullPathFilename = $some_dir . $file;
    my $fileSize = -s $fullPathFilename;
    my $md5sum = `md5sum '$fullPathFilename' |gawk '{print \$1}' `;
    chomp $md5sum;
    #print $file . "\n";
    #printf "md5sum: %s\t File: %s \tfilesize: %d\n",$md5sum,$fullPathFilename,$fileSize;
    printf "%s\t%s\t%d\n",$md5sum,$fullPathFilename,$fileSize;
} 
