#!/usr/bin/env perl

#$Id$
#从命令行接收要分发的BIND配置文件的名称，然后把它们scp到远程主机上。

use utf8;
use strict;
use warnings;
use Encode;

use URI::Escape;
use LWP;
use DBI;

#Constants.
use constant DB_CONNECTION => {Host=>"127.0.0.1",Database=>"cdn_gslb",User=>"root",Password=>"mysql"};

sub getDbConnection {
	#printf "DBI:mysql:database=" . DB_CONNECTION->{Database} . ";host=" . DB_CONNECTION->{Host} . "\n";
	
	my $dbh = DBI->connect_cached("DBI:mysql:database=" . DB_CONNECTION->{Database} . ";host=" . DB_CONNECTION->{Host}, DB_CONNECTION->{User},DB_CONNECTION->{Password}, {'RaiseError' => 1});
	
	$dbh->do("set names utf8");
	return $dbh;
}

sub distribute {
    my ($config_file) = @_;
    my $dbh = &getDbConnection();
    my $sth = $dbh->prepare("select * from dns_server");
    $sth->execute();

    # iterate through resultset
    # print values
    while (my $row = $sth->fetchrow_hashref()) {
        my $ip_address = $row->{ip_address};
        print "/usr/bin/scp $config_file root\@$ip_address:/root";
        print `/usr/bin/scp $config_file root\@$ip_address:/root`;
        print "<br/>";
    }
}

print "======================================================\n";
my $arg1 = shift @ARGV;
&distribute($arg1);

