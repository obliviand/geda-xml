#!/usr/bin/perl

use utf8;
use strict;
use Getopt::Std;
use XML::Writer;
use IO::File;
use XML::LibXML;

my %args;
getopt('s', \%args);
my $file = shift;

my $output = new IO::File(">$file");

my $writer = new XML::Writer(OUTPUT => $output,
			     DATA_MODE => 1,
			     DATA_INDENT => 2);

my $sym_filename = $args{s};
open SYM_FILE, "$sym_filename" or die $!;
my $line;

$writer->xmlDecl("UTF-8");
$writer->startTag("part", 
		  "xmlns" => "http://www.gpleda.org/schemas/geda-gaf/part",
		  "xmlns:gs" => "http://www.gpleda.org/schemas/geda-gaf/libgeda",
		  "xmlns:pcb" => "http://www.gpleda.org/schemas/geda-gaf/pcb",
		  "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		  "xsi:schemaLocation" => "http://www.gpleda.org/schemas/geda-gaf/part ../part/part.xsd");
if (is_font()) {
	write_font();
} else {
	write_symbol();
}

close SYM_FILE or die $!;

$writer->endTag("part");
$writer->end();
$output->close();

my $doc = XML::LibXML->new->parse_file($file);

my $xmlschema = XML::LibXML::Schema->new( location => "../part/part.xsd" );
eval { $xmlschema->validate( $doc ); };

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
	my %attributes;
	my $found_attribute = 0;

	while ($line = <SYM_FILE>) {
		if (!utf8::is_utf8($line)) {
			utf8::encode($line);
		}
		my @params = split(' ', $line);

		my $params_size = scalar @params;
		my @pass_params = splice(@params, 1, $params_size);

		if ($found_attribute) {
			my @attribute = split('=', $line);
			if ($attribute[0] eq "angle") {
				$attributes{'angle'} = trim($attribute[1]);
			} elsif ($attribute[0] eq "mirror") {
				$attributes{'mirror'} = (trim($attribute[1]) == 1) ? "mirrored" : "not-mirrored";
			} elsif ($attribute[0] eq "device") {
				$attributes{'device'} = trim($attribute[1]);
			} elsif ($attribute[0] eq "description") {
				$attributes{'description'} = trim($attribute[1]);
			} elsif ($attribute[0] eq "author") {
				$attributes{'author'} = trim($attribute[1]);
			} elsif ($attribute[0] eq "graphical") {
				$attributes{'graphical'} = (trim($attribute[1]) == 1) ? "true" : "false";
			} elsif ($attribute[0] eq "selectable") {
				$attributes{'selectable'} = (trim($attribute[1]) == 1) ? "selectable" : "not-selectable";
			}
		}

		if ($params[0] eq "v") {
			$attributes{'version'} = "@pass_params";
		} elsif ($params[0] eq "T") {
			$found_attribute=1;
			next;
		}
		$found_attribute=0;
	}

	my $curr_pos = tell(SYM_FILE);

	add_documentation();

	$writer->startTag("symbol",
			  %attributes);

	add_global_attributes();
	add_drawing_primatives();

	$writer->startTag("pins");
	add_pins();
	$writer->endTag("pins");

	seek(SYM_FILE, $curr_pos, 0);

	$writer->endTag("symbol");
}

sub is_font
{
	my $curr_pos = tell(SYM_FILE);
	seek(SYM_FILE, 0, 0);
	my @pass_params;
	my $found_font = 0;

	while ($line = <SYM_FILE>) {
		if (!utf8::is_utf8($line)) {
			utf8::encode($line);
		}
		my @params = split(' ', $line);

		my $params_size = scalar @params;

		@pass_params = splice(@params, 1, $params_size);

		if ($params[0] eq "F" && !$found_font) { # Line
			@pass_params = splice(@params, 1, $params_size);
			$found_font = 1;
		} elsif ($params[0] eq "F" && !$found_font) {
			print "Error: found extra font primative in $file. There should be only one.\n";
			exit();
		}
	}
	seek(SYM_FILE, $curr_pos, 0);
	return $found_font;
}

sub add_font
{
	seek(SYM_FILE, 0, 0);
	my @pass_params;
	my $found_font = 0;

	while ($line = <SYM_FILE>) {
		if (!utf8::is_utf8($line)) {
			utf8::encode($line);
		}
		my @params = split(' ', $line);

		my $params_size = scalar @params;

		@pass_params = splice(@params, 1, $params_size);

		if ($params[0] eq "F" && !$found_font) { # Line
			@pass_params = splice(@params, 1, $params_size);
			$found_font = 1;
		} elsif ($params[0] eq "F" && !$found_font) {
			print "Error: found extra font primative in $file. There should be only one.\n";
			exit();
		}
	}

	$writer->startTag("f",
			  "p" => join(" ",@pass_params));

	add_drawing_primatives();
	
	$writer->endTag("f");
	
}

sub add_documentation
{
	seek(SYM_FILE, 0, 0);
	my $found_subitem=0;
	my $found_text=0;
	my @pass_params;

	while ($line = <SYM_FILE>) {
		if (!utf8::is_utf8($line)) {
			utf8::encode($line);
		}
		my @params = split(' ', $line);

		my $params_size = scalar @params;
		my %attributes;

		if (!$found_subitem) {
			if ($found_text == 1) {
				# This is an attribute
				if ($line =~ m/=/) {
					my @attribute = split('=', $line);
					if ($attribute[0] eq "documentation") {
						$attributes{'uri'} = trim($attribute[1]);
						$writer->emptyTag("documentation",
			  					  %attributes);
					}
				}
				$found_text -= 1;
			}
		} else {
			if ($params[0] eq "}") {
				$found_subitem = 0;
			}
			next;
		}

		@pass_params = splice(@params, 1, $params_size);

		if ($params[0] eq "T") { # Text
			if ($#pass_params < 10) {
				$found_text = 1;
			} else {
				$found_text = $pass_params[$#pass_params];
			}
			next;
		} elsif ($params[0] eq "{") {
			$found_subitem=1;
			next;
		}
		$found_text=0;
	}
}


sub add_global_attributes
{
	seek(SYM_FILE, 0, 0);
	my $found_subitem=0;
	my $found_text=0;
	my @pass_params;

	while ($line = <SYM_FILE>) {
		if (!utf8::is_utf8($line)) {
			utf8::encode($line);
		}
		my @params = split(' ', $line);

		my $params_size = scalar @params;
		my %attributes;
		my @text_array;

		if (!$found_subitem) {
			if ($found_text == 1) {
				# This is an attribute
				if ($line =~ m/=/) {
					my @attribute = split('=', $line);
					if ($attribute[0] ne "angle" &&
					    $attribute[0] ne "mirror" &&
					    $attribute[0] ne "device" &&
					    $attribute[0] ne "description" &&
					    $attribute[0] ne "author" &&
					    $attribute[0] ne "graphical" &&
					    $attribute[0] ne "selectable" &&
					    $attribute[0] ne "documentation") {
						$attributes{'n'} = trim($attribute[0]);
						$attributes{'v'} = trim($attribute[1]);
						write_primative("gs:attr",\@pass_params,\%attributes);
					}
				}
				$found_text -= 1;
			}
		} else {
			if ($params[0] eq "}") {
				$found_subitem = 0;
			}
			next;
		}

		@pass_params = splice(@params, 1, $params_size);

		if ($params[0] eq "T") { # Text
			if ($#pass_params < 10) {
				$found_text = 1;
			} else {
				$found_text = $pass_params[$#pass_params];
			}
			next;
		} elsif ($params[0] eq "{") {
			$found_subitem=1;
			next;
		}
		$found_text=0;
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

sub add_pins
{
	seek(SYM_FILE, 0, 0);
	my $found_subitem=0;
	my $found_text=0;
	my @pass_params;
	my %attributes;

	while ($line = <SYM_FILE>) {
		if (!utf8::is_utf8($line)) {
			utf8::encode($line);
		}
		my @params = split(' ', $line);

		my $params_size = scalar @params;

		if ($found_subitem) {
			if ($params[0] eq "}") {
				write_primative("p",\@pass_params,\%attributes);
				$found_text = 0;
				$found_subitem = 0;
				next;
			}
			if ($found_text == 1) {
				# This is an attribute
				if ($line =~ m/=/) {
					my @attribute = split('=', $line);
					if ($attribute[0] eq "pinnumber") {
						$attributes{'number'} = trim($attribute[1]);
					} elsif ($attribute[0] eq "pinseq") {
						$attributes{'seq'} = trim($attribute[1]);
					} elsif ($attribute[0] eq "pinlabel") {
						$attributes{'label'} = trim($attribute[1]);
					} elsif ($attribute[0] eq "pintype") {
						$attributes{'type'} = trim($attribute[1]);
					}
				}
				$found_text -= 1;
			}
		}

		if ($params[0] eq "P") { # Pin
			@pass_params = splice(@params, 1, $params_size);
		} elsif ($params[0] eq "T") { # Text
			$found_text=1;
			next;
		} elsif ($params[0] eq "{") {
			$found_subitem=1;
			next;
		}
		$found_text=0;
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
