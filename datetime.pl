#!/usr/bin/env perl

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

print($year);
print("\n");
print($year+1900);
print("\n");
printf "%d-%d-%d %d:%d:%d\n",$year + 1900,$mon + 1,$mday,$hour,$min,$sec;
