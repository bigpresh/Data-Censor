#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Data::Censor;

plan tests => 5;

diag( "Testing Data::Censor $Data::Censor::VERSION, Perl $], $^X" );

sub get_data {
    return {
        name => 'David Precious',
        email => 'davidp@preshweb.co.uk',
        password => 'supersecret',
        card => {
            pan => '4929000000006',
            cvv => '123',
            expiry => '03/16',
        },
    };
}

# Basic stuff.
my $censor = Data::Censor->new;

my $data = get_data();
my $count = $censor->censor($data);
my $hidden = 'Hidden (looks potentially sensitive)';
is($count, 3, "Two items censored with default config");
is($data->{password}, $hidden, 'password field censored');
is($data->{email}, 'davidp@preshweb.co.uk', 'email field not censored');
is($data->{card}{pan}, $hidden, 'pan field censored (recursion works)');
is($data->{card}{expiry}, '03/16', 'expiry field not censored');
