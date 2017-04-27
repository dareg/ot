#! /usr/bin/perl

use strict;
use warnings;
use diagnostics;
use Gtk3 -init;
use Glib qw/TRUE FALSE/;
use List::MoreUtils qw(all any);
use List::Util qw (min);
use utf8;
use open qw(:std :utf8);
use File::Find;
use File::HomeDir;
use Encode qw(decode);

sub generate_db {
				my @directories_to_search = (File::HomeDir->my_home);

				sub preprocess {
								#rejects hidden directories
								return grep { -f or (-d and /^[^.]/) } @_;
				}

				sub wanted_closure {
								my @found = ();

								my $finder = sub { push @found, decode('UTF-8', $File::Find::name)};
								my $results = sub {@found};

								return ($finder, $results);
				}

				my ($wanted, $list_of_files) = wanted_closure();

				find({preprocess => \&preprocess, wanted => $wanted }, @directories_to_search);
				return $list_of_files->();
}

#First argument must be the file containing the list of files
#Other arguments are search keywords
sub get_list_of_match {
#This array is for searching anywhere in filepath or filename
				my @matches_anywhere;

#This array is for searching in the filename only
				my @matches_in_filename;

				my @results;
				my @list_of_files = generate_db();


#Push regex into the arrays
				foreach my $argnum (1 .. $#_) {
								my $word = $_[$argnum];
								push @matches_anywhere,qr/$word/i;
								push @matches_in_filename, qr/$word[^\/]*$/i;
				}

				foreach my $file (@list_of_files) {
								if ( all {$file =~ $_ } @matches_anywhere) {
												if ( any { $file =~ $_ } @matches_in_filename ) {
																push @results,$file
												}
								}
				}
				return @results
}

my $num_matches = 0;
my $max_matches = 20;
my @labels;

my $window = Gtk3::Window->new ('toplevel');
$window->signal_connect (delete_event => sub { Gtk3->main_quit });

my $box = Gtk3::Box->new("vertical", 2);
my $search_bar = Gtk3::SearchBar->new();
my $search_entry = Gtk3::SearchEntry->new();
my $scrolledwindow = Gtk3::ScrolledWindow->new();
my $listbox = Gtk3::ListBox->new();

foreach(my $i = 0; $i < $max_matches; $i++){
				push @labels, Gtk3::Label->new("");
				$listbox->insert($labels[$i], -1);
};

$listbox->set_filter_func(sub {
								my $row = $_[0];
								return ($num_matches != 0 && $row->get_index() < $num_matches);
				}
);

$scrolledwindow->add($listbox);
$box->pack_start($search_bar, FALSE, TRUE, 0);
$box->pack_start($scrolledwindow, TRUE, TRUE, 0);

$search_bar->add($search_entry);
$search_bar->connect_entry($search_entry);
$search_bar->set_search_mode(TRUE);
$search_entry->signal_connect("search-changed" => sub {
								my $string_of_args = $search_entry->get_text();
								my @args = split(' ', $string_of_args);
								print "[@args]\n";
								my @results = get_list_of_match("db_file.txt", @args);
								$num_matches = scalar @results;
								print "$num_matches results\n";
								for(my $i = 0; $i < min ($num_matches, $max_matches); $i++){
												my $s = "$results[$i]";
												print "res:$s";
												$labels[$i]->set_text("$s");
								};
								$listbox->invalidate_filter();
				}
);

$listbox->signal_connect("row-activated" => sub {
								my $row = $_[1];
								my $label = $row->get_child();
								my $selected_file = $label->get_text();
								exec("xdg-open \"$selected_file\"");
				},
);

$window->add($box);
$window->show_all();
Gtk3::main;
