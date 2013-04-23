#!/bin/perl
#load module
use DBI;
use strict;

# connect
my $dbh = DBI->connect("DBI:mysql:database=hzyyx;host=127.0.0.1", "root", "mysql", {'RaiseError' => 1});

# execute INSERT query
#my $rows = $dbh->do("INSERT INTO users (id, username, country) VALUES (4, 'jay', 'CZ')");
#print "$rows row(s) affected ";

# execute SELECT query
my $galleryId = 15;
my $sth = $dbh->prepare("select * from `gallery_images` where gallery_id = ?");
$sth->execute($galleryId);

my $delStmt = $dbh->prepare("delete from `gallery_images` where id = ?");

# iterate through resultset
# print values
while(my $ref = $sth->fetchrow_hashref()) {
    print "id : $ref->{id} ";
    print "GalleryID: $ref->{gallery_id} ";
    print "Photo: $ref->{image_id} \n";
    print "---------- \n";
    $delStmt->execute($ref->{"id"});
}

# clean up
$dbh->disconnect();
