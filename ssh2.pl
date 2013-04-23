#!/usr/bin/env perl

use Net::SSH2;
use strict;

my $ssh2 = Net::SSH2->new();

$ssh2->connect("10.10.11.24") or die "Can not connect to remote server.";
if($ssh2->auth_password('root',"21vianet")) {
    #do something.
    my $chan = $ssh2->channel();
    my $result = $chan->exec("ls ~/gnome-sshman.py");
    
    my($len, $buff);
    while($len = $chan->read($buff, 1024)) {
        print $buff;
    }
    $chan->close;
}