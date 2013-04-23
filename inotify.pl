#!/usr/bin/env perl
use strict;

use Linux::Inotify2;

# create a new object
 my $inotify = new Linux::Inotify2
    or die "unable to create new inotify object: $!";
 
 # add watchers
 $inotify->watch ("/home/jacky/Workspaces/perl",IN_ALL_EVENTS);
 # manual event loop
 
#while () {
#    $inotify->poll;
#}

while () {
    my @events = $inotify->read;
    unless (@events > 0) {
        print "read error: $!";
        last ;
    }
    #printf "mask\t%d\n", $_->mask foreach @events ; 
    foreach my $e (@events) {
        my $name = $e->fullname;
        print "$name was accessed\n" if $e->IN_ACCESS;
        #print "$name is no longer mounted\n" if $e->IN_UNMOUNT;
        print "$name is gone\n" if $e->IN_IGNORED;
        print "events for $name have been lost\n" if $e->IN_Q_OVERFLOW;
        print "$name was created ! \n" if $e->IN_CREATE;
        print "$name was deleted !\n" if $e->IN_DELETE;
        print "$name was closed !\n" if $e->IN_CLOSE;
        print "$name was modified!\n" if $e->IN_MODIFY;
        printf "$name mask\t%d\n", $e->mask;
        
    }
}
