use LWP::UserAgent;

#ensure there is only one instance.

my $instance=`ps aux|grep $0|grep -v grep|wc -l`;
print $instance;
#print (int)$instance;
if ($instance > 1) {
    print "程序已经运行\n";
    exit;
}


sub GetFileSize{
        my $url=shift;
        $ua = new LWP::UserAgent;
        $ua->agent("Mozilla/5.0");
        my $req = new HTTP::Request 'HEAD' => $url;
        $req->header('Accept' => 'text/html');
        $res = $ua->request($req);
        if ($res->is_success) {
            my $headers = $res->headers;
            if ($headers) {
                return $headers->content_length;
             }
        }
return 0;
}

$link='http://apache.etoak.com/commons/io/binaries/commons-io-1.4-bin.zip';
$filesize = GetFileSize($link);
if ($filesize) {
    print "File size: ".$filesize." bytes\n";
    my $sync_dir = "/home/harley/tmp";
    my $local_filename = "commons-io-1.4-bin.zip";
    `wget -O $sync_dir/$local_filename $link`;
    
    my $downloadedFilesize = -s "$sync_dir/commons-io-1.4-bin.zip";
    
    print "Download File size: ".$downloadedFilesize." bytes\n";
    chomp $filesize;
    chomp $downloadedFilesize;
    if($filesize eq $downloadedFilesize) {
        print "success.\n";
        `md5sum $sync_dir/$local_filename >  $sync_dir/$local_filename.md5`;
    }
    
    
} else {
    print "failed.";
}

exit;
