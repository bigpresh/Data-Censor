#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Data::Censor;

plan tests => 9;

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

# Test replacement callback
$censor = Data::Censor->new(
    replacement_callbacks => {
        pan => sub {
            my $pan = shift;
            return "x" x (length($pan) - 4) 
                . substr($pan, -4, 4);
        },
    },
);
$data = get_data();
$count = $censor->censor($data);
is($data->{password}, $hidden, "password censored normally");
is ($data->{card}{pan}, 'xxxxxxxxx0006', "pan censored by callback");

# Test basic censored_data call
SKIP: {
    eval { require Clone };
    skip "Clone not installed", 2 if $@;
    my $censored_data = Data::Censor->censored_data(get_data());
    is($censored_data->{password}, $hidden, "censored_data password censored");
    is($censored_data->{email}, 'davidp@preshweb.co.uk',
        "censored_data email not censored");
}

