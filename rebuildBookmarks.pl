#!/usr/bin/perl -w
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Author:  Kai Lauterbach (klaute at gmail dot com)
# Date:    04.08.2013
#

use strict;

use threads;
use Term::ANSIColor;
use List::MoreUtils qw/ uniq /;
require LWP::UserAgent;
my $ua = LWP::UserAgent->new;
$ua->timeout(5);

$| = 1; # autoflush

########################################### constants #######################################

my $THREADS_MAX = 10;

my $TEMPLATE_FOLDER = "templates";
my $TEMPLATE_SUBFOLDER = "chrome"; # TODO should be variable

my $BUZZWORD_FILE = "buzzwords.txt";

my $BOOKMARK_LNK_EXTRACT_START_FILE = "$TEMPLATE_FOLDER/$TEMPLATE_SUBFOLDER/bookmark_link_extract_start.tpl";
my $BOOKMARK_LNK_EXTRACT_END_FILE = "$TEMPLATE_FOLDER/$TEMPLATE_SUBFOLDER/bookmark_link_extract_end.tpl";
my $BOOKMARK_HEAD_FILE = "$TEMPLATE_FOLDER/$TEMPLATE_SUBFOLDER/bookmark_head.tpl";
my $BOOKMARK_FOOT_FILE = "$TEMPLATE_FOLDER/$TEMPLATE_SUBFOLDER/bookmark_foot.tpl";
my $BOOKMARK_SF_HEAD_FILE = "$TEMPLATE_FOLDER/$TEMPLATE_SUBFOLDER/bookmark_subfolder_head.tpl";
my $BOOKMARK_SF_FOOT_FILE = "$TEMPLATE_FOLDER/$TEMPLATE_SUBFOLDER/bookmark_subfolder_foot.tpl";
my $BOOKMARK_LINK_FILE = "$TEMPLATE_FOLDER/$TEMPLATE_SUBFOLDER/bookmark_link.tpl";

my $TEXT_ONLINE = "online";
my $TEXT_OFFLINE = "offline";
my $TEXT_UNSORTED = "unsorted ";

########################################### start #######################################

my @lines;

my $infile = $ARGV[0];

########################################### read start and end strings for link extraction #######################################

my $temp_link_extract_start = "";
my $temp_link_extract_end = "";

open LNKS, "< $BOOKMARK_LNK_EXTRACT_START_FILE" || die "Can't open file $BOOKMARK_LNK_EXTRACT_START_FILE: $?";
    $temp_link_extract_start = <LNKS>;
    chomp $temp_link_extract_start;
close LNKS;
open LNKE, "< $BOOKMARK_LNK_EXTRACT_END_FILE" || die "Can't open file $BOOKMARK_LNK_EXTRACT_END_FILE: $?";
    $temp_link_extract_end = <LNKE>;
    chomp $temp_link_extract_end;
close LNKE;

########################################### read bookmarks #######################################

print color("green"). "Reading bookmarks\n";
print color("white");
if ($infile eq "")
{
    @lines = <>; # read data from stdin
} else {
    # read file which name is given by commandline argument
    print "Using file: ". color("yellow"). $infile. color("white"). "\n";
    open FILE, "< $infile" || die "Can't open file $infile: $?";
        my $tlnkcnt = 0;
        foreach (<FILE>)
        {
            my $tline = $_;
            $tlnkcnt = $tlnkcnt + 1 if ($tline =~ /$temp_link_extract_start/);
            push @lines, $tline;
        }
        print "URL's before: ". color("yellow"). $tlnkcnt. color("white"). "\n";
    close FILE;
}

########################################### sort and unique #######################################

print color("green"). "Sorting and unifying bookmarks\n";
my @unique = uniq @lines;
   @unique = sort @unique;

my @urls;
foreach my $line (@unique)
{ # extract links from file
    my $url = "";
    if ($line =~ /$temp_link_extract_start(.*)$temp_link_extract_end/i )
    {
        $url = $1;
        $url =~ s/^\s+//;
        $url =~ s/\s+$//;
        chomp $url;

        push @urls, $url;
    }
    
}

print color("white"). "URL's after: ". color("yellow"). ($#urls+1). color("white"). "\n";

########################################### read buzzwords #######################################

print color("green"). "Reading keywords and categories\n";
print color("white");

my @buzzwords;

open BUZZ, "< $BUZZWORD_FILE" || die "Can't open file: $?";
    my $tk = 0;
    my $tc = 0;
    foreach my $line (<BUZZ>)
    { # process buzzwords
        chomp $line;
        #print $line. "\n";
        my @words = split (";", $line);
        my %thash = ();
        my $first = 1;
        my @twords;
        foreach my $e (@words)
        { # process words in file
            if ($first == 1)
            {
                # add category name
                $e =~ s/://ig;
                $thash{"category"} = $e;
                $first = 0;
                #print "Category ". color("blue"). $e. color("white"). " added with keywords: ";
                $tc = $tc + 1;
                print "\rCategories: ". color("yellow"). $tc. color("white"). " Keywords: ". color("yellow"). $tk. color("white"). "      ";
            } else {
                # add keyword to category
                push @twords, $e;
                $tk = $tk + 1;
                #print color("yellow"). $e. " ". color("white");
            }
        }
        my $t = \@twords;
        $thash{"words"} = $t; 
        $t = \%thash;
        push @buzzwords, $t;
        #print "\n";
    }
close BUZZ;
print "\n";

########################################### online test #######################################

print color("green"). "Bookmark online test\n";
print color("white");

my @turl_list;
my @url_list;
my $cnt_online  = 0;
my $cnt_offline = 0;
my @anim = ( "-", "\\", "|", "/" );
my $i = 0;
my $tend = 0;

print color("yellow"). ($#urls+1). color("white"). " to process...\n";

while ($tend == 0)
{
    if (($#urls + 1) >= 1 && threads->list(threads::running) < $THREADS_MAX)
    { # start a new thread if there are at least one url left
        my $url = shift @urls; # first element from array
        if ( defined $url && $url ne "" )
        {
            #print "\r ". $anim[$i]. " | ". (($#urls+1) - ($#turl_list+1)). " left | processing within ". (threads->list(threads::running)+1). " threads...      ";
            print "\r ". color("yellow"). $anim[$i]. color("white"). " | ";
            print color("yellow"). ($#turl_list+1). " done ";
            print color("white"). "| processing within ";
            print color("yellow"). (threads->list(threads::running)+1). " threads". color("white"). "...      ";

            # create a thread to process the url online test
            # bind it to an temporary variable becaus we can't read
            # the results of the thread without those binding
            my $thr = threads->create(\&online_test, $url);

            # next animation element
            $i = $i + 1;
            $i = 0 if ($i >= 4);
        }
    }

    if (threads->list() >= $THREADS_MAX || (threads->list() > 0 && ($#urls + 1) < $THREADS_MAX))
    {
        # if there are at least $THREADS_MAX threads or less than $THREADS_MAX
        # url's to test and more than zero treads running wait for them
        my @thr = threads->list();

        foreach my $thrd (@thr)
        {
            # is the current thread joinable (finished and ready to read the result)
            if ($thrd->is_joinable())
            {
                my $res = $thrd->join();
                if (defined $res)
                { # process threads result
                    my %thash = %$res;
                    #print "\n". $thash{"url"}. "\n";

                    my $t = \%thash;
                    push @turl_list, $t;
                }
            }

            # it's possible to start another thread...
        }

    }

    #  abort condition
    if (($#urls + 1) == 0 && threads->list() <= 0)
    {
        $tend = 1; # all url's done
    }
}

print "\r                                                                             \r";
print color("yellow"). ($#turl_list+1). color("white"). " done\n";

########################################### process online test results #######################################

print color("green"). "Processing online test results\n". color("white");

# TODO add multitreading support
foreach (@turl_list)
{
    my $tuh = $_;
    my %thash = %$tuh;
    my $url = $thash{"url"};
    if ( $url ne "" )
    {
        print color("blue"). $url. color("white"). " - ";

        my $response = $thash{"response"}; # read webserver results

        if ($response->is_success)
        {
            # url is online
            print color("green"). $TEXT_ONLINE. color("white"). " - ";

            #my %thash = ();
            #$thash{"url"} = $url;

            my $title = $url;
            my $temp_html = $response->content;

            $thash{"content"} = $temp_html;

            $temp_html =~ s/\n//ig;
            $temp_html =~ s/\r//ig;
            if ($temp_html =~ s#.*<title>(.*?)</title>.*#$1#ig) # extract title from content
            {
                $temp_html = $1;
                # TODO nur unsichtbare spaces tabs etc. entfernen
                $temp_html =~ s/^\s+//;
                $temp_html =~ s/\s+$//;
                print "\"". $temp_html. "\"";
                $title = $temp_html;
            } else {
                print color("red"). "title unknown". color("white");
            }
            print "\n";
            $thash{"title"} = $title;
            $thash{"status"} = $TEXT_ONLINE;
            my $t = \%thash;
            push @url_list, $t;
            $cnt_online = $cnt_online + 1;
        } else {
            # url is offline
            print $response->status_line;
            print " - ". color("red"). "offline\n". color("white");
            my %thash = ();
            $thash{"url"} = $url;
            $thash{"title"} = $url;
            $thash{"status"} = $TEXT_OFFLINE;
            $thash{"content"} = "";
            my $t = \%thash;
            push @url_list, $t;
            $cnt_offline = $cnt_offline + 1;
        }
    }
}

########################################### generate categories/keywords for each url #######################################

# TODO add multitreading support
print color("green"). "Generating keywords\n";
print color("white");

my $cnt_withcategory = 0;
my $cnt_withoutcategory = 0;
my @url_list_categorized;

foreach (@url_list)
{
    my $t = $_;
    my %thash = %$t;
    print color("blue"). $thash{"url"}. color("white"). " - ";
    my $temp_html = $thash{"content"};
    my $found = 0;

    foreach (@buzzwords)
    {
        my $t2 = $_;
        my %bw = %$t2;
        my $tw = $bw{"words"};
        my @w = @$tw;
        foreach (@w)
        {
            my $kw = $_;
            if ($temp_html =~ /\s$kw\s/ig || $thash{"url"} =~ /$kw/) # TODO optimized keyword recognition required
            {
                print "Keyword ". color("yellow"). $bw{"category"}. ":$kw". color("white"). " found";
                $thash{"category"} = $bw{"category"};
                $found = 1; # skip to next url because just one category per url is allowed
                $cnt_withcategory = $cnt_withcategory + 1;
            }
            last if ($found == 1); # keyword found, abort search
        }
        last if ($found == 1); # keyword found, abort category recognition
    }
    if ($found == 0)
    {
        # no category found
        $thash{"category"} = $TEXT_UNSORTED;
        print color("red"). "No keyword". color("white"). " found";
        $cnt_withoutcategory = $cnt_withoutcategory + 1;
    }
    $found = 0 if ($found == 1);
    my $th = \%thash;
    push @url_list_categorized, $th; # generate a new list of categorized url's

    print "\n";
}

########################################### read template files for bookmark output #######################################

my $bk_hd = "";
my $bk_ft = "";
my $bk_sf_hd = "";
my $bk_sf_ft = "";
my $bk_lnk = "";

print color("green"). "Reading bookmark template files";
print color("white");
my $tplfile = $BOOKMARK_HEAD_FILE;
print ".";
open FILE, "< $tplfile" || die "Can't open $tplfile $?";
    foreach my $line (<FILE>)
    {
        $bk_hd .= $line;
    }
close FILE;
print ".";
$tplfile = $BOOKMARK_FOOT_FILE;
open FILE, "< $tplfile" || die "Can't open $tplfile $?";
    foreach my $line (<FILE>)
    {
        $bk_ft .= $line;
    }
close FILE;
print ".";
$tplfile = $BOOKMARK_SF_HEAD_FILE;
open FILE, "< $tplfile" || die "Can't open $tplfile $?";
    foreach my $line (<FILE>)
    {
        $bk_sf_hd .= $line;
    }
close FILE;
print ".";
$tplfile = $BOOKMARK_SF_HEAD_FILE;
open FILE, "< $tplfile" || die "Can't open $tplfile $?";
    foreach my $line (<FILE>)
    {
        $bk_sf_ft .= $line;
    }
close FILE;
print ".";
$tplfile = $BOOKMARK_LINK_FILE;
open FILE, "< $tplfile" || die "Can't open $tplfile $?";
    foreach my $line (<FILE>)
    {
        $bk_lnk .= $line;
    }
close FILE;
print ".". color("yellow"). "ok\n". color("white");

#exit 0;

########################################### save new data #######################################

print color("green"). "Generating new bookmark file ";
print color("white");

my $date = `date -I`;
chomp $date;
my $outfile = "bookmarks_$date.html";
print ": ". color("yellow"). $outfile. color("white"). "\n";

system("rm $outfile");

open FILE, "> $outfile" || die "Can't open $outfile: $?";

    print FILE $bk_hd. "\n";

    foreach (@buzzwords)
    { # generate every category folder only once in bookmark file
        my $tch = $_;
        my %tcathash = %$tch;
        my $cat = $tcathash{"category"};
        my $found = 0;

        foreach (@url_list_categorized)
        { # search for the url's with the current category and write them into the bookmark file
            my %thash = %$_;

            if ($thash{"category"} eq $cat && $found == 0)
            {
                print color("white"). "Add url's for category: ". color("yellow"). $cat. color("white"). "\n";
                $found = 1;
                my $sf = $bk_sf_hd;
                $sf =~ s/<!-- SUBFOLDER_NAME -->/$cat/ig; # open new subfolder
                print FILE $sf. "\n";
            }
            if ($thash{"status"} eq $TEXT_ONLINE && $thash{"category"} eq $cat)
            {
                # write url in category folder
                my $lnk = $bk_lnk;
                $lnk =~ s/<!-- URL -->/$thash{"url"}/ig;
                $lnk =~ s/<!-- URL_NAME -->/$thash{"title"}/ig;
                print FILE $lnk;
            }
        }
        
        print FILE $bk_sf_ft if ($found == 1); # close subfolder if required
    }
    my $found = 0;
    foreach (@url_list_categorized)
    {
        my %thash = %$_;
        if ($thash{"category"} eq $TEXT_UNSORTED && $found == 0)
        {
            print color("white"). "Add ". color("yellow"). $TEXT_UNSORTED. color("white"). " url's\n";
            my $sf = $bk_sf_hd;
            $sf =~ s/<!-- SUBFOLDER_NAME -->/$TEXT_UNSORTED/ig; # open new subfolder
            print FILE $sf. "\n";
            $found = 1;
        }
        if ($thash{"status"} eq $TEXT_ONLINE && $thash{"category"} eq $TEXT_UNSORTED)
        {
            # write url in category folder
            my $lnk = $bk_lnk;
            $lnk =~ s/<!-- URL -->/$thash{"url"}/ig;
            $lnk =~ s/<!-- URL_NAME -->/$thash{"title"}/ig;
            print FILE $lnk;
        }
    }
    print FILE $bk_sf_ft if ($found == 1); # close subfolder if required


    # build offline url list (unsorted)
    print color("white"). "Add ". color("yellow"). $TEXT_OFFLINE. color("white"). " folder and maybe url's\n";
    my $sf = $bk_sf_hd;
    $sf =~ s/<!-- SUBFOLDER_NAME -->/$TEXT_OFFLINE/ig;
    print FILE $sf. "\n";
    # write offline url's into file
    foreach (@url_list_categorized)
    {
        my %thash = %$_;
        if ($thash{"status"} eq $TEXT_OFFLINE)
        {
            next if ( $thash{"url"} eq "" );
            my $lnk = $bk_lnk;
            $lnk =~ s/<!-- URL -->/$thash{"url"}/ig;
            $lnk =~ s/<!-- URL_NAME -->/$thash{"title"}/ig;
            print FILE $lnk;
        }
    }
    print FILE $bk_sf_ft;
    print FILE $bk_ft;
close FILE;

########################################### stats #######################################

print color("green"). "Done!". color("white"). "\n";

########################################### stats #######################################

print color("green"). "Statistics". color("white"). "\n";
print color("blue"). "Online:           ". color("white"). $cnt_online. "\n";
print color("blue"). "Offline:          ". color("white"). $cnt_offline. "\n";
print color("blue"). "With category:    ". color("white"). $cnt_withcategory. "\n";
print color("blue"). "Without category: ". color("white"). $cnt_withoutcategory. "\n";

print color("white"). "\n";

########################################### end #######################################

exit 0;

########################################### online test sub #######################################

sub online_test
{
    my $url = shift;
    my %thash = ();

    my $response = $ua->get($url); # request data from webserver

    $thash{"response"} = $response;
    $thash{"url"} = $url;
    my $t = \%thash;
    return $t;
}

########################################### end subs #######################################

