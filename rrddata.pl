#!/usr/bin/env perl

#$Id$
# 从文件中读取要分发的服务器，然后把本地的文件下发到这些服务器的指定目录下。
#

use strict;
use warnings;
use utf8;
use Encode;
use URI::Escape;
use DBI;
use POSIX;
#Constants.
use constant DB_CONNECTION => {Host=>"192.168.234.63",Database=>"ecloud_fz_online",User=>"root",Password=>"china-ops"};



#File contains servers the file to be send.

                            
my $rrd_file = shift @ARGV;

die("File $rrd_file was not found!") if ! -e $rrd_file;


my @values = & get_cpu_data();
foreach  my $data (@values) {
	my $update_cmd = "rrdtool update $rrd_file " . $data->{insert_time} . ":" . ceil($data->{CPU});
	print $update_cmd . "\n";
	`$update_cmd`;
}
	
sub getDbConnection {
	#printf "DBI:mysql:database=" . DB_CONNECTION->{Database} . ";host=" . DB_CONNECTION->{Host} . "\n";
	
	my $dbh = DBI->connect_cached("DBI:mysql:database=" . DB_CONNECTION->{Database} . ";host=" . DB_CONNECTION->{Host}, DB_CONNECTION->{User},DB_CONNECTION->{Password}, {'RaiseError' => 1});
	
	$dbh->do("set names utf8");
	return $dbh;
}


sub get_cpu_data {
    my @data = ();
    
    my $dbh = &getDbConnection();
    my $sql = "select `NAME`,CPU,IP,`TIME`,UNIX_TIMESTAMP(`TIME`)  as `insert_time`  from S_XENTOP where `NAME`= 'i-3A91063A' and `TIME` > '2011-04-08 00:00:00' order by ID asc;";
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    
    while( my $ref = $sth->fetchrow_hashref()) {
        
        push @data,$ref;
    }
	# clean up
	$dbh->disconnect();

    return @data;
}



