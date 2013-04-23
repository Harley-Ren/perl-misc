#!/usr/bin/env perl
#$Id$
use utf8;
use strict;
use warnings;
use Encode;

use URI::Escape;

my $file = "测试.txt";

#转成gbk编码
$file = encode("gbk",decode("utf-8",$file));

my $encodeFilename = uri_escape($file);

printf "%s\n",$encodeFilename;

