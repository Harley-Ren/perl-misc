#!/usr/bin/env perl

#@author Harley Ren.

use utf8;
use strict;
use warnings;
use Encode;

use URI::Escape;
#use URI::Escape qw( uri_escape_utf8 );
use LWP;
use DBI;

#Constants.
use constant DB_CONNECTION => {Host=>"127.0.0.1",Database=>"cdn_fds",User=>"root",Password=>"21vianet"};
#use constant DB_CONNECTION => {Host=>"10.10.10.51",Database=>"rsync_new",User=>"sms_alert",Password=>"1q2w3e4r"};

#Get DB Connection
sub getDbConnection {
	my $dbh = DBI->connect_cached("DBI:mysql:database=" . DB_CONNECTION->{Database} . ";host=" . DB_CONNECTION->{Host}, DB_CONNECTION->{User},DB_CONNECTION->{Password}, {'RaiseError' => 1});
	
	$dbh->do("set names utf8");
	return $dbh;
}

#Send SMS message to specific mobile.
sub send_sms() {
    my($mobile,$message) = @_;
    my $ua = LWP::UserAgent->new;
    my $url = "http://59.151.19.71/smsmg/sms.php";
    $message = encode("gbk",$message);
    $message= uri_escape($message);
    my $params = {PROJECT_ID=>"30",UNAME=>"21cdn",MOBILE=>$mobile,TEXT=>$message};
    printf("Send message:%s to %s\n",$message,$mobile);
    #printf("$url");
    $ua->post($url,$params);
    #$ua->post($url);
}

my $dbh = &getDbConnection();

my $sql = <<END;
SELECT distinct a.`id`,a.`ftp_id`, e.`name` as `customer_name` , `filename`,`filesize`, `filemd5`, `sync_operation`, `state`, 
  d.`sync_expiration`,  unix_timestamp(a.`create_time`) as `create_time`, `sync_finished_time` 
FROM  `rsync_ftp_files` a 
join rsync_in_process b on a.id = b.`sync_file_id`
join `rsync_user_ftp` d on a.`ftp_id` = d.`ftp_id`
join `rsync_entry` e on d.`user_id` = e.`user_id` 
where a.`ftp_id` > 0 and  a.`sync_finished_time` is null
END

my $sth = $dbh->prepare($sql);
$sth->execute();

my $current_time = time;

#timeout is half an hour.
#my $timeout = 30 * 60;

my @mobiles = qw/13801200407 13801200408/;

my %abnormal_files;

while (my $row = $sth->fetchrow_hashref()) {
    printf("%s - %i\n",$row->{customer_name},$row->{sync_expiration});    
    
    my $timeout = $row->{sync_expiration};    
    if(($current_time - $row->{create_time}) > $timeout) {
        if( exists ($abnormal_files{$row->{customer_name}})) {
            my $count = $abnormal_files{$row->{customer_name}};
            $count = $count + 1;
            $abnormal_files{$row->{customer_name}} = $count;
        } else {
             $abnormal_files{$row->{customer_name}} = 1;
        }
    }
}

if(keys %abnormal_files) {
    my $message = "FTP同步系统告警：";

    while(my ($user,$count) = each %abnormal_files) {
        print "$user = $count \n";
        $message .= Encode::decode_utf8( $user ) . "有${count}个文件,";
    }

    $message .= "同步超时，请速查看！";
    print "$message\n";

    foreach my $mobile (@mobiles) {
        printf "Sent message %s to user %s\n",$message,$mobile;
        &send_sms($mobile,$message);
    }
}
