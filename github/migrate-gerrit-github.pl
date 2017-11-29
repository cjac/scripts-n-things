#!/usr/bin/perl -w
use strict;

use Net::GitHub;
use Data::Dumper::Concise;

my $oauth_token = qx(gpg --decrypt ../default.gpg 2>/dev/null);

use Net::GitHub;
my $gh = Net::GitHub->new( version      => 3,
                           login        => 'cjac',
                           access_token => $oauth_token );

my @github_repos = $gh->repos->list;
my @github_repo_names = map { $_->{name} } @github_repos;
print( "Existing GitHub repos:", join($/,@github_repo_names),$/);

my ( @repo_list ) =
  split( $/, qx(ssh -p 29418 git.allseenalliance.org gerrit ls-projects) );

foreach my $repo ( @repo_list ) {
  next if $repo eq 'All-Users';

  my $gerrit_url = 'ssh://git.allseenalliance.org:29418/' . ${repo};

  my $github_repo_name = $repo;
  $github_repo_name =~ s{/}{-}g;

  my $repo_dir = "${github_repo_name}.git";

  my $github_url = 'git@github.com:alljoyn/' . ${repo_dir};

  qx{git clone --bare "${gerrit_url}" "${repo_dir}"};
  chdir "${repo_dir}";

  unless ( grep { $_ eq $github_repo_name } @github_repo_names ) {
    my $rp = $gh->repos->create(
                        { "name"        => $github_repo_name,
                          "description" => "mirror of ASA gerrit project $repo",
                          "homepage"    => "$gerrit_url",
                          "license_template" => "apache-2.0",
                          "org"              => "alljoyn",
                        } );
  }

  qx{git push --mirror "${github_url}"};
  chdir "..";
  qx{rm -rf "${repo_dir}"};

  #  exit;
}

