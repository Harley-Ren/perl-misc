#!/usr/bin/env perl

#$Id$
# 从10.10.11.51中获取服务器列表
#

use strict;
use warnings;
use utf8;
use Encode;
use DBI;
use Expect;

#Constants.
use constant DB_CONNECTION => {Host=>"127.0.0.1",Database=>"cdn_fds",User=>"root",Password=>"21vianet"};
#~ use constant DB_CONNECTION => {Host=>"10.10.10.51",Database=>"rsync_new",User=>"sms_alert",Password=>"1q2w3e4r"};

use Getopt::Long;

#~ my $server_file = shift @ARGV;
#~ 
#~ die("File $server_file was not found!") if ! -e $server_file;
#~ die("File $server_file was not a text file!") if ! -f $server_file;



# ============ subroutines ============

sub getDbConnection {
	#printf "DBI:mysql:database=" . DB_CONNECTION->{Database} . ";host=" . DB_CONNECTION->{Host} . "\n";
	
	my $dbh = DBI->connect_cached("DBI:mysql:database=" . DB_CONNECTION->{Database} . ";host=" . DB_CONNECTION->{Host}, DB_CONNECTION->{User},DB_CONNECTION->{Password}, {'RaiseError' => 1});
	
	$dbh->do("set names utf8");
	return $dbh;
}

sub get_servers {
    my @servers= ();
    
    my $dbh = &getDbConnection();
    my $sql = "select * from  `rsync_server`";                
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    
    while( my $ref = $sth->fetchrow_hashref()) {
        
        push @servers,$ref;
    }
    return @servers;
}

my @servers = &get_servers();
my $count = @servers;
printf "count = %d\n",$count;
foreach my $server (@servers) {
    #printf "%s\t%s\t%s\t%s\n",$server->{name},$server->{ip},$server->{user},$server->{passwd};
    printf "<server name=\"%s\" ip=\"%s\" loginid=\"%s\" passwd=\"%s\"/>\n",$server->{name},$server->{cache_ip},$server->{user},$server->{passwd};
}
