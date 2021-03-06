#!/usr/bin/perl

package Sling::Search;

=head1 NAME

Search - search related functionality for Sakai implemented over rest
APIs.

=head1 ABSTRACT

Perl library providing a layer of abstraction to the REST search methods

=cut

#{{{imports
use strict;
use lib qw ( .. );
use Fcntl ':flock';
use Time::HiRes;
use Sling::Print;
use Sling::Request;
use Sling::SearchUtil;
#}}}

#{{{sub new

=pod

=head2 new

Create, set up, and return a Search object.

=cut

sub new {
    my ( $class, $url, $lwpUserAgent, $verbose, $log ) = @_;
    die "url not defined!" unless defined $url;
    die "no lwp user agent provided!" unless defined $lwpUserAgent;
    my $response;
    my $search = { BaseURL => "$url",
                   LWP => $lwpUserAgent,
		   Hits => 0,
		   Message => "",
		   Response => \$response,
		   TimeElapse => 0,
		   Verbose => $verbose,
		   Log => $log };
    bless( $search, $class );
    return $search;
}
#}}}

#{{{sub set_results
sub set_results {
    my ( $search, $hits, $message, $response, $timeElapse ) = @_;
    $search->{ 'Hits' } = $hits;
    $search->{ 'Message' } = $message;
    $search->{ 'Response' } = $response;
    $search->{ 'TimeElapse' } = $timeElapse;
    return 1;
}
#}}}

#{{{sub search
sub search {
    my ( $search, $searchTerm ) = @_;
    my $startTime = Time::HiRes::time;
    my $res = Sling::Request::request( \$search,
        Sling::SearchUtil::search_setup( $search->{ 'BaseURL' }, $searchTerm ) );
    my $endTime = Time::HiRes::time;
    my $timeElapse = $endTime - $startTime;
    if ( Sling::SearchUtil::search_eval( $res ) ) {
	my $hits = ($$res->content);
	$hits =~ s/.*?"total":([0-9]+).*/$1/;
	# Check hits total was correctly extracted:
	$hits = ( ( $hits =~ /^[0-9]+/ ) ? $hits : die "Problem calculating number of search hits!" );
	# TODO make timeElapse significant to about 3 decimal places only in printed output.
	my $message = Sling::Print::dateTime .
	    " Searching for \"$searchTerm\": Search OK. Found $hits hits. Time $timeElapse seconds.";
        $search->set_results( $hits, $message, $res, $timeElapse );
	return 1;
    }
    else {
        my $message = Sling::Print::dateTime . " Searching for \"$searchTerm\": Search failed!";
        $search->set_results( 0, $message, $res, $timeElapse );
	return 0;
    }
}
#}}}

#{{{sub search_all
sub search_all {
    my ( $search, $searchTerm ) = @_;
    $search->search( $search, $searchTerm, "/" );
}
#}}}

#{{{sub search_user
sub search_user {
    my ( $search, $searchTerm ) = @_;
    my $content = $search->search( $search, $searchTerm, "/_private" );
    my $firstName = $content;
    $firstName =~ s/.*"sakai:firstName":"([^"])*"/$1/;
    my $lastName = $content;
    $lastName =~ s/.*"sakai:lastName":"([^"])*"/$1/;
    print "FirstName: $firstName, LastName: $lastName\n";
}
#}}}

#{{{sub search_from_file
sub search_from_file {
    my ( $search, $file, $forkId, $numberForks ) = @_;
    $forkId = 0 unless defined $forkId;
    $numberForks = 1 unless defined $numberForks;
    my $count = 0;
    open ( FILE, $file );
    while ( <FILE> ) {
        if ( $forkId == ( $count++ % $numberForks ) ) {
            chomp;
	    $_ =~ /^(.*?)$/;
	    my $searchTerm = $1;
	    if ( $searchTerm !~ /^$/ ) {
                $search->search( $searchTerm );
		Sling::Print::print_result( $search );
	    }
	}
    }
    close ( FILE ); 
    return 1;
}
#}}}

1;
