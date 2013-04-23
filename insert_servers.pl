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
use Getopt::Long;
use Pod::Usage;

#Constants.
use constant DB_CONNECTION => {Host=>"127.0.0.1",Database=>"cdn_fds",User=>"root",Password=>"21vianet"};



#File contains servers the file to be send.
my $ip_column_number = 0;
my $hostname_column_number = 0;
my $interval_ip_column_number;

my $user = "root";
my $password = "DVAspFlH";
my $test = 0;
my $showUsage;


#read command line arguments
my $options = GetOptions( "ip-column-number|i=i" => \$ip_column_number,
                            "hostname-column-number|n=i" => \$hostname_column_number,
                            "internal-ip-column-number=i"  => \$interval_ip_column_number,
                            "user|u:s" => \$user,
                            "password|p:s" => \$password,
                            "help" => \$showUsage,
                            "test-only" => \$test
                            );
                            
my $server_file = shift @ARGV;

printf ("ip_column_number: %s\n",$ip_column_number);
printf ("hostname_column_number: %s\n",$hostname_column_number);
printf ("internal-ip-column-number: %s\n",$interval_ip_column_number);
printf ("user: %s\n",$user);
printf ("password: %s\n",$password);
printf ("test:$test\n");

pod2usage(1) if $showUsage;

die("File $server_file was not found!") if ! -e $server_file;
die("File $server_file was not a text file!") if ! -f $server_file;

open SERVER_FILE ,$server_file;

while(<SERVER_FILE>) {
    chomp;
    #printf "%s\n", $_;
    next if (! $_);
        
    my @server_info = split /\s+/,$_;
    
    my $size = @server_info;
    #printf  "size of account info array : %i\n", $size; 
    die("invalid argument :ip-column-number=$ip_column_number,the file you specified have $size column!") if ($ip_column_number < 0 || $ip_column_number > ($size - 1)) ;
    
    die("invalid argument :hostname-column-number=$hostname_column_number,the file you specified have $size column!") if ($hostname_column_number < 0 || $hostname_column_number > ($size - 1)) ;
    
    die("invalid argument :interval_ip_column_number=$hostname_column_number,the file you specified have $size column!") if ($interval_ip_column_number < 0 || $interval_ip_column_number > ($size - 1)) ;
        
    my $hostname = $server_info[$hostname_column_number];
    my $serverIP = $server_info[$ip_column_number];
    my $internalIP = $server_info[$interval_ip_column_number];
    #test existence of the server to be inserted into.
    #printf "IP: %s\t hostname: %s\t User: %s\t Password: %s\n", $serverIP,$hostname,$user,$password;    
    printf "<server name=\"%s\" ip=\"%s\" loginid=\"%s\" passwd=\"%s\"/>\n",$hostname, $serverIP,$user,$password;   
    
    if ($test) {
        printf "IP: %s\t Internal-IP: %s\t hostname: %s\t User: %s\t Password: %s\n", $serverIP,$internalIP,$hostname,$user,$password;
    } else {
        if(!&exitInDb($serverIP)) {
            printf "%s not in database;\n", $serverIP;
            &insertIntoDb($serverIP,$internalIP,$hostname,$user,$password);
        } else {
            printf "%s already in database;\n", $serverIP;
        }
    }
    
    
}

close SERVER_FILE;

# ============ subroutines ============

sub getDbConnection {
	#printf "DBI:mysql:database=" . DB_CONNECTION->{Database} . ";host=" . DB_CONNECTION->{Host} . "\n";
	
	my $dbh = DBI->connect_cached("DBI:mysql:database=" . DB_CONNECTION->{Database} . ";host=" . DB_CONNECTION->{Host}, DB_CONNECTION->{User},DB_CONNECTION->{Password}, {'RaiseError' => 1});
	
	$dbh->do("set names utf8");
	return $dbh;
}

sub exitInDb {
    my ($serverIP) = @_;
    my $dbh = &getDbConnection();
    my $sth = $dbh->prepare("select COUNT(id) as iCount from `rsync_server`  where ip = ?");
    $sth->execute($serverIP);

    # iterate through resultset
    # print values
    if (my $row = $sth->fetchrow_hashref()) {
        return $row->{iCount};
    } else {
        return 0;
    }
}


sub insertIntoDb {
    my ($serverIP,$internalIP,$hostname,$user,$password) = @_;
    my $dbh = &getDbConnection();
    my $sql = "INSERT INTO 
                  `rsync_server`
                (
                  `name`,
                  `ip`,
                  `cache_ip`,
                  `rsync_server_id`,
                  `user`,
                  `passwd`,
                  `sync_dir`,
                  `found_time`,
                  `tag`
                ) 
                VALUE (
                  ?,
                  ?,
                  ?,
                  0,
                  ?,
                  ?,
                  '/siteroot',
                  unix_timestamp(),
                  0
                );";
                
    my $sth = $dbh->prepare($sql);
    $sth->execute($hostname,$serverIP,$internalIP,$user,$password);
}


 __END__

=head1 NAME

insert_servers - read servers from given file and insert them to DB.

=head1 SYNOPSIS

insert_servers [options] [server_file]

=head1 OPTIONS

=over 8

=item B<--ip-column-number >

IP column number in servers file.


=item B<--hostname-column-number >

hostname column number in servers file.


=item B<--internal-ip-column-number>

internal IP column number in servers file.



=item B<--user>

user name for all servers.

=item B<--password >

password for all servers.

=item B<--test-only>

Just show fileds parse from Server file,do not insert to DB.

=item B<--help>

brief help message.

=back

=head1 DESCRIPTION
    read servers from given file and insert them to DB.
=cut
