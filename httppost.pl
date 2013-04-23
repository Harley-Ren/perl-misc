#!/usr/bin/env perl

#@author Harley Ren.

use utf8;
use strict;
use warnings;
use Encode;

use URI::Escape;
use LWP;
use DBI;


my($mobile,$message) = @_;
my $ua = LWP::UserAgent->new;
my $url = "http://211.151.65.41/task/cdn.php";

my $xml='<?xml version="1.0" encoding="UTF-8"?><vianet><cust_id>21vianet</cust_id><password>ae92e40b441a2d73215faafd70026644</password><item><itemID>1</itemID><op>sync</op><source_urls><play_link>http://219.234.83.53/vod/TBGZ/TBSX_GZ2_02130-40.mp4</play_link></source_urls></item></vianet>';

#$xml = uri_escape($xml);
my $params = {content=>$xml};

my $response = $ua->post($url,$params);
printf "Response.code: %d \n Response.message: %s\n", $response->code,$response->message;
if($response->is_success()) {
    printf "request success. %s \n", $response->content;
} else {
    print "request failed.\n";
}



