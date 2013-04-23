#!/usr/bin/env perl

use utf8;
use strict;
#use Net::SCP::Expect;
use Expect;

#~ my $scpe = Net::SCP::Expect->new(host=>'10.10.11.24', user=>'root', password=>'21vianet',timeout=>30);
#~ $scpe->scp('/tmp/dns_config-2009-09-29-14-33-34.tar.gz','/root'); # 'file' copied to 'host' at '/some/dir'

my $exp = Expect->spawn('ssh root@10.10.11.24 pwd');
$exp->raw_pty(1);
#~ $exp->debug(3);
#~ $exp->exp_internal(1);
my $timeout = 30;
$exp->expect($timeout,
           [ qr/\(yes\/no\)\?\s*\r?$/ => sub { my $exp = shift;
                                 $exp->send("yes\n");
                                 exp_continue; } ],
           [ qr/\spassword.*\r?$/ => sub { my $exp = shift;
                                 $exp->send("21vianet\n");
                                 }  ],
            [ "eof" => sub {} ]
          );
#~ printf "Before: %s\n",$exp->before();
#~ printf "After: %s\n",$exp->after();
$exp->soft_close();
