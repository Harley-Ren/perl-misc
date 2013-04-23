#!/usr/bin/env perl
# restart tomcat.
# please place this file in $CATALINA_HOME/bin.
use strict;
use warnings;
use Cwd qw/getcwd/;
use Cwd qw(abs_path);
use File::Basename qw/dirname/;

#printf("script: %s\n",$0 );
my $path = dirname($0);
#printf("path: %s\n",$path );
my $workdir=`cd $path && cd .. && pwd`;
#printf("workdir: %s\n",$workdir);
my $CATALINA_HOME=$workdir;
chomp $CATALINA_HOME;

sub get_pid_of_tomcat {
    my $pid = 0;
    use vars qw($CATALINA_HOME);
    my $tomcat_ps=`ps aux|grep ".* -Dcatalina.home=$CATALINA_HOME .* org.apache.catalina.startup.Bootstrap start"|grep -v grep`;
    chomp $tomcat_ps;
    if($tomcat_ps eq '') {
        #print "tomcat is not running. \n"
    } else {
        my @info = split /\s+/, $tomcat_ps;
        #printf "pid: %s\n", $info[1];
        $pid = $info[1];
    }
    return $pid;
}

sub start {
    use vars qw($CATALINA_HOME);
    printf "starting tomcat ... \n";
    #`nohup sh $CATALINA_HOME/bin/startup.sh`;
    
    my @args = ("sh", "$CATALINA_HOME/bin/startup.sh");
    system(@args) == 0 or die "system @args failed: $?";
}

sub stop {
    my $tomcat_pid = &get_pid_of_tomcat();
    print "stopping tomcat .";
    while ($tomcat_pid > 0) {
        print ".";
        system "kill -9 $tomcat_pid";
        sleep 1;
        $tomcat_pid = &get_pid_of_tomcat(); 
    }

    print ".\n";
}

sub restart() {
    &stop();
    &start();
}


&restart(); 
