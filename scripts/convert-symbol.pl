#!/usr/bin/perl

use utf8;
use strict;
use Getopt::Std;
use XML::Writer;
use XML::LibXML;
use XML::Schematron::XPath;
require Gschem::File;

my %args;
getopt('s', \%args);
my $file = shift;

my %sym_validation;
my %sym_global_attributes;
my %sym_tag_attributes;
my %sym_pins;

my $output = new IO::File(">$file");

my $writer = new XML::Writer(OUTPUT => $output,
			     DATA_MODE => 1,
			     DATA_INDENT => 2);

my $sym_filename = $args{s};
open SYM_FILE, "$sym_filename" or die $!;
my $line;

$writer->xmlDecl("UTF-8");
$writer->startTag("part", 
		  "xmlns" => "http://www.geda-project.org/schemas/geda-gaf/part",
		  "xmlns:gs" => "http://www.geda-project.org/schemas/geda-gaf/libgeda",
		  "xmlns:pcb" => "http://www.geda-project.org/schemas/geda-gaf/pcb",
		  "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		  "xsi:schemaLocation" => "http://www.geda-project.org/schemas/geda-gaf/part ../part/part.xsd");

process_sym_file("validate");

foreach (keys(%sym_global_attributes)) {
	print "$_ = $sym_global_attributes{$_}\n";
}
foreach (keys(%sym_tag_attributes)) {
	print "$_ = $sym_tag_attributes{$_}\n";
}

if ($sym_validation{'is_font'}) {
	write_font();
} else {
	write_symbol();
}

close SYM_FILE or die $!;

$writer->endTag("part");
$writer->end();
$output->close();

#my $doc = XML::LibXML->new->parse_file($file);

#my $xmlschema = XML::LibXML::Schema->new( location => "../part/part.xsd" );
#my $ret = $xmlschema->validate( $doc );
#print "XML Schema result = $ret\n";

#my $tron = XML::Schematron::XPath->new( schema => "../part/part.xsd" );

#my @messages = $tron->verify($file);

#print "Schematron results:\n";
#foreach (@messages) {
#	print trim($_) . "\n";
#}

#
#
#
#
sub write_font
{
	my %attributes;

	while ($line = <SYM_FILE>) {
		if (!utf8::is_utf8($line)) {
			utf8::encode($line);
		}
		my @params = split(' ', $line);

		my $params_size = scalar @params;
		my @pass_params = splice(@params, 1, $params_size);
		if ($params[0] eq "v") {
			$attributes{'version'} = "@pass_params";
		}
	}

	my $curr_pos = tell(SYM_FILE);

	$writer->startTag("font",
			  %attributes);

	add_font();

	seek(SYM_FILE, $curr_pos, 0);

	$writer->endTag("font");
}

sub write_symbol
{
	my $attributes = shift;
	
	$writer->startTag("symbol",
			  %{$attributes});

	add_global_attributes();
	add_drawing_primatives();

	if ($sym_validation{'has_pins'}) {
		$writer->startTag("pins");
		process_sym_file("process_pins");
		$writer->endTag("pins");
	}

	$writer->endTag("symbol");
}

sub add_font
{
	my $pass_params = shift;
	$writer->startTag("f",
			  "p" => join(" ",@{$pass_params}));

	add_drawing_primatives();
	
	$writer->endTag("f");
	
}

sub add_documentation
{
	my %attributes;
	if ($sym_global_attributes{'documentation'}) {
		$attributes{'uri'} = $sym_global_attributes{'documentation'};
		$writer->emptyTag("documentation", %attributes);
	}
}


sub add_global_attributes
{
	my $params = shift;
	my %attributes;
	
	foreach (keys(%sym_global_attributes)) {
		if ($_ ne "documentation") {
			$attributes{'n'} = trim($_);
			$attributes{'v'} = trim($sym_global_attributes{$_});
			write_primative("gs:attr",$params,\%attributes);
		}
	}
}

sub add_drawing_primatives
{
	seek(SYM_FILE, 0, 0);
	my $found_subitem=0;
	my $found_text=0;
	my $done_text=1;
	my $found_path=0;
	my $done_path=1;
	my @path_params;
	my @pass_params;
	my @text_array;

	while ($line = <SYM_FILE>) {
		if (!utf8::is_utf8($line)) {
			utf8::encode($line);
		}
		my @params = split(' ', $line);

		my $params_size = scalar @params;

		if (!$found_subitem) {
			if ($found_text) {
				# This is not an attribute
				if (!($line =~ m/=/)) {
					push (@text_array, $line);
					$found_text -= 1;
					next;
				} else {
					# Reset on an attribute
					$done_text = 1;
					@text_array = ();
				}
			} elsif (!$done_text) {
				$writer->startTag("gs:t",
						  "p" => join(" ", @pass_params));
				foreach (@text_array) {
					$writer->characters(trim($_));
				}
				$writer->endTag("gs:t");
				$done_text = 1;
				@text_array = ();
			}
		} else {
			if ($params[0] eq "}") {
				$found_subitem = 0;
			} else {
				next;
			}
		}

		if ($found_path) {
			if ($params[0] eq "M") { # Path MoveTo
				@path_params = splice(@params, 1, $params_size);
				write_primative("gs:m",\@path_params);
			} elsif ($params[0] eq "L") { # Path Line
				@path_params = splice(@params, 1, $params_size);
				write_primative("gs:l",\@path_params);
			} elsif ($params[0] eq "C") { # Path CurveTo
				@path_params = splice(@params, 1, $params_size);
				write_primative("gs:c",\@path_params);
			} elsif ($params[0] eq "Z" || $params[0] eq "z") { # Close Path
				write_primative("gs:z");
			}
			$found_path -= 1;
			if (!$found_path && !$done_path) {
				$writer->endTag("gs:h");
				$found_path = 0;
				$done_path = 1;
			}
			next;
		}

		if ($params[0] eq "L") { # Line
			@pass_params = splice(@params, 1, $params_size);
			write_primative("gs:l",\@pass_params);
		} elsif ($params[0] eq "G") { # Picture
			@pass_params = splice(@params, 1, $params_size);
			write_primative("gs:g",\@pass_params);
		} elsif ($params[0] eq "B") { # Box
			@pass_params = splice(@params, 1, $params_size);
			write_primative("gs:b",\@pass_params);
		} elsif ($params[0] eq "V") { # Circle
			@pass_params = splice(@params, 1, $params_size);
			write_primative("gs:v",\@pass_params);
		} elsif ($params[0] eq "A") { # Arc
			@pass_params = splice(@params, 1, $params_size);
			write_primative("gs:a",\@pass_params);
		} elsif ($params[0] eq "T") { # Text
			@pass_params = splice(@params, 1, $params_size);
			if ($#pass_params < 10) {
				$found_text = 1;
			} else {
				$found_text = $pass_params[$#pass_params];
			}
			$done_text = 0;
			next;
		} elsif ($params[0] eq "H") { # Path
			@pass_params = splice(@params, 1, $params_size);
			$writer->startTag("gs:h",
					  "p" => join(" ", @pass_params));
			$found_path = $pass_params[$#pass_params];
			$done_path = 0;
		} elsif ($params[0] eq "{") {
			$found_subitem=1;
			next;
		} elsif ($params[0] eq "v" || $params[0] eq "F") {
		} elsif (!$found_text && !$found_path && !$found_subitem && 
			 $done_text && $done_path &&
			 ($params[0] ne "P") && ($params[0] ne "}")) {
			print "Unhandled primative '$params[0]' found in $file\n";
			exit();
		}

		$found_text=0;
	}
}

sub is_attribute
{
	my $line = shift;
	
	if ($line =~ m/=/) {
		return 1;
	}
	return 0;
}

# Allowed modes:
# $mode = "validate"
# $mode = "process_drawing_primatives"
# $mode = "process_pins"
sub process_sym_file
{
	my $mode = shift;
	
	my $in_text = 0;
	my $text_num_lines = 0;
	my $text_line_count = 0;
	my $in_path = 0;
	my $path_num_lines = 0;
	my $path_line_count = 0;
	my $in_attribute_list = 0;
	my $line_number = 0;

	if ($mode eq "validate") {
		$sym_validation{'is_font'} = 0;
		$sym_validation{'has_tag_attributes'} = 0;
		$sym_validation{'has_global_attributes'} = 0;
		$sym_validation{'has_attribute_list'} = 0;
		$sym_validation{'has_primative_attributes'} = 0;
		$sym_validation{'has_pins'} = 0;
	}

	my @text_;

	while ($line = <SYM_FILE>) {
		$line_number++;
		# Convert to utf-8 if it's not already
		if (!utf8::is_utf8($line)) {
			utf8::encode($line);
		}
		my @params = split(' ', $line);

		if ($in_text) {
			# Capture global attributes
			if (is_attribute($line)) {
				if (!$in_path && !$in_attribute_list) {
					my @attribute = split('=', $line);
					if ($mode eq "validate") {
						get_attribute(\@attribute,1);
					}
				} else {
					if ($mode eq "validate") {
						$sym_validation{'has_primative_attributes'}++;
					}
				}
			}
			$text_line_count++;
			if ($text_line_count < $text_num_lines) {
				next;
			} else {
				$in_text = 0;
				next;
			}
		}

		if ($in_path) {
			if ($mode = "validate") {
				# Validate path primatives
				if (!($params[0] eq "M" || $params[0] eq "L" || $params[0] eq "C" ||
				      uc($params[0]) eq "Z")) {
				    	print "Found unexpected primative $params[0] in $file\n";
				    	exit();
				}
				
				if (uc($params[0]) eq "Z" && $path_line_count < ($path_num_lines - 1)) {
					print "Found end of path Z before count expired in $file\n";
					exit();
				} elsif (uc($params[0]) eq "Z") {
					$path_line_count++;
				}
				
				if ($path_line_count < $path_num_lines) {
					next;
				} else {
					$in_path = 0;
				}
			}
		}

		if (!$in_text && !$in_path && !$in_attribute_list) {
			if ($params[0] eq "T") { # Text
				# If there are less than 11 text parameters (including the "T"),
				# it's the old format...
				$text_line_count = 0;
				if ($#params < 11) {
					$text_num_lines = 1;
				} else {
					$text_num_lines = $params[$#params];
				}
				$in_text = 1;
			} elsif ($params[0] eq "H") { # Path
				if ($mode eq "validate") {
					$sym_validation{'paths'}++;
				}
				$path_line_count = 0;
				$path_num_lines = $params[$#params];
				$in_path = 1;
			} elsif ($params[0] eq "{") { # Start attribute_list
				if ($mode eq "validate") {
					$sym_validation{'has_attribute_list'} = 1;
				}
				$in_attribute_list=1;
			} elsif ($params[0] eq "}") { # End Subitems
				$in_attribute_list=0;
				if ($mode eq "process_pins") {
					$writer->endTag("p");
				}
			} elsif ($params[0] eq "v") { # Save file version
				my @version_params = splice(@params, 1, $#params);
				$sym_tag_attributes{'version'} = "@version_params";
			} elsif ($params[0] eq "F" && !$sym_validation{'is_font'}) { # Record if this is a font file
				if ($mode eq "validate") {
					$sym_validation{'is_font'} = 1;
				}
			} elsif ($params[0] eq "P") { # Record number of pins found
				if ($mode eq "validate") {
					$sym_validation{'has_pins'}++;
				}
				if ($mode eq "process_pins") {
					my @pin_params = splice(@params, 1, $#params);
					$writer->startTag("p", \@pin_params);
				}
			} elsif (!($params[0] eq "L" || $params[0] eq "G" || $params[0] eq "B" || 
				   $params[0] eq "V" || $params[0] eq "A")) {
				print "Unhandled primative '$params[0]' found in $file\n";
				exit();
			} elsif ($mode eq "process_drawing_primatives") {
				process_drawing_primatives();
			}
		}
	}
}

sub get_attribute
{
	my $attribute = shift;
	my $record_validation = shift;

	if (@{$attribute}[0] eq "angle" ||
	    @{$attribute}[0] eq "device" ||
	    @{$attribute}[0] eq "description" ||
	    @{$attribute}[0] eq "author") {
	    	$sym_tag_attributes{@{$attribute}[0]} = trim(@{$attribute}[1]);
	    	if ($record_validation) {
	    		$sym_validation{'has_tag_attributes'}++;
	    	}
	} elsif (@{$attribute}[0] eq "mirror") {
		$sym_global_attributes{'mirror'}  = 
			(trim(@{$attribute}[1]) == 1) ? "mirrored" : "not-mirrored";
	} elsif (@{$attribute}[0] eq "graphical") {
		$sym_global_attributes{'graphical'}  = 
			(trim(@{$attribute}[1]) == 1) ? "true" : "false";
	} elsif (@{$attribute}[0] eq "selectable") {
		$sym_global_attributes{'selectable'}  = 
			(trim(@{$attribute}[1]) == 1) ? "selectable" : "not-selectable";
	} else {
		$sym_global_attributes{@{$attribute}[0]} = trim(@{$attribute}[1]);
		if ($record_validation) {
			$sym_validation{'has_global_attributes'}++;
		}
	}
}

sub process_pins
{
	my $pin_params = shift;
	my $attributes = shift;

	while ($line = <SYM_FILE>) {
		if (!utf8::is_utf8($line)) {
			utf8::encode($line);
		}
		my @params = split(' ', $line);

		if ($params[0] eq "}") {
			write_primative("p",$pin_params,$attributes);
		}
		# This is an attribute
	#	if ($line =~ m/=/) {
	#		my @attribute = split('=', $line);
	#		if ($attribute[0] eq "pinnumber") {
	#			$attributes{'number'} = trim($attribute[1]);
	#		} elsif ($attribute[0] eq "pinseq") {
	#			$attributes{'seq'} = trim($attribute[1]);
	#		} elsif ($attribute[0] eq "pinlabel") {
	#			$attributes{'label'} = trim($attribute[1]);
	#		} elsif ($attribute[0] eq "pintype") {
	#			$attributes{'type'} = trim($attribute[1]);
	#		}
	#	}
	}	
}

sub write_primative
{
	my $primative = shift;
	my $params = shift;
	my $attributes = shift;

	if (!defined($params)) {
		if (defined($attributes) && keys (%{$attributes}) != 0) {
			$writer->emptyTag("$primative",
					  %{$attributes});
		} else {
			$writer->emptyTag("$primative");
		}
	} else {
		if (defined($attributes) && keys (%{$attributes}) != 0) {
			$writer->emptyTag("$primative",
					  "p" => join(" ",@{$params}),
					  %{$attributes});
		} else {
			$writer->emptyTag("$primative",
					  "p" => join(" ",@{$params}));
		}
	}
}

sub trim
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
