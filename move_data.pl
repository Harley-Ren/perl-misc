#!/usr/bin/env perl

use utf8;
use DBI;
use strict;
use Date::Manip;

# connect
my $dbh = DBI->connect("DBI:mysql:database=rsync;host=127.0.0.1", "root", "mysql", {'RaiseError' => 1});

$dbh->do("set names utf8");

# execute INSERT query
#my $rows = $dbh->do("INSERT INTO users (id, username, country) VALUES (4, 'jay', 'CZ')");
#print "$rows row(s) affected ";

# execute SELECT query
my $galleryId = 15;

my $dirName = "/ftproot/user/fenfatest";
my $sth = $dbh->prepare("select * from `rsync_user`");
$sth->execute();

my $insertStmt = $dbh->prepare("insert into rsync_user_ftp (`user_id`,`ftp_loginid`,`ftp_dir`,
 `disk_space`,`speed_limit`,`zip_supported`,`frozen_tag`,`creator` ,`create_time`,
 `updator`,`last_update_time`) values(?,?,?,?,?,?,?,?,?,?,?)");

# iterate through resultset
# print values
while (my $ref = $sth->fetchrow_hashref()) {
    print "UserID : $ref->{user_id}\n";
    print "ftp_dir: $ref->{ftp_dir}\n";
    print "rsync_dir: $ref->{rsync_dir}\n";
    print "disk_space: $ref->{disk_space}\n";
    #print "ittime:" . ParseDate("epoch " . $ref->{itime}). "\n"; 
    print "itime:" . UnixDate("epoch " . $ref->{itime},"%Y-%m-%d %H:%M:%S") . "\n";
    print "Creator: " . $ref->{ioptr};
    #print "Creator: " . utf8::encode($ref->{ioptr});
    
#     $insertStmt->execute($ref->{user_id}, $ref->{ftp_id},$ref->{ftp_dir},$ref->{disk_space},$ref->{speed_limit},$ref->{tag},$ref->{frozen_tag}
#     ,$ref->{ioptr},UnixDate("epoch " . $ref->{itime},"%Y-%m-%d %H:%M:%S"),$ref->{uoptr} , UnixDate("epoch " . $ref->{utime},"%Y-%m-%d %H:%M:%S"));
    
    $insertStmt->execute($ref->{user_id}, $ref->{ftp_id},$ref->{ftp_dir},$ref->{disk_space},$ref->{speed_limit},$ref->{tag},$ref->{frozen_tag}
    ,$ref->{ioptr},UnixDate("epoch " . $ref->{itime},"%Y-%m-%d %H:%M:%S"),$ref->{uoptr}, UnixDate("epoch " . $ref->{utime},"%Y-%m-%d %H:%M:%S"));
    
    print "---------- \n";
}

# clean up
$dbh->disconnect();
