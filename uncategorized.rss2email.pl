#!/usr/bin/perl

use lib '/nfs/users/nfs_j/jb26/lib/perl/lib/site_perl';
use lib '/nfs/users/nfs_j/jb26/lib/perl/lib/site_perl/5.8.8/x86_64-linux-thread-multi';

use strict;
use XML::RSS;
use DateTime::Format::W3CDTF;
use Time::localtime;
use MIME::Lite;

my $debug = 0;


my $lastdate = DateTime->from_epoch(epoch => 0);
#pull down the feed list (seems to be the only consistent way 
#to get the request out of the internal network, i.e. not possible by HTTP:Request?)
system("wget -O journalpix.rdf http://www.citeulike.org/rss/group/10570/library");
my $datetimeformatter = DateTime::Format::W3CDTF->new;

if (!$debug){
  open (IN, "lastupdate.txt");
  my $e = <IN>;
  chomp($e);
  close IN;  
  $lastdate = DateTime->from_epoch(epoch => $e);
}

if (!(-s "journalpix.rdf")){
  die "No journalpix source file. Disaster?\n";
}

my $rss = new XML::RSS (version => '2.0');
$rss->add_module(prefix=>'prism',uri=>'http://prismstandard.org/namespaces/1.2/basic/');
$rss->parsefile( "journalpix.rdf" );

my $message = "";    #"<html><body>";

if (-s "header.txt"){
    open (IN, "header.txt");
    while (<IN>){
	$message .= $_;
    }
    close IN;
}else{
    $message .= "This week's journal pix!\n\n";
}
my $newstuff = 0;

foreach my $item ( @{$rss->{'items'}} ) {
  my $date = $datetimeformatter->parse_datetime($item->{'dc'}->{'date'});
  if ($date > $lastdate){
    my $title = $item->{'title'};
    my $doi = $item->{'dc'}->{'identifier'};

    my $tags = $item->{'prism'}->{'category'};
    if ($tags =~ /staffpaper/){
        $message .= "[STAFF PAPER] ";
    }

    my $link = "http://dx.doi.org/$doi";
    if (!$doi){
	print "Couldn't find DOI for $title\n";
	$link = $item->{'link'};
    }

    my $authors = $item->{'dc'}->{'creator'};
    my $authorstring;
    if (ref($authors) eq "ARRAY"){
	my $count = 0;
	foreach my $a (@{$authors}){
	    if ($count >= 3){
		$authorstring .= "et al. ";
		last;
	    }
	    $authorstring .= "$a, ";
	    $count++;
	}
	chop($authorstring);
	chop($authorstring);
	$authorstring .= ".";
    }else{
      $authorstring = $authors;
    }

    my $source = $item->{'dc'}->{'source'};
    $message .= "$title ($link)\n$authorstring $source\n\n";
    $newstuff = 1;
  }
}


my $subject;
my $to;
my $from = "The Journal Annotation Team<journal_picks\@sanger.ac.uk>";

if ($newstuff){
  $subject = "Journal Picks Weekly Digest";
  if (!$debug){
    $to = "hinx\@sanger.ac.uk, all\@ebi.ac.uk";
  }else{
    $to = "jb26\@sanger.ac.uk";
  }
}else{
  $subject = "No new picks!";
  if (!$debug){
    $to = "journal_picks\@sanger.ac.uk";
  }else{
    $to = "jb26\@sanger.ac.uk";
  }
  $message = "There weren't any new picks, so I didn't send an update email.\nYou'd better work harder at picking articles!\n"
}

my $msg = MIME::Lite->new( To => $to, Subject => $subject, Type => 'text/plain', From=>$from, Data=>$message);
$msg->attr('content-type.charset' => 'UTF8');

$msg->send();

if (!$debug){
  open (OUT, ">lastupdate.txt");
  my $e = time();
  print OUT "$e\n";
  close OUT;

  system("rm journalpix.rdf");
}
