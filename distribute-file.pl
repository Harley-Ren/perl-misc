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
use Getopt::Long;

#Constants.
use constant DB_CONNECTION => {Host=>"127.0.0.1",Database=>"cdn_gslb",User=>"root",Password=>"mysql"};

#File contains servers the file to be send.
my $server_file;
my $ip_column_number = 0;
my $user = "root";
my $password = "DVAspFlH";

#read command line arguments
my $options = GetOptions("file|f=s" => \$server_file,
                            "--ip-column-number:i" => \$ip_column_number,
                            "--user|u:s" => \$user,
                            "--password|p:s" => \$password);

my $local_file = shift @ARGV;
my $remote_dir = shift @ARGV;

printf ("local_file: %s\n",$local_file);
printf ("remote_dir: %s\n",$remote_dir);
printf ("File path: %s\n",$server_file);
printf ("ip_column_number: %s\n",$ip_column_number);
printf ("user: %s\n",$user);
printf ("password: %s\n",$password);

die("File $server_file was not found!") if ! -e $server_file;
die("File $server_file was not a text file!") if ! -f $server_file;

open SERVER_FILE ,$server_file;

while(<SERVER_FILE>) {
    chomp;
    printf "%s\n", $_;
    my @account_info = split /\s/,$_;
    
    my $size = @account_info;
    printf  "size of account info array : %i\n", $size; 
    die("invalid argument :ip-column-number=$ip_column_number,the file you specified have $size column!") if ($ip_column_number < 0 || $ip_column_number > ($size - 1)) ;
       
    my $serverIP = $account_info[$ip_column_number];
    
    #use embed user and password.:(
    if ($user =~ /\s+/) {
        ($user,$password) = split /\//,"root/DVAspFlH";
    }
    
    #execute uanme -a at remote server.
    #&showUname($serverIP,$user,$password);
    
    #copy local file to servers use scp;
    &scpToServer($serverIP,$user,$password,$local_file,$remote_dir);
    
    #~ print "login to server $serverIP\n";
    #~ my $sshconn = Net::OpenSSH->new("$user\@$serverIP",password=>$password);
    #~ $sshconn->error and die "Couldn't establish SSH connection: ". $sshconn->error;
    
}

close SERVER_FILE;

# ============ subroutines ============

sub showUname {
    my ($host,$user,$password) = @_;
    my $exp = Expect->spawn("ssh root\@$host 'uname -a'");    
    $exp->raw_pty(1);
    #$exp->debug(3);
    #$exp->exp_internal(1);
    my $timeout = 30;
    $exp->expect($timeout,
               [ qr/\(yes\/no\)\?\s*\r?$/ => sub { my $exp = shift;
                                     $exp->send("yes\n");
                                     exp_continue; } ],
               [ qr/\spassword.*\r?$/ => sub { my $exp = shift;
                                     $exp->send("$password\n");
                                     }],
                [ "eof" => sub {} ]
              );
    #~ #printf "Before: %s\n",$exp->before();
    #~ #printf "After: %s\n",$exp->after();
    $exp->soft_close();
}

##
#  Connect to server use expect.
#@param host        host name or IP
#@param user        login ID
#@param password    password
#
sub scpToServer {
    
    #
    my ($host,$user,$password,$local_file,$remote_dir) = @_;
        
    #~ my $scpe = Net::SCP::Expect->new(host=>$host, user=>$user, password=>$password,timeout=>60,verbose=>1,auto_yes=>1);
    #~ $scpe->scp($local_file,$remote_dir);
    print("scp $local_file $user\@$host:$remote_dir\n");
    my $ssh = Net::OpenSSH->new($host,user=>$user, password=>$password);
    $ssh->scp_put({quiet =>0},$local_file,$remote_dir);
}

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
