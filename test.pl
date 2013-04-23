#!/usr/bin/env perl

#$Id$
# 从文件中读取要分发的服务器，然后把本地的文件下发到这些服务器的指定目录下。
#

use strict;
use warnings;
use utf8;
use Encode;
use URI::Escape;
use LWP;
use DBI;
use Net::OpenSSH;
use Expect;

my %filemd5 = ("/siteroot/api.vips100.com/BeetleFramework-1.3.7.zip"=>"3953cf8aa5f0aa33e28f826e8bea4210",
"/siteroot/api.vips100.com/CT_HW_EVDO_Driver_V2.1.0.zip"=>"9eb00167c72fb834065fd424f97847b3","/siteroot/api.vips100.com/httpwatchpro-v4.0.54.rar"=>"1e8a85aa42a6fe4b9508ab3f3a924aa4",
"/siteroot/api.vips100.com/pingan001.rar"=>"63881351bbf4c5aa960010ec47f470d4",
"/siteroot/api.vips100.com/PC_Setup4000.exe"=>"c638bcdbb34992084f0c464d803c4d46",
"/siteroot/api.vips100.com/UU_Setup4000.exe"=>"99d3bc170ef773e290a6b0c4ed9f4ea9");


open SERVER_FILE ,"/home/harley/workspaces/perl/rtask.log";

while(<SERVER_FILE>) {
    chomp;

    my @server_info = split /\s/,$_;
    printf "md5: %s \t filename: %s\n", $server_info[0], $server_info[1];
    
    if(exists $filemd5{$server_info[1]}) {
        printf "md5: %s \t filename: %s\n", $filemd5{$server_info[1]}, $server_info[1];
    
        if(! $server_info[0] eq $filemd5{$server_info[1]}) {
            print "md5hash is not identical\n";
        }
    } else {
        
    }
    
}

close SERVER_FILE;
