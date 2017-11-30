#!/usr/bin/perl -w
use strict;

use Net::GitHub;
use Data::Dumper::Concise;

my $oauth_token = qx(gpg --decrypt ../default.gpg 2>/dev/null);

my $gh = Net::GitHub->new( version      => 3,
                           login        => 'cjac',
                           access_token => $oauth_token );
my $repos = $gh->repos;

my @github_repos = $repos->list;
my %github_repo = map { $_->{name} => $_ } @github_repos;
print( "Existing GitHub repos:", join( $/, keys %github_repo ), $/ );

my ( @repo_list ) =
  split( $/, qx(ssh -p 29418 git.allseenalliance.org gerrit ls-projects) );

foreach my $repo ( @repo_list ) {
  next
    if $repo eq 'All-Users'
    or $repo eq 'uplusconn'
    or $repo eq 'test-sandbox'
    or $repo eq 'gateway-update';

  my $gerrit_url = 'ssh://git.allseenalliance.org:29418/' . ${repo};

  my $github_repo_name = $repo;
  $github_repo_name =~ s{/}{-}g;

  my $repo_dir = "${github_repo_name}.git";

  my $github_url = 'git@github.com:alljoyn/' . ${repo_dir};

  qx{git clone --bare "${gerrit_url}" "${repo_dir}"};
  chdir "${repo_dir}";

  my $attributes = {
              "name"        => $github_repo_name,
              "description" => "mirror of AllSeenAlliance gerrit project $repo",
              "homepage"    => "$gerrit_url",
              "license_template" => "apache-2.0",
              "org"              => "alljoyn", };

  if ( exists $github_repo{$github_repo_name} ) {

    # update
    $repos->set_default_user_repo( 'alljoyn', $github_repo_name );
    $repos->update( $attributes );
  } else {

    # create
    my $rp = $gh->repos->create( $attributes );
  }

  qx{git push --mirror "${github_url}"};
  chdir "..";
  qx{rm -rf "${repo_dir}"};

  #  exit;
}

