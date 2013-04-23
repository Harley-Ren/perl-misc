#!/usr/bin/env perl

#$Id$
# 从文件中读取要分发的服务器，然后执行指定的任务。
#
# Author Harley Ren. 2010

use strict;
use warnings;
use utf8;
use Encode;
use DBI;
use Net::OpenSSH;
use Socket;
use Expect;
use XML::LibXML;
use Cwd qw/getcwd/;
use Data::Dumper;

# ============ classes ============
{ package Task;
    sub exec {
        
    }
}

#
{package ExecTask;
    #constructor.
    sub new {
        my ($class,$sshh,$command) = @_; 
         # Bless a hash to instantiate the new object... 
        my $new_object = bless {},$class;
        
        #command to be executed.
        $new_object->{command} = $command;
        $new_object->{ssh_handel} = $sshh;
        return $new_object;
    }
    
    sub getCmd {
        my ($self) = @_;
        return $self->{command};
    }
    
    sub setOutputCapture {
        my ($self,$outputCapture) = @_;
        $self->{outputCapture} = $outputCapture;
    }
    
    sub isOutputCapture {
        my ($self) = @_;
        return $self->{outputCapture} != 0;
    }
    
    sub do {
        my ($self,$ssh) = @_;
        printf "run command: %s\n",$self->getCmd();
        if ($self->{outputCapture}) {
            my @output = $ssh->capture($self->getCmd());
                     
            foreach my $line (@output) {
                printf "%s",$line;
            }
            
            if ($ssh->error) {
                printf "run command [%s] failed, error:%s\n",$self->getCmd(),$ssh->error;
                -1;
            } else {
                0;
            }
        } else {
            if(!$ssh->system($self->getCmd())) {
                printf "run command [%s] failed, error:%s\n",$self->getCmd(),$ssh->error;
            }
        }
    }
}

{package ScpPutTask;
    #constructor.
    sub new {
        my ($class,$sshh) = @_; 
         # Bless a hash to instantiate the new object... 
        my $new_object = bless {},$class;
        
        #command to be executed.
        $new_object->{ssh_handel} = $sshh;
        return $new_object;
    }
    
    sub setFrom {
        my ($self,$from) = @_;
        $self->{from} = $from;
    }
    
    sub getFrom {
        my ($self) = @_;
        return $self->{from};
    }
    
    sub setTo {
        my ($self,$to) = @_;
        $self->{to} = $to;
    }
    
    sub getTo {
        my ($self) = @_;
        return $self->{to};
    }
    
    sub do {
        my ($self,$ssh) = @_;
        printf "scp put: from= %s ,to=%s ... ",$self->getFrom(),$self->getTo();
        if($ssh->scp_put($self->getFrom(),$self->getTo())) {
            print "success!\n"
        } else {
            print "faile"
        }
    }
}

{package PortDetectionTask;
    use Socket;
    #constructor.
    sub new {
        my ($class,$port) = @_; 
         # Bless a hash to instantiate the new object... 
        my $new_object = bless {},$class;
        
        #command to be executed.
        $new_object->{port} = $port;
        return $new_object;
    }
    
    sub setTaskRefForSuccess{
        my ($self,$taskref) = @_;
        $self->{taskRefForSuccess} = $taskref;
    }
    
    sub getTaskRefForSuccess {
        my ($self) = @_;
        return $self->{taskRefForSuccess};
    }
    
    sub setTaskRefForFailure {
        my ($self,$taskref) = @_;
        $self->{taskRefForFailure} = $taskref;
    }
    
    sub getTaskRefForFailure {
        my ($self) = @_;
        return $self->{taskRefForFailure};
    }
    
    sub setTaskHash {
        my ($self,$taskHash) = @_;
        $self->{taskHash} = $taskHash;
    }
    
    sub do {
        my ($self,$ssh) = @_;
        my $host = $ssh->get_host;
        
        my %taskshash = %{$self->{taskHash}};
        printf "PortDetection: taskRefForSuccess: %s\n" ,$self->{taskRefForSuccess} if $self->{taskRefForSuccess} ;
        printf "PortDetection: taskRefForFailure: %s\n" ,$self->{taskRefForFailure} if $self->{taskRefForFailure} ;
        
        if($self->detect_port($host,$self->{port})) {
            printf "port $self->{port} on $host is listening!\n";
            if ($self->{taskRefForSuccess}) {
                #$taskhash{$self->{taskRefForSuccess}}->do($ssh);
                
                my $tasksref = $taskshash{$self->{taskRefForSuccess}};
                foreach my $task (@{$tasksref}) {
                    $task->do($ssh);
                }
            }
        } else {
            printf "port $self->{port} on $host is NOT listening !!!\n";
            if ($self->{taskRefForFailure}) {
                #$taskhash{$self->{taskRefForSuccess}}->do($ssh);
                
                my $tasksref = $taskshash{$self->{taskRefForFailure}};
                foreach my $task (@{$tasksref}) {
                    $task->do($ssh);
                }
            }
        }
        
    }
    
    sub detect_port {
        my ($self,$host,$port) = @_;
        
        my $proto = getprotobyname('tcp');

        # get the port address
        my $iaddr = inet_aton($host);
        my $paddr = sockaddr_in($port, $iaddr);
        # create the socket, connect to the port        
        if(! socket(SOCKET, PF_INET, SOCK_STREAM, $proto) ) {
            print "socket: $!\n";
            return 0;
         }
        if (! connect(SOCKET, $paddr) ) {
            print"connect: $!\n";
            return 0;
         }

        close SOCKET;
        1;
    }
    
}

my %taskshash = ();

sub parseTask {
    my ($node,$sshh) = @_;
    my $tagname = $node->nodeName;
    use vars qw(%taskshash);
    
    if($tagname eq 'exec') {
        my $execTask = ExecTask->new($sshh,$node->textContent());
        if($node->hasAttribute("capture_output")) {
            if($node->getAttribute("capture_output") eq "true") {
                $execTask->setOutputCapture(1);
            }
        }
        return $execTask;
    }elsif($tagname eq 'scp_put') {
        my $scpPushTask = ScpPutTask->new($sshh);
        my $from = $node->findvalue("from");
        my $to = $node->findvalue("to");
        #printf "from=%s\n",$from;
        $scpPushTask->setFrom($from);
        $scpPushTask->setTo($to);
        return $scpPushTask;
    } elsif ($tagname eq "detect") {
        my $port;
        if($node->hasAttribute("port")) {
            $port = $node->getAttribute("port")
        } else {
            printf "invalid detect task,port is required!\n";
            return;
        }
        my $portDetectionTask = PortDetectionTask->new($port);
        
        if($node->hasAttribute("taskForSuccess")) {
            $portDetectionTask->setTaskRefForSuccess($node->getAttribute("taskForSuccess"));
        }
        
        if($node->hasAttribute("taskForFailure")) {
            $portDetectionTask->setTaskRefForFailure($node->getAttribute("taskForFailure"));
        }
        
        $portDetectionTask->setTaskHash(\%taskshash);
        
        return $portDetectionTask;
    }
}

# ============ subroutines ============

sub showUname {
    my ($host,$user,$password) = @_;
    my $exp = Expect->spawn("ssh $user\@$host 'uname -a'");
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

sub run_command {
    my ($host,$user,$password,$cmd) = @_;
    printf("Cmd: %s \n",$cmd);
    my $exp = Expect->spawn("ssh $user\@$host '$cmd'");
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
    #printf "Before: %s\n",$exp->before();
    #printf "After: %s\n",$exp->after();
    $exp->soft_close();
}

#=====================================================

my $cwd = &getcwd;
#print $cwd;

my $task_file = shift @ARGV;
if (not $task_file) {
    $task_file = "$cwd/tasks.xml";
}

if (not -e $task_file) {
    printf "task file %s was not found!\n",$task_file;
    exit(-1);
}

my $parser = XML::LibXML->new();
my $doc = $parser->parse_file($task_file);
#print $doc;

#Get nodes by xpath expression.
my @server_groups_elements = $doc->findnodes("/rtasks/server_groups/server_group");

#print Dumper(@server_groups);
my %server_groups;

foreach my $server_group_element (@server_groups_elements) {
    #printf "%s\n",$server_group_element->getAttribute("name");
    my $server_group_name = $server_group_element->getAttribute("name");
    
    my @servers ;
    my @server_elements = $server_group_element->getChildrenByTagName("server");
    foreach my $server_element (@server_elements) {
        
        my $server_name = $server_element->getAttribute("name");
        my $server_ip = $server_element->getAttribute("ip");
        my $loginid = $server_element->getAttribute("loginid");
        my $passwd = $server_element->getAttribute("passwd");
        
        #printf "%s \t%s  \t%s  \t%s \n",$server_name,$server_ip,$loginid,$passwd;
        my %server_hash = ();
        $server_hash{"name"} = $server_name;
        $server_hash{"ip"} = $server_ip;
        $server_hash{'loginid'} = $loginid;
        $server_hash{'passwd'} = $passwd;
        
        #list of hashes.
        push (@servers, {%server_hash});
    }

    #list as hash value
    $server_groups{$server_group_name} = \@servers;
}

foreach my $server_group_key (keys %server_groups) {
    printf "$server_group_key \n";
    my $server_array_ref = $server_groups{$server_group_key};
    foreach my $server ( @{$server_array_ref} ) {
        printf encode("utf8",$server->{name}) . "\n";
    }
}

#Get ssh handle.
my $sshh = "";

#get tasks

my @tasks_elements = $doc->findnodes("/rtasks/task");
foreach my $task_element (@tasks_elements) {
    my $taskname = $task_element->getAttribute("name");
    printf "Taskname: %s\n",$taskname;
    my @children = $task_element->nonBlankChildNodes();
    my @tasks = ();
    foreach my $child (@children) {        
        my $task = &parseTask($child,$sshh);
        if($task) {
            push @tasks,$task;
        }
    }

    $taskshash{$taskname} = \@tasks;
}

#Get workflows
my @workflow_elements = $doc->findnodes("/rtasks/workflow");
foreach my $workflow_element (@workflow_elements) {
    #Get steps
    my @step_elements  = $workflow_element->findnodes("step");
    foreach my $step_element (@step_elements) {
        #get tasks ref
        my @taskref_elements = $step_element->findnodes("taskref");
        
        my $taskref_count = @taskref_elements;
        
        if ($taskref_count < 1) {
            next;
        }
        printf "taskref_count: %d\n",$taskref_count ;
        
        my $server_ref = $step_element->getAttribute("servers");
        my $server_array_ref = $server_groups{$server_ref};
        foreach my $server ( @{$server_array_ref} ) {
            
            printf "\ntry to connect to ". encode("utf8",$server->{name}) ." [". $server->{ip} . "] ...\n";
            
            #host in knownhost?
            my $exists = `ssh-keygen -F $server->{ip}`;
            if(!$exists) {
               &showUname($server->{ip} ,$server->{loginid},$server->{passwd});
            }
            
            #try to get ssh session.
            my $ssh = Net::OpenSSH->new($server->{ip},user=> $server->{loginid},passwd=>$server->{passwd},timeout=>30);
            
            if ($ssh->error) {
                print "Couldn't establish SSH connection: ". $ssh->error . "\n";
                next;
            }
            
            print "SSH connection established!\n";
            
            foreach my $taskref_element (@taskref_elements) {
                my $taskref_name = $taskref_element->getAttribute("taskname");
                printf "taskref name:%s\n",$taskref_name;
                
                if(! exists($taskshash{$taskref_name})) {
                    printf "[error] task:%s does not exist.\n",$taskref_name;
                }

                my $tasksref = $taskshash{$taskref_name};
                foreach my $task (@{$tasksref}) {
                    $task->do($ssh);
                }
            }
        }
    }
}
