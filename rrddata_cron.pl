#!/usr/bin/env perl
# encoding: utf8

#$Id$
# 从数据库中取出xentop的值，并更新到rrd文件中。
#
# Last modified: 2012-11-08 by renhuailin
# 2013-03-12 之前的 判断已运行的进程的脚本有问题，`ps -ef|grep $basename| grep -v $PID | grep -v grep `;
# 这个版本修正了这个问题。
# by renhuailin
use strict;
use English;
use warnings;
use utf8;
use Encode;
use URI::Escape;
use DBI;
use POSIX;
use File::Basename;

#Constants.
#~ use constant DB_XENTOP_CONNECTION => {Host=>"localhost",Database=>"xentop",User=>"root",Password=>"mysql"};
#~ use constant DB_RRDINFO_CONNECTION => {Host=>"localhost",Database=>"ecloud_monitor",User=>"root",Password=>"mysql"};

use constant DB_XENTOP_CONNECTION => {Host=>"172.16.8.75",Database=>"xentop",User=>"xentop",Password=>"china-ops"};

use constant DB_RRDINFO_CONNECTION => {Host=>"localhost",Database=>"ecloud_monitor",User=>"root",Password=>"china-ops"};

my $RRD_TOOLS = "/opt/rrdtool-1.4.7/bin/rrdtool";

sub main() {
	my $basename = basename($0);
	print "$basename \n";
	print "Current process id: $PID \n";
	my $process = `ps -ef|grep $basename| grep -v $PID | grep -v grep | grep perl`;
	if($process) {
		print $process;
		print "There is another process[$process]  running,exit\n";
		exit -1;
	}
	
	#Test xentop database connnection;
	my $dbh = &getXentopDbConnection();
	if(!$dbh) {
		print "Can not connect to database: " . DB_XENTOP_CONNECTION->{Database} . "@" . DB_XENTOP_CONNECTION->{Host} ;
		exit -1;
	} else {
		print "Connect to db successful.\n"
	}
	
	$dbh = &getRRDInfoDbConnection();
	if(!$dbh) {
		print "Can not connect to database: " . DB_RRDINFO_CONNECTION->{Database} . "@" . DB_RRDINFO_CONNECTION->{Host} ;
		exit -1;
	} else {
		print "Connect to db successful.\n"
	}

	&process();
}

## ++++++++++++++++++++++ functions +++++++++++++++++++++ 

sub process() {
	my $last_xentop_id = &get_last_xentop_id();
	print "last_xentop_id = $last_xentop_id\n";
	
	my $data_count = &get_xentop_data_count($last_xentop_id);
	print "Data count: $data_count \n";
	
	my $page_size = 10000;
	my $pages = &calculate_page_count($data_count,$page_size);
	print "Page count: $pages \n";
	for(my $i = 1; $i <= $pages;$i++) {
		my @xentop_data = &get_xentop_data($last_xentop_id,$i,$page_size);

		foreach my $xentop (@xentop_data) {
			printf "id=%d  name=%s time=%s \n",$xentop->{ID},$xentop->{NAME},$xentop->{TIME};
			
			&update_rrd_files($xentop);
			&save_last_xentop_id($xentop->{ID});
			#$last_xentop_id = $xentop->{ID};
		}
	}
	
}

sub calculate_page_count () {
	my ($result_count,$page_size) = @_;
	
	my $page_count;
	if($result_count < $page_size) {
		return 1;
	}
	
	$page_count =  int($result_count / $page_size);
	my $remainder = $result_count % $page_size;
	if ($remainder != 0) {
		$page_count++;
	}
	return $page_count;
}

sub update_rrd_files () {
	my ($xentop) = @_;
	my $instance_sid = $xentop->{NAME};
	
	#Get rrd file path
	my $rrd_file_path = &get_rrd_filepath($instance_sid);
	if($rrd_file_path) {
		&update_cup_rrd($rrd_file_path->{cpu_rrd},$xentop->{insert_time},$xentop->{CPU});
		&update_traffic_rrd($rrd_file_path->{traffic_rrd},$xentop->{insert_time},$xentop->{NETRX},$xentop->{NETTX});
		&update_vbd_rrd($rrd_file_path->{disc_rrd},$xentop->{insert_time},$xentop->{VBD_RD},$xentop->{VBD_WR});
	} else {
		print "there is not rrd file info associate with $instance_sid \n";
	}
}

sub update_cup_rrd() {
	my ($cpu_rrd_filepath,$ltime,$percent) = @_;
	use vars qw($RRD_TOOLS);
	if (not -e $cpu_rrd_filepath) {
	    #printf "task file %s was not found!\n",$cpu_rrd_filepath;
		#exit(-1);
		&create_cpu_rrd($cpu_rrd_filepath);
	}
	my $update_cmd = "$RRD_TOOLS update $cpu_rrd_filepath " . $ltime . ":" . ceil($percent);
	print "$update_cmd\n";
	`$update_cmd`;
}

sub create_cpu_rrd () {
	use vars qw($RRD_TOOLS);
	my ($cpu_rrd_filepath) = @_;
	my $cmd = "$RRD_TOOLS create $cpu_rrd_filepath --step 60 --start 1301587200 DS:cpu_system:GAUGE:180:0:100 RRA:AVERAGE:0.5:1:2880 RRA:AVERAGE:0.5:5:2880 RRA:AVERAGE:0.5:30:1500 RRA:AVERAGE:0.5:120:1000 RRA:AVERAGE:0.5:1440:500 RRA:MIN:0.5:1:2880 RRA:MIN:0.5:5:2880 RRA:MIN:0.5:30:1500 RRA:MIN:0.5:120:1000 RRA:MIN:0.5:1440:500 RRA:MAX:0.5:1:2880 RRA:MAX:0.5:5:2880 RRA:MAX:0.5:30:1500 RRA:MAX:0.5:120:1000 RRA:MAX:0.5:1440:500 RRA:LAST:0.5:1:2880 RRA:LAST:0.5:5:2880 RRA:LAST:0.5:30:1500 RRA:LAST:0.5:120:1000 RRA:LAST:0.5:1440:500";
	`$cmd`;
}

sub update_traffic_rrd() {
	my ($traffic_rrd_filepath,$ltime,$netrx,$nettx) = @_;
	use vars qw($RRD_TOOLS);
	if (not -e $traffic_rrd_filepath) {
		&create_traffic_rrd($traffic_rrd_filepath);
	}
	
	my $update_cmd = "$RRD_TOOLS update $traffic_rrd_filepath " . $ltime . ":" . $netrx . ":" . $nettx;
	`$update_cmd`;
}

sub create_traffic_rrd () {
	use vars qw($RRD_TOOLS);
	my ($traffic_rrd_filepath) = @_;
	my $cmd = "$RRD_TOOLS create $traffic_rrd_filepath --step 60 --start 1301587200 DS:traffic_in:COUNTER:180:U:U DS:traffic_out:COUNTER:180:U:U RRA:AVERAGE:0.5:1:2880 RRA:AVERAGE:0.5:5:2880 RRA:AVERAGE:0.5:30:1500 RRA:AVERAGE:0.5:120:1000 RRA:AVERAGE:0.5:1440:500 RRA:MIN:0.5:1:2880 RRA:MIN:0.5:5:2880 RRA:MIN:0.5:30:1500 RRA:MIN:0.5:120:1000 RRA:MIN:0.5:1440:500 RRA:MAX:0.5:1:2880 RRA:MAX:0.5:5:2880 RRA:MAX:0.5:30:1500 RRA:MAX:0.5:120:1000 RRA:MAX:0.5:1440:500 RRA:LAST:0.5:1:2880 RRA:LAST:0.5:5:2880 RRA:LAST:0.5:30:1500 RRA:LAST:0.5:120:1000 RRA:LAST:0.5:1440:500";
	`$cmd`;
}

sub update_vbd_rrd() {
	my ($vbd_rrd_filepath,$ltime,$vbd_rd,$vbd_wr) = @_;
	use vars qw($RRD_TOOLS);
	if (not -e $vbd_rrd_filepath) {
		&create_vbd_rrd($vbd_rrd_filepath);
	}
	my $update_cmd = "$RRD_TOOLS update $vbd_rrd_filepath " . $ltime . ":" . $vbd_rd . ":" . $vbd_wr;
	`$update_cmd`;
}

sub create_vbd_rrd() {
	use vars qw($RRD_TOOLS);
	my ($vbd_rrd_filepath) = @_;
	my $cmd = "$RRD_TOOLS create $vbd_rrd_filepath --step 60 --start 1301587200 DS:vbd_read:COUNTER:180:U:U DS:vbd_write:COUNTER:180:U:U RRA:AVERAGE:0.5:1:2880 RRA:AVERAGE:0.5:5:2880 RRA:AVERAGE:0.5:30:1500 RRA:AVERAGE:0.5:120:1000 RRA:AVERAGE:0.5:1440:500 RRA:MIN:0.5:1:2880 RRA:MIN:0.5:5:2880 RRA:MIN:0.5:30:1500 RRA:MIN:0.5:120:1000 RRA:MIN:0.5:1440:500 RRA:MAX:0.5:1:2880 RRA:MAX:0.5:5:2880 RRA:MAX:0.5:30:1500 RRA:MAX:0.5:120:1000 RRA:MAX:0.5:1440:500 RRA:LAST:0.5:1:2880 RRA:LAST:0.5:5:2880 RRA:LAST:0.5:30:1500 RRA:LAST:0.5:120:1000 RRA:LAST:0.5:1440:500";
	`$cmd`;
}

sub getXentopDbConnection {
	#printf "DBI:mysql:database=" . DB_CONNECTION->{Database} . ";host=" . DB_CONNECTION->{Host} . "\n";
	
	my $dbh = DBI->connect_cached("DBI:mysql:database=" . DB_XENTOP_CONNECTION->{Database} . ";host=" . DB_XENTOP_CONNECTION->{Host}, DB_XENTOP_CONNECTION->{User},DB_XENTOP_CONNECTION->{Password}, {'RaiseError' => 1});
	
	$dbh->do("set names utf8");
	return $dbh;
}

sub getRRDInfoDbConnection {
	#printf "DBI:mysql:database=" . DB_CONNECTION->{Database} . ";host=" . DB_CONNECTION->{Host} . "\n";
	
	my $dbh = DBI->connect_cached("DBI:mysql:database=" . DB_RRDINFO_CONNECTION->{Database} . ";host=" . DB_RRDINFO_CONNECTION->{Host}, DB_RRDINFO_CONNECTION->{User},DB_RRDINFO_CONNECTION->{Password}, {'RaiseError' => 1});
	
	$dbh->do("set names utf8");
	return $dbh;
}

#Get RRD files by instance SID
sub get_rrd_filepath() {
	my ($instance_sid) = @_;
	my $dbh = &getRRDInfoDbConnection();
	
    my $sql = "select * from rrdinfo where `instance_sid` = ?;";
    my $sth = $dbh->prepare($sql);
    $sth->execute($instance_sid);
    my $hashref;
    if ( my $ref = $sth->fetchrow_hashref() ) {
        $hashref = $ref;
    }
    
    $sth->finish();
	# clean up
	$dbh->disconnect();
    return $hashref;
}

sub get_last_xentop_id() { 
	my $dbh = &getRRDInfoDbConnection();
	my $last_xentop_id;
    my $bookmark_name = "xentop_id";
    my $sql = "SELECT `id`,`bm_name`,`position`,`last_update_time` FROM `bookmarks` where `bm_name` = ? ;";
    my $sth = $dbh->prepare($sql);
    $sth->execute($bookmark_name);
    
    if ( my $ref = $sth->fetchrow_hashref() ) {
        $last_xentop_id = $ref->{position};
    } else {
		#Insert bookmark;
		&insert_bookmark();
		$last_xentop_id = 0;
	}
	$sth->finish();
	# clean up
	$dbh->disconnect();

    return $last_xentop_id;
}

sub save_last_xentop_id() {
	my ($last_xentop_id) = @_;
	my $dbh = &getRRDInfoDbConnection();
   
    my $sql = "UPDATE `bookmarks`  SET `position` = ?,`last_update_time` = now() WHERE  `bm_name` = ?";
    my $sth = $dbh->prepare($sql);
    $sth->execute($last_xentop_id,"xentop_id");
    
	# clean up
	$dbh->disconnect();
}


sub insert_bookmark() {
	my ($last_xentop_id) = @_;
	my $dbh = &getRRDInfoDbConnection();
	my $sql = "insert into `bookmarks`(`bm_name`,`position`,`last_update_time`) values(?,0,now());";
    #my $sql = "UPDATE `bookmarks`  SET `position` = ?,`last_update_time` = now() WHERE  `bm_name` = ?";
    my $sth = $dbh->prepare($sql);
    $sth->execute("xentop_id");
    
	# clean up
	$dbh->disconnect();
}


sub get_xentop_data {
	my ($last_xentop_id,$page,$page_size) = @_;
    my @data = ();
    
    my $dbh = &getXentopDbConnection();
    my $sql = "SELECT `ID`,`TIME`,UNIX_TIMESTAMP(`TIME`) as `insert_time`,`HOSTNAME`,`IP`,`NAME`,`CPU`,`MAXMEM`,`VCPUS`,`NETTX`,`NETRX`,`VBD_OO`,`VBD_RD`,`VBD_WR` FROM `S_XENTOP` where `ID` > ? order by `ID`  limit " . (($page - 1) * $page_size) . "," . $page_size;
    
    my $sth = $dbh->prepare($sql);
    $sth->execute($last_xentop_id);
    
    while( my $ref = $sth->fetchrow_hashref()) {        
        push @data,$ref;
    }
    
    $sth->finish();
	# clean up
	$dbh->disconnect();

    return @data;
}

sub get_xentop_data_count {
	my ($last_xentop_id) = @_;
    my $count;
    
    my $dbh = &getXentopDbConnection();
    my $sql = "SELECT count(`ID`) as iCount FROM `S_XENTOP` where `ID` > ? ;";
    my $sth = $dbh->prepare($sql);
    $sth->execute($last_xentop_id);
    
    if ( my $ref = $sth->fetchrow_hashref() ) {
        $count = $ref->{iCount};
    }
    
    $sth->finish();
	# clean up
	$dbh->disconnect();

    return $count;
}

&main();

