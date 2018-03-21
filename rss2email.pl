#!/usr/bin/perl

# author: Jeff Barrett (jb26)
# maintainer: Dan Rice (dr9)

use strict;

use DateTime::Format::W3CDTF;
use Time::localtime;
use MIME::Lite;

my $debug = 0;

my $lastdate = DateTime->from_epoch(epoch => 0);
my $datetimeformatter = DateTime::Format::W3CDTF->new;

#pull down the feed list (seems to be the only consistent way 
#to get the request out of the internal network, i.e. not possible by HTTP:Request?)
system("wget -O journalpix.rdf http://www.citeulike.org/rss/group/10570/library");

open (IN, "lastupdate.txt");
my $e = <IN>;
chomp($e);
close IN;  
$lastdate = DateTime->from_epoch(epoch => $e);

if (!(-s "journalpix.rdf")){
  die "No journalpix source file. Disaster?\n";
}

open (my $in, "<", "journalpix.rdf");
my $in_item = 0;
my @items;
my %titles;
my %tags;
my %links;
my %authors;
my %sources;
my %dates;
while (<$in>){
    if (/<item rdf:about=\"(.+)\">/){
	my $id = $1;
	push @items, $id;
	my @a;
	my $doi;
	while (<$in>){
	    if (/<title>(.+)<\/title>/){
		$titles{$id} = $1;
	    }elsif (/<dc:creator>(.+)<\/dc:creator>/){
		push @a, $1;
	    }elsif (/<dc:source>(.+)<\/dc:source>/){
		$sources{$id} = $1;
	    }elsif (/<dc:identifier>(.+)<\/dc:identifier>/){
		$doi = $1;
	    }elsif (/<prism:category>(.+)<\/prism:category>/){
		$tags{$id} .= $1;
	    }elsif (/<dc:date>(.+)<\/dc:date>/){
		$dates{$id} = $1;
	    }elsif (/<\/item>/){
		if ($#a == 0){
		    $authors{$id} = $a[0];
		}else{
		    my $count = 0;
		    my $ultimate;
		    my $penultimate;
		    foreach my $a (@a){
			if ($count == 0){
			  $authors{$id} .= "$a";
			}elsif ($count <= 2){
			  $authors{$id} .= ", $a";
			}else{
			  $penultimate = $ultimate;
			  $ultimate = $a;
			}
			$count++;
		    }
		    if ($count == 4){
		      $authors{$id} .= ", $ultimate";
		    }elsif ($count == 5){
		      $authors{$id} .= ", $penultimate, $ultimate";
		    }elsif ($count > 5){
		      $authors{$id} .= " ... $penultimate, $ultimate";
		    }
		}
		$authors{$id} .= ".";

		if ($doi){
		    $links{$id} = "http://dx.doi.org/$doi";
		}else{
		    $links{$id} = $id;
		}
		
		last;
	    }
	}
    }
}

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

my $bioinfsection, my $cancersection, my $humsection, my $infectionsection, my $cellsection, my $othersection;
foreach my $item ( @items ) {
  my $date = $datetimeformatter->parse_datetime($dates{$item});
  if ($date > $lastdate){
      my $outstring = "$titles{$item} ($links{$item})\n$authors{$item} $sources{$item}\n\n";
      $newstuff = 1;
      if ($tags{$item} =~ /staffpaper/i){
	  $outstring = "[Staff paper] $outstring";
      }

      if ($tags{$item} =~ /bioinformatics/i || $tags{$item} =~ /annotation/i || $tags{$item} =~ /informatics/i){
	  $bioinfsection .= $outstring;
      }elsif ($tags{$item} =~ /cancer/i){
	  $cancersection .= $outstring;
      }elsif ($tags{$item} =~ /humgen/i || $tags{$item} =~ /human/i){
	  $humsection .= $outstring;
      }elsif ($tags{$item} =~ /pathogens/i || $tags{$item} =~ /pathogen/i || $tags{$item} =~ /malaria/i){
	  $infectionsection .= $outstring;
      }elsif ($tags{$item} =~ /cell/i || $tags{$item} =~ /cells/i){
	  $cellsection .= $outstring;
      }else{
	  $othersection .= $outstring;
      }
  }
}

$message .= "*Informatics*\n----------------\n$bioinfsection";
$message .= "*Cancer, aging, somatic mutation*\n----------------\n$cancersection";
$message .= "*Human genetics*\n----------------\n$humsection";
$message .= "*Infection genomics*\n----------------\n$infectionsection";
$message .= "*Cellular genetics*\n----------------\n$cellsection";
$message .= "*Other*\n----------------\n$othersection";

$message .= "\nTo get copies of any non-subscribed picks in this list, please contact the library:  https://helix.wtgc.org/services/ordering-articles-and-inter-library-loans\n";
$message .= "If you are the author of papers you might find these links useful.\nThe ARRIVE Guidelines. Animal Research: Reporting of In Vivo Experiments:\nhttps://www.nc3rs.org.uk/sites/default/files/documents/Guidelines/NC3Rs\%20ARRIVE\%20Guidelines\%202013.pdf\nPublication Policy Compliance and Europe PMC / PubMed Central:\nhttps://helix.wtgc.org/services/publication-policy-compliance-and-europe-pmc-pubmed-central";


my $subject;
my $to;
my $from = "The Journal Annotation Team<journal_picks\@sanger.ac.uk>";

if ($newstuff){
  $subject = "Journal Picks Weekly Digest";
  if (!$debug){
    $to = "hinx\@sanger.ac.uk, all\@ebi.ac.uk, bic\@wellcomegenomecampus.org";
  }else{
    $to = "dr9\@sanger.ac.uk";
  }
}else{
  $subject = "No new picks!";
  if (!$debug){
    $to = "journal_picks\@sanger.ac.uk";
  }else{
    $to = "dr9\@sanger.ac.uk";
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
