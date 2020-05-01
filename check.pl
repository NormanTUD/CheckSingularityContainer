#!/usr/bin/perl

use strict;
use warnings;
use LWP::Simple;
use Data::Dumper;
use Term::ANSIColor;
use Digest::MD5 qw/md5_hex/;

my %options = (
	debug => 0,
	recipe_file => undef,
	codename => undef,
	os => undef,
	arch => undef
);

analyze_args(@ARGV);

sub red (@) {
	my @args = @_;
	foreach (@args) {
		print color("red").$_.color("reset")."\n";
	}
}


sub debug (@) {
	my @args = @_;
	return unless $options{debug};
	foreach (@args) {
		warn "DEBUG: $_\n";
	}
}

main();

sub main {
	debug "main()";

	if(-e $options{recipe_file}) {
		my $contents = '';
		open my $fh, '<', $options{recipe_file};
		while (<$fh>) {
			$contents .= $_;
		}
		close $fh;
		my @apps = get_apt($contents);
		my @pip = get_pip($contents);

		foreach my $ta (@apps) {
			my $exists = package_exists($ta);
			if($exists == 0) {
				red "apt: $ta";
			}
		}

		foreach my $pa (@pip) {
			my $exists = pip_package_exists($pa);
			if($exists == 0) {
				red "pip3: $pa";
			}
		}
	} else {
		die "$options{recipe_file} not found";
	}
}

sub get_pip {
	my $contents = shift;
	my @pip = ();

	$contents =~ s#.*%post##gis;
	$contents =~ s#%environment.*##gis;
	$contents =~ s#\s+\\\s*[\n\r]##gis;
	foreach my $line (split(/\R/, $contents)) {
		if($line =~ m#pip3 install (.*)#) {
			my $install = $1;
			if($install !~ /^--/ && $install !~ /^-/) {
				push @pip, grep { m#.# } split(/\s+/, $install);
			}
		}
	}
	return @pip;
}

sub get_apt {
	my $contents = shift;
	my @apps = ();

	$contents =~ s#.*%post##gis;
	$contents =~ s#%environment.*##gis;
	$contents =~ s#\s+\\\s*[\n\r]##gis;
	foreach my $line (split(/\R/, $contents)) {
		if($line =~ m#apt-get\s*(?:.*)?\s*install(.*)#) {
			my $install = $1;
			push @apps, grep { m#.# } split(/\s+/, $install);
		}
	}
	return @apps;
}

sub pip_package_exists {
	my $package = shift;
	debug "pip_package_exists($package)";


	my $cache_file = "./cache/pip_".md5_hex($package);
	my $returns = 0;
	if(-e $cache_file) {
		#print "$cache_file\n";
		my $contents = '';
		open my $fh, '<', $cache_file or die $!;
		while (<$fh>) {
			$contents .= $_;
		}
		close $fh;
		$returns = $contents;
		chomp $returns;
	} else {
		my $command = "pip3 search $package";
		my $output = qx($command);
		my $retval = $?;

		my $exists = 0;

		if($retval == 0) {
			$exists = 1;
		} else {
			$exists = 0;
		}

		open my $fh, '>', $cache_file or die $!;
		print $fh $exists;
		close $fh;
		$returns = $exists;
	}

	return $returns;
}

sub package_exists {
	my $package = shift;
	debug "package_exists($package)";
	my $site = get_server().'/'.$package.'/download';
	my $page = myget($site);

	if(!$page) {
		$page = get($site);
		if(!$page) {
			return 0;
		}
	}

	if($page =~ m#\d+\sByte#) {
		return 1;
	} else {
		return 0;
	}
}

sub get_server {
	my $os = $options{os};
	my $codename = $options{codename};
	my $arch = $options{arch};

	if(!$os) {
		die "No OS name given";
	}

	if(!$codename) {
		die "No codename given";
	}

	if(!$arch) {
		die "No arch given";
	}

	if($os eq "ubuntu") {
		return "https://packages.ubuntu.com/de/$codename/$arch";
	}
}

sub analyze_args {
	my @args = @_;

	foreach (@args) {
		if(/^--debug$/) {
			$options{debug} = 1;
		} elsif (/^--recipe_file=(.*)$/) {
			$options{recipe_file} = $1;
		} elsif (/^--codename=(.*)$/) {
			$options{codename} = $1;
		} elsif (/^--os=(.*)$/) {
			$options{os} = $1;
		} elsif (/^--arch=(.*)$/) {
			$options{arch} = $1;
		} else {
			die "Unknown parameter $_";
		}
	}
}

sub myget {
	my $url = shift;

	my $cache = './cache/';
	my $cache_file = $cache.md5_hex($url);
	mkdir $cache unless -d $cache;

	my $contents = '';
	if(-e $cache_file) {
		open my $tfh, '<', $cache_file or die $!;
		while (<$tfh>) {
			$contents .= $_;
		}
		close $tfh;
	} else {
		$contents = get($url);
		if($contents) {
			open my $tfh, '>', $cache_file or die $!;
			print $tfh $contents;
			close $tfh;
		}
	}

	return $contents;
}
