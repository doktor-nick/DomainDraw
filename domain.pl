#!/usr/bin/perl 

# ***************************************************************************
# *   Copyright (C) Dr Nick, Lynn Fink 2005                                 *
# *   nick@maths.uq.edu.au, l.fink@imb.uq.edu.au                            *
# *                                                                         *
# *   This program is free software; you can redistribute it and/or modify  *
# *   it under the terms of the GNU General Public License as published by  *
# *   the Free Software Foundation; either version 2 of the License, or     *
# *   (at your option) any later version.                                   *
# *                                                                         *
# *   This program is distributed in the hope that it will be useful,       *
# *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
# *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
# *   GNU General Public License for more details.                          *
# *                                                                         *
# *   You should have received a copy of the GNU General Public License     *
# *   along with this program; if not, write to the                         *
# *   Free Software Foundation, Inc.,                                       *
# *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
# ***************************************************************************/

# Domain Draw 1.41
# (c) Dr Nick, Lynn Fink 2005
#     n.hamilton@imb.uq.edu.au, l.fink@imb.uq.edu.au 


# Uncomment the following line if you using the script to connect to a gimp server
# $ENV{'GIMP_HOST'} = 'pwd@localhost';

# This has been tested using gimp 1.2.3 under RedHat 9.0
# It requires the gimp-perl module version 1.2.3
# It has also been tested to a lesser extent under gimp 2.2.0 with Fedora Core 3.

# Example calls:

# Put this file in ~/.gimp/plug-ins/ and make it executable, if you
# run the gimp it will appear as a menu item under
#     "Xtns/Domain/" or "Perl-Fu/Protein Domains"

# NOTES:
# 1. for any domain that scales to less than 4 pixels wide it 
#    is drawn as a borderless box
# 2. For image mapping everything is treated as a rectangle, no ovals!
# 3. Fonts not being installed on your system can cause trouble.
#    $font, $sitefont set the fonts. use "xfontsel" under unix/linux
#    to select valid fonts.
#    If antialiasing of text is set ($antialias = 1; below)
#    Then the system actually asks for a font 3 times larger.
#    Most X font servers will handle this well and create a
#    scaled font on the fly. But some do not. So if you get
#    error messages like
#      gimp_text_get_extents_fontname: procedural database execution failed ...
#    It may be because of this. In which case either:
#      1. Turn anti-aliasing off 
#      2. Select a font size (e.g. 12 pt) such that
#         the font server has one 3 times large (i.e. 36 pt).

# Suggested fonts:
# scale factor 1
#  font     Courier 12
#  sitefont Courier 18
# For large scale images
#  scale factor 3
#  font     Courier 36
#  sitefont Courier 56

# TODO:
#  better input validity checking

#BUGS:
# long domain names .( > 30 characters) can cause trouble under gimp 1.2.3
#
# Gimp 2.2 doesn't like the default font settings
#      Change them to
# [PF_FONT,   "font", "font", "Courier 12"],
# [PF_FONT,   "sitefont", "Site font", "Courier 18"]
# if you experience difficulties


use Gimp ":auto";
use Gimp qw(:auto __ N_);
use Gimp::Fu;
use Gimp::Util;
use Gimp::Net;

# these are neccessary for the upgrade from 1.2.23 to 2.2.3
my $BG_IMAGE_FILL = 1;
my $REPLACE = 2;

######################
#some default values #
######################
my $antialias = 0; # Do anti-aliasing on text 0=FALSE, 1=TRUE
my $points = 0;    # Measure fonts in pixels = 0, or points = 1;
my $ysizeperprotein = 70;
my $xindent = 20;
my $yindent = 10;

# Note you may also want to change the large fonts in the section # Do scaling if necessary #
my $fontsize = 12;
my $font = "-*-courier-medium-r-normal-*-".$fontsize."-*-*-*-*-*-iso8859-1";

my $sitechar = "*"; # character to represent sites.
my $sitefontsize = 34;
my $sitefont = "-*-courier-medium-r-normal-*-".$sitefontsize."-*-*-*-*-*-iso8859-1";

my $sitesize = 6; # we pretend a site has size 10 residues for collision detectgion

my $texth = 16; #height of text box
my $boxh = 20;  #height of protein bar
my $bordersize = 1;
my $dextra = 4;
my $legendboxsize = 10;
my $doffsetscale = 5; # number of pixels to do offsets by for colliding domains.
my $heightspace = 1.3;

my $barcolour;  # colour for the protein bar
my $bgcolour;  # default background colour
my $defaultdomcolour; # default domain colour

my $red =    "#FF2100";  # colours for border of domain boxes
my $yellow = "#FFA500";
my $green =  "#58D804";


sub hex_to_dec{ # gimp 2 doesn't seem to like hex anymore
                # so we do conversion
    my $hex = shift; # input is of form '#5F9EA0'
    my $r = substr($hex,1,2);
    my $g = substr($hex,3,2);
    my $b = substr($hex,5,2);
    return hex($r),hex($g),hex($b);
    
}

sub custom_set_bg{ # gimp 2.2 doesn't seem to like hex anymore
                   # so we do conversion
    my $colour = shift;

    if ($colour =~ /^\#/){
	my $r = substr($colour,1,2);
	my $g = substr($colour,3,2);
	my $b = substr($colour,5,2);
	#print "$r $g $b ". hex($r) ." ". hex($g)." ". hex($b) ."\n";
	gimp_palette_set_background([hex($r),hex($g),hex($b)]);
    }
    else {
	gimp_palette_set_background($colour);
    }
}

sub custom_set_fg{ # gimp 2.2 doesn't seem to like hex anymore
                   # so we do conversion
    my $colour = shift;

    if ($colour =~ /^\#/){
	my $r = substr($colour,1,2);
	my $g = substr($colour,3,2);
	my $b = substr($colour,5,2);
	#print "$r $g $b ". hex($r) ." ". hex($g)." ". hex($b) ."\n";
	gimp_palette_set_foreground([hex($r),hex($g),hex($b)]);
    }
    else {
	gimp_palette_set_foreground($colour);
    }
}


sub max {
    my ($a,$b) = @_;
    if ($a > $b) {return $a;}
    else {return $b;}
}
sub draw_borderless_box {
# draws box with corners (x0,y0),(x0+width,y0+height)
# and fill colour

    my ($img,$x0,$y0,$width,$height,$fill_colour) = @_;

    my $bg_colour = gimp_palette_get_background();
    gimp_undo_push_group_start($img);

    gimp_rect_select($img,
		     $x0, $y0, 
		     $width, 
		     $height,
		     $REPLACE, 0,0);

    custom_set_bg($fill_colour);
    gimp_edit_fill($layer, $BG_IMAGE_FILL);

    # tidy up
    gimp_palette_set_background($bg_colour);
    gimp_selection_none($img);
    gimp_selection_none($img);
    gimp_displays_flush();
    gimp_undo_push_group_end($img);
} 

sub draw_box {
# draws box with corners (x0,y0),(x0+width,y0+height)
# the border width, border colour and fill colour are also set

    my ($img,$x0,$y0,$width,$height,$border_width,$border_colour,$fill_colour) = @_;

    my $bg_colour = gimp_palette_get_background();

    gimp_undo_push_group_start($img);

    gimp_rect_select($img,
		     $x0, $y0, $width, $height,
		     $REPLACE, 0,0);

    custom_set_bg($border_colour);
    gimp_edit_fill($layer, $BG_IMAGE_FILL);
    gimp_selection_none($img);

    gimp_rect_select($img,
		     $x0+$border_width, $y0+$border_width, 
		     $width-2*$border_width, 
		     $height-2*$border_width,
		     $REPLACE, 0,0);

    custom_set_bg($fill_colour);

    gimp_edit_fill($layer, $BG_IMAGE_FILL);

    # tidy up
    gimp_palette_set_background($bg_colour);
    gimp_selection_none($img);
    gimp_selection_none($img);
    gimp_displays_flush();
    gimp_undo_push_group_end($img);
} 
sub draw_ellipse{
# draws ellipse with corners (x0,y0),(x0+width,y0+height)
# the border width, border colour and fill colour are also set

    my ($img,$layer,$x0,$y0,$width,$height,$border_width,$border_colour,$fill_colour) = @_;

    my $bg_colour = gimp_palette_get_background();
    gimp_undo_push_group_start($img);

    gimp_rect_select($img,
		     $x0, $y0, $width, $height,
		     $REPLACE,0,0);
    my $roundness = ($width<$height) ? $width : $height;
    perl_fu_round_sel($img,$layer,$roundness/2);
    custom_set_bg($border_colour);
    gimp_edit_fill($layer, $BG_IMAGE_FILL);
    gimp_selection_none($img);

    gimp_rect_select($img,
		     $x0+$border_width, $y0+$border_width, 
		     $width-2*$border_width, 
		     $height-2*$border_width,
		     $REPLACE,0,0);
    perl_fu_round_sel($img,$layer,$roundness/2);
    custom_set_bg($fill_colour);
    gimp_edit_fill($layer, $BG_IMAGE_FILL);

    # tidy up
    gimp_palette_set_background($bg_colour);
    gimp_selection_none($img);
    gimp_displays_flush();
    gimp_undo_push_group_end($img);
} 

sub draw_protein_bar { # draw the protein main box, title and residue range
 my ($image,$layer,$xoffset,$yoffset,$bgcolour, $length, $name,$xscale) = @_;

 #print "$name length: $length ::";
 if ($length =~ /([\d,\-]+)\s*\:\s*([\d,\-]+)/) 
 {
     $start = "$1";
     $end = "$2";
     $length = $2 - $1 + 1;
 }
 else 
{
    $start = "1";
    $end = "$length";  
}
#print " $length\n";
 # print the name text
 my $text_layer = gimp_text_fontname($image,$layer,2*$xindent, 
				     $yoffset,$name,0,$antialias,
				     $fontsize,$points,$font);
				     #xlfd_size($font),$font);
 gimp_floating_sel_anchor($text_layer);

 # print residue numbers text
 ($textw,@tmp) = gimp_text_get_extents_fontname($start,$fontsize,$points,$font);
 $text_layer = gimp_text_fontname($image,$layer,$xindent-$textw/2+$xoffset*$xscale, 
				  $yoffset+$texth,$start,0,$antialias,
				  $fontsize,$points,$font);
				  #xlfd_size($font),$font);
 gimp_floating_sel_anchor($text_layer);
 ($textw,@tmp) = gimp_text_get_extents_fontname($end,$fontsize,$points,$font);
 $text_layer = gimp_text_fontname($image,$layer,$xindent+($xoffset+$length)*$xscale-$textw/2, 
				  $yoffset+$texth,$end,0,$antialias,
				  $fontsize,$points,$font);
				  #xlfd_size($font),$font);
 gimp_floating_sel_anchor($text_layer);
 #print "Drawing protein bar\n";
 draw_box($image,$xindent+$xscale*$xoffset,$yoffset+2*$texth,$length*$xscale,$boxh,$bordersize,
	  $barcolour,$barcolour);
}

sub draw_single_domain {
    my ($image,$layer,$xoffset,$yoffset,
	$domainstart,$domainend,$class,$veracity, $fillcolour,$xscale,$imap,$imapurl,$length) = @_;
# draw the domain box
    my $boxwidth = int($xscale*($domainend-$domainstart));
    my $boxheight = int($boxh+2*$dextra);
    
    my $pstart = 1;
    if  ($length =~ /([\d,\-]+)\s*\:\s*([\d,\-]+)/) {$pstart = $1;}

    my $x0 = int($xindent+$xscale*($xoffset+$domainstart - $pstart));
    my $y0;

    if ($class eq "T"){
	# then we're doing a special character for a site
	
	my ($charw,$charh) = gimp_text_get_extents_fontname($sitechar,$sitefontsize,$points,$sitefont);

	$x0 = $x0 + $xscale*$sitesize/2 - $charw/4;
	$y0 = int($yoffset+2*$texth+$boxh/2 - $charh/8);

	my $fgcolour = gimp_palette_get_foreground();

        custom_set_fg($fillcolour);
	my $text_layer = gimp_text_fontname($image,$layer,$x0, 
					    $y0,$sitechar,0,$antialias,
					    $sitefontsize,$points,$sitefont);
	                                    #xlfd_size($sitefont),$sitefont);
	gimp_floating_sel_anchor($text_layer);

	gimp_palette_set_foreground($fgcolour);

    }
    else {
	if ($boxwidth-2 < (2*$bordersize+1)){
	    $boxwidth = max(1,$boxwidth);
	    $y0 = int($yoffset+2*$texth-$dextra);
	    draw_borderless_box($image,$x0,$y0,
				$boxwidth,$boxheight,$fillcolour);
	}
	else{ 
	    $bordercolour = $fillcolour;
	    if (($veracity eq "R") || ($veracity eq "r")) {$bordercolour = $red};
	    if (($veracity eq "Y") || ($veracity eq "y")) {$bordercolour = $yellow};
	    if (($veracity eq "G") || ($veracity eq "g")) {$bordercolour = $green};
	    
	    $y0 = int($yoffset+2*$texth-$dextra);
	    if ($class eq "F"){
		draw_ellipse($image,$layer,$x0,$y0,
			     $boxwidth,$boxheight,$bordersize,
			     $bordercolour,$fillcolour);}
	    else {
		draw_box($image,$x0,$y0,
			 $boxwidth,$boxheight,$bordersize,
			 $bordercolour,$fillcolour);}
	    
	}
    }
 # do the image mapping file stuff
 if (($imap ne "None") && ($imapurl ne "")){
     my $x1 = $x0+$boxwidth;
     my $y1 = $y0+$boxheight;
     printf IMAP "rect %s %5d %5d %5d %5d\n", $imapurl,$x0,$y0,$x1,$y1;
 }
}

sub do_collision_detection { 
# calculating offsets so that domains that overlap are at different "heights"
# is a graph colouring problem
# an integer is appended to each of the domain lines. 
# The set of integers is centered around 0

    my $alldomains = $_[0];
    
    @domains = split(/\n/,$alldomains);
    # trivial case
    if (@domains == 1) {
	chomp($alldomains);
	return "$alldomains&0";}
    
    # extract domain start/end
    $i = 0;
    foreach $line (@domains){
	my ($protein,$domain,$range,$class,$colour, $descr, 
	    $method, $veracity,$length,$imapurl) = split(/&/,$line);
	if ($range =~ /:/){($dstart[$i],$dend[$i]) = split(/:/,$range);}
	else {
	    $dstart[$i] = $range;
	    $dend[$i] = $range;
	}
	$i++;
    }

    # work out overlap intersection graph
    foreach $i (0..$#domains-1){ #slightly inefficient, should use symmetry!
	foreach $j ($i+1..$#domains){
	    
	    if ((($dstart[$i] < $dstart[$j]) && ($dstart[$j] < $dend[$i])) ||
		(($dstart[$i] < $dend[$j]) && ($dend[$j] < $dend[$i]))     ||
		(($dstart[$j] < $dstart[$i]) && ($dstart[$i] < $dend[$j])) ||
		(($dstart[$j] < $dend[$i]) && ($dend[$i] < $dend[$j])))
	    {
		$inc[$i][$j] = 1;
		$inc[$j][$i] = 1;
	    }
	    else {$inc[$i][$j] = 0;
		  $inc[$j][$i] = 0;}
	}
    }

    # find degrees of vertices
    $maxdeg = 0;
    $mindeg = 1000;
    foreach $i (0..$#domains){
	$degree[$i] = 0;
	foreach $j (0..$#domains){
	    if ($inc[$i][$j] == 1) {$degree[$i]++;}
	}
	if ($degree[$i] > $maxdeg) {$maxdeg = $degree[$i];}
	if ($degree[$i] < $mindeg) {$mindeg = $degree[$i];}

    }    

    # go through the vertices by decreasing degree
    # color the vertices:
    # (1) in order of decreasing degree
    # (2) for each vertex use smallest natural number that is not
    #     already adjacent to that vertex

    my %colour;
    my $maxcolour = 0;

    for ($d=$maxdeg; $d>=$mindeg; $d--){
	for ($i=0; $i <= $#domains; $i++){

	    if ($degree[$i] == $d){
		# find first non-used colour that is adjacent to i.

		my @used;
		foreach $j (0..$#domains){
		    if (($inc[$i][$j] == 1) && (defined($colour{$j}))){
			$used[$colour{$j}] = 1;
		    }
		}
		
		$j = 0;
		while (defined($used[$j])){
		    $j++;
		}
		$colour{$i} = $j;
		if ($j > $maxcolour) {$maxcolour = $j;}
	    }
	}
    }    
    # normalise the colours from 0..n to -n/2 to n/2
    foreach $c (keys(%colour)){
	if (($colour{$c} % 2) == 1){$colour{$c} = int(($colour{$c}+1)/2);}
	else {$colour{$c} = -1*int(($colour{$c}+1)/2);}
    }

    my $coloureddomains = "";

    foreach $i (0..$#domains){
	$domains[$i] = "$domains[$i]&$colour{$i}"; 
    }
 
    # sort domains if some are contained in others
    foreach $i (0..$#domains){ 
	foreach $j (0..$#domains){
	    
	    if (($i != $j) && ($dstart[$j] <= $dstart[$i]) 
		&& ($dend[$i] <= $dend[$j])
		&& !(($dstart[$i] == $dstart[$i]) && ($dend[$i] == $dend[$j]))
		) # $domain[$i] < $domain[$j]
	    {
		$inc[$i][$j] = 1;
	    }
	    else {$inc[$i][$j] = 0;}
	}
    }

    # we sort according to this partial order on domains
    # via the _bad_ algorithm of swapping pairs that are out of order

    $i = 0; 
    while ($i <= $#domains){ #there's a bug in here for >= 15 domains.
	$j = $i+1;
	$found = 0;
	while (($found == 0) && ($j <= $#domains)){
	    if ($inc[$i][$j] == 1){
		$found = 1;
		$tmpdomain  = $domains[$i];
		$domains[$i] = $domains[$j];
		$domains[$j] = $tmpdomain;
		# swap i,j rows and columns in inc.
		# this really is apalling 
		for ($k = 0; $k <= $#domains; $k++){
		    $tmp = $inc[$i][$k];
		    $inc[$i][$k] = $inc[$j][$k];
		    $inc[$j][$k] = $tmp;
		}
		for ($k = 0; $k <= $#domains; $k++){
		    $tmp = $inc[$k][$i];
		    $inc[$k][$i] = $inc[$k][$j];
		    $inc[$k][$j] = $tmp;
		}

		$i = -1;
	    }
	    else {$j++;}
	}
	$i++;
    }

    foreach $i (0..$#domains-1){
	$coloureddomains = "$coloureddomains$domains[$i]\n";
    }   
    $coloureddomains = "$coloureddomains$domains[$#domains]";    
    
    return $coloureddomains;
}


    #################################
    # MAIN ROUTINE TO DO EVERYTHING #
    #################################

sub domain {

    my $domainstring = shift;
    my $filename = shift;
    my $imagewidth = shift;
    my $align = shift;
    my $scalefactor = shift;
    my $simplelegend = shift;
    $barcolour = shift; 
    $bgcolour = shift;
    my $textcolour = shift;
    my $imap = shift;
    $font = shift;
    $sitefont = shift;
    $antialias = shift;
    #$barcolour=Gimp::canonicalize_colour($barcolour);

    #print "Input bar colour = $barcolour\n";

    if ($font =~ /^-[^-]*-[^-]*-[^-]*-[^-]*-[^-]*-[^-]*-([^-]*)-/){
	$fontsize = $1; # gimp 1.2.3
    }
    else {
	$font =~/\s(\d+)$/;
	$fontsize = $1; # gimp 2.2.0
    }
    if ($sitefont =~ /^-[^-]*-[^-]*-[^-]*-[^-]*-[^-]*-[^-]*-([^-]*)-/){
	$sitefontsize = $1; # gimp 1.2.3   
    }
    else {
	$sitefont =~/\s(\d+)$/;
	$sitefontsize = $1; # gimp 2.2.0
    }


    ##########################
    # Do scaling if necessary #
    ##########################

    if ($scalefactor != 1.0){ #make it all larger
	$ysizeperprotein = $ysizeperprotein*$scalefactor;
	$xindent = $xindent*$scalefactor;
	$yindent = $yindent*$scalefactor;

        $texth = $texth*$scalefactor;
        $boxh = $boxh*$scalefactor;
	$bordersize = $bordersize*$scalefactor;
	$dextra = $dextra*$scalefactor;
	$legendboxsize = $legendboxsize*$scalefactor;
	$doffsetscale = $doffsetscale *$scalefactor;
	
    }


    ###################
    # read in domains #
    ###################
    my @domains = ();
    if ($domainstring ne "None"){
	$domainstring =~ s/\&\s+/\&/g; # remove superfluous white space
	$domainstring =~ s/\s+\&/\&/g;
	$domainstring =~ s/^\s+//g;	
	$domainstring =~ s/\s+$//g;	
	$domains[0] = $domainstring;
    }
    else {
	open(FH,"<$filename")
	    or die "Couldn't open $filename for reading: $!\n";

	while (defined($line = <FH>)){
	    $line =~ s/\&\s+/\&/g; # remove superfluous white space
	    $line =~ s/\s+\&/\&/g;
	    $line =~ s/^\s+//g;	
	    $line =~ s/\s+$//g;	
	    if (!(($line =~ /^\#/) || ($line =~ /^\s*$/))){
		chomp($line);
		push(@domains,$line);
		#print $line,"\n";
	    }
	}
	close(FH);
    }

    ########################
    # check input validity #
    ########################
    foreach $i (0..$#domains){ 
	$line = $domains[$i];
	chomp($line);
	if (!($line =~ /^\#/)){ 
	    my $ampersands = $line;
	    if ($line =~ /^(.*)http/){
	      $ampersands = $1;
	      #print $1;
	    }
	    $ampersands =~ s/[^\&]//g;
	    if (length($ampersands) != 9){
		print "\n\nERROR in input line:\n  $line\n";
		print "Input should be of form:\n";
		print "  Protein & Domain & Range & Class & Color & Desc. & Method & Veracity & Length & Url\n";
		print "Url may be empty, but all other fields must be used.\n";
		print "Length is usually the length of the protein, but may\n";
		print "also be used as a residue number range, i.e. 20:212.\n";
		print "White space around '&' and at the beginning and eol are ignored.\n\n";
		exit(0);
	    }
	    my ($protein,$domain,$range,$class,$colour, $descr, 
		$method, $veracity,$length,$imapurl) = split(/&/,$line);

	    # do some more input validity checking here !!
	    
	}
    }

    my $oldname = "";
    my $nproteins = 0;
    my $maxlength = 0; # find longest protein, and number of them, and the domain colours
    my $ndomains  = 0;

    my $maxd1 = -1; # for aligning domains. maxd1 is the maximum #residues of the
    my $maxdL = -1; # named domain from residue 1 to the start of the domain
                   # maxdL is maximum from start of domain to last residue
    

 
    ######################################################################
    # site proteins need to be fiddled with as they are a single residue #
    # but their image is a * character                                   #
    ######################################################################
       
    my ($starw,$starh) = gimp_text_get_extents_fontname($sitechar,$sitefontsize,$points,$sitefont);
    #my ($starw,$starh) = 15;

    foreach $i (0..$#domains){ 
	$line = $domains[$i];
	chomp($line);
	if (!(($line =~ /^\#/) || ($line =~ /^\s*$/))){ #ignore comment lines that begin with a hash
	    my ($protein,$domain,$range,$class,$colour, $descr, 
		$method, $veracity,$length,$imapurl) = split(/&/,$line);
	    if ($class eq "T") {
		$siterange{$domain} = $range;
		my $srange = int($range - $sitesize/2);
		my $erange = int($range + $sitesize/2);
		$range = "$srange:$erange";
		$domains[$i] = "$protein&$domain&$range&$class&$colour&$descr&$method&$veracity&$length&$imapurl\n";
	
	    }
	}
    }

    ########################################
    # extract the domains and the proteins #
    ########################################

    my @protnames; # need to keep order that proteins are read in
	my %veracitiesUsed = ();
	my $nVeracities;
	my @uniqueDomainNames = ();

    foreach $line (@domains){ 
	#print " XX: $line\n";
	chomp($line);
	if (!($line =~ /^\#/)){ #ignore comment lines that begin with a hash
	    my ($protein,$domain,$range,$class,$colour, $descr, 
			$method, $veracity,$length,$imapurl) = split(/&/,$line);
	    my $protein_start = 1;
	    if  ($length =~ /([\d,\-]+)\s*\:\s*([\d,\-]+)/) 
	    {
			$length = $2 - $1+1;
			$protein_start = $1;
	    }
	    
		if (!defined($domcolours{"$domain"})){
			push(@uniqueDomainNames,$domain);			
		}

	    if ($length > $maxlength) {$maxlength = $length}
	    if ($colour ne ""){$domcolours{"$domain"} = "$colour";}
	    else {$domcolours{"$domain"} = $defaultdomcolour;}
	    
	    $domclass{"$domain"} = $class;
	    $domurl{"$domain"} = $imapurl;
	    
	    if ($oldname ne $protein){
			$oldname = $protein;
			push(@protnames, $protein);
			$proteins{"$protein"}= $line . "\n";
			$nproteins += 1;  
			$maxd1forprotein = 0;
	    }
	    else {
			$proteins{"$protein"} = $proteins{"$protein"} . $line . "\n";
	    }
	    # domain alignment calcs

	    # FIX THIS FOR NON-ONE PROTEIN START
	    if ($align eq $domain){
		if ($range =~ /:/){($domainstart,$domainend) = split(/:/,$range);}
		else {$domainstart = $range;}#FIX!!!
 
		if ($domainstart-$protein_start+1 > $maxd1) {
		    $maxd1 = $domainstart-$protein_start+1;
		}
		if ($domainstart-$protein_start+1 > $maxd1forprotein) {
		    $maxd1forprotein = $domainstart-$protein_start+1; #record maximum for a given protein
		}
		if (($length-($domainstart-$protein_start+1)) > $maxdL) {$maxdL = $length-($domainstart-$protein_start+1);}

		$palign{$protein} = $maxd1forprotein; # mark the proteins to be aligned
		#print "$protein :: $palign{$protein}\n"; #seems to be calculating these ok.
	    }
		# check if there are distinct vercities
		if (($veracity ne "") && (!defined($vercitiesUsed{$veracity}))){
			$veracitiesUsed{$veracity} = 1;	
			#print "V-",$veracity,"-\n";
		}

	    $ndomains++;
	}
    }
	$nVeracities = scalar keys(%veracitiesUsed);
	#print "# veracities is ",$nVeracities,"\n";

    ############################################################
    # work out collision detection and offsets for the domains #
    ############################################################

    foreach $protein (keys(%proteins)){
	$proteins{"$protein"} = do_collision_detection($proteins{"$protein"});
    }
 

    ####################################################################
    # Do some size calculations and create the canvas to put it all on #
    ####################################################################

    if ($align eq "None"){
	$xscale =  ($imagewidth - 2*$xindent)/$maxlength; # pixels per residue
    }
    else {$xscale = ($imagewidth - 2*$xindent)/max(($maxd1+$maxdL),$maxlength);}

    my $yoffset = $yindent;
    my $xsize = $imagewidth;
 
    @domainnames = keys(%domclass);

	my $veracityLegendSpace = 0;
	if ($nVeracities > 1){ $veracityLegendSpace = $nVeracities}	

    if (($simplelegend == 0)){
	$ysize = $yoffset + $nproteins * $ysizeperprotein 
	                  + $heightspace*($ndomains+$veracityLegendSpace)*$texth;}
    else {
	$ysize = $yoffset + $nproteins * $ysizeperprotein 
	                  + $heightspace*(@domainnames+$veracityLegendSpace)*$texth;}

    $img = gimp_image_new($xsize, $ysize, RGB);  # Create a new image and layer
    $layer = gimp_layer_new($img, $xsize, $ysize, RGB,
                        "Layer 1", 100, NORMAL_MODE);
    gimp_image_add_layer($img, $layer, -1); # add the layer to the image

    custom_set_bg($bgcolour);
    custom_set_fg($textcolour);
    gimp_edit_fill($layer, $BG_IMAGE_FILL);  # Paint the layer bgcolour

    $yoffset = $yoffset - $ysizeperprotein;
    my $xoffset = 0; # how many residues to indent a protein bar
    $oldname = "";
 

    #################################
    # draw protein bars and domains #
    #################################
    if ($imap ne "None"){
	open(IMAP, "> $imap")
	    or die "Couldn't open $imap for reading: $!\n";
    }
   
    foreach $prot (@protnames){

	@protdoms = split(/\n/,$proteins{$prot});
	my $drawnpb = 0;
	for ($i=0; $i<=$#protdoms; $i++){
	    $dom = $protdoms[$i];
	    my ($protein,$domain,$range,$class,$colour, $descr, $method, 
		$veracity,$length,$imapurl,$doffset) = split(/&/,$dom);
	    #print "$protein :  $maxd1 :  $palign{$protein}\n";
	    if ($range =~ /:/){($domainstart,$domainend) = split(/:/,$range);}
	    else {$domainstart = $range;
	          $domainend = $range;}

	    if (defined($palign{$protein})){$xoffset =  $maxd1 - $palign{$protein};}
	    else {$xoffset = 0;}
	    if ($drawnpb == 0){
		# start a new protein bar
		$yoffset += $ysizeperprotein;

		draw_protein_bar($img,$layer,$xoffset,$yoffset,$bgcolour, 
				 $length, $protein,$xscale);
		$drawnpb = 1;
	    }
	    # draw the domain
	    draw_single_domain($img,$layer,$xoffset,$yoffset - $doffset * $doffsetscale,
			       $domainstart,$domainend,$class,$veracity,
			       $domcolours{"$domain"},$xscale, $imap, $imapurl,$length);
	}
    }

    
    ###########################
    # draw legend for domains #
    ###########################

    $yoffset += $ysizeperprotein;

    if (($simplelegend == 0)){
	foreach (@domains){
	    #print "$_\n;";
	    if (!(/^\#/)){ # file comment lines begin with a hash
		chomp;
		my ($protein,$domain,$range,$class,$colour, $descr, 
		    $method, $veracity,$length,$imapurl) = split(/&/);    
		
		if (($imap ne "None") && ($imapurl ne "")){
		    printf IMAP "rect %s %5d %5d %5d %5d\n", $imapurl,$xindent,$yoffset,
			                                     $xindent+$legendboxsize,
                                                             $yoffset+$legendboxsize;
		}

		if ($domclass{"$domain"} eq "T"){
		    
		    my $fgcolour = gimp_palette_get_foreground();
		    custom_set_fg($domcolours{"$domain"});
		    my $text_layer = gimp_text_fontname($img,$layer,$xindent,
							$yoffset,$sitechar,0,$antialias,
							$sitefontsize,$points,$sitefont);
		    gimp_floating_sel_anchor($text_layer);
		    
		    custom_set_fg($fgcolour);
		    $dtext = "$domain";
		}
		else {
		    if ($domclass{"$domain"} eq "F"){
			draw_ellipse($img,$layer,$xindent,$yoffset,$legendboxsize,$legendboxsize,
				     $bordersize,$domcolours{"$domain"},
				     $domcolours{"$domain"});}
		    else {
			draw_box($img,$xindent,$yoffset,$legendboxsize,$legendboxsize,
				 $bordersize,$domcolours{"$domain"},$domcolours{"$domain"});}
		}
		if ($domclass{"$domain"} eq "T"){
		    $dtext = "$domain ($siterange{$domain})";}
		else {
		    $dtext = "$domain ($range)\n";
		}
		my $text_layer = gimp_text_fontname($img,$layer,$xindent+1.5*$legendboxsize,
						    $yoffset,$dtext,0,$antialias,
						    $fontsize,$points,$font);
						    #xlfd_size($font),$font);
		gimp_floating_sel_anchor($text_layer);

		$yoffset = $yoffset + $heightspace*$texth;
	    }
	}
    }
    else {	
	foreach $domain (@uniqueDomainNames){
	   
	    if ($domclass{"$domain"} eq "T"){
		
		my $fgcolour = gimp_palette_get_foreground();
		custom_set_fg($domcolours{"$domain"});
		my $text_layer = gimp_text_fontname($img,$layer,$xindent,
						    $yoffset,$sitechar,0,$antialias,
						    $sitefontsize,$points,$sitefont);
						    #xlfd_size($sitefont),$sitefont);
		gimp_floating_sel_anchor($text_layer);
		custom_set_fg($fgcolour);
		$dtext = "$domain";
		my $text_layer = gimp_text_fontname($img,$layer,$xindent+1.5*$legendboxsize,
						    $yoffset,$dtext,0,$antialias,
						    $fontsize,$points,$font);
						    #xlfd_size($font),$font);
		gimp_floating_sel_anchor($text_layer);
		
	    }
	    else {
		if ($domclass{"$domain"} eq "F"){
		    draw_ellipse($img,$layer,$xindent,$yoffset,$legendboxsize,$legendboxsize,
				 $bordersize,$domcolours{"$domain"},$domcolours{"$domain"});
		}
		else {
		    draw_box($img,$xindent,$yoffset,$legendboxsize,$legendboxsize,
			     $bordersize,$domcolours{"$domain"},$domcolours{"$domain"});}	
		$dtext = "$domain";
		my $text_layer = gimp_text_fontname($img,$layer,$xindent+1.5*$legendboxsize,
						    $yoffset,$dtext,0,$antialias,
						    $fontsize,$points,$font);
		#xlfd_size($font),$font);
		gimp_floating_sel_anchor($text_layer);
	    
	    }
	    if (($imap ne "None") && ($domurl{"$domain"} ne "")){
		printf IMAP "rect %s %5d %5d %5d %5d\n", $domurl{"$domain"},$xindent,$yoffset,
		                                         $xindent+$legendboxsize,
		                                         $yoffset+$legendboxsize;
	    }
	    
	    $yoffset = $yoffset + $heightspace*$texth;
	}
    }

    if ($imap ne "None"){
	close(IMAP);
    }
    
    #########################################################
    # draw the class legend if there is more than one class #
    #########################################################
	if ($nVeracities > 1)
	{
    ############ yellow ############
	if (defined($veracitiesUsed{"y"}) || defined($veracitiesUsed{"Y"}))
	{ 
    	draw_box($img,$xindent,$yoffset,$legendboxsize,$legendboxsize,
	     $bordersize,$yellow,$bgcolour);
    	$dtext = "Predicted, unconfirmed";
    	my $text_layer = gimp_text_fontname($img,$layer,$xindent+1.5*$legendboxsize,
						$yoffset,$dtext,0,$antialias,
						$fontsize,$points,$font);
						#xlfd_size($font),$font);
    	gimp_floating_sel_anchor($text_layer);
    	$yoffset = $yoffset + $heightspace*$texth;
	}
    
    ############ red ############
	if (defined($veracitiesUsed{"r"}) || defined($veracitiesUsed{"R"}))
	{ 
    	draw_box($img,$xindent,$yoffset,$legendboxsize,$legendboxsize,
	     $bordersize,$red,$bgcolour);
    	$dtext = "Disproved";
    	my $text_layer = gimp_text_fontname($img,$layer,$xindent+1.5*$legendboxsize,
					$yoffset,$dtext,0,$antialias,
					$fontsize,$points,$font);
                                        #xlfd_size($font),$font);
    	gimp_floating_sel_anchor($text_layer);
    	$yoffset = $yoffset + $heightspace*$texth;
	}
    ############ green ############ 
	if (defined($veracitiesUsed{"g"}) || defined($veracitiesUsed{"G"}))
	{ 
    	draw_box($img,$xindent,$yoffset,$legendboxsize,$legendboxsize,
	    	 $bordersize,$green,$bgcolour);
    	$dtext = "Confirmed";
    	my $text_layer = gimp_text_fontname($img,$layer,$xindent+1.5*$legendboxsize,
					$yoffset,$dtext,0,$antialias,
					$fontsize,$points,$font);
					#xlfd_size($font),$font);
    	gimp_floating_sel_anchor($text_layer);
    	$yoffset = $yoffset + $heightspace*$texth;
	}
	}
    # Return the image
    return $img;
  }

register
        "domain",
        "Used to generate images of multiple domains on multiple proteins",
        "Creates images of protein domains",
        "Dr Nick <nick\@maths.uq.edu.au>\n",
        "Copyright (c) 2006 Dr Nick and Lynn Fink. Released under GPL.",
        "2005",
        "<Toolbox>/Xtns/Perl-Fu/DomainDraw",
        "RGB",
        [
                [PF_STRING, "singledomain", "Single Domain string","None"],
                [PF_STRING, "batchfile", "Batch domains file name","domainex9.txt"],
                [PF_INT,    "xpixels", "Image width in pixels", "400"],
                [PF_STRING, "alignto", "Align to domain", "None"],
                [PF_FLOAT,  "scale", "Scale factor", 1.0],
                [PF_TOGGLE, "simplelegend", "Do simplified legend", 1],
                [PF_STRING, "barcolour", "Color of protein bar","#DEDEDE"],
                [PF_STRING, "bgcolour", "Color of background","#FFFFFF"],
                [PF_STRING, "textcolour", "Color of text","#000000"], 
                [PF_STRING, "imap", "Output image map file","None"],
	        [PF_FONT,   "font", "font", "-*-courier-medium-r-normal-*-12-*-*-*-*-*-iso8859-1"],

	        [PF_FONT,   "sitefont", "Site font", "-*-courier-medium-r-normal-*-18-*-*-*-*-*-iso8859-1"],
	        # for gimp 2.2 use following two default fonts instead of previous 2
	        #[PF_FONT,   "font", "font", "Sans 12"],
	        #[PF_FONT,   "sitefont", "Site font", "Sans 18"],
	        [PF_TOGGLE, "antialias", "Anti-alias text", 0]
        ],
        [PF_IMAGE],
        \&domain;

  exit main();

