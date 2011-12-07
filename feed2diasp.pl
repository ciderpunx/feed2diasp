#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use autodie;
use 5.10.0;
use Data::Dumper;
use JSON;
use XML::Feed;
use WWW::Mechanize;
use HTML::Strip;
use Readonly;


Readonly my $CONFIGPATH => 'feed2diasp.json';
Readonly my $FEEDSSEEN  => 'feed2diasp-seen';

my $config = get_config();
my $mech   = do_diaspora_login($config);
# status_update($mech, "I is diasporizing an ting. What a gwan?"); # DEBUG

open my $in, '<:utf8', $FEEDSSEEN;
my @seen = <$in>;
close $in;

my %seen = map { chomp; $_ => 1 } @seen;

my $max_items = $config->{max_items};
my $new_items = 0;
for my $feed (@{$config->{feeds}}){
	my @feed_items = fetch_feed($feed);
	open my $out, ">>:utf8", $FEEDSSEEN;
	for(@feed_items) {
		next if ($seen{$feed . $_->id});
		my $msg = '';
		$msg .= format_msg($_->summary->body) if ($_->summary && $_->summary->body);
		$msg .= format_msg($_->content->body) if ($_->content && $_->content->body);
		$msg .= "\nRead more at: " 
				. $_->link if ($_->link);
		# say "Status update: " . $_->link . "\n" . $msg; # DEBUG
		$mech = status_update($config, $mech, $msg);
		$new_items++;
		print $out $feed . $_->id . "\n"; 
		last unless $new_items < $max_items;
	}
	close $out;
}

sub get_config {
	open my $in, '<:utf8', $CONFIGPATH;
	my @lines = <$in>;
	close $in;
	my $config = decode_json "@lines";
	#die Dumper $config; #DEBUG
	return $config;
}

sub do_diaspora_login {
	my $config = shift;
	my $login_url = "https://" . $config->{pod} . "/users/sign_in";
	my $mech = WWW::Mechanize->new();
  $mech->get($login_url);
	my $form = $mech->form_id('user_new');
	my $auth_token = $form->value('authenticity_token'); # not quite sure how this works. 
  my $res = $mech->submit_form(
        form_id			=> 'user_new',
        fields => {
            'user[password]'     => $config->{password},
            'user[username]'     => $config->{username},
            'authenticity_token' => $auth_token,
            'utf8'               => '✓',
            'user[remember_me]'  => 0,
            'commit'             => 'Sign in',
        },
  );
	die "Fuck it, can't login. Maybe you need to change the login details in $CONFIGPATH?" unless $res->is_success;
	
	return $mech;
}

sub status_update {
	my ($config,$mech,$msg) = (shift,shift,shift);
	my $form = $mech->form_id('new_status_message');
	my $auth_token = $form->value('authenticity_token');
	my $res = $mech->submit_form(
		form_id	=> 'new_status_message',
		fields	=> {
			'status_message[fake_text]' => $msg,
			'status_message[text]'			=> $msg,
      'utf8'											=> '✓',
			'commit'										=> 'Share',
			'aspect_ids[]'							=> 'all_aspects',
		}
	);
	warn "Fuck it, can't post $msg" unless $res->is_success;
	$mech->get("https://" . $config->{pod} . "/stream");
	return $mech;
}

sub fetch_feed {
	my $uri = shift;
	my $feed = XML::Feed->parse(URI->new($uri));
	return $feed->entries;
}

sub format_msg {
	my $msg = shift;
	my $hs = HTML::Strip->new();
	return $hs->parse( $msg );
}

__END__

=head1 NAME

feed2diasp.pl : Get a feed and squish it into diaspora.

=head2 VERSION

0.1

=head1 SYNOPSIS

Edit feed2diasp.json to set up your account details then just:

$ feed2diasp.pl 

You probably want to run this as a cronjob

=head1 DESCRIPTION

Install by untarring with 

$ tar xvzf feed2diasp.tar.gz

Then

$ cd feed2diasp

You'll need to make sure you have Perl 5.10.0 and the CPAN dependencies. 

$ sudo cpan XML::Feed Readonly HTML::Strip Data::Dumper WWW::Mechanize

Then copy the example config file and edit it to something more to your taste.

$ cp feed2diasp.json.example feed2diasp.json

You should make feed2diasp.pl executable wiith

$ chmod 750 feed2diasp.pl

Finally you can start updating your feed with

$ ./feed2diasp.pl

You may want to put that in a cron job.

=head2 OPTIONS

All options are set in feed2yaml.json . I used JSON rather than YAML to reduce dependencies

=head1 REQUIREMENTS

Perl 5.10.0 
Data::Dumper
JSON
XML::Feed
WWW::Mechanize
HTML::Strip
Readonly

=head1 COPYRIGHT AND LICENCE

           Copyright (C)2011 Charlie Harvey

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 
 2 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be 
 useful, but WITHOUT ANY WARRANTY; without even the implied 
 warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR 
 PURPOSE.  See the GNU General Public License for more 
 details.

 You should have received a copy of the GNU General Public 
 License along with this program; if not, write to the Free
 Software Foundation, Inc., 59 Temple Place - Suite 330,
 Boston, MA  02111-1307, USA.
 Also available on line: http://www.gnu.org/copyleft/gpl.html

=cut
