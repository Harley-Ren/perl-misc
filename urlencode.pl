#!/usr/bin/env perl

#此文件接受shell脚本传过来的inotify事件的参数，确认用户的数据文件和.md5均已上传，把文件转成正确的编码，
#并进行URLEncode之后转发给中心tomcat处理。
#当中心tomcat宕机时，本程序把事件记录到数据库中，以后中心tomcat恢复后处理;
use utf8;
use strict;
use warnings;
use Encode;

use URI::Escape;
use LWP;
use DBI;
#use Date::Manip;

#use POSIX qw/tzset/;

#Constants.
use constant FTP_ROOT_DIR => "/home/jacky/MyFiles/temp/";
use constant SYNC_STATE_NEED_SYNC => 0;
use constant SYNC_OPERATION => {Add=>0,Rename=>1,Delete=>2};

#
#If this script can not pass INotify Event to java servlet,
#we must insert it to DB for later process by java.
#
sub processInotifyEvent() {
    my ($watchedDir,$file,$event) = @_;
	if ($watchedDir =~ /^\/home\/jacky\/MyFiles\/temp\/(.*)/) {
		print "valid dir! \n";

		print "$1\n";
		my @paths = split(/\//,$1,2);

		my $domain = $paths[0];
		print "Domain: $paths[0] \n";
		my $ftpId = &getFtpIdByDomain(FTP_ROOT_DIR . $domain);
		printf "FTP id: %d \n",$ftpId;
		my $relatvieFilePath = $1 . $file;

		my $fullPathFile = $watchedDir . $file;
		
		my $eventID = 0;
		if ($event =~ "(.*?)CLOSE_WRITE.*") {
			#there should be a file to be distributed and <filename>.md5 file in the same dir.otherwise do nothing.
			if(! &checkMd5sum($watchedDir,$file)) {
				return;
			}	
			&processCloseEvent($ftpId,$relatvieFilePath);
		} elsif ($event =~ "(.*?)DELETE.*" ) {
			&processDeleteEvent($ftpId,$relatvieFilePath);
		} elsif ($event =~ "(.*?)MOVED_TO.*" ) {
			if(! &checkMd5sum($watchedDir,$file)) {
				return;
			}
			&processCloseEvent($ftpId,$relatvieFilePath);
		} elsif ($event =~ "(.*?)MOVED_FROM.*" ) {
			&processDeleteEvent($ftpId,$relatvieFilePath);
		}		
				
	} else {
		printf "%s not match",$watchedDir;
	}
}

sub processCloseEvent {
	my ($ftpId,$relativeFilePath) = @_;
	my $fullPathFile = FTP_ROOT_DIR . $relativeFilePath;
	if(-f -e $fullPathFile) {
		#It's a file and exists.
		#insert this to DB;
		my $fileSize = -s $fullPathFile;

		#calculate md5sum value.
		my $md5sum =`md5sum $fullPathFile |gawk '{print \$1}' `;
		chomp($md5sum);
		printf "Size: %d,MD5Sum: %s\n",$fileSize,$md5sum;

		#does this file exist in DB?

		my $md5sumInDB = &getMd5sumInDB($ftpId,$relativeFilePath);
		
		#my $operation = &existInDB($relativeFilePath,$md5sum);
		if (! $md5sumInDB  eq "") {			
			&updateMd5sumOperationState($ftpId,$relativeFilePath,$md5sum,SYNC_OPERATION->{Add},SYNC_STATE_NEED_SYNC);
			#&updateAddState($ftpId,$relativeFilePath);
		} else {
			&insertEvent2DB($ftpId,$relativeFilePath,$fileSize,$md5sum,SYNC_OPERATION->{Add});
		}
	}
}

sub processDeleteEvent {	
	my ($ftpId,$relativeFilePath) = @_;
	my $fullPathFile = FTP_ROOT_DIR . $relativeFilePath;

	if ($relativeFilePath =~ "(.*?).md5") {
		print "Delete a .md5 file:$fullPathFile\n";
		return;
	}
	
	
    #does this file exit in DB?
	if (not &exitInDBFtpFilename($ftpId,$relativeFilePath)) {
		&insertEvent2DB($ftpId,$relativeFilePath,0,"empty",SYNC_OPERATION->{Delete});
	} else {
		&updateDeleteState($ftpId,$relativeFilePath);
	}
}

#
#Test whether there is record with specified RelativeFilePath and md5sum in database .
# if it exists return the last operation of it.otherwise return -100;
sub existInDB {
	my ($relativeFilePath,$md5sum) = @_;
	
	my $dbh = &getDbConnection();
	my $sth = $dbh->prepare("select sync_operation from `rsync_ftp_files` where filename = ? and filemd5 = ?");
	$sth->execute($relativeFilePath,$md5sum);

	my $state = -100;
	if(my $ref = $sth->fetchrow_hashref()) {
		print "there is a row!!!!";
		$state = $ref->{sync_operation};
		print "State : $state\n";
	}
	printf "select sync_operation from `rsync_ftp_files` where filename = '%s' and filemd5 = '%s'\n",$relativeFilePath,$md5sum;
	print "State : $state\n";
	
	# clean up
	$sth->finish;
	$dbh->disconnect();
	return $state;
}


#
#Test whether there is record with specified RelativeFilePath and md5sum in database .
# if it exists return the last operation of it.otherwise return -100;
sub getMd5sumInDB {
	my ($ftpId,$relativeFilePath) = @_;
	
	my $dbh = &getDbConnection();
	my $sth = $dbh->prepare("select filemd5 from `rsync_ftp_files` where ftp_id = ? and filename = ?");
	$sth->execute($ftpId,$relativeFilePath);

	my $md5sum = "";
	if(my $ref = $sth->fetchrow_hashref()) {
		print "there is a row!!!!";
		$md5sum = $ref->{filemd5};
		print "md5sum in db : $md5sum\n";
	}
	
	# clean up
	$sth->finish;
	$dbh->disconnect();
	return $md5sum;
}


sub exitInDBFtpFilename {
	my ($ftpId,$relativeFilePath) = @_;
	
	my $dbh = &getDbConnection();

	my $sth = $dbh->prepare("select count(id) as iCount from `rsync_ftp_files` where ftp_id = ? and filename = ?");
	$sth->execute($ftpId,$relativeFilePath);

	my $count = 0;
	if(my $ref = $sth->fetchrow_hashref()) {
		$count = $ref->{iCount};
	}
	# clean up
	$sth->finish;
	$dbh->disconnect();
	return $count > 0;
}




sub updateDeleteState {
	my ($ftpId,$relativeFilePath) = @_;
	
	my $dbh = &getDbConnection();
	my $sth = $dbh->prepare("update rsync_ftp_files set sync_operation = ? ,state = 0 where ftp_id = ? and  filename= ?");
	$sth->execute(SYNC_OPERATION->{Delete},$ftpId,$relativeFilePath);

	# clean up
	$sth->finish;
	$dbh->disconnect();
}



sub updateOperationState {
	my ($ftpId,$relativeFilePath,$oper) = @_;
	
	my $dbh = &getDbConnection();
	my $sth = $dbh->prepare("update rsync_ftp_files set sync_operation = ? ,state = ? where ftp_id = ? and  filename= ?");
	$sth->execute($oper,SYNC_STATE_NEED_SYNC,$ftpId,$relativeFilePath);	

	# clean up
	$sth->finish;
	$dbh->disconnect();
}


sub updateMd5sumOperationState {
	my ($ftpId,$relativeFilePath,$md5sum,$oper,$state) = @_;
	
	my $dbh = &getDbConnection();
	my $sth = $dbh->prepare("update rsync_ftp_files set filemd5= ?, sync_operation = ? ,state = ? where ftp_id = ? and  filename= ?");
	$sth->execute($md5sum,$oper,$state,$ftpId,$relativeFilePath);	

	# clean up
	$sth->finish;
	$dbh->disconnect();

}

#
#Get User FTP id by domain;
#
#
sub getFtpIdByDomain {
	my ($ftpDir) = @_;
	print "FTP dir : $ftpDir";
	
	my $dbh = &getDbConnection();	
	my $sth = $dbh->prepare("select ftp_id from `rsync_user_ftp` where ftp_dir = ?");
	$sth->execute($ftpDir);

	my $ftpId = 0;
	if(my $ref = $sth->fetchrow_hashref()) {
		$ftpId = $ref->{ftp_id};
	}
	# clean up
	$sth->finish;
	$dbh->disconnect();
	return $ftpId;
}

sub insertEvent2DB {
	my ($ftpId,$relativeFilePath,$fileSize,$md5sum,$event) = @_;

	my $dbh = &getDbConnection();
	my $sql = "INSERT INTO `rsync_ftp_files` (`ftp_id`,`filename`,`filesize`,`filemd5`,`sync_operation`,`state`,`create_time`) VALUE (?,?,?,?,?,?,now())";
	my $insertStmt = $dbh->prepare($sql);
	$insertStmt->execute($ftpId,$relativeFilePath,$fileSize,$md5sum,$event,SYNC_STATE_NEED_SYNC);	
	
	# clean up
	$insertStmt->finish;
	$dbh->disconnect();
}

sub getDbConnection {
	my $dbh = DBI->connect("DBI:mysql:database=rsync;host=127.0.0.1", "root", "mysql", {'RaiseError' => 1});
	$dbh->do("set names utf8");
	return $dbh;
}

sub checkMd5sum {
    my ($watchedDir,$file) = @_;
    my $syncFile = "";
    my $md5File = "";
    if ($file =~ "(.*?).md5") {
        $md5File = $watchedDir . $file;
        $syncFile = $watchedDir . $1;
        
        #Does this file exist?
        if (! -e -f $syncFile) {
			printf "Sync file :'%s' not found or was not uploaded!\n",$syncFile;
			return 0;
		}
    } else {
		#it is a file need to be synchronized.
		$syncFile = $watchedDir . $file;
		$md5File = $syncFile . ".md5";

        #Does md5 file exist?
        if (! -e -f $md5File) {
			printf ".md5 file :'%s' not found or was not uploaded!\n",$md5File;
			return 0;
		}		
    }

	print "MD5File: $md5File\n";

	#Get md5sum value from file.
	my $md5sumInFile = `cat $md5File |gawk '{print \$1}' `;
	chomp $md5sumInFile;

	my $md5sum = `md5sum $syncFile |gawk '{print \$1}' `;
	chomp $md5sum;
	
	if ($md5sum  eq $md5sumInFile) {
		return 1;
	} else {
		print "md5sumInFile:'$md5sumInFile' ,md5sumCalculated:'$md5sum'\n";
		print "md5sum check failed!\n";
		return 0;
	}
}

#======================================================
print "======================================================\n";

my $arg1 = shift @ARGV;
#print "Arg[0]:$arg1\n";

my @parts = split /:::/,$arg1;

#Encode URL.
my $watch = $parts[0];
my $escaptedWatchDir = uri_escape($watch);

my $file = $parts[1];



#print "File: $file\n";
#print "File name in UTF-8: " . encode("utf-8",decode("gbk",$file));

my $escapedFile = uri_escape($file);

#skip unnessary event
my $event = $parts[2];
if (not ($event =~ "(.*?)CLOSE_WRITE.*" or $event =~ "(.*?)DELETE.*" or $event =~ "(.*?)MOVED_TO.*" or $event =~ "(.*?)MOVED_FROM.*" )) {
	print "skip this event\n";
	exit;
}

if ($event =~ "(.*?)CLOSE_WRITE.*" or $event =~ "(.*?)MOVED_TO.*") {
	if(! &checkMd5sum($watch,$file)) {
		exit;
	} else {
		if ($file =~ "(.*?).md5") {
			#if it is a .md5 file ,trigger a event with original file.
			printf "File:%s\n",$1;
			$file = $1;
		}
	}
}

$file = encode("utf-8",decode("gbk",$file));

my $ua = LWP::UserAgent->new;

#Send a HTTP POST request.
my $response = $ua->post("http://localhost:8080/cdn-fds/inotify?w=$escaptedWatchDir&f=$escapedFile&e=$event");
printf "Response.code: %d \n Response.message: %s\n", $response->code,$response->message;
if($response->is_success()) {
    print "request success.\n";
} else {
    print "request failed.\n";
	&processInotifyEvent($watch,$file,$event);
}
